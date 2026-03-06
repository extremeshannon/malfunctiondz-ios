// File: MalfunctionDZ/Views/Calendar/DZStatusUpdateView.swift
// Admin/Ops: DZ status = Open/Closed (modal). Announcements = separate modal. Push still sent from API when updated from app.

import SwiftUI

// MARK: - Status modal (Open / Closed only)
struct DZStatusModalView: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?
    @State private var status: String = "open"
    @State private var saving = false
    @State private var lastError: String?
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Set drop zone status. App users with notifications on will receive a push when their device is locked.")
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
                        }
                        .pickerStyle(.segmented)
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
                                Text("Update Status")
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
                    Spacer()
                }
                .padding(isWide ? 24 : 16)
            }
            .navigationTitle("DZ Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.mdzAmber)
                }
            }
            .task { await loadCurrent() }
        }
    }

    private func loadCurrent() async {
        do {
            let current = try await CalendarAPIService.shared.fetchDzStatus()
            // Show open/closed only; if current is "announcement" default to closed
            status = (current.status == "open") ? "open" : "closed"
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func save() async {
        lastError = nil
        saving = true
        defer { saving = false }
        do {
            _ = try await CalendarAPIService.shared.updateDzStatus(status: status, announcement: nil)
            await MainActor.run {
                onSaved?()
                dismiss()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}

// MARK: - Announcement modal (send announcement; sets status to "announcement" with message)
struct DZAnnouncementModalView: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?
    @State private var announcement: String = ""
    @State private var saving = false
    @State private var lastError: String?
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Send an announcement to all app users with notifications on (when their device is locked).")
                        .font(.system(size: isWide ? 14 : 13))
                        .foregroundColor(.mdzMuted)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ANNOUNCEMENT")
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
                        Task { await send() }
                    } label: {
                        HStack {
                            if saving {
                                ProgressView().tint(.white).scaleEffect(0.9)
                            } else {
                                Text("Send Announcement")
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
                    .disabled(saving || announcement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }
                .padding(isWide ? 24 : 16)
            }
            .navigationTitle("Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.mdzAmber)
                }
            }
        }
    }

    private func send() async {
        lastError = nil
        saving = true
        defer { saving = false }
        let text = announcement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            _ = try await CalendarAPIService.shared.updateDzStatus(status: "announcement", announcement: text)
            await MainActor.run {
                onSaved?()
                dismiss()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
