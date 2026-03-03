// File: ASC/ViewModels/GroundSchoolViewModel.swift
import Foundation
import SwiftUI

@MainActor
class GroundSchoolViewModel: ObservableObject {
    @Published var courses:   [LMSCourse] = []
    @Published var isLoading  = false
    @Published var error:     String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              // ← my_courses.php returns only enrolled courses for students,
              //   all courses for admins/instructors
              let url = URL(string: "\(kServerURL)/api/lms/my_courses.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(LMSCoursesResponse.self, from: data)
            courses = resp.courses.sorted { $0.isActive && !$1.isActive }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markComplete(lessonId: Int, courseId: Int) async {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/complete.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["lesson_id": lessonId, "course_id": courseId])
        _ = try? await URLSession.shared.data(for: req)
        await load()
    }
}
