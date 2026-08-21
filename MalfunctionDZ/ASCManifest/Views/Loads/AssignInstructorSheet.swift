import SwiftUI

struct AssignInstructorSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    let pending: PendingStudentAdd
    var onSaved: () -> Void

    @State private var instructors: [InstructorCandidate] = []
    @State private var query = ""
    @State private var primaryID: Int?
    @State private var secondID: Int?
    @State private var videoChoice: VideoAssignment = .none
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var needsVideo: Bool {
        InstructorPairing.needsVideo(for: pending.jumpType)
    }

    private var videoCandidates: [CheckedInUser] {
        store.checkedIn.filter { user in
            let id = user.user_id
            if id == primaryID || id == secondID { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Assign instructor(s) before adding \(pending.person.name) to the load. Instructors must be checked in today.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(pending.person.isTandem ? "Passenger" : "Student") {
                    LabeledContent("Name", value: pending.person.name)
                    LabeledContent("Jump", value: pending.jumpLabel)
                }

                instructorSection(
                    title: pending.pairing.label,
                    selectedID: $primaryID,
                    excludeID: secondID
                )

                if pending.pairing.needsSecond {
                    instructorSection(
                        title: pending.pairing.label2.isEmpty ? "Instr. 2" : pending.pairing.label2,
                        selectedID: $secondID,
                        excludeID: primaryID
                    )
                }

                if needsVideo {
                    videoSection
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Assign Instructor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.pendingStudentAdd = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Load") { Task { await save() } }
                        .disabled(isSaving || !canSave)
                }
            }
            .searchable(text: $query, prompt: "Filter instructors")
            .onChange(of: query) { _, newValue in
                Task { await loadInstructors(query: newValue) }
            }
            .onChange(of: primaryID) { _, _ in
                if case .handCam = videoChoice, primaryID == nil {
                    videoChoice = .none
                }
            }
            .task {
                await store.refreshCheckIns()
                await loadInstructors(query: "")
            }
        }
    }

    private var canSave: Bool {
        guard primaryID != nil else { return false }
        if pending.pairing.needsSecond {
            guard let primaryID, let secondID, primaryID != secondID else { return false }
        }
        return true
    }

    @ViewBuilder
    private var videoSection: some View {
        Section("Video") {
            Button {
                videoChoice = .none
            } label: {
                videoRow(title: "No video", selected: videoChoice == .none)
            }
            if primaryID != nil {
                Button {
                    videoChoice = .handCam
                } label: {
                    videoRow(
                        title: "Video Hand (same as instructor)",
                        selected: videoChoice == .handCam
                    )
                }
            }
            if videoCandidates.isEmpty {
                Text("Check in an outside videographer to assign separate video.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(videoCandidates) { user in
                    Button {
                        videoChoice = .outside(user.user_id)
                    } label: {
                        videoRow(
                            title: "\(user.resolvedName) · outside video",
                            selected: videoChoice == .outside(user.user_id)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func videoRow(title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NightOps.accent)
            }
        }
    }

    @ViewBuilder
    private func instructorSection(
        title: String,
        selectedID: Binding<Int?>,
        excludeID: Int?
    ) -> some View {
        Section(title) {
            if isLoading {
                ProgressView()
            } else if filteredInstructors(excluding: excludeID).isEmpty {
                Text("No matching instructors checked in. Check in an instructor first, or adjust your search.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredInstructors(excluding: excludeID)) { instructor in
                    Button {
                        selectedID.wrappedValue = instructor.id
                    } label: {
                        HStack {
                            Text(instructor.displayName)
                            Spacer()
                            if selectedID.wrappedValue == instructor.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(NightOps.accent)
                            }
                        }
                    }
                }
            }
        }
    }

    private func filteredInstructors(excluding excludeID: Int?) -> [InstructorCandidate] {
        instructors.filter { $0.id != excludeID }
    }

    private func loadInstructors(query: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await session.apiClient.fetchInstructors(
                jumpType: pending.jumpType,
                query: query,
                date: store.selectedDate
            )
            instructors = response.instructors ?? []
        } catch {
            instructors = []
            errorMessage = error.localizedDescription
        }
    }

    private func resolvedVideographerID() -> Int? {
        switch videoChoice {
        case .none:
            return nil
        case .handCam:
            return primaryID
        case .outside(let id):
            return id
        }
    }

    private func save() async {
        guard let primaryID else {
            errorMessage = pending.pairing.requiredMessage
            return
        }
        if pending.pairing.needsSecond {
            guard let secondID else {
                errorMessage = pending.pairing.requiredMessage2
                return
            }
            if primaryID == secondID {
                errorMessage = "Instr. 1 and Instr. 2 must be different people."
                return
            }
        }
        if case .outside(let vgID) = videoChoice {
            if vgID == primaryID || vgID == secondID {
                errorMessage = "Outside videographer must be different from the instructor(s)."
                return
            }
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let ok = await store.addPersonToLoad(
            loadID: pending.loadID,
            person: pending.person,
            jumpType: pending.jumpType,
            instructorUserID: primaryID,
            secondInstructorUserID: pending.pairing.needsSecond ? secondID : nil,
            videographerUserID: resolvedVideographerID()
        )
        if ok {
            store.pendingStudentAdd = nil
            onSaved()
            dismiss()
        } else {
            errorMessage = store.errorMessage
        }
    }
}
