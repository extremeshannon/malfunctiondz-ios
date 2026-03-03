// File: ASC/Models/SkydiverLogbook.swift
// Purpose: Skydiver/student logbook entries for ASP (Alaska Skydiver Program) and LMS.
//          Matches printable logbook layout: Jump, DZ, Altitude, Delay, Date, Aircraft,
//          Equipment, Total Time, Jump Type, Comments, Signature. Links to LMS signoffs.
import Foundation

// MARK: - API Responses

struct SkydiverLogbookResponse: Codable {
    let ok: Bool
    let entries: [SkydiverLogbookEntry]?
    let otherTrainingNotes: String?  // "Other training / comments" at bottom (e.g. Clear to jump)
    let priorJumpCount: Int?
    let startFreefallTime: String?
    let homeDropzone: String?
    let totalJumps: Int?
    let isStudent: Bool?
    let isSkydiver: Bool?
    let nextJumpNumber: Int?

    enum CodingKeys: String, CodingKey {
        case ok, entries
        case otherTrainingNotes = "other_training_notes"
        case priorJumpCount = "prior_jump_count"
        case startFreefallTime = "start_freefall_time"
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
    let aadMfrs: [String]?
    let aadModelsByMfr: [String: [String]]?
    let reserveMfrs: [String]?
    let reserveModelsByMfr: [String: [String]]?
    let reserveSizesByMfrModel: [String: [String: [Int]]]?

    enum CodingKeys: String, CodingKey {
        case ok
        case aadMfrs = "aad_mfrs"
        case aadModelsByMfr = "aad_models_by_mfr"
        case reserveMfrs = "reserve_mfrs"
        case reserveModelsByMfr = "reserve_models_by_mfr"
        case reserveSizesByMfrModel = "reserve_sizes_by_mfr_model"
    }
}
