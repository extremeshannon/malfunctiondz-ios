import SwiftUI

/// Modal for failed check-in — lists compliance blockers and offers prep + override (web Load Manager parity).
struct CheckInBlockedSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    @State var context: CheckInBlockedContext
    var onResolved: () -> Void

    @State private var isBusy = false

    private var canSaveAndRetry: Bool {
        context.showSkydiverPrep || context.showTandemPrep || context.rentingAllowed
            || (context.overrideAllowed && context.needsPayment)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(context.personName)
                        .font(.headline)
                    Text("The following must be resolved before this person can check in:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Missing / blocking") {
                    ForEach(Array(context.reasons.enumerated()), id: \.offset) { _, reason in
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(NightOps.danger)
                    }
                }

                if context.rentingAllowed || context.showSkydiverPrep {
                    Section("Desk prep") {
                        if context.rentingAllowed {
                            Toggle("Renting a DZ rig", isOn: $context.rentingDzRig)
                        }
                        if context.showSkydiverPrep {
                            Toggle("ID checked", isOn: $context.idChecked)
                            Toggle("Signed affidavit", isOn: $context.affidavitSigned)
                            Toggle("DZ briefing", isOn: $context.dzBriefing)
                        }
                    }
                }

                if context.showTandemPrep {
                    Section("Tandem desk prep") {
                        Toggle("Waiver signed", isOn: $context.waiverSigned)
                        Toggle("ID checked", isOn: $context.idChecked)
                        Toggle("Watched video", isOn: $context.videoWatched)
                        Toggle("Signed affidavit", isOn: $context.affidavitSigned)
                        Toggle("Trained / briefing complete", isOn: $context.trainingComplete)
                    }
                }

                if context.needsPayment || context.payLabel != nil {
                    Section("Payment") {
                        if let label = context.payLabel, !label.isEmpty {
                            Text(label + (context.needsPayment ? " due" : ""))
                                .font(.subheadline)
                                .foregroundStyle(context.needsPayment ? NightOps.danger : .secondary)
                        }
                        if context.needsPayment {
                            Toggle("Mark paid at desk (cash / card)", isOn: $context.markPaid)
                        }
                        if context.overrideAllowed && context.needsPayment {
                            TextField(
                                "Payment override note (required if unpaid)",
                                text: $context.overrideNote,
                                axis: .vertical
                            )
                            .lineLimit(2...4)
                        }
                    }
                } else if context.overrideAllowed {
                    Section("Override") {
                        Text("You can acknowledge and override remaining blockers with a note.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Override note", text: $context.overrideNote, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                if let statusMessage = context.statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(NightOps.danger)
                    }
                }

                Section {
                    if canSaveAndRetry {
                        Button {
                            Task { await saveAndCheckIn() }
                        } label: {
                            if isBusy {
                                ProgressView()
                            } else {
                                Text(primaryActionTitle)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isBusy)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NightOps.navy)
            .navigationTitle("Cannot check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("OK") { dismiss() }
                        .disabled(isBusy)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var primaryActionTitle: String {
        if context.overrideAllowed && context.needsPayment && !context.markPaid {
            return "Confirm override & check in"
        }
        return "Save and check in"
    }

    private func saveAndCheckIn() async {
        isBusy = true
        context.statusMessage = nil
        defer { isBusy = false }

        do {
            switch context.kind {
            case .jumper(let userID):
                let prep = try await session.apiClient.updateCheckInPrep(
                    userID: userID,
                    idChecked: context.idChecked,
                    affidavitSigned: context.affidavitSigned,
                    dzBriefing: context.dzBriefing
                )
                if !prep.ok {
                    context.statusMessage = prep.error ?? "Could not save prep."
                    if let reasons = prep.compliance_reasons, !reasons.isEmpty {
                        context.reasons = reasons
                    }
                    return
                }
                let response = try await session.apiClient.checkInUser(
                    userID: userID,
                    date: store.selectedDate,
                    rentingDzRig: context.rentingDzRig
                )
                if response.ok {
                    onResolved()
                    dismiss()
                    return
                }
                context.apply(response: response)
                context.statusMessage = response.error ?? "Still blocked."

            case .tandem(let tandemID):
                let prep = try await session.apiClient.updateTandemCheckInPrep(
                    tandemStudentID: tandemID,
                    waiverSigned: context.waiverSigned,
                    idChecked: context.idChecked,
                    videoWatched: context.videoWatched,
                    affidavitSigned: context.affidavitSigned,
                    trainingComplete: context.trainingComplete
                )
                if !prep.ok {
                    context.statusMessage = prep.error ?? "Could not save tandem prep."
                    if let reasons = prep.compliance_reasons, !reasons.isEmpty {
                        context.reasons = reasons
                    }
                    return
                }

                let note = context.overrideNote.trimmingCharacters(in: .whitespacesAndNewlines)
                let wantsOverride = context.overrideAllowed && context.needsPayment && !context.markPaid
                if wantsOverride && note.isEmpty {
                    context.statusMessage = "Override note is required to check in an unpaid tandem."
                    return
                }

                let response = try await session.apiClient.checkInTandemStudent(
                    tandemStudentID: tandemID,
                    date: store.selectedDate,
                    markPaid: context.markPaid,
                    acknowledgeOverride: wantsOverride,
                    overrideNote: note
                )
                if response.ok {
                    onResolved()
                    dismiss()
                    return
                }
                context.apply(response: response)
                context.statusMessage = response.error ?? "Still blocked."
            }
        } catch {
            context.statusMessage = error.localizedDescription
        }
    }
}
