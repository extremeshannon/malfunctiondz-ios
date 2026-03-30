// File: ASC/Models/SkydiverLogbook.swift
// Purpose: Skydiver/student logbook entries for ASP (Alaska Skydiver Program) and LMS.
//          Matches printable logbook layout: Jump, DZ, Altitude, Delay, Date, Aircraft,
//          Equipment, Total Time, Jump Type, Comments, Signature. Links to LMS signoffs.
import Foundation
import MalfunctionDZCore

// MARK: - API Responses

struct SkydiverLogbookResponse: Codable {
    let ok: Bool
    let entries: [SkydiverLogbookEntry]?
    let otherTrainingNotes: String?  // "Other training / comments" at bottom (e.g. Clear to jump)
    let priorJumpCount: Int?
    /// Seconds of freefall logged before this platform (pre-platform total).
    let priorFreefallSeconds: Int?
    /// Cumulative freefall seconds: prior + sum of logged jumps.
    let totalFreefallSeconds: Int?
    let startFreefallTime: String?
    /// Canonical jump type (e.g. rw, freefly) prefilled when adding a jump.
    let defaultJumpType: String?
    let homeDropzone: String?
    let totalJumps: Int?
    let isStudent: Bool?
    let isSkydiver: Bool?
    let nextJumpNumber: Int?

    enum CodingKeys: String, CodingKey {
        case ok, entries
        case otherTrainingNotes = "other_training_notes"
        case priorJumpCount = "prior_jump_count"
        case priorFreefallSeconds = "prior_freefall_seconds"
        case totalFreefallSeconds = "total_freefall_seconds"
        case startFreefallTime = "start_freefall_time"
        case defaultJumpType = "default_jump_type"
        case homeDropzone = "home_dropzone"
        case totalJumps = "total_jumps"
        case isStudent = "is_student"
        case isSkydiver = "is_skydiver"
        case nextJumpNumber = "next_jump_number"
    }
}

// MARK: - Logbook Entry (one jump / one sign-off row)

struct SkydiverLogbookEntry: Codable, Identifiable {
    let id: Int
    let jumpNumber: Int
    let dz: String?
    let altitude: String?
    let delay: String?
    let date: String?
    let aircraft: String?
    let equipment: String?
    let rigId: Int?
    let rigLabel: String?
    let totalTime: String?
    let jumpType: String?
    let comments: String?
    /// pass | repeat (no "failed" — repeat only)
    let result: String?
    let signedBy: String?
    let instructorLicenseNumber: String?
    let signedAt: String?
    /// Locked after instructor signs; no further edits.
    let isLocked: Bool
    /// LMS link
    let courseId: Int?
    let moduleId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case jumpNumber = "jump_number"
        case dz
        case altitude
        case delay
        case date
        case aircraft
        case equipment
        case rigId = "rig_id"
        case rigLabel = "rig_label"
        case totalTime = "total_time"
        case jumpType = "jump_type"
        case comments
        case result
        case signedBy = "signed_by"
        case instructorLicenseNumber = "instructor_license_number"
        case signedAt = "signed_at"
        case isLocked = "is_locked"
        case courseId = "course_id"
        case moduleId = "module_id"
    }

    var resultDisplay: String {
        switch result?.lowercased() {
        case "pass": return "Pass"
        case "repeat": return "Repeat"
        default: return result ?? "—"
        }
    }

    var isSigned: Bool { (signedAt != nil && !(signedAt?.isEmpty ?? true)) || isLocked }

    /// Display: rig label when set, else equipment free text
    var equipmentDisplay: String? {
        if let label = rigLabel, !label.isEmpty { return label }
        return equipment
    }
}

// MARK: - Jumper-owned rig (for Add Jump selection & repack/expiry tracking)

struct JumperRig: Codable, Identifiable {
    let id: Int
    let rigLabel: String
    let harness: RigComponent?
    /// Main canopy (sport); optional when not configured.
    let main: RigReserveComponent?
    let reserve: RigReserveComponent?
    let aad: RigComponent?
    let notes: String?

    struct RigComponent: Codable {
        let mfr: String?
        let model: String?
        let sn: String?
        let dom: String?
    }

    struct RigReserveComponent: Codable {
        let mfr: String?
        let model: String?
        let sizeSqft: Int?
        let sn: String?
        let dom: String?

        enum CodingKeys: String, CodingKey {
            case mfr, model, sn, dom
            case sizeSqft = "size_sqft"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case rigLabel = "rig_label"
        case harness
        case main
        case reserve
        case aad
        case notes
    }

    var reserveDomDisplay: String? { reserve?.dom }
    var aadDomDisplay: String? { aad?.dom }
}

struct RigsResponse: Codable {
    let ok: Bool
    let rigs: [JumperRig]?
}

// MARK: - Rig catalog (for Add Rig dropdowns, matches loft)

struct RigCatalogResponse: Codable {
    let ok: Bool?
    let harnessMfrs: [String]?
    let harnessModelsByMfr: [String: [String]]?
    let aadMfrs: [String]?
    let aadModelsByMfr: [String: [String]]?
    let reserveMfrs: [String]?
    let reserveModelsByMfr: [String: [String]]?
    let reserveSizesByMfrModel: [String: [String: [Int]]]?
    let mainMfrs: [String]?
    let mainModelsByMfr: [String: [String]]?
    let mainSizesByMfrModel: [String: [String: [Int]]]?

    enum CodingKeys: String, CodingKey {
        case ok
        case harnessMfrs = "harness_mfrs"
        case harnessModelsByMfr = "harness_models_by_mfr"
        case aadMfrs = "aad_mfrs"
        case aadModelsByMfr = "aad_models_by_mfr"
        case reserveMfrs = "reserve_mfrs"
        case reserveModelsByMfr = "reserve_models_by_mfr"
        case reserveSizesByMfrModel = "reserve_sizes_by_mfr_model"
        case mainMfrs = "main_mfrs"
        case mainModelsByMfr = "main_models_by_mfr"
        case mainSizesByMfrModel = "main_sizes_by_mfr_model"
    }
}

// MARK: - Jump type defaults (matches server `normalize_jump_type`)

enum LogbookJumpTypeOptions {
    static let all: [(value: String, label: String)] = [
        ("rw", "RW"),
        ("freefly", "Freefly"),
        ("solo", "Solo"),
        ("hopnpop", "Hop & pop"),
        ("student", "Student / training"),
        ("tandem", "Tandem"),
        ("aff", "AFF"),
        ("coach", "Coach"),
        ("wingsuit", "Wingsuit"),
        ("video", "Video"),
        ("crw", "CRW"),
        ("fun", "Fun"),
        ("other", "Other"),
    ]

    static func label(for value: String) -> String {
        let v = value.lowercased()
        return all.first { $0.value == v }?.label ?? value
    }
}

// MARK: - Freefall duration (M:SS input + cumulative display)

enum FreefallDurationFormatting {
    /// Formats digit input as M:SS once there are more than two digits (last two are seconds, 0–59).
    static func formatWhileTyping(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(6))
        guard !digits.isEmpty else { return "" }
        if digits.count <= 2 { return digits }
        let minPart = String(digits.dropLast(2))
        var sec = Int(String(digits.suffix(2))) ?? 0
        if sec > 59 { sec = 59 }
        return "\(minPart):\(String(format: "%02d", sec))"
    }

    /// Cumulative seconds as H:MM:SS or M:SS (minutes may exceed 59). Uses `0:00` when total is zero.
    static func formatCumulativeSeconds(_ total: Int) -> String {
        let t = max(0, total)
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
