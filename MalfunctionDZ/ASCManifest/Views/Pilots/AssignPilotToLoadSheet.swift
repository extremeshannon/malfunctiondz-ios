import SwiftUI

struct AssignPilotToLoadSheet: View {
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    let pilot: ManifestPilotCard

    @State private var selectedLoadID: Int?
    @State private var role = "pic"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var needsOverride = false
    @State private var overrideNote = ""

    private let roles: [(id: String, label: String)] = [
        ("pic", "PIC"),
        ("second", "Second PIC"),
        ("training", "Training pilot"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Assign \(pilot.resolvedName) to a load for \(store.selectedDate.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Load") {
                    if store.loads.isEmpty {
                        Text("No loads today. Create a load on Load Manager first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.loads) { load in
                            Button {
                                selectedLoadID = load.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(loadLabel(load))
                                        if let status = load.status {
                                            Text(status.capitalized)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedLoadID == load.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NightOps.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Role") {
                    Picker("Role", selection: $role) {
                        ForEach(roles, id: \.id) { item in
                            Text(item.label).tag(item.id)
                        }
                    }
                }

                if needsOverride {
                    Section("Compliance override") {
                        TextField("Override note (required)", text: $overrideNote, axis: .vertical)
                            .lineLimit(2...4)
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
            .navigationTitle("Assign to load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || selectedLoadID == nil)
                }
            }
        }
    }

    private func loadLabel(_ load: ManifestLoad) -> String {
        let plane = (load.aircraft ?? "").trimmingCharacters(in: .whitespaces)
        if plane.isEmpty {
            return "Load #\(load.id)"
        }
        return "Load #\(load.id) · \(plane)"
    }

    private func save() async {
        guard let loadID = selectedLoadID else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let ok = await store.assignPilot(
            loadID: loadID,
            userID: pilot.user_id,
            displayName: pilot.resolvedName,
            role: role,
            override: needsOverride,
            overrideNote: overrideNote
        )
        if ok {
            dismiss()
            return
        }
        errorMessage = store.errorMessage
        if (errorMessage ?? "").localizedCaseInsensitiveContains("override")
            || (errorMessage ?? "").localizedCaseInsensitiveContains("checked in")
            || (errorMessage ?? "").localizedCaseInsensitiveContains("waiver")
            || (errorMessage ?? "").localizedCaseInsensitiveContains("medical") {
            needsOverride = true
        }
    }
}
