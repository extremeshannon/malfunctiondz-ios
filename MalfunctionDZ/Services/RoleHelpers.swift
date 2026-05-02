// File: ASC/Services/RoleHelpers.swift
import Foundation
import MalfunctionDZCore

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

    var isOpsAdminRole: Bool {
        hasAnyRole(["ops_admin"]) || isAdminLevel
    }

    var isManifestRole: Bool {
        hasAnyRole(["manifest"]) || isAdminLevel
    }

    /// Manifest-only: has manifest role but no other operational roles (ops, pilot, admin, etc.)
    var isManifestOnly: Bool {
        guard hasAnyRole(["manifest"]) else { return false }
        return !hasAnyRole(["admin", "master", "godmode", "pilot", "ops", "ops_admin", "chief_pilot", "chief pilot", "instructor", "lms_instructor"])
    }

    var isChiefPilotRole: Bool {
        hasAnyRole(["chief_pilot", "chief pilot"]) || isAdminLevel
    }

    // MARK: - Tab access
    var canAccessAviation: Bool {
        hasAnyRole(["admin", "master", "godmode", "pilot", "ops", "ops_admin"])
    }

    /// Full Loft access: Admin and Master Rigger only (not ops_admin — they use Rigs)
    var canAccessLoft: Bool {
        hasAnyRole(["admin", "master", "godmode", "master_rigger"])
    }

    /// Rig owners see their own rigs only. Ops/Ops Admin always get Rigs tab; skydivers when they own rigs (not manifest-only).
    var canAccessMyRigs: Bool {
        hasAnyRole(["ops", "ops_admin"]) || (!canAccessLoft && !isManifestOnly && (totalRigs ?? 0) > 0)
    }

    /// Consolidated Rigs tab: Ops Admin and Manifest get ONE "Rigs" tab with all rigs (personal + DZ). DZ rigs read-only.
    var canAccessRigs: Bool {
        hasAnyRole(["ops_admin", "manifest"])
    }

    /// DZ-owned rigs: Ops, Packers, or 25+ jumps. Ops Admin and Manifest use consolidated Rigs tab instead.
    var canAccessDzRigs: Bool {
        hasAnyRole(["packer", "ops"]) || ((totalJumps ?? 0) >= 25 && !isManifestOnly)
    }

    /// 25 Jump Check tab: Ops, Ops Admin, Admin (Manifest sees widget on Home only)
    var canAccess25JumpCheck: Bool {
        hasAnyRole(["ops", "ops_admin", "admin", "master", "godmode"])
    }

    /// Can mark DZ rigs as packed (parity with API roles): packer, rigger, or 25+ jumps — UI should prefer `can_mark_packed` from GET /api/loft/dz_rigs.
    var canMarkPackedDzRigs: Bool {
        hasAnyRole(["packer", "rigger"]) || (totalJumps ?? 0) >= 25
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

    /// Logbook: Skydivers, Pilots, Students, Instructors — not Ops/Ops Admin or Manifest-only
    var canAccessLogbook: Bool {
        !hasAnyRole(["ops", "ops_admin"]) && !isManifestOnly
    }

    /// Admin, Chief Pilot, Ops Manager can manage users (list, create, edit roles)
    var canManageUsers: Bool {
        hasAnyRole(["admin", "master", "godmode", "ops", "chief_pilot", "chief pilot", "ops_admin"])
    }

    /// Admin, Instructor, Ops, Ops Admin can manage LMS content (courses, modules, lessons, quizzes)
    var canManageLMS: Bool {
        hasAnyRole(["admin", "master", "godmode", "instructor", "lms_instructor", "ops", "ops_admin"])
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

    /// See all aircraft (admin full edit, Ops/Ops Admin read-only)
    var seesAllAircraft: Bool {
        canManageAircraft || hasAnyRole(["ops", "ops_admin"])
    }

    /// Aviation is read-only for Ops/Ops Admin (no add aircraft, no log flights/pax)
    var isAviationReadOnly: Bool {
        hasAnyRole(["ops", "ops_admin"])
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

    /// Calendar: all except Manifest-only (events + shifts)
    var canAccessCalendar: Bool { !isManifestOnly }

    /// Admin and Ops can update DZ status and send push notifications.
    var canUpdateDzStatus: Bool {
        hasAnyRole(["admin", "master", "godmode", "ops"])
    }

    // MARK: - Display label
    var roleDisplayLabel: String {
        if isAdminLevel      { return "Admin" }
        if isOpsAdminRole    { return "Ops Admin" }
        if isPilotRole       { return "Pilot" }
        if isInstructorRole  { return "Instructor" }
        if isStudentRole     { return "Student" }
        if isLoftRole        { return "Loft" }
        if isOpsRole         { return "Ops" }
        if isManifestRole    { return "Manifest" }
        if isChiefPilotRole  { return "Chief Pilot" }
        return role?.capitalized ?? "Member"
    }

    /// Manifest tile on Home: for Admin/Chief Pilot/Ops who run manifest — not for manifest-only users
    var canSeeManifestTile: Bool {
        canAccessManifest && !isManifestOnly
    }

    /// Manifest / Ops Admin / Admin / Master: may check other users in (no self check-in).
    var canCheckInUsers: Bool {
        hasAnyRole(["manifest", "ops_admin", "admin", "master", "godmode"])
    }

    /// Matches server `aircraft_has_full_access`: may choose another pilot when starting a PAX flight.
    var canSelectPilotForPaxFlightStart: Bool {
        hasAnyRole(["admin", "master", "godmode", "ops_admin", "ops", "ops admin", "platform_admin"])
    }
}

// MARK: - Dropzone check-in (Bearer API)
enum CheckinAPI {
    /// Whether the current user is checked in for `dateStr` (yyyy-MM-dd).
    static func isCheckedIn(dateStr: String) async -> Bool {
        guard let token = KeychainHelper.readToken(),
              var c = URLComponents(string: "\(kServerURL)/api/checkin/status.php") else { return false }
        c.queryItems = [URLQueryItem(name: "date_str", value: dateStr)]
        guard let url = c.url else { return false }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["ok"] as? Bool) == true else { return false }
        return (json["checked_in"] as? Bool) ?? false
    }

    /// Load users eligible for check-in (staff-only API).
    static func fetchEligibleUsersForCheckIn() async -> [(id: Int, name: String)] {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/checkin/eligible-users.php") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["ok"] as? Bool) == true,
              let raw = json["users"] as? [[String: Any]] else { return [] }
        return raw.compactMap { row in
            let id: Int? = {
                if let i = row["id"] as? Int { return i }
                if let d = row["id"] as? Double { return Int(d) }
                return nil
            }()
            guard let id else { return nil }
            let name = (row["name"] as? String) ?? ""
            return (id, name.isEmpty ? "User \(id)" : name)
        }
    }

    /// Check another user in (`userId` > 0). Returns nil on success, or an error message.
    static func checkInUser(userId: Int, dateStr: String) async -> String? {
        guard userId > 0 else { return "Select a user" }
        guard let token = KeychainHelper.readToken(),
              var c = URLComponents(string: "\(kServerURL)/api/checkin.php") else { return "Not configured" }
        c.queryItems = [
            URLQueryItem(name: "date_str", value: dateStr),
            URLQueryItem(name: "user_id", value: "\(userId)"),
        ]
        guard let url = c.url else { return "Bad URL" }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "No response"
        }
        if (json["ok"] as? Bool) == true { return nil }
        return (json["error"] as? String) ?? "Check-in failed"
    }
}
