// File: ASC/ViewModels/LogbookViewModel.swift
// Purpose: Load skydiver logbook entries for a course (LMS-linked).
import Foundation

@MainActor
class LogbookViewModel: ObservableObject {
    @Published var entries: [SkydiverLogbookEntry] = []
    @Published var otherTrainingNotes: String = ""
    @Published var isLoading = false
    @Published var error: String?

    /// Load logbook for the given course and current user (or optional student user_id for instructors).
    func load(courseId: Int, userId: Int? = nil) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        var components = URLComponents(string: "\(kServerURL)/api/lms/logbook.php")
        components?.queryItems = [URLQueryItem(name: "course_id", value: "\(courseId)")]
        if let uid = userId {
            components?.queryItems?.append(URLQueryItem(name: "user_id", value: "\(uid)"))
        }

        guard let token = KeychainHelper.readToken(),
              let url = components?.url else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try? JSONDecoder().decode(SkydiverLogbookResponse.self, from: data)
            if let resp = decoded, resp.ok {
                entries = resp.entries ?? []
                otherTrainingNotes = resp.otherTrainingNotes ?? ""
            } else {
                // Backend may not exist yet; treat as empty
                entries = []
                otherTrainingNotes = ""
            }
        } catch {
            self.error = error.localizedDescription
            entries = []
            otherTrainingNotes = ""
        }
    }
}
