// File: ASC/Services/RoleHelpers.swift
import Foundation

extension User {

    // MARK: - Private role resolution
    private var allRolesLowercased: [String] {
        var r = roles ?? []
        if let p = role { r.append(p) }
        return r.map { $0.lowercased() }
    }

    private func hasAnyRole(_ candidates: [String]) -> Bool {
        let r = allRolesLowercased
        return candidates.contains(where: { r.contains($0) })
    }

    // MARK: - Role checks
    var isAdminLevel: Bool {
        hasAnyRole(["admin", "master", "godmode"])
    }

    var isPilotRole: Bool {
        hasAnyRole(["pilot"]) || isAdminLevel
    }

    var isInstructorRole: Bool {
        hasAnyRole(["instructor", "lms_instructor"]) || isAdminLevel
    }

    var isStudentRole: Bool {
        hasAnyRole(["student", "lms_student"])
    }

    var isLoftRole: Bool {
        hasAnyRole(["loft", "rigger"]) || isAdminLevel
    }

    var isOpsRole: Bool {
        hasAnyRole(["ops"]) || isAdminLevel
    }

    var isManifestRole: Bool {
        hasAnyRole(["manifest"]) || isAdminLevel
    }

    var isChiefPilotRole: Bool {
        hasAnyRole(["chief_pilot", "chief pilot"]) || isAdminLevel
    }

    // MARK: - Tab access
    var canAccessAviation: Bool {
        hasAnyRole(["admin", "master", "godmode", "pilot", "ops"])
    }

    /// Full Loft access: Admin and Master Rigger only
    var canAccessLoft: Bool {
        hasAnyRole(["admin", "master", "godmode", "master_rigger"])
    }

    /// Rig owners see their own rigs only (read-only). Ops always get Rigs tab; others when they own rigs and lack full Loft access.
    var canAccessMyRigs: Bool {
        hasAnyRole(["ops"]) || (!canAccessLoft && (totalRigs ?? 0) > 0)
    }

    /// DZ-owned rigs: Ops (read-only), Packers + 25+ jumps (can mark packed)
    var canAccessDzRigs: Bool {
        hasAnyRole(["packer", "ops"]) || (totalJumps ?? 0) >= 25
    }

    /// 25 Jump Check: Ops (and admin) see users with jump counts
    var canAccess25JumpCheck: Bool {
        hasAnyRole(["ops", "admin", "master", "godmode"])
    }

    /// Can mark DZ rigs as packed: Packers or 25+ jumps (Ops is read-only)
    var canMarkPackedDzRigs: Bool {
        hasAnyRole(["packer"]) || (totalJumps ?? 0) >= 25
    }

    var canAccessGroundSchool: Bool {
        // Pilots must complete training — they get Ground School too
        hasAnyRole(["admin", "master", "godmode",
                    "instructor", "lms_instructor",
                    "student",   "lms_student",
                    "pilot"])
        || ["student", "lms_student", "instructor", "lms_instructor", "pilot"]
            .contains(role?.lowercased() ?? "")
    }

    var canAccessManifest: Bool {
        hasAnyRole(["admin", "master", "godmode", "manifest", "chief_pilot", "chief pilot", "ops"])
    }

    /// Logbook is available to all authenticated users except Ops (Ops use Rigs instead)
    var canAccessLogbook: Bool {
        !hasAnyRole(["ops"])
    }

    /// Admin, Chief Pilot, Ops Manager can manage users (list, create, edit roles)
    var canManageUsers: Bool {
        hasAnyRole(["admin", "master", "godmode", "ops", "chief_pilot", "chief pilot", "ops_admin"])
    }

    /// Admin, Instructor, Ops can manage LMS content (courses, modules, lessons, quizzes)
    var canManageLMS: Bool {
        hasAnyRole(["admin", "master", "godmode", "instructor", "lms_instructor", "ops"])
    }

    /// Only full admin (admin/master/godmode) can edit admin users or assign admin role. Chief Pilot/Ops cannot.
    var canEditAdminUsers: Bool {
        isAdminLevel
    }

    // MARK: - Feature-level access within tabs
    /// Full aircraft/flight/pax management (Admin only)
    var canManageAircraft: Bool {
        hasAnyRole(["admin", "master", "godmode"])
    }

    /// Ops: sees aircraft + pax read-only; can edit pilots
    var canEditPilotsInAviation: Bool {
        hasAnyRole(["admin", "master", "godmode", "ops"])
    }

    var canLogFlights: Bool {
        isPilotRole
    }

    /// See all aircraft (admin full edit, Ops read-only)
    var seesAllAircraft: Bool {
        canManageAircraft || hasAnyRole(["ops"])
    }

    /// Aviation is read-only for Ops (no add aircraft, no log flights/pax)
    var isAviationReadOnly: Bool {
        hasAnyRole(["ops"])
    }

    var canManageGroundSchool: Bool {
        isInstructorRole
    }

    // MARK: - Aviation view mode
    enum AviationViewMode {
        case adminFull       // Admin: full edit
        case opsReadOnly     // Ops: aircraft + pax read-only, pilots editable
        case pilotRestricted // Pilot: own flights only
    }

    var aviationViewMode: AviationViewMode {
        if canManageAircraft { return .adminFull }
        if isAviationReadOnly { return .opsReadOnly }
        return .pilotRestricted
    }

    /// Shift positions map 1:1 to roles. User can pick shifts only for positions they have.
    func canPickShiftForPosition(_ positionKey: String) -> Bool {
        let key = positionKey.lowercased()
        return allRolesLowercased.contains(key) || isAdminLevel
    }

    /// All users can view calendar (events + shifts); shifts require auth.
    var canAccessCalendar: Bool { true }

    /// Admin and Ops can update DZ status and send push notifications.
    var canUpdateDzStatus: Bool {
        hasAnyRole(["admin", "master", "godmode", "ops"])
    }

    // MARK: - Display label
    var roleDisplayLabel: String {
        if isAdminLevel      { return "Admin" }
        if isPilotRole       { return "Pilot" }
        if isInstructorRole  { return "Instructor" }
        if isStudentRole     { return "Student" }
        if isLoftRole        { return "Loft" }
        if isOpsRole         { return "Ops" }
        if isManifestRole    { return "Manifest" }
        if isChiefPilotRole  { return "Chief Pilot" }
        return role?.capitalized ?? "Member"
    }
}
