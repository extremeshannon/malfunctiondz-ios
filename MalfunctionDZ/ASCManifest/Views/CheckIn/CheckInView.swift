import SwiftUI

struct CheckInView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore

    var onBack: (() -> Void)? = nil

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filter = ""
    @State private var tandemQuery = ""
    @State private var tandemResults: [SearchPerson] = []
    @State private var isSearchingTandem = false
    @State private var newTandemFirst = ""
    @State private var newTandemLast = ""
    @State private var isCreatingTandem = false
    @State private var checkingInTandemID: Int?
    @State private var selectedUser: EligibleUser?
    @State private var blockedCheckIn: CheckInBlockedContext?

    private var canOperate: Bool {
        session.currentUser?.canCheckInUsers ?? true
    }

    private var filteredEligible: [EligibleUser] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.eligibleUsers }
        return store.eligibleUsers.filter { ($0.name ?? "").lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                ManifestLeftPaneHeader(
                    title: "Check-In",
                    onBack: onBack,
                    onRefresh: { Task { await reload() } }
                )
            }

            Group {
                if session.isAuthenticated && session.currentUser == nil {
                    ProgressView("Loading staff profile…")
                } else if !canOperate {
                    ContentUnavailableView(
                        "Check-In Unavailable",
                        systemImage: "lock.fill",
                        description: Text("Your account needs Manifest, Ops Admin, or Admin role.")
                    )
                } else {
                    VStack(spacing: 0) {
                        CheckedInDragPool()
                            .padding()
                        listContent
                    }
                }
            }
        }
        .background(NightOps.navy)
        .sheet(item: $selectedUser) { user in
            CheckInUserSheet(user: user) {
                Task { await reload() }
            }
        }
        .sheet(item: $blockedCheckIn) { ctx in
            CheckInBlockedSheet(context: ctx) {
                Task { await reload() }
            }
        }
        .task { await reload() }
    }

    private var listContent: some View {
        List {
            Section {
                Text("Tap a jumper to set ID / affidavit / briefing. Search tandem passengers below. Loads stay on the right.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if canOperate && !store.checkedIn.isEmpty {
                    Button("Check Out All", role: .destructive) {
                        Task { await checkOutAll() }
                    }
                }
            }

            Section("Tandem passengers") {
                if !store.checkedInTandem.isEmpty {
                    Text("Checked in — drag from the list above onto a load.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(store.checkedInTandem) { student in
                        HStack {
                            Text(student.resolvedName)
                            Spacer()
                            Text("In")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                        }
                    }
                }

                TextField("Search tandem passenger", text: $tandemQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: tandemQuery) { _, newValue in
                        Task { await searchTandem(query: newValue) }
                    }
                if isSearchingTandem {
                    ProgressView()
                }
                if tandemResults.isEmpty && !isSearchingTandem {
                    Text("No tandem passengers yet. Add one below or run seed_manifest_test_users.py on the server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(tandemResults.prefix(12)) { person in
                    let tandemID = person.tandem_student_id ?? person.id
                    Button {
                        Task { await checkInTandem(tandemID: tandemID, personName: person.displayName) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.displayName)
                                if let email = person.email, !email.isEmpty {
                                    Text(email)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if checkingInTandemID == tandemID {
                                ProgressView()
                                    .controlSize(.small)
                            } else if store.checkedInTandem.contains(where: { $0.tandemID == tandemID }) {
                                Text("In")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            } else {
                                Text("Check In")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(NightOps.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(checkingInTandemID != nil)
                }
            }

            Section("Add tandem passenger") {
                TextField("First name", text: $newTandemFirst)
                    .textInputAutocapitalization(.words)
                TextField("Last name", text: $newTandemLast)
                    .textInputAutocapitalization(.words)
                Button {
                    Task { await createTandemPassenger() }
                } label: {
                    if isCreatingTandem {
                        ProgressView()
                    } else {
                        Text("Create passenger")
                    }
                }
                .disabled(isCreatingTandem || newTandemFirst.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Jumpers & staff") {
                TextField("Filter by name", text: $filter)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if store.eligibleUsers.isEmpty && !isLoading {
                    Text("No eligible users returned from API.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredEligible.prefix(100)) { user in
                    Button {
                        selectedUser = user
                    } label: {
                        HStack {
                            Text(user.name ?? "User \(user.id)")
                            Spacer()
                            if store.checkedIn.contains(where: { $0.id == user.id }) {
                                Text("In")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        await store.refreshCheckIns()
        await searchTandem(query: tandemQuery)
    }

    private func checkOutAll() async {
        do {
            _ = try await session.apiClient.checkOutAll(date: store.selectedDate)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func searchTandem(query: String) async {
        isSearchingTandem = true
        defer { isSearchingTandem = false }
        do {
            let response = try await session.apiClient.searchTandemStudents(query: query)
            tandemResults = response.people ?? []
        } catch {
            tandemResults = []
        }
    }

    private func createTandemPassenger() async {
        isCreatingTandem = true
        errorMessage = nil
        defer { isCreatingTandem = false }
        let first = newTandemFirst.trimmingCharacters(in: .whitespaces)
        let last = newTandemLast.trimmingCharacters(in: .whitespaces)
        guard !first.isEmpty else { return }
        do {
            let response = try await session.apiClient.createTandemStudent(
                firstName: first,
                lastName: last
            )
            if response.ok, let person = response.person {
                newTandemFirst = ""
                newTandemLast = ""
                tandemResults = [person]
                if let tid = response.tandem_student_id ?? person.tandem_student_id ?? person.id as Int? {
                    await checkInTandem(tandemID: tid, personName: person.displayName)
                } else {
                    await reload()
                }
            } else {
                errorMessage = response.error ?? "Could not create tandem passenger."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkInTandem(tandemID: Int, personName: String) async {
        errorMessage = nil
        checkingInTandemID = tandemID
        defer { checkingInTandemID = nil }
        let ok = await store.checkInTandemStudent(tandemStudentID: tandemID)
        if ok {
            await reload()
            return
        }
        if let response = store.lastTandemCheckInResponse {
            blockedCheckIn = .from(
                response: response,
                kind: .tandem(tandemStudentID: tandemID),
                personName: personName
            )
        } else if let msg = store.errorMessage {
            blockedCheckIn = CheckInBlockedContext(
                kind: .tandem(tandemStudentID: tandemID),
                personName: personName,
                reasons: [msg],
                overrideAllowed: store.tandemCheckInOverrideAllowed,
                needsPayment: false,
                payLabel: nil,
                rentingAllowed: false,
                showSkydiverPrep: false,
                showTandemPrep: true,
                idChecked: false,
                affidavitSigned: false,
                dzBriefing: false,
                rentingDzRig: false,
                waiverSigned: false,
                videoWatched: false,
                trainingComplete: false,
                markPaid: false,
                overrideNote: "",
                statusMessage: nil
            )
        }
    }
}
