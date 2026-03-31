// File: ASC/ViewModels/GroundSchoolViewModel.swift
import Foundation
import SwiftUI
import MalfunctionDZCore

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
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                await AuthManager.shared.logout()
                error = "Session expired"
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                error = "You don't have permission to view courses"
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                error = "Ground School is not available on this server"
                return
            }
            let resp = try JSONDecoder().decode(LMSCoursesResponse.self, from: data)
            if resp.ok {
                courses = (resp.courses ?? []).sorted { $0.isActive && !$1.isActive }
            } else {
                error = resp.error ?? "Failed to load courses"
            }
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
