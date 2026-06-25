// A-License Progress — USPA ISP categories A–H sign-off status (read-only for students).
import Foundation
import MalfunctionDZCore

@MainActor
final class ALicenseProgressViewModel: ObservableObject {
    @Published var blocks: [ProgressionBlock] = []
    @Published var categoryProgress: ProgressionStats?
    @Published var overallProgress: ProgressionStats?
    @Published var studentName = ""
    @Published var updatedAt = ""
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/progression-form.php") else {
            error = "Not configured"
            return
        }
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
                error = "You don't have permission to view the progression card"
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                error = "Progression card is not available on this server yet"
                return
            }
            let decoded = try JSONDecoder().decode(ProgressionFormResponse.self, from: data)
            guard decoded.ok else {
                error = decoded.error ?? "Failed to load progression card"
                return
            }
            blocks = decoded.blocks ?? []
            categoryProgress = decoded.categoryProgress
            overallProgress = decoded.progress
            studentName = decoded.studentName ?? ""
            updatedAt = decoded.updatedAt ?? ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - API models

struct ProgressionFormResponse: Decodable {
    let ok: Bool
    let error: String?
    let studentName: String?
    let updatedAt: String?
    let progress: ProgressionStats?
    let categoryProgress: ProgressionStats?
    let blocks: [ProgressionBlock]?

    enum CodingKeys: String, CodingKey {
        case ok, error, progress, blocks
        case studentName = "student_name"
        case updatedAt = "updated_at"
        case categoryProgress = "category_progress"
    }
}

struct ProgressionStats: Decodable {
    let done: Int
    let total: Int
    let progressPct: Double
    let complete: Bool
    let currentStep: String?

    enum CodingKeys: String, CodingKey {
        case done, total, complete
        case progressPct = "progress_pct"
        case currentStep = "current_step"
    }
}

struct ProgressionBlock: Decodable, Identifiable {
    let type: String
    let key: String
    let title: String
    let note: String?
    let progress: ProgressionStats
    let sections: [ProgressionSection]

    var id: String { key }
}

struct ProgressionSection: Decodable, Identifiable {
    let key: String
    let title: String
    let note: String?
    let quizDate: String?
    let fields: [ProgressionField]?
    let rows: [ProgressionRow]?
    let progress: ProgressionStats?

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, title, note, fields, rows, progress
        case quizDate = "quiz_date"
    }
}

struct ProgressionField: Decodable, Identifiable {
    let name: String
    let label: String
    let type: String
    let prefix: String?
    let value: ProgressionFieldValue?
    let done: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, label, type, prefix, value, done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        label = try c.decode(String.self, forKey: .label)
        type = try c.decode(String.self, forKey: .type)
        prefix = try c.decodeIfPresent(String.self, forKey: .prefix)
        done = try c.decode(Bool.self, forKey: .done)
        if let s = try? c.decode(String.self, forKey: .value) {
            value = .string(s)
        } else if let b = try? c.decode(Bool.self, forKey: .value) {
            value = .bool(b)
        } else if let arr = try? c.decode([String].self, forKey: .value) {
            value = .strings(arr)
        } else {
            value = nil
        }
    }
}

enum ProgressionFieldValue {
    case string(String)
    case bool(Bool)
    case strings([String])

    var displayText: String {
        switch self {
        case .string(let s): return s
        case .bool(let b): return b ? "Yes" : ""
        case .strings(let a): return a.joined(separator: ", ")
        }
    }
}

struct ProgressionRow: Decodable, Identifiable {
    let label: String
    let mode: String
    let done: Bool
    let coach: String?
    let instructor: String?
    let checked: [String]?
    let options: [String]?

    var id: String { label }
}
