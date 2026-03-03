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
    let totalJumps: Int?
    let isStudent: Bool?
    let isSkydiver: Bool?
    let nextJumpNumber: Int?

    enum CodingKeys: String, CodingKey {
        case ok, entries
        case otherTrainingNotes = "other_training_notes"
        case priorJumpCount = "prior_jump_count"
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
}
