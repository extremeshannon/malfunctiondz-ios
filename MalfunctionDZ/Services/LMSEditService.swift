// File: ASC/Services/LMSEditService.swift
// API client for LMS management. Uses kServerURL and KeychainHelper.

import Foundation
import MalfunctionDZCore

enum LMSEditService {

    private static func baseURL(_ path: String) -> URL {
        URL(string: "\(kServerURL)/api/lms/\(path)")!
    }

    private static func makeRequest(path: String, method: String, jsonBody: [String: Any]? = nil) throws -> URLRequest {
        guard let token = KeychainHelper.readToken(), !token.isEmpty else {
            throw LMSEditError.notAuthenticated
        }
        var req = URLRequest(url: baseURL(path))
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let jsonBody {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        return req
    }

    private static func perform<T: Decodable>(_ req: URLRequest, decodeAs: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LMSEditError.network("No response") }
        if http.statusCode == 401 { throw LMSEditError.notAuthenticated }
        if http.statusCode == 403 { throw LMSEditError.server("Permission denied") }
        guard (200...299).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode([String: String].self, from: data), let msg = err["error"] {
                throw LMSEditError.server(msg)
            }
            throw LMSEditError.server("Request failed (\(http.statusCode))")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LMSEditError.decoding(error.localizedDescription)
        }
    }

    enum LMSEditError: Error, LocalizedError {
        case notAuthenticated
        case network(String)
        case server(String)
        case decoding(String)
        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Session expired"
            case .network(let m): return m
            case .server(let m): return m
            case .decoding(let m): return m
            }
        }
    }

    // MARK: - Courses

    static func fetchCourses() async throws -> [LMSEditCourse] {
        let req = try makeRequest(path: "manage_courses.php", method: "GET")
        let res = try await perform(req, decodeAs: LMSCoursesListResponse.self)
        guard res.ok else { throw LMSEditError.server("Failed to load courses") }
        return res.courses
    }

    static func createCourse(slug: String, title: String, description: String, isActive: Bool) async throws -> Int {
        let body: [String: Any] = [
            "slug": slug, "title": title, "description": description, "is_active": isActive,
            "sort_order": 0, "modules_in_order": false, "lessons_in_order": false,
        ]
        let req = try makeRequest(path: "manage_courses.php", method: "POST", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok, let id = res.id else { throw LMSEditError.server(res.error ?? "Create failed") }
        return id
    }

    static func updateCourse(id: Int, slug: String, title: String, description: String, isActive: Bool) async throws {
        let body: [String: Any] = [
            "slug": slug, "title": title, "description": description, "is_active": isActive,
            "sort_order": 0, "modules_in_order": false, "lessons_in_order": false,
        ]
        let req = try makeRequest(path: "manage_course.php?id=\(id)", method: "PUT", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Update failed") }
    }

    static func deleteCourse(id: Int) async throws {
        let req = try makeRequest(path: "manage_course.php?id=\(id)", method: "DELETE")
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Delete failed") }
    }

    static func fetchCourseDetail(id: Int) async throws -> LMSCourseDetailResponse {
        let req = try makeRequest(path: "manage_course.php?id=\(id)", method: "GET")
        return try await perform(req, decodeAs: LMSCourseDetailResponse.self)
    }

    static func reorderCourseModules(courseId: Int, moduleIds: [Int]) async throws {
        let body: [String: Any] = ["course_id": courseId, "module_ids": moduleIds]
        let req = try makeRequest(path: "manage_course_module.php", method: "PUT", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Reorder failed") }
    }

    static func fetchCourseQuizzes(courseId: Int) async throws -> [LMSEditCourseQuiz] {
        let req = try makeRequest(path: "manage_course_quizzes.php?course_id=\(courseId)", method: "GET")
        let res = try await perform(req, decodeAs: LMSCourseQuizzesResponse.self)
        guard res.ok else { throw LMSEditError.server("Failed to load quizzes") }
        return res.quizzes
    }

    static func reorderCourseQuizzes(courseId: Int, quizIds: [Int]) async throws {
        let body: [String: Any] = ["course_id": courseId, "quiz_ids": quizIds]
        let req = try makeRequest(path: "manage_course_quizzes.php", method: "PUT", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Reorder failed") }
    }

    // MARK: - Modules

    static func fetchModules() async throws -> [LMSEditModule] {
        let req = try makeRequest(path: "manage_modules.php", method: "GET")
        let res = try await perform(req, decodeAs: LMSModulesListResponse.self)
        guard res.ok else { throw LMSEditError.server("Failed to load modules") }
        return res.modules
    }

    static func createModule(title: String, sortOrder: Int = 0) async throws -> Int {
        let body: [String: Any] = ["title": title, "sort_order": sortOrder]
        let req = try makeRequest(path: "manage_modules.php", method: "POST", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok, let id = res.id else { throw LMSEditError.server(res.error ?? "Create failed") }
        return id
    }

    static func updateModule(id: Int, title: String, sortOrder: Int) async throws {
        let body: [String: Any] = ["title": title, "sort_order": sortOrder]
        let req = try makeRequest(path: "manage_module.php?id=\(id)", method: "PUT", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Update failed") }
    }

    static func deleteModule(id: Int) async throws {
        let req = try makeRequest(path: "manage_module.php?id=\(id)", method: "DELETE")
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Delete failed") }
    }

    static func reorderModuleLessons(moduleId: Int, lessonIds: [Int]) async throws {
        let body: [String: Any] = ["module_id": moduleId, "lesson_ids": lessonIds]
        let req = try makeRequest(path: "manage_module_lesson.php", method: "PUT", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Reorder failed") }
    }

    // MARK: - Lessons

    static func fetchLessons(courseId: Int? = nil, moduleId: Int? = nil) async throws -> [LMSEditLesson] {
        var q: [String] = []
        if let c = courseId, c > 0 { q.append("course_id=\(c)") }
        if let m = moduleId, m > 0 { q.append("module_id=\(m)") }
        let query = q.isEmpty ? "" : "?" + q.joined(separator: "&")
        let req = try makeRequest(path: "manage_lessons.php\(query)", method: "GET")
        let res = try await perform(req, decodeAs: LMSLessonsListResponse.self)
        guard res.ok else { throw LMSEditError.server("Failed to load lessons") }
        return res.lessons
    }

    static func createLesson(courseId: Int, moduleId: Int, title: String, lessonType: String, contentBody: String, sortOrder: Int) async throws -> Int {
        let body: [String: Any] = [
            "course_id": courseId, "module_id": moduleId, "title": title,
            "lesson_type": lessonType, "content_body": contentBody, "sort_order": sortOrder,
        ]
        let req = try makeRequest(path: "manage_lessons.php", method: "POST", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok, let id = res.id else { throw LMSEditError.server(res.error ?? "Create failed") }
        return id
    }

    static func updateLesson(id: Int, courseId: Int, moduleId: Int, title: String, lessonType: String, contentBody: String, sortOrder: Int) async throws {
        let body: [String: Any] = [
            "course_id": courseId, "module_id": moduleId, "title": title,
            "lesson_type": lessonType, "content_body": contentBody, "sort_order": sortOrder,
        ]
        let req = try makeRequest(path: "manage_lesson.php?id=\(id)", method: "PUT", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Update failed") }
    }

    static func deleteLesson(id: Int) async throws {
        let req = try makeRequest(path: "manage_lesson.php?id=\(id)", method: "DELETE")
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Delete failed") }
    }

    // MARK: - Quizzes

    static func fetchQuizzes() async throws -> [LMSEditQuiz] {
        let req = try makeRequest(path: "manage_quizzes.php", method: "GET")
        let res = try await perform(req, decodeAs: LMSQuizzesListResponse.self)
        guard res.ok else { throw LMSEditError.server("Failed to load quizzes") }
        return res.quizzes
    }

    static func fetchQuiz(id: Int) async throws -> LMSEditQuizDetail {
        let req = try makeRequest(path: "manage_quiz.php?id=\(id)", method: "GET")
        let res = try await perform(req, decodeAs: LMSQuizDetailResponse.self)
        guard res.ok, let quiz = res.quiz else { throw LMSEditError.server(res.error ?? "Quiz not found") }
        return quiz
    }

    static func createQuiz(title: String, passPercentage: Double, questionIds: [Int]) async throws -> Int {
        var body: [String: Any] = ["title": title, "pass_percentage": passPercentage, "active": true]
        if !questionIds.isEmpty { body["question_ids"] = questionIds }
        let req = try makeRequest(path: "manage_quizzes.php", method: "POST", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok, let id = res.id else { throw LMSEditError.server(res.error ?? "Create failed") }
        return id
    }

    static func updateQuiz(id: Int, title: String, passPercentage: Double, questionIds: [Int]) async throws {
        var body: [String: Any] = ["title": title, "pass_percentage": passPercentage, "active": true]
        body["question_ids"] = questionIds
        let req = try makeRequest(path: "manage_quiz.php?id=\(id)", method: "PUT", jsonBody: body)
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Update failed") }
    }

    static func deleteQuiz(id: Int) async throws {
        let req = try makeRequest(path: "manage_quiz.php?id=\(id)", method: "DELETE")
        let res = try await perform(req, decodeAs: LMSIdResponse.self)
        guard res.ok else { throw LMSEditError.server(res.error ?? "Delete failed") }
    }

    // MARK: - Questions

    static func fetchQuestions() async throws -> [LMSEditQuestion] {
        let req = try makeRequest(path: "manage_questions.php", method: "GET")
        let res = try await perform(req, decodeAs: LMSQuestionsListResponse.self)
        guard res.ok else { throw LMSEditError.server("Failed to load questions") }
        return res.questions
    }
}
