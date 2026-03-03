// File: ASC/Models/LMSEditModels.swift
// Codable models for LMS management API (courses, modules, lessons, quizzes, questions).

import Foundation

// MARK: - Course

struct LMSEditCourse: Codable, Identifiable {
    let id: Int
    let slug: String
    let title: String
    let description: String?
    let sort_order: Int
    let is_active: Int

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description
        case sort_order
        case is_active
    }
}

struct LMSCoursesListResponse: Codable {
    let ok: Bool
    let courses: [LMSEditCourse]
}

struct LMSCourseDetailResponse: Codable {
    let ok: Bool
    let course: LMSEditCourse?
    let linked_modules: [LMSEditCourseModule]?
    let error: String?
}

struct LMSEditCourseModule: Codable {
    let id: Int
    let title: String?
    let sort_order: Int?
}

struct LMSEditCourseQuiz: Codable, Identifiable {
    let id: Int
    let title: String?
    let sort_order: Int?
}

struct LMSCourseQuizzesResponse: Codable {
    let ok: Bool
    let quizzes: [LMSEditCourseQuiz]
}

struct LMSIdResponse: Codable {
    let ok: Bool
    let id: Int?
    let error: String?
}

// MARK: - Module

struct LMSEditModule: Codable, Identifiable {
    let id: Int
    let title: String
    let sort_order: Int

    enum CodingKeys: String, CodingKey {
        case id, title
        case sort_order
    }
}

struct LMSModulesListResponse: Codable {
    let ok: Bool
    let modules: [LMSEditModule]
}

// MARK: - Lesson

struct LMSEditLesson: Codable, Identifiable {
    let id: Int
    let title: String
    let course_id: Int?
    let course_title: String?
    let primary_module_id: Int?
    let module_title: String?
    let sort_order: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case course_id
        case course_title
        case primary_module_id
        case module_title
        case sort_order
    }
}

struct LMSLessonsListResponse: Codable {
    let ok: Bool
    let lessons: [LMSEditLesson]
}

struct LMSLessonDetailResponse: Codable {
    let ok: Bool
    let lesson: LMSEditLessonDetail?
    let error: String?
}

struct LMSEditLessonDetail: Codable {
    let id: Int
    let course_id: Int
    let title: String
    let lesson_type: String
    let content_url: String?
    let content_body: String?
    let sort_order: Int?
    let primary_module_id: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case course_id
        case lesson_type
        case content_url
        case content_body
        case sort_order
        case primary_module_id
    }
}

// MARK: - Quiz (flexible decoding for API variations)

struct LMSEditQuiz: Decodable, Identifiable {
    let id: Int
    let title: String
    let pass_percentage: Double?
    let num_questions: Int?
    let active: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case pass_percentage, pass_score_pct
        case num_questions
        case active
    }

    init(id: Int, title: String, pass_percentage: Double?, num_questions: Int?, active: Int?) {
        self.id = id
        self.title = title
        self.pass_percentage = pass_percentage
        self.num_questions = num_questions
        self.active = active
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        pass_percentage = (try? c.decode(Double.self, forKey: .pass_percentage))
            ?? (try? c.decode(Int.self, forKey: .pass_percentage)).map { Double($0) }
            ?? (try? c.decode(Double.self, forKey: .pass_score_pct))
            ?? (try? c.decode(Int.self, forKey: .pass_score_pct)).map { Double($0) }
        num_questions = try? c.decode(Int.self, forKey: .num_questions)
        active = try? c.decode(Int.self, forKey: .active)
    }
}

struct LMSQuizzesListResponse: Codable {
    let ok: Bool
    let quizzes: [LMSEditQuiz]
}

struct LMSQuizDetailResponse: Codable {
    let ok: Bool
    let quiz: LMSEditQuizDetail?
    let error: String?
}

struct LMSEditQuizDetail: Codable {
    let id: Int
    let title: String
    let randomize_questions: Int?
    let is_timed: Int?
    let time_limit: Int?
    let pass_percentage: Double?
    let num_questions: Int?
    let active: Int?
    let questions: [LMSEditQuizQuestion]?

    enum CodingKeys: String, CodingKey {
        case id, title
        case randomize_questions
        case is_timed
        case time_limit
        case pass_percentage
        case num_questions
        case active
        case questions
    }
}

struct LMSEditQuizQuestion: Codable {
    let question_id: Int
    let text: String?
}

// MARK: - Question

struct LMSEditQuestion: Codable, Identifiable {
    let id: Int
    let text: String
    let type: String?
    let categories: String?

    enum CodingKeys: String, CodingKey {
        case id, text, type, categories
    }
}

struct LMSQuestionsListResponse: Codable {
    let ok: Bool
    let questions: [LMSEditQuestion]
}
