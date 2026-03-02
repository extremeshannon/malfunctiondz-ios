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

    // MARK: - Tab access
    var canAccessAviation: Bool {
        hasAnyRole(["admin", "master", "godmode", "pilot", "ops"])
    }

    var canAccessLoft: Bool {
        hasAnyRole(["admin", "master", "godmode", "loft", "rigger", "ops"])
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

    // MARK: - Feature-level access within tabs
    var canManageAircraft: Bool {
        hasAnyRole(["admin", "master", "godmode", "ops"])
    }

    var canLogFlights: Bool {
        isPilotRole
    }

    var seesAllAircraft: Bool {
        canManageAircraft
    }

    var canManageGroundSchool: Bool {
        isInstructorRole
    }

    // MARK: - Aviation view mode
    enum AviationViewMode {
        case adminFull
        case pilotRestricted
    }

    var aviationViewMode: AviationViewMode {
        canManageAircraft ? .adminFull : .pilotRestricted
    }

    // MARK: - Display label
    var roleDisplayLabel: String {
        if isAdminLevel     { return "Admin" }
        if isPilotRole      { return "Pilot" }
        if isInstructorRole { return "Instructor" }
        if isStudentRole    { return "Student" }
        if isLoftRole       { return "Loft" }
        if isOpsRole        { return "Ops" }
        return role?.capitalized ?? "Member"
    }
}
