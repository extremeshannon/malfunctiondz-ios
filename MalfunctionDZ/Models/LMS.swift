// File: ASC/Models/LMS.swift
// Purpose: Codable models for LMS courses, modules, lessons, quizzes, and sign-off data.
import Foundation
import MalfunctionDZCore

// MARK: - Course List Response (courses optional so 401/403 body decodes without failure)
struct LMSCoursesResponse: Codable {
    let ok: Bool
    let courses: [LMSCourse]?
    let error: String?
}

// MARK: - Course
struct LMSCourse: Codable, Identifiable, Hashable {
    static func == (lhs: LMSCourse, rhs: LMSCourse) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: Int
    let slug: String
    let title: String
    let description: String?
    let isActive: Bool
    let enrolled: Bool
    let status: String
    let enrolledAt: String?
    let completedAt: String?
    let totalLessons: Int
    let completedLessons: Int
    let progressPct: Double
    let modules: [LMSModule]
    let quizzes: [LMSQuizSummary]?
    let courseCategory: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description, enrolled, status, modules, quizzes
        case courseCategory  = "course_category"
        case isActive        = "is_active"
        case enrolledAt     = "enrolled_at"
        case completedAt    = "completed_at"
        case totalLessons   = "total_lessons"
        case completedLessons = "completed_lessons"
        case progressPct    = "progress_pct"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        slug = try c.decode(String.self, forKey: .slug)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        enrolled = (try? c.decode(Bool.self, forKey: .enrolled)) ?? false
        status = (try? c.decode(String.self, forKey: .status)) ?? "not_enrolled"
        enrolledAt = try? c.decodeIfPresent(String.self, forKey: .enrolledAt)
        completedAt = try? c.decodeIfPresent(String.self, forKey: .completedAt)
        totalLessons = (try? c.decode(Int.self, forKey: .totalLessons)) ?? 0
        completedLessons = (try? c.decode(Int.self, forKey: .completedLessons)) ?? 0
        progressPct = (try? c.decode(Double.self, forKey: .progressPct)) ?? 0
        modules = (try? c.decode([LMSModule].self, forKey: .modules)) ?? []
        quizzes = try? c.decodeIfPresent([LMSQuizSummary].self, forKey: .quizzes)
        courseCategory = try? c.decodeIfPresent(String.self, forKey: .courseCategory)
    }

    /// Pilot / aircraft training courses (jump-plane, etc.).
    var isPilotTraining: Bool {
        if courseCategory?.lowercased() == "pilot" { return true }
        let s = slug.lowercased()
        if s.contains("jump-plane") || s.contains("jump_plane") { return true }
        let t = title.lowercased()
        return t.contains("jump plane") || t.contains("jump pilot")
            || t.contains("cessna 206") && t.contains("jump")
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

    var lessonsComplete: Bool {
        lessonCount > 0 && completedCount >= lessonCount
    }

    var isReadingAssignmentsModule: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines) == "Reading Assignments"
    }
}

// MARK: - Reading assignment helpers

enum ReadingAssignmentHelper {
    private static let hints: [String: String] = [
        "A": "Complete Tandem 1 first",
        "B": "Complete Tandem 2 first",
        "C": "Pass Level 2 first",
        "D": "Pass Level 3 first (available before Level 4)",
        "E": "Pass Level 5 first (available before Level 6)",
        "F": "Pass Level 7 first (available before Level 8)",
        "G": "Pass Level 9 first (available before Level 10)",
        "H": "Pass Level 12 first (available before Level 13)",
    ]

    static func letter(fromLessonTitle title: String) -> String? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for letter in hints.keys.sorted() {
            if t == "Category \(letter) Reading" { return letter }
        }
        return nil
    }

    static func lockHint(forLessonTitle title: String, serverReason: String?) -> String? {
        if let letter = letter(fromLessonTitle: title), let hint = hints[letter] {
            return hint
        }
        return serverReason
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
    let isLocked: Bool
    let lockReason: String?

    enum CodingKeys: String, CodingKey {
        case id, title, completed
        case isLocked = "is_locked"
        case lockReason = "lock_reason"
    }

    init(id: Int, title: String, completed: Bool, isLocked: Bool = false, lockReason: String? = nil) {
        self.id = id
        self.title = title
        self.completed = completed
        self.isLocked = isLocked
        self.lockReason = lockReason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        lockReason = try c.decodeIfPresent(String.self, forKey: .lockReason)
    }
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
    let moduleId: Int?
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
        case moduleId          = "module_id"
        case lastAttempt       = "last_attempt"
    }
}

extension LMSCourse {
    func quizzesForModule(_ module: LMSModule) -> [LMSQuizSummary] {
        guard module.lessonsComplete else { return [] }
        return (quizzes ?? []).filter { quiz in
            guard quiz.isUnlocked else { return false }
            if let moduleId = quiz.moduleId {
                return moduleId == module.id
            }
            return module.requireQuiz && quiz.title.localizedCaseInsensitiveContains(String(module.title.prefix(12)))
        }
    }

    // MARK: - Home dashboard (training-first; matches GroundSchoolView)

    var accessibleModules: [LMSModule] {
        modules.filter { !$0.isLocked }
    }

    var trainingModules: [LMSModule] {
        accessibleModules.filter { !$0.isReadingAssignmentsModule }
    }

    var currentTrainingModule: LMSModule? {
        trainingModules.first(where: { !$0.isComplete })
    }

    static func affLevelNumber(from title: String) -> Int? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = t.range(of: "Level ", options: .caseInsensitive) else { return nil }
        let after = t[range.upperBound...]
        var digits = ""
        for ch in after where ch.isNumber {
            digits.append(ch)
        }
        return Int(digits)
    }

    func moduleShortLabel(_ module: LMSModule) -> String {
        if let n = Self.affLevelNumber(from: module.title) {
            return "Level \(n)"
        }
        return module.title
    }

    /// Next lesson / current work for the home screen — training levels before reading assignments.
    func studentHomeProgress() -> LMSStudentHomeProgress {
        let completedTraining = trainingModules.filter(\.isComplete).count

        if let module = currentTrainingModule {
            let level = Self.affLevelNumber(from: module.title) ?? max(1, completedTraining + 1)
            let lesson = module.lessons.first(where: { !$0.completed && !$0.isLocked })
            let headline: String
            if let lesson {
                headline = lesson.title
            } else if module.lessonsComplete {
                switch module.unlockStatusEnum {
                case .awaitingInstructor:
                    headline = "\(moduleShortLabel(module)) — Instructor sign-off"
                case .awaitingJump:
                    headline = "\(moduleShortLabel(module)) — Jump sign-off"
                case .jumpFailed:
                    headline = "\(moduleShortLabel(module)) — Repeat jump"
                default:
                    headline = moduleShortLabel(module)
                }
            } else {
                headline = moduleShortLabel(module)
            }
            return LMSStudentHomeProgress(
                courseId: id,
                currentAffLevel: level,
                nextLessonTitle: headline,
                currentModuleTitle: lesson != nil ? moduleShortLabel(module) : nil,
                progressSubtitle: "\(completedLessons) of \(totalLessons) lessons complete · Level \(level)",
                moduleId: module.id,
                lessonId: lesson?.id
            )
        }

        if let reading = accessibleModules.first(where: \.isReadingAssignmentsModule), !reading.isComplete {
            let lesson = reading.lessons.first(where: { !$0.completed && !$0.isLocked })
            let level = max(1, completedTraining)
            return LMSStudentHomeProgress(
                courseId: id,
                currentAffLevel: level,
                nextLessonTitle: lesson?.title ?? reading.title,
                currentModuleTitle: reading.title,
                progressSubtitle: "\(completedLessons) of \(totalLessons) lessons complete · Level \(level)",
                moduleId: reading.id,
                lessonId: lesson?.id
            )
        }

        let level = max(1, completedTraining)
        return LMSStudentHomeProgress(
            courseId: id,
            currentAffLevel: level,
            nextLessonTitle: "Course complete",
            currentModuleTitle: nil,
            progressSubtitle: "\(completedLessons) of \(totalLessons) lessons complete · Level \(level)",
            moduleId: nil,
            lessonId: nil
        )
    }
}

/// Home / Continue → Ground School at the student's current module or lesson.
struct GroundSchoolResumeTarget: Equatable {
    let courseId: Int
    let moduleId: Int
    let lessonId: Int?
}

/// Home / Today card snapshot derived from `LMSCourse`.
struct LMSStudentHomeProgress {
    let courseId: Int
    let currentAffLevel: Int
    let nextLessonTitle: String
    let currentModuleTitle: String?
    let progressSubtitle: String
    let moduleId: Int?
    let lessonId: Int?

    var resumeTarget: GroundSchoolResumeTarget? {
        guard let moduleId else { return nil }
        return GroundSchoolResumeTarget(courseId: courseId, moduleId: moduleId, lessonId: lessonId)
    }
}

// MARK: - Last Attempt
struct LMSLastAttempt: Codable, Hashable, Equatable {
    let score: Double
    let passed: Bool
    let date: String?
}
