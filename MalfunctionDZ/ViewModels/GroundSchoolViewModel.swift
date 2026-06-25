// File: ASC/ViewModels/GroundSchoolViewModel.swift
import Foundation
import SwiftUI
import MalfunctionDZCore

private func isBenignLoadCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let url = error as? URLError, url.code == .cancelled { return true }
    let ns = error as NSError
    return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
}

@MainActor
class GroundSchoolViewModel: ObservableObject {
    @Published var courses:   [LMSCourse] = []
    @Published var isLoading  = false
    @Published var error:     String?
    @Published var pendingInstructorReviews = 0

    func load(scope: GroundSchoolScope = .all) async {
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
                AuthManager.shared.logout()
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
                var list = resp.courses ?? []
                if scope == .pilotTrainingOnly {
                    list = list.filter(\.isPilotTraining)
                }
                courses = list.sorted { $0.isActive && !$1.isActive }
                error = nil
            } else {
                error = resp.error ?? "Failed to load courses"
            }
        } catch {
            guard !isBenignLoadCancellation(error) else { return }
            self.error = error.localizedDescription
        }
        await loadPendingInstructorReviews()
    }

    private func loadPendingInstructorReviews() async {
        guard AuthManager.shared.currentUser?.isInstructorRole == true,
              let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/pending_signoffs.php") else {
            pendingInstructorReviews = 0
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        struct PR: Decodable { let ok: Bool; let data: PD?; struct PD: Decodable { let pending_count: Int } }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(PR.self, from: data),
              resp.ok, let d = resp.data else { return }
        pendingInstructorReviews = d.pending_count
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
