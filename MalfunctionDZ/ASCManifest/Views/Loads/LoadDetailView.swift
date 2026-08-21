import SwiftUI

struct LoadDetailView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    let load: ManifestLoad

    @State private var slots: [ManifestSlot] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddSlot = false
    @State private var showAssignPilot = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Aircraft", value: load.aircraft ?? "—")
                    LabeledContent("Time", value: load.time ?? "—")
                    LabeledContent("Status") {
                        ManifestStatusPill(status: load.statusKey)
                    }
                    LabeledContent("Slots", value: load.slotCountLabel)
                    LabeledContent("PIC") {
                        Text(store.pilotName(for: load) ?? "Not assigned")
                    }
                    if load.pilot_user_id == nil {
                        Text("This load needs a pilot before you can Call / Advance.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Button("Assign PIC…") {
                        showAssignPilot = true
                    }
                }

                Section("Jumpers") {
                    if isLoading {
                        ProgressView()
                    } else if slots.isEmpty {
                        Text("No jumpers on this load yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(slots) { slot in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(slot.name)
                                        .font(.headline)
                                    JumpTypeBadge(jumpType: slot.jump_type ?? "solo")
                                }
                                Spacer()
                                if slot.hasWarning {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.yellow)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await removeSlot(slot) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Load \(load.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSlot = true
                    } label: {
                        Label("Add Jumper", systemImage: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if load.statusKey.next != nil {
                        Button("Advance to \(load.statusKey.next!.label)") {
                            Task {
                                await store.advanceStatus(load: load)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(NightOps.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSlot) {
                AddSlotSheet(loadID: load.id) {
                    Task { await reloadSlots() }
                }
            }
            .sheet(isPresented: $showAssignPilot) {
                AssignPilotSheet(loadID: load.id) {
                    Task {
                        await store.refresh()
                        await reloadSlots()
                    }
                }
            }
            .task { await reloadSlots() }
        }
    }

    private func reloadSlots() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await session.apiClient.fetchSlots(loadID: load.id)
            if response.ok {
                slots = response.slots ?? []
            } else {
                errorMessage = response.error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeSlot(_ slot: ManifestSlot) async {
        do {
            _ = try await session.apiClient.deleteSlot(slotID: slot.id)
            await reloadSlots()
            await store.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
