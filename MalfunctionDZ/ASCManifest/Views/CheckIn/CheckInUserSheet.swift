import SwiftUI

struct CheckInUserSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    let user: EligibleUser
    var onChanged: () -> Void

    @State private var idChecked = false
    @State private var affidavitSigned = false
    @State private var dzBriefing = false
    @State private var statusMessage: String?
    @State private var isBusy = false
    @State private var isCheckedIn = false
    @State private var blockedCheckIn: CheckInBlockedContext?

    @State private var showIDScan = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(user.name ?? "User \(user.id)")
                        .font(.headline)
                    if isCheckedIn {
                        Label("Checked in today", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section("Prep (desk checklist)") {
                    Toggle("ID checked", isOn: $idChecked)
                    Toggle("Affidavit signed", isOn: $affidavitSigned)
                    Toggle("DZ briefing complete", isOn: $dzBriefing)
                    Button("Scan ID (PDF417)") {
                        showIDScan = true
                    }
                    Button("Save prep") {
                        Task { await savePrep() }
                    }
                    .disabled(isBusy)
                }

                Section {
                    Button("Check in for today") {
                        Task { await checkIn() }
                    }
                    .disabled(isBusy || isCheckedIn)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(statusMessage.contains("success") || statusMessage.contains("Checked") ? .green : .secondary)
                    }
                }
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onChanged()
                        dismiss()
                    }
                }
            }
            .task { await loadState() }
            .sheet(item: $blockedCheckIn) { ctx in
                CheckInBlockedSheet(context: ctx) {
                    isCheckedIn = true
                    statusMessage = "Checked in successfully."
                    onChanged()
                }
            }
            .sheet(isPresented: $showIDScan) {
                IDScanView(userID: user.id) { _, idChecked in
                    if idChecked { self.idChecked = true }
                    Task { await savePrep() }
                }
            }
        }
    }

    private func loadState() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let list = try await session.apiClient.fetchCheckInList(date: store.selectedDate)
            isCheckedIn = (list.users ?? []).contains { $0.id == user.id }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func savePrep() async {
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        do {
            let prep = try await session.apiClient.updateCheckInPrep(
                userID: user.id,
                idChecked: idChecked,
                affidavitSigned: affidavitSigned,
                dzBriefing: dzBriefing
            )
            if prep.ok {
                statusMessage = "Prep saved."
                if let remaining = prep.compliance_reasons, !remaining.isEmpty {
                    statusMessage = "Prep saved — \(remaining.count) item(s) still blocking check-in."
                }
            } else {
                statusMessage = prep.error ?? "Could not save prep."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func checkIn() async {
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        do {
            let response = try await session.apiClient.checkInUser(
                userID: user.id,
                date: store.selectedDate
            )
            if response.ok {
                isCheckedIn = true
                statusMessage = "Checked in successfully."
                onChanged()
            } else {
                blockedCheckIn = .from(
                    response: response,
                    kind: .jumper(userID: user.id),
                    personName: user.name ?? "User \(user.id)"
                )
                // Prefill from current desk toggles when API prep is empty
                if var ctx = blockedCheckIn {
                    if ctx.showSkydiverPrep {
                        if !ctx.idChecked { ctx.idChecked = idChecked }
                        if !ctx.affidavitSigned { ctx.affidavitSigned = affidavitSigned }
                        if !ctx.dzBriefing { ctx.dzBriefing = dzBriefing }
                    }
                    blockedCheckIn = ctx
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
