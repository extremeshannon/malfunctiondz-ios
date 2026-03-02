// File: ASC/Models/LMS.swift
// Purpose: Codable models for LMS courses, modules, lessons, quizzes, and sign-off data.
import Foundation

// MARK: - Course List Response
struct LMSCoursesResponse: Codable {
    let ok: Bool
    let courses: [LMSCourse]
}

// MARK: - Course
struct LMSCourse: Codable, Identifiable {
    let id: Int
    let slug: String
    let title: String
    let description: String?
    let enrolled: Bool
    let status: String
    let enrolledAt: String?
    let completedAt: String?
    let totalLessons: Int
    let completedLessons: Int
    let progressPct: Double
    let modules: [LMSModule]
    let quizzes: [LMSQuizSummary]?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description, enrolled, status, modules, quizzes
        case enrolledAt       = "enrolled_at"
        case completedAt      = "completed_at"
        case totalLessons     = "total_lessons"
        case completedLessons = "completed_lessons"
        case progressPct      = "progress_pct"
    }

    var enrollmentStatus: EnrollmentStatus {
        switch status {
        case "enrolled":  return .enrolled
        case "completed": return .completed
        default:          return .notEnrolled
        }
    }
}

// MARK: - Enrollment Status
enum EnrollmentStatus {
    case notEnrolled, enrolled, completed

    var label: String {
        switch self {
        case .notEnrolled: return "NOT ENROLLED"
        case .enrolled:    return "IN PROGRESS"
        case .completed:   return "COMPLETED"
        }
    }

    var color: String {
        switch self {
        case .notEnrolled: return "mdzMuted"
        case .enrolled:    return "mdzBlue"
        case .completed:   return "mdzGreen"
        }
    }
}

// MARK: - Module
struct LMSModule: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let estMinutes: Int?
    let objectives: String?
    let inPersonOnly: Bool
    let requireQuiz: Bool
    let requireSignoff: Bool
    let signoffType: String
    let sortOrder: Int
    let lessonCount: Int
    let completedCount: Int
    let isLocked: Bool
    let lockReason: String?
    let unlockStatus: String
    let isComplete: Bool
    let signoffBlock: LMSSignoffBlock?
    let lessons: [LMSLesson]

    enum CodingKeys: String, CodingKey {
        case id, title, objectives, lessons
        case estMinutes     = "est_minutes"
        case inPersonOnly   = "in_person_only"
        case requireQuiz    = "require_quiz"
        case requireSignoff = "require_signoff"
        case signoffType    = "signoff_type"
        case sortOrder      = "sort_order"
        case lessonCount    = "lesson_count"
        case completedCount = "completed_count"
        case isLocked       = "is_locked"
        case lockReason     = "lock_reason"
        case unlockStatus   = "unlock_status"
        case isComplete     = "is_complete"
        case signoffBlock   = "signoff_block"
    }

    var unlockStatusEnum: ModuleUnlockStatus {
        ModuleUnlockStatus(rawValue: unlockStatus) ?? .inProgress
    }
}

// MARK: - Module Unlock Status
enum ModuleUnlockStatus: String {
    case locked             = "locked"
    case inProgress         = "in_progress"
    case awaitingInstructor = "awaiting_instructor"
    case awaitingJump       = "awaiting_jump"
    case jumpFailed         = "jump_failed"
    case complete           = "complete"

    var label: String {
        switch self {
        case .locked:             return "LOCKED"
        case .inProgress:         return "IN PROGRESS"
        case .awaitingInstructor: return "READY FOR SIGN-OFF"
        case .awaitingJump:       return "AWAITING JUMP"
        case .jumpFailed:         return "JUMP FAILED — REPEAT"
        case .complete:           return "COMPLETE"
        }
    }
}

// MARK: - Sign-off Block
struct LMSSignoffBlock: Codable, Hashable {
    let type: String
    let instructorReady: LMSSignoffRecord?
    let jumpResult: LMSSignoffRecord?
    let pendingRequest: String?
    let canRequestInstructor: Bool
    let canRequestJump: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case instructorReady      = "instructor_ready"
        case jumpResult           = "jump_result"
        case pendingRequest       = "pending_request"
        case canRequestInstructor = "can_request_instructor"
        case canRequestJump       = "can_request_jump"
    }
}

struct LMSSignoffRecord: Codable, Hashable {
    let result: String
    let signedAt: String

    enum CodingKeys: String, CodingKey {
        case result
        case signedAt = "signed_at"
    }
}

// MARK: - Lesson
struct LMSLesson: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let completed: Bool
}

// MARK: - Quiz Summary
struct LMSQuizSummary: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let passPercentage: Double
    let questionCount: Int
    let maxAttempts: Int?
    let attemptCount: Int
    let attemptsRemaining: Int?
    let unlockRule: String
    let isUnlocked: Bool
    let lockReason: String?
    let lastAttempt: LMSLastAttempt?

    enum CodingKeys: String, CodingKey {
        case id, title
        case passPercentage    = "pass_percentage"
        case questionCount     = "question_count"
        case maxAttempts       = "max_attempts"
        case attemptCount      = "attempt_count"
        case attemptsRemaining = "attempts_remaining"
        case unlockRule        = "unlock_rule"
        case isUnlocked        = "is_unlocked"
        case lockReason        = "lock_reason"
        case lastAttempt       = "last_attempt"
    }
}

// MARK: - Last Attempt
struct LMSLastAttempt: Codable, Hashable, Equatable {
    let score: Double
    let passed: Bool
    let date: String?
}
