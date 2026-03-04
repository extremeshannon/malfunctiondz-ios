// File: MalfunctionDZ/Views/Calendar/DZStatusUpdateView.swift
// Admin/Ops: Update DZ status and send push notifications. Navigate from Home banner.
import SwiftUI

struct DZStatusUpdateView: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?
    @State private var status: String = "open"
    @State private var announcement: String = ""
    @State private var loading = false
    @State private var saving = false
    @State private var currentStatus: DZStatus?
    @State private var lastError: String?
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Update drop zone status. All app users with notifications on will receive a push.")
                        .font(.system(size: isWide ? 14 : 13))
                        .foregroundColor(.mdzMuted)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("STATUS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.mdzMuted)
                            .tracking(1.5)
                        Picker("Status", selection: $status) {
                            Text("DZ Open").tag("open")
                            Text("DZ Closed").tag("closed")
                            Text("Announcement").tag("announcement")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ANNOUNCEMENT (optional)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.mdzMuted)
                            .tracking(1.5)
                        TextField("e.g. Closed today due to weather", text: $announcement, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(.mdzText)
                            .padding(14)
                            .lineLimit(3...6)
                            .background(Color.mdzCard)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
                    }

                    if let err = lastError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.mdzDanger)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if saving {
                                ProgressView().tint(.white).scaleEffect(0.9)
                            } else {
                                Text("Update Status & Notify")
                                    .font(.system(size: isWide ? 16 : 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isWide ? 52 : 48)
                        .background(Color.mdzRed)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(saving)
                }
                .padding(isWide ? 24 : 16)
            }
            .refreshable { await loadCurrent() }
        }
        .navigationTitle("DZ Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .task { await loadCurrent() }
    }

    private func loadCurrent() async {
        loading = true
        defer { loading = false }
        do {
            currentStatus = try await CalendarAPIService.shared.fetchDzStatus()
            if let s = currentStatus {
                status = s.status
                announcement = s.announcement ?? ""
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func save() async {
        lastError = nil
        saving = true
        defer { saving = false }
        do {
            _ = try await CalendarAPIService.shared.updateDzStatus(
                status: status,
                announcement: announcement.isEmpty ? nil : announcement
            )
            await MainActor.run {
                onSaved?()
                dismiss()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
