// File: ASC/Views/GroundSchool/ModuleSignoffBlock.swift
// Purpose: Displays the sign-off block at the bottom of a module — shows instructor ready
//          and jump result sign-off status, and allows students to request sign-offs.
import SwiftUI

struct ModuleSignoffBlock: View {
    let courseId: Int
    let moduleId: Int
    let signoffBlock: LMSSignoffBlock
    let unlockStatus: ModuleUnlockStatus
    var onRequestSent: (() -> Void)? = nil

    @State private var showRequestSheet = false
    @State private var requestType: String = ""
    @State private var noteText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header ───────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.signature")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mdzAmber)
                Text("SIGN-OFF REQUIRED")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzAmber)
                    .tracking(2)
                Spacer()
                StatusPill(label: unlockStatus.label, color: statusColor)
            }

            Divider().background(Color.mdzBorder)

            // ── Instructor Ready ──────────────────────────────
            SignoffRow(
                icon: "person.badge.clock",
                title: "Instructor Sign-Off",
                subtitle: "Instructor reviews module & confirms jump readiness",
                record: signoffBlock.instructorReady,
                isPending: signoffBlock.pendingRequest == "instructor_ready"
            )

            // ── Jump Result ───────────────────────────────────
            SignoffRow(
                icon: "parachute.fill",
                title: "Jump Sign-Off",
                subtitle: "Actual skydive — pass to unlock next module",
                record: signoffBlock.jumpResult,
                isPending: signoffBlock.pendingRequest == "jump_result"
            )

            // ── Request buttons ───────────────────────────────
            if signoffBlock.canRequestInstructor {
                RequestButton(label: "Notify Instructor I'm Ready") {
                    requestType = "instructor_ready"
                    showRequestSheet = true
                }
            }

            if signoffBlock.canRequestJump {
                RequestButton(label: "Request Jump Sign-Off") {
                    requestType = "jump_result"
                    showRequestSheet = true
                }
            }

            if let pending = signoffBlock.pendingRequest {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(pending == "instructor_ready" ? "Waiting for instructor review..." : "Waiting for jump sign-off...")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.mdzAmber)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.mdzDanger)
            }
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzAmber.opacity(0.3), lineWidth: 1))
        .sheet(isPresented: $showRequestSheet) {
            SignoffRequestSheet(
                requestType: requestType,
                noteText: $noteText,
                isSubmitting: $isSubmitting,
                onSubmit: submitRequest,
                onCancel: { showRequestSheet = false }
            )
        }
    }

    private var statusColor: Color {
        switch unlockStatus {
        case .complete:           return .mdzGreen
        case .jumpFailed:         return .mdzDanger
        case .awaitingInstructor,
             .awaitingJump:       return .mdzAmber
        default:                  return .mdzMuted
        }
    }

    private func submitRequest() {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/signoff.php") else { return }

        isSubmitting = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "course_id":    courseId,
            "module_id":    moduleId,
            "request_type": requestType,
            "note":         noteText,
        ])
        let req = request

        Task {
            defer { isSubmitting = false }
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let resp = try JSONDecoder().decode([String: AnyCodable].self, from: data)
                await MainActor.run {
                    showRequestSheet = false
                    noteText = ""
                    onRequestSent?()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Sub-views

struct SignoffRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let record: LMSSignoffRecord?
    let isPending: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(circleColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: record != nil ? (record!.result == "approved" ? "checkmark" : "xmark") : (isPending ? "clock" : icon))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(circleColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mdzText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.mdzMuted)
                if let rec = record {
                    Text(rec.result == "approved" ? "Approved" : "Failed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(rec.result == "approved" ? .mdzGreen : .mdzDanger)
                } else if isPending {
                    Text("Pending...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.mdzAmber)
                } else {
                    Text("Not yet signed")
                        .font(.system(size: 11))
                        .foregroundColor(.mdzMuted)
                }
            }
            Spacer()
        }
    }

    private var circleColor: Color {
        guard let rec = record else { return isPending ? .mdzAmber : .mdzMuted }
        return rec.result == "approved" ? .mdzGreen : .mdzDanger
    }
}

struct RequestButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.mdzBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color.mdzAmber)
            .cornerRadius(8)
        }
    }
}

struct SignoffRequestSheet: View {
    let requestType: String
    @Binding var noteText: String
    @Binding var isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text(requestType == "instructor_ready"
                         ? "I've completed all lessons and hands-on training for this module and I'm ready to jump."
                         : "Request jump sign-off from your instructor.")
                        .font(.system(size: 14))
                        .foregroundColor(.mdzText)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note (optional)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.mdzMuted)
                        TextEditor(text: $noteText)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.mdzCard)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
                            .foregroundColor(.mdzText)
                    }

                    Button {
                        onSubmit()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Sending..." : "Send Request")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.mdzAmber)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(requestType == "instructor_ready" ? "Request Instructor Sign-Off" : "Request Jump Sign-Off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.mdzAmber)
                }
            }
        }
    }
}

// Minimal AnyCodable for response decoding
struct AnyCodable: Codable {
    init(from decoder: Decoder) throws {
        _ = try? decoder.singleValueContainer()
    }
    func encode(to encoder: Encoder) throws {}
}
