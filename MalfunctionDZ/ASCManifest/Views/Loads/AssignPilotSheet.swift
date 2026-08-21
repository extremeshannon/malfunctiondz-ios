import SwiftUI

struct AssignPilotSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    let loadID: Int
    var onSaved: () -> Void

    @State private var query = ""
    @State private var results: [SearchPerson] = []
    @State private var selectedID: Int?
    @State private var selectedName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var needsOverride = false
    @State private var overrideNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("PIC must have the Pilot role and usually be checked in. Waiver/medical blocks can be overridden with a note if you have permission.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Checked in today") {
                    if store.checkedIn.isEmpty {
                        Text("Nobody is checked in yet. Check in a pilot first, or search below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.checkedIn) { user in
                            Button {
                                selectedID = user.user_id
                                selectedName = user.resolvedName
                            } label: {
                                HStack {
                                    Text(user.resolvedName)
                                    Spacer()
                                    if selectedID == user.user_id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NightOps.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Or search") {
                    TextField("Name or username (try pilot1)", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, newValue in
                            Task { await search(query: newValue) }
                        }
                    ForEach(results) { person in
                        Button {
                            selectedID = person.user_id ?? person.id
                            selectedName = person.displayName
                        } label: {
                            HStack {
                                Text(person.displayName)
                                Spacer()
                                if selectedID == (person.user_id ?? person.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(NightOps.accent)
                                }
                            }
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
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Assign PIC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") { Task { await save() } }
                        .disabled(isSaving || selectedID == nil)
                }
            }
            .task {
                await store.refreshCheckIns()
            }
        }
    }

    private func search(query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            results = []
            return
        }
        do {
            let response = try await session.apiClient.searchJumpers(query: q)
            results = response.people ?? []
        } catch {
            results = []
        }
    }

    private func save() async {
        guard let selectedID else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let ok = await store.assignPilot(
            loadID: loadID,
            userID: selectedID,
            displayName: selectedName,
            override: needsOverride,
            overrideNote: overrideNote
        )
        if ok {
            onSaved()
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
