import SwiftUI

private struct EligiblePickRow: Identifiable {
    let user: EligibleUser
    let tab: CheckInTab
    var id: Int { user.id }
}

struct CheckInView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore

    var onBack: (() -> Void)? = nil
    var onOpenMenu: (() -> Void)? = nil

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listFilter = ""
    @State private var pickQuery = ""
    @State private var pickResults: [SearchPerson] = []
    @State private var eligibleSuggestions: [EligiblePickRow] = []
    @State private var isSearchingPick = false
    @State private var activeTab: CheckInTab = .staff
    @State private var newTandemFirst = ""
    @State private var newTandemLast = ""
    @State private var isCreatingTandem = false
    @State private var checkingInUserID: Int?
    @State private var checkingInTandemID: Int?
    @State private var selectedUser: EligibleUser?
    @State private var blockedCheckIn: CheckInBlockedContext?

    private var canOperate: Bool {
        session.currentUser?.canCheckInUsers ?? true
    }

    private var pools: CheckInPools? { store.checkInPools }

    private var activePool: [CheckInPoolPerson] {
        guard let pools else { return fallbackPool(for: activeTab) }
        switch activeTab {
        case .staff: return pools.staffList
        case .jumpers: return pools.jumpersList
        case .tandem: return pools.tandemList
        case .students: return pools.studentsList
        }
    }

    private var filteredPool: [CheckInPoolPerson] {
        let q = listFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return activePool }
        return activePool.filter { $0.resolvedName.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            hintRow
                            pickSection
                            tabBar
                            poolSection
                            if activeTab == .tandem {
                                addTandemSection
                            }
                            footerActions
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
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

    private var header: some View {
        VStack(spacing: 0) {
            if let onBack {
                ManifestLeftPaneHeader(
                    title: "Check-In",
                    onBack: onBack,
                    onRefresh: { Task { await reload() } }
                )
            } else {
                HStack {
                    Text("Check-In")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if let onOpenMenu {
                        Button("Menu") { onOpenMenu() }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Button("Refresh") { Task { await reload() } }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NightOps.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(NightOps.navyLight)
            }
        }
    }

    private var hintRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Check in first, then drag onto a load.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NightOps.textMuted)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(NightOps.danger)
            }
        }
        .padding(.top, 8)
    }

    private var pickSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                activeTab == .tandem ? "Search tandem student to check in…" : "Type to check someone in…",
                text: $pickQuery
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: pickQuery) { _, newValue in
                Task { await runPickSearch(query: newValue) }
            }
            .onChange(of: activeTab) { _, _ in
                pickQuery = ""
                pickResults = []
                eligibleSuggestions = []
            }

            if isSearchingPick {
                ProgressView()
                    .controlSize(.small)
            }

            if activeTab == .tandem {
                ForEach(pickResults.prefix(12)) { person in
                    let tandemID = person.tandem_student_id ?? person.id
                    pickResultButton(
                        title: person.displayName,
                        subtitle: person.email,
                        busy: checkingInTandemID == tandemID,
                        checkedIn: CheckInRoleBuckets.alreadyCheckedTandemID(tandemID, pools: pools)
                    ) {
                        Task { await checkInTandem(tandemID: tandemID, personName: person.displayName) }
                    }
                }
            } else {
                ForEach(eligibleSuggestions.prefix(20)) { row in
                    pickResultButton(
                        title: row.user.suggestLabel,
                        subtitle: row.tab.label,
                        busy: checkingInUserID == row.user.id,
                        checkedIn: CheckInRoleBuckets.alreadyCheckedUserID(row.user.id, pools: pools)
                    ) {
                        Task { await checkInUser(row.user) }
                    }
                }
            }
        }
    }

    private func pickResultButton(
        title: String,
        subtitle: String?,
        busy: Bool,
        checkedIn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(NightOps.textMuted)
                    }
                }
                Spacer()
                if busy {
                    ProgressView().controlSize(.small)
                } else if checkedIn {
                    Text("In")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NightOps.success)
                } else {
                    Text("Check In")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NightOps.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy || checkingInUserID != nil || checkingInTandemID != nil)
    }

    private var tabBar: some View {
        let rows: [[CheckInTab]] = [[.staff, .jumpers], [.tandem, .students]]
        return VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { tab in
                        tabButton(tab)
                    }
                }
            }
        }
    }

    private func tabButton(_ tab: CheckInTab) -> some View {
        Button {
            activeTab = tab
            listFilter = ""
        } label: {
            HStack(spacing: 4) {
                Text(tab.label)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(poolCount(tab))")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(activeTab == tab ? NightOps.accent : Color.white.opacity(0.1))
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var poolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Filter this list…", text: $listFilter)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if filteredPool.isEmpty && !isLoading {
                Text(emptyPoolMessage)
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
                    .padding(.vertical, 8)
            }

            ForEach(filteredPool) { person in
                HStack(spacing: 0) {
                    CheckInPersonRow(person: person)
                        .draggable(person.boardPerson)
                    Button {
                        if person.isTandem {
                            // Tandem prep opens blocked flow on re-check-in; use tandem detail later.
                        } else {
                            selectedUser = person.eligibleUser()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundStyle(NightOps.textMuted)
                            .padding(.leading, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addTandemSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add tandem passenger")
                .font(.caption.weight(.bold))
                .foregroundStyle(NightOps.textMuted)
            TextField("First name", text: $newTandemFirst)
                .textInputAutocapitalization(.words)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            TextField("Last name", text: $newTandemLast)
                .textInputAutocapitalization(.words)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                Task { await createTandemPassenger() }
            } label: {
                if isCreatingTandem {
                    ProgressView()
                } else {
                    Text("Create passenger")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(NightOps.accent)
            .disabled(isCreatingTandem || newTandemFirst.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var footerActions: some View {
        VStack(spacing: 8) {
            if canOperate && (!store.checkedIn.isEmpty || !store.checkedInTandem.isEmpty) {
                Button("Check Out All", role: .destructive) {
                    Task { await checkOutAll() }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.top, 4)
    }

    private var emptyPoolMessage: String {
        switch activeTab {
        case .staff: return "No staff checked in."
        case .jumpers: return "No jumpers checked in."
        case .tandem: return "No tandem students checked in."
        case .students: return "No students checked in."
        }
    }

    private func poolCount(_ tab: CheckInTab) -> Int {
        guard let pools else { return fallbackPool(for: tab).count }
        switch tab {
        case .staff: return pools.staffList.count
        case .jumpers: return pools.jumpersList.count
        case .tandem: return pools.tandemList.count
        case .students: return pools.studentsList.count
        }
    }

    private func fallbackPool(for tab: CheckInTab) -> [CheckInPoolPerson] {
        switch tab {
        case .tandem:
            return store.checkedInTandem.map { student in
                CheckInPoolPerson(
                    record_id: student.tandemID,
                    tandem_student_id: student.tandemID,
                    display_name: student.resolvedName,
                    first_name: student.first_name,
                    last_name: student.last_name,
                    email: student.email,
                    kind: "tandem",
                    weight_lb: student.weight_lb,
                    pay_state: student.pay_state,
                    pay_label: student.pay_label,
                    pay_tone: student.pay_tone,
                    due_cents: student.due_cents,
                    checked_in_at: student.checked_in_at
                )
            }
        default:
            return store.checkedIn.compactMap { user in
                let roles = user.roles ?? []
                let matches: Bool
                switch tab {
                case .staff: matches = CheckInRoleBuckets.isStaff(roles)
                case .students: matches = CheckInRoleBuckets.isStudent(roles) && !CheckInRoleBuckets.isStaff(roles)
                case .jumpers: matches = !CheckInRoleBuckets.isStaff(roles) && !CheckInRoleBuckets.isStudent(roles)
                case .tandem: matches = false
                }
                guard matches else { return nil }
                return CheckInPoolPerson(
                    record_id: user.user_id,
                    user_id: user.user_id,
                    display_name: user.resolvedName,
                    first_name: user.first_name,
                    last_name: user.last_name,
                    username: user.username,
                    roles: user.roles,
                    weight_lb: user.weight_lb,
                    pay_state: user.pay_state,
                    pay_label: user.pay_label,
                    next_jump_label: user.next_jump_label,
                    checked_in_at: user.checked_in_at
                )
            }
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        await store.refreshCheckIns()
        await runPickSearch(query: pickQuery)
    }

    private func runPickSearch(query: String) async {
        isSearchingPick = true
        defer { isSearchingPick = false }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if activeTab == .tandem {
            do {
                let response = try await session.apiClient.searchTandemStudents(query: query)
                let people = response.people ?? []
                pickResults = people.filter {
                    let tid = $0.tandem_student_id ?? $0.id
                    return !CheckInRoleBuckets.alreadyCheckedTandemID(tid, pools: pools)
                }
            } catch {
                pickResults = []
            }
            eligibleSuggestions = []
            return
        }
        pickResults = []
        guard !trimmed.isEmpty else {
            eligibleSuggestions = []
            return
        }
        let needle = trimmed.lowercased()
        eligibleSuggestions = store.eligibleUsers
            .filter { !CheckInRoleBuckets.alreadyCheckedUserID($0.id, pools: pools) }
            .filter { $0.searchHaystack.contains(needle) }
            .map { EligiblePickRow(user: $0, tab: CheckInRoleBuckets.tabForUser($0)) }
            .sorted { lhs, rhs in
                let lhsTabMatch = lhs.tab == activeTab
                let rhsTabMatch = rhs.tab == activeTab
                if lhsTabMatch != rhsTabMatch { return lhsTabMatch }
                return lhs.user.resolvedName.localizedCaseInsensitiveCompare(rhs.user.resolvedName) == .orderedAscending
            }
    }

    private func checkOutAll() async {
        do {
            _ = try await session.apiClient.checkOutAll(date: store.selectedDate)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
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

    private func checkInUser(_ user: EligibleUser) async {
        errorMessage = nil
        checkingInUserID = user.id
        defer { checkingInUserID = nil }
        do {
            let response = try await session.apiClient.checkInUser(
                userID: user.id,
                date: store.selectedDate
            )
            if response.ok {
                pickQuery = ""
                eligibleSuggestions = []
                activeTab = CheckInRoleBuckets.tabForUser(user)
                await reload()
            } else {
                blockedCheckIn = .from(
                    response: response,
                    kind: .jumper(userID: user.id),
                    personName: user.resolvedName
                )
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
            pickQuery = ""
            pickResults = []
            activeTab = .tandem
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
