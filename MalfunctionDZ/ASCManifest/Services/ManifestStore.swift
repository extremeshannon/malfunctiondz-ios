import Foundation

@MainActor
final class ManifestStore: ObservableObject {
    @Published var selectedDate = ManifestAppConfig.opsToday
    @Published var loads: [ManifestLoad] = []
    @Published var statusFilter: ManifestLoadStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var aircraft: [ManifestAircraft] = []
    @Published var dayListUnavailable = false
    /// Legacy flag; staff desk no longer builds the board from public display.
    @Published var usingDisplayFallback = false
    @Published var checkedIn: [CheckedInUser] = []
    @Published var checkedInTandem: [CheckedInTandemStudent] = []
    @Published var checkInPools: CheckInPools?
    @Published var eligibleUsers: [EligibleUser] = []
    @Published var lastOverrideUsed = false
    @Published var tandemCheckInOverrideAllowed = false
    /// Soft-failure payload from the last tandem check-in attempt (blocked modal).
    @Published var lastTandemCheckInResponse: GenericOKResponse?
    @Published var pendingStudentAdd: PendingStudentAdd?
    @Published var pilots: [ManifestPilotCard] = []
    @Published var pilotCounts: ManifestPilotCounts?
    @Published var pilotsCanManage = false
    @Published var isLoadingPilots = false
    @Published var pilotsErrorMessage: String?

    /// When true, silent board refresh also reloads pilot cards.
    var pilotsBoardActive = false

    /// Light poll so web and iPad stay aligned without websockets (web reloads; iPad pulls).
    private static let pollIntervalNanoseconds: UInt64 = 45_000_000_000
    private var pollTask: Task<Void, Never>?

    private weak var session: ManifestSessionStore?

    func bind(session: ManifestSessionStore) {
        self.session = session
    }

    var filteredLoads: [ManifestLoad] {
        guard let statusFilter else { return loads }
        return loads.filter { $0.statusKey == statusFilter }
    }

    /// Active jump planes from `/api/manifest/aircraft.php` (`platform_aircraft.is_jumpable`).
    var jumpPlanes: [ManifestAircraft] {
        aircraft.filter { $0.isJumpPlane && $0.isActiveForManifest }
    }

    func daySummary(forAircraftID aircraftID: Int) -> ManifestAircraftDaySummary {
        let planeLoads = loads.filter { $0.aircraft_id == aircraftID }
        let filled = planeLoads.reduce(0) { partial, load in
            partial + (load.filled ?? load.slots?.count ?? 0)
        }
        let total = planeLoads.reduce(0) { partial, load in
            partial + (load.total ?? load.max_pax_per_load ?? 0)
        }
        return ManifestAircraftDaySummary(
            loadCount: planeLoads.count,
            filledSeats: filled,
            totalSeats: total
        )
    }

    func loads(forAircraftID aircraftID: Int) -> [ManifestLoad] {
        loads.filter { $0.aircraft_id == aircraftID }
    }

    func startLivePolling() {
        stopLivePolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
                guard !Task.isCancelled else { break }
                await self?.refresh(silent: true)
            }
        }
    }

    func stopLivePolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Drop in-memory board/check-in state (env switch or missing day API — never keep another host's seed).
    func resetBoard() {
        loads = []
        checkedIn = []
        checkedInTandem = []
        checkInPools = nil
        eligibleUsers = []
        aircraft = []
        dayListUnavailable = false
        usingDisplayFallback = false
        errorMessage = nil
        lastOverrideUsed = false
        tandemCheckInOverrideAllowed = false
        lastTandemCheckInResponse = nil
        pendingStudentAdd = nil
        pilots = []
        pilotCounts = nil
        pilotsCanManage = false
        pilotsErrorMessage = nil
        pilotsBoardActive = false
    }

    func refresh(silent: Bool = false) async {
        guard let session else { return }
        if !silent {
            isLoading = true
            errorMessage = nil
        }
        defer {
            if !silent { isLoading = false }
        }
        await refreshCheckIns()
        if pilotsBoardActive {
            await loadPilots(silent: silent)
        }
        do {
            let response = try await session.apiClient.fetchDayManifest(date: selectedDate)
            if response.error == "day_list_unavailable" || Self.isMissingDayRoute(response.error) {
                dayListUnavailable = true
                usingDisplayFallback = false
                loads = []
                if !silent {
                    let host = session.environment.baseURL.host ?? session.environment.displayName
                    errorMessage = "Staff day API missing on \(host). Deploy GET /api/manifest/day.php (docs/VPS_DEPLOY_LATEST.md), then re-login and refresh. Desk edits need real load ids."
                }
                return
            }
            dayListUnavailable = false
            usingDisplayFallback = false
            if response.ok {
                loads = response.loads ?? []
                await hydrateMissingSlots()
            } else {
                loads = []
                if !silent {
                    errorMessage = response.error ?? "Could not load manifest."
                }
            }
        } catch {
            // Network blip on silent poll: keep last good board. Explicit refresh: clear so we never look "live" with stale Local seed.
            if !silent {
                loads = []
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func isMissingDayRoute(_ message: String?) -> Bool {
        guard let message else { return false }
        let m = message.lowercased()
        return m == "not found" || m.contains("http 404")
    }

    func refreshCheckIns() async {
        guard let session else { return }
        do {
            let poolsResponse = try await session.apiClient.fetchCheckInPools(date: selectedDate)
            if poolsResponse.ok, let pools = poolsResponse.pools {
                checkInPools = pools
                checkedIn = (pools.staffList + pools.jumpersList + pools.studentsList).map { person in
                    CheckedInUser(
                        user_id: person.resolvedUserID ?? person.user_id ?? person.record_id ?? 0,
                        display_name: person.display_name,
                        name: person.resolvedName,
                        username: person.username,
                        checked_in_at: person.checked_in_at,
                        first_name: person.first_name,
                        last_name: person.last_name,
                        weight_lb: person.weight_lb,
                        roles: person.roles,
                        pay_state: person.pay_state,
                        pay_label: person.pay_label,
                        next_jump_label: person.next_jump_label
                    )
                }
                checkedInTandem = pools.tandemList.map { person in
                    CheckedInTandemStudent(
                        id: person.resolvedTandemID ?? person.record_id ?? 0,
                        tandem_student_id: person.resolvedTandemID,
                        user_id: person.user_id,
                        display_name: person.display_name,
                        first_name: person.first_name,
                        last_name: person.last_name,
                        email: person.email,
                        checked_in_at: person.checked_in_at,
                        kind: person.kind,
                        weight_lb: person.weight_lb,
                        pay_state: person.pay_state,
                        pay_label: person.pay_label,
                        pay_tone: person.pay_tone,
                        due_cents: person.due_cents
                    )
                }
            } else {
                checkInPools = nil
                async let listTask = session.apiClient.fetchCheckInList(date: selectedDate)
                async let tandemTask = session.apiClient.fetchCheckedInTandemStudents(date: selectedDate)
                let (list, tandem) = try await (listTask, tandemTask)
                checkedIn = list.ok ? (list.users ?? []) : []
                checkedInTandem = tandem.ok ? (tandem.students ?? []) : []
            }
        } catch {
            // Keep last good pools on transient network errors during silent refresh.
            if checkInPools == nil {
                checkedIn = []
                checkedInTandem = []
            }
        }
        do {
            let elig = try await session.apiClient.fetchEligibleUsers()
            if elig.ok {
                eligibleUsers = elig.users ?? []
            }
        } catch {
            // Non-fatal — desk can still show checked-in pools.
        }
    }

    func checkInTandemStudent(
        tandemStudentID: Int,
        markPaid: Bool = false,
        acknowledgeOverride: Bool = false,
        overrideNote: String = ""
    ) async -> Bool {
        guard let session else { return false }
        lastTandemCheckInResponse = nil
        do {
            let response = try await session.apiClient.checkInTandemStudent(
                tandemStudentID: tandemStudentID,
                date: selectedDate,
                markPaid: markPaid,
                acknowledgeOverride: acknowledgeOverride,
                overrideNote: overrideNote
            )
            tandemCheckInOverrideAllowed = response.override_allowed == true
            if response.ok {
                errorMessage = nil
                lastTandemCheckInResponse = nil
                tandemCheckInOverrideAllowed = false
                await refreshCheckIns()
                return true
            }
            lastTandemCheckInResponse = response
            errorMessage = response.error ?? "Could not check in tandem student."
        } catch ManifestAPIError.serverError(let msg) {
            errorMessage = msg
            lastTandemCheckInResponse = nil
            tandemCheckInOverrideAllowed = false
        } catch {
            errorMessage = error.localizedDescription
            lastTandemCheckInResponse = nil
            tandemCheckInOverrideAllowed = false
        }
        return false
    }

    func loadAircraft() async {
        guard let session else { return }
        do {
            let response = try await session.apiClient.fetchAircraft()
            if response.ok {
                aircraft = response.aircraft ?? []
            }
        } catch {
            // Non-fatal
        }
    }

    func createLoad(aircraftID: Int?) async -> Bool {
        guard let session else { return false }
        do {
            let response = try await session.apiClient.createLoad(date: selectedDate, aircraftID: aircraftID)
            if response.ok, let loadID = response.load_id {
                // Only optimistic-add when the day list API works; otherwise placeholders diverge from web.
                if !dayListUnavailable {
                    let plane = aircraft.first(where: { $0.id == aircraftID })
                    if !loads.contains(where: { $0.id == loadID }) {
                        loads.append(.placeholder(id: loadID, aircraft: plane))
                    }
                }
                await refresh()
                return !dayListUnavailable
            }
            errorMessage = response.error ?? "Could not create load."
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func advanceStatus(load: ManifestLoad) async {
        guard let session else { return }
        if load.id <= 0 {
            errorMessage = "Invalid load id. Refresh after staff day API is deployed."
            return
        }
        guard let next = load.statusKey.next else { return }
        do {
            let response = try await session.apiClient.advanceLoadStatus(loadID: load.id, status: next.rawValue)
            if response.ok {
                errorMessage = nil
                await refresh()
            } else {
                errorMessage = response.error ?? "Status update failed."
            }
        } catch ManifestAPIError.complianceBlocked(let msg) {
            errorMessage = msg
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteLoad(_ load: ManifestLoad) async {
        guard let session else { return }
        if load.id <= 0 {
            errorMessage = "Invalid load id. Refresh after staff day API is deployed."
            return
        }
        do {
            _ = try await session.apiClient.deleteLoad(loadID: load.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addPersonToLoad(
        loadID: Int,
        person: BoardPerson,
        jumpType: String = ManifestJumpType.solo.rawValue,
        instructorUserID: Int? = nil,
        secondInstructorUserID: Int? = nil,
        videographerUserID: Int? = nil
    ) async -> Bool {
        guard let session else { return false }
        if loadID <= 0 {
            errorMessage = "Invalid load id. Deploy GET /api/manifest/day.php, then refresh."
            return false
        }
        lastOverrideUsed = false
        do {
            var response = try await session.apiClient.addSlot(
                loadID: loadID,
                displayName: person.name,
                jumpType: jumpType,
                userID: person.isTandem ? nil : person.id,
                tandemStudentID: person.tandemStudentID,
                instructorUserID: instructorUserID,
                secondInstructorUserID: secondInstructorUserID,
                videographerUserID: videographerUserID,
                acknowledgeOverride: false,
                overrideNote: ""
            )
            if !response.ok, response.override_allowed == true {
                response = try await session.apiClient.addSlot(
                    loadID: loadID,
                    displayName: person.name,
                    jumpType: jumpType,
                    userID: person.isTandem ? nil : person.id,
                    tandemStudentID: person.tandemStudentID,
                    instructorUserID: instructorUserID,
                    secondInstructorUserID: secondInstructorUserID,
                    videographerUserID: videographerUserID,
                    acknowledgeOverride: true,
                    overrideNote: "iPad Load Manager"
                )
                lastOverrideUsed = response.ok
            }
            if response.ok {
                errorMessage = lastOverrideUsed
                    ? "Added \(person.name) with a desk override (payment/rig/USPA)."
                    : nil
                await refreshLoadSlots(loadID)
                await refreshCheckIns()
                return true
            }
            errorMessage = response.error ?? "Could not add \(person.name) to the load."
        } catch ManifestAPIError.complianceBlocked(let msg) {
            errorMessage = msg
        } catch ManifestAPIError.serverError(let msg) {
            errorMessage = msg
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func loadPilots(silent: Bool = false) async {
        guard let session else { return }
        if !silent {
            isLoadingPilots = true
            pilotsErrorMessage = nil
        }
        defer {
            if !silent { isLoadingPilots = false }
        }
        do {
            let response = try await session.apiClient.fetchManifestPilots(date: selectedDate)
            if response.ok {
                pilots = response.pilots ?? []
                pilotCounts = response.counts
                pilotsCanManage = response.can_manage ?? false
            } else {
                pilots = []
                if !silent {
                    pilotsErrorMessage = response.error ?? "Could not load pilots."
                }
            }
        } catch {
            if !silent {
                pilots = []
                pilotsErrorMessage = error.localizedDescription
            }
        }
    }

    func assignPilot(
        loadID: Int,
        userID: Int,
        displayName: String,
        role: String = "pic",
        override: Bool = false,
        overrideNote: String = ""
    ) async -> Bool {
        guard let session else { return false }
        if loadID <= 0 {
            errorMessage = "Invalid load id. Deploy GET /api/manifest/day.php, then refresh before assigning PIC."
            return false
        }
        do {
            var response = try await session.apiClient.setLoadPilot(
                loadID: loadID,
                userID: userID,
                role: role,
                acknowledgeOverride: override,
                overrideNote: overrideNote
            )
            if !response.ok, response.override_allowed == true, !override {
                response = try await session.apiClient.setLoadPilot(
                    loadID: loadID,
                    userID: userID,
                    role: role,
                    acknowledgeOverride: true,
                    overrideNote: overrideNote.isEmpty ? "iPad Load Manager" : overrideNote
                )
            }
            if response.ok {
                errorMessage = nil
                if role == "pic" {
                    replaceLoad(loadID) { $0.updating(pilotUserId: userID) }
                }
                await refresh()
                if pilotsBoardActive {
                    await loadPilots(silent: true)
                }
                return true
            }
            errorMessage = response.error ?? "Could not assign \(displayName) as PIC."
        } catch ManifestAPIError.complianceBlocked(let msg) {
            errorMessage = msg
        } catch ManifestAPIError.serverError(let msg) {
            errorMessage = msg
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func removePilotFromLoad(loadID: Int, role: String = "pic") async -> Bool {
        guard let session else { return false }
        if loadID <= 0 { return false }
        do {
            let response = try await session.apiClient.setLoadPilot(loadID: loadID, userID: nil, role: role)
            if response.ok {
                await refresh()
                if pilotsBoardActive {
                    await loadPilots(silent: true)
                }
                return true
            }
            errorMessage = response.error ?? "Could not remove pilot."
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func dropOnLoad(_ person: BoardPerson, loadID: Int, asPilot: Bool) async {
        if asPilot {
            _ = await assignPilot(loadID: loadID, userID: person.id, displayName: person.name)
        } else {
            await handleJumperDrop(person, loadID: loadID)
        }
    }

    /// Resolve ASP/LMS jump level and open instructor assignment when required.
    @discardableResult
    func prepareStudentAdd(loadID: Int, person: BoardPerson, jumpTypeHint: String? = nil) async -> Bool {
        if person.isTandem {
            return await prepareTandemAdd(loadID: loadID, person: person)
        }
        guard let session else { return false }
        do {
            let next = try await session.apiClient.fetchNextLevel(userID: person.id)
            if next.enrolled == true {
                if next.needs_enrollment == true {
                    errorMessage = "This student is not enrolled in ASP. Enroll them before adding as a student jumper."
                    return false
                }
                let jumpType = next.jump_type ?? jumpTypeHint ?? "student"
                let label = next.label ?? jumpType
                return await finishStudentAdd(
                    loadID: loadID,
                    person: person,
                    jumpType: jumpType,
                    jumpLabel: label
                )
            }
            if let jumpTypeHint, InstructorPairing.spec(for: jumpTypeHint).needs {
                return await finishStudentAdd(
                    loadID: loadID,
                    person: person,
                    jumpType: jumpTypeHint,
                    jumpLabel: jumpTypeHint.uppercased()
                )
            }
            let jumpType = jumpTypeHint ?? ManifestJumpType.fun.rawValue
            return await addPersonToLoad(loadID: loadID, person: person, jumpType: jumpType)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func finishStudentAdd(
        loadID: Int,
        person: BoardPerson,
        jumpType: String,
        jumpLabel: String
    ) async -> Bool {
        let pairing = InstructorPairing.spec(for: jumpType)
        if pairing.needs {
            pendingStudentAdd = PendingStudentAdd(
                loadID: loadID,
                person: person,
                jumpType: jumpType,
                jumpLabel: jumpLabel,
                pairing: pairing
            )
            return false
        }
        return await addPersonToLoad(loadID: loadID, person: person, jumpType: jumpType)
    }

    @discardableResult
    func prepareTandemAdd(loadID: Int, person: BoardPerson) async -> Bool {
        await finishStudentAdd(
            loadID: loadID,
            person: person,
            jumpType: ManifestJumpType.tandem.rawValue,
            jumpLabel: "Tandem"
        )
    }

    private func handleJumperDrop(_ person: BoardPerson, loadID: Int) async {
        _ = await prepareStudentAdd(loadID: loadID, person: person)
    }

    func removeSlot(_ slot: ManifestSlot, loadID: Int) async {
        guard let session else { return }
        do {
            _ = try await session.apiClient.deleteSlot(slotID: slot.id)
            await refreshLoadSlots(loadID)
            await refreshCheckIns()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshLoadSlots(_ loadID: Int) async {
        guard let session else { return }
        do {
            let response = try await session.apiClient.fetchSlots(loadID: loadID)
            if response.ok {
                let slots = response.slots ?? []
                let filledSeats = slots.reduce(into: 0) { acc, slot in
                    if !slot.isPilotSlot {
                        acc += slot.jumperSeatCount
                    }
                }
                replaceLoad(loadID) { $0.updating(slots: slots, filled: filledSeats) }
            }
        } catch {
            await refresh()
        }
    }

    func pilotName(for load: ManifestLoad) -> String? {
        let fromAPI = (load.pilot_name ?? "").trimmingCharacters(in: .whitespaces)
        if !fromAPI.isEmpty { return fromAPI }
        guard let pid = load.pilot_user_id else { return nil }
        return staffName(for: pid)
    }

    func pilotPayLabel(for load: ManifestLoad) -> String {
        let fromAPI = (load.pilot_pay_label ?? "").trimmingCharacters(in: .whitespaces)
        if !fromAPI.isEmpty { return fromAPI }
        if let cents = load.pilot_pay_cents, cents > 0 {
            return String(format: "($%.2f)", Double(cents) / 100.0)
        }
        return load.pilot_user_id == nil ? "" : "($20.00)"
    }

    func staffName(for userID: Int?) -> String? {
        guard let userID, userID > 0 else { return nil }
        if let person = checkedIn.first(where: { $0.user_id == userID }) {
            return person.resolvedName
        }
        return "Staff #\(userID)"
    }

    private func replaceLoad(_ loadID: Int, transform: (ManifestLoad) -> ManifestLoad) {
        guard let index = loads.firstIndex(where: { $0.id == loadID }) else { return }
        loads[index] = transform(loads[index])
    }

    private func hydrateMissingSlots(onlyRealIDs: Bool = false) async {
        let needsSlots = loads.filter { load in
            guard load.slots == nil else { return false }
            if onlyRealIDs { return load.id > 0 }
            return true
        }
        for load in needsSlots.prefix(20) {
            await refreshLoadSlots(load.id)
        }
    }
}
