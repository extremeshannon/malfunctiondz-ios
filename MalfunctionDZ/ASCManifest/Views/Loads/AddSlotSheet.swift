import SwiftUI

struct AddSlotSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    let loadID: Int
    var onSaved: () -> Void

    @State private var jumperQuery = ""
    @State private var tandemQuery = ""
    @State private var jumperResults: [SearchPerson] = []
    @State private var tandemResults: [SearchPerson] = []
    @State private var selectedPerson: BoardPerson?
    @State private var jumpType = ManifestJumpType.solo
    @State private var displayName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedJumpTypeHint: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Jumpers and tandem passengers must usually be checked in first. ASP students and tandems require an instructor when added.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Checked in today") {
                    if store.checkedIn.isEmpty && store.checkedInTandem.isEmpty {
                        Text("Check people in on the left first, or search below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.checkedIn) { user in
                        pickRow(
                            BoardPerson.user(id: user.user_id, name: user.resolvedName),
                            jumpHint: nil
                        )
                    }
                    ForEach(store.checkedInTandem) { student in
                        pickRow(
                            BoardPerson.tandem(id: student.tandemID, name: student.resolvedName),
                            jumpHint: ManifestJumpType.tandem.rawValue
                        )
                    }
                }

                Section("Or search jumpers") {
                    TextField("Name or username", text: $jumperQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: jumperQuery) { _, newValue in
                            Task { await searchJumpers(query: newValue) }
                        }
                    ForEach(jumperResults) { person in
                        pickRow(
                            BoardPerson.user(id: person.user_id ?? person.id, name: person.displayName),
                            jumpHint: person.next_jump_type,
                            kind: person.kind
                        )
                    }
                }

                Section("Or search tandem passengers") {
                    TextField("Tandem student name", text: $tandemQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: tandemQuery) { _, newValue in
                            Task { await searchTandem(query: newValue) }
                        }
                    ForEach(tandemResults) { person in
                        let tandemID = person.tandem_student_id ?? person.id
                        pickRow(
                            BoardPerson.tandem(id: tandemID, name: person.displayName),
                            jumpHint: ManifestJumpType.tandem.rawValue,
                            kind: "tandem"
                        )
                    }
                }

                Section("Slot") {
                    TextField("Display name", text: $displayName)
                    if selectedPerson?.isTandem != true {
                        Picker("Jump type", selection: $jumpType) {
                            ForEach(ManifestJumpType.allCases) { jt in
                                Text(jt.label).tag(jt)
                            }
                        }
                    } else {
                        LabeledContent("Jump type", value: "TANDEM")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Add Jumper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty || selectedPerson == nil)
                }
            }
            .task {
                await store.refreshCheckIns()
                await searchTandem(query: "")
            }
        }
    }

    @ViewBuilder
    private func pickRow(_ person: BoardPerson, jumpHint: String?, kind: String? = nil) -> some View {
        Button {
            selectedPerson = person
            displayName = person.name
            selectedJumpTypeHint = jumpHint
            if person.isTandem {
                jumpType = .tandem
            }
        } label: {
            HStack {
                Text(person.name)
                if person.isTandem || (kind ?? "").lowercased() == "tandem" {
                    Text("Tandem")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
                Spacer()
                if selectedPerson == person {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(NightOps.accent)
                }
            }
        }
    }

    private func searchJumpers(query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            jumperResults = []
            return
        }
        do {
            let response = try await session.apiClient.searchJumpers(query: q)
            jumperResults = response.people ?? []
        } catch {
            jumperResults = []
        }
    }

    private func searchTandem(query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            tandemResults = []
            return
        }
        do {
            let response = try await session.apiClient.searchTandemStudents(query: q)
            tandemResults = response.people ?? []
        } catch {
            tandemResults = []
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        guard let person = selectedPerson else {
            errorMessage = "Pick someone first."
            return
        }
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let boardPerson = BoardPerson(
            id: person.id,
            name: trimmedName,
            tandemStudentID: person.tandemStudentID
        )
        let hint = person.isTandem
            ? ManifestJumpType.tandem.rawValue
            : (selectedJumpTypeHint ?? jumpType.rawValue)
        let added = await store.prepareStudentAdd(loadID: loadID, person: boardPerson, jumpTypeHint: hint)
        if store.pendingStudentAdd != nil {
            dismiss()
            return
        }
        if added {
            onSaved()
            dismiss()
            return
        }
        errorMessage = store.errorMessage
    }
}
