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
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header ───────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.signature")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.amber)
                Text("SIGN-OFF REQUIRED")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(2)
                Spacer()
                StatusPill(label: unlockStatus.label, color: statusColor)
            }

            Divider().background(colors.border)

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
                .foregroundColor(colors.amber)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(colors.danger)
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.amber.opacity(0.3), lineWidth: 1))
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
        case .complete:           return colors.green
        case .jumpFailed:         return colors.danger
        case .awaitingInstructor,
             .awaitingJump:       return colors.amber
        default:                  return colors.muted
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
    @Environment(\.mdzColors) private var colors

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
                    .foregroundColor(colors.text)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
                if let rec = record {
                    Text(rec.result == "approved" ? "Approved" : "Failed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(rec.result == "approved" ? colors.green : colors.danger)
                } else if isPending {
                    Text("Pending...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.amber)
                } else {
                    Text("Not yet signed")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
            }
            Spacer()
        }
    }

    private var circleColor: Color {
        guard let rec = record else { return isPending ? colors.amber : colors.muted }
        return rec.result == "approved" ? colors.green : colors.danger
    }
}

struct RequestButton: View {
    let label: String
    let action: () -> Void
    @Environment(\.mdzColors) private var colors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(colors.background)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(colors.amber)
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
    @Environment(\.mdzColors) private var colors

    var body: some View {
        NavigationView {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text(requestType == "instructor_ready"
                         ? "I've completed all lessons and hands-on training for this module and I'm ready to jump."
                         : "Request jump sign-off from your instructor.")
                        .font(.system(size: 14))
                        .foregroundColor(colors.text)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note (optional)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colors.muted)
                        TextEditor(text: $noteText)
                            .frame(height: 100)
                            .padding(8)
                            .background(colors.card)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
                            .foregroundColor(colors.text)
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
                        .background(colors.amber)
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
                        .foregroundColor(colors.amber)
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
