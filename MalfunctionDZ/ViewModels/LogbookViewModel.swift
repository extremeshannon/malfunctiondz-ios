// File: ASC/ViewModels/LogbookViewModel.swift
// Purpose: Load skydiver logbook entries — for a course (LMS) or all entries (standalone).
import Foundation

@MainActor
class LogbookViewModel: ObservableObject {
    @Published var entries: [SkydiverLogbookEntry] = []
    @Published var otherTrainingNotes: String = ""
    @Published var priorJumpCount: Int = 0
    @Published var totalJumps: Int = 0
    @Published var isStudent: Bool = false
    @Published var isSkydiver: Bool = false
    @Published var nextJumpNumber: Int = 1
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    private var currentCourseId: Int?

    /// Load logbook. Pass courseId to filter by course (LMS flow); pass nil for all entries (standalone, skydivers without LMS).
    func load(courseId: Int? = nil, userId: Int? = nil) async {
        isLoading = true
        error = nil
        currentCourseId = courseId
        defer { isLoading = false }

        var components = URLComponents(string: "\(kServerURL)/api/lms/logbook.php")
        var items: [URLQueryItem] = []
        if let cid = courseId, cid > 0 {
            items.append(URLQueryItem(name: "course_id", value: "\(cid)"))
        }
        if let uid = userId {
            items.append(URLQueryItem(name: "user_id", value: "\(uid)"))
        }
        if !items.isEmpty { components?.queryItems = items }

        guard let token = KeychainHelper.readToken(),
              let url = components?.url else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 404 {
                entries = []
                otherTrainingNotes = ""
                return
            }
            let decoded = try? JSONDecoder().decode(SkydiverLogbookResponse.self, from: data)
            if let resp = decoded, resp.ok {
                entries = resp.entries ?? []
                otherTrainingNotes = resp.otherTrainingNotes ?? ""
                priorJumpCount = resp.priorJumpCount ?? 0
                totalJumps = resp.totalJumps ?? priorJumpCount
                isStudent = resp.isStudent ?? false
                isSkydiver = resp.isSkydiver ?? false
                nextJumpNumber = resp.nextJumpNumber ?? (priorJumpCount + 1)
            } else {
                entries = []
                otherTrainingNotes = ""
                priorJumpCount = 0
                totalJumps = 0
                isStudent = false
                isSkydiver = false
                nextJumpNumber = 1
            }
        } catch {
            entries = []
            otherTrainingNotes = ""
            self.error = error.localizedDescription
        }
    }

    /// Set prior jump count (jumps before this system). Standalone only.
    func setPriorJumpCount(_ count: Int) async {
        guard count >= 0 else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["prior_jump_count": count])

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                priorJumpCount = count
                totalJumps = max(priorJumpCount, totalJumps)
                nextJumpNumber = totalJumps + 1
                isStudent = totalJumps < 25
                isSkydiver = totalJumps >= 25
            } else {
                error = (json?["error"] as? String) ?? "Failed to save"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Add a jump entry. Skydivers only (total >= 25).
    func addEntry(dz: String?, altitude: String?, delay: String?, date: String?, aircraft: String?,
                  equipment: String?, totalTime: String?, jumpType: String?, comments: String?) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_add.php") else { return }

        var body: [String: Any?] = [
            "dz": dz?.isEmpty == true ? nil : dz,
            "altitude": altitude?.isEmpty == true ? nil : altitude,
            "delay": delay?.isEmpty == true ? nil : delay,
            "date": date?.isEmpty == true ? nil : date,
            "aircraft": aircraft?.isEmpty == true ? nil : aircraft,
            "equipment": equipment?.isEmpty == true ? nil : equipment,
            "total_time": totalTime?.isEmpty == true ? nil : totalTime,
            "jump_type": jumpType?.isEmpty == true ? nil : jumpType,
            "comments": comments?.isEmpty == true ? nil : comments,
        ]
        let clean = body.compactMapValues { $0 }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: clean) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if statusCode == 403 {
                error = json?["error"] as? String ?? "You need 25 jumps to add entries."
                return
            }
            if (json?["ok"] as? Bool) == true {
                await load(courseId: currentCourseId, userId: nil)
            } else {
                error = json?["error"] as? String ?? "Failed to add entry"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
