// Rig squawks — all rigs list for ASC Packers.
import Foundation
import SwiftUI
import MalfunctionDZCore

private func rigSquawksExtractJsonPrefix(_ data: Data) -> Data {
    if let first = data.first, first == UInt8(ascii: "{") { return data }
    if let str = String(data: data, encoding: .utf8),
       let start = str.firstIndex(of: "{"),
       let extracted = str[start...].data(using: .utf8) {
        return extracted
    }
    return data
}

private func rigSquawksApiErrorMessage(_ slice: Data) -> String? {
    guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else { return nil }
    if let e = obj["error"] as? String, !e.isEmpty { return e }
    if let d = obj["detail"] as? String, !d.isEmpty { return d }
    if let arr = obj["detail"] as? [[String: Any]] {
        let parts = arr.compactMap { $0["msg"] as? String }.filter { !$0.isEmpty }
        if let first = parts.first { return first }
    }
    return nil
}

private func responseHasRigsWithoutSquawks(_ slice: Data) -> Bool {
    guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else { return false }
    return obj["rigs"] != nil && obj["squawks"] == nil
}

private func humanizeRigSquawksApiMessage(_ raw: String?) -> String {
    let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if t.caseInsensitiveCompare("not found") == .orderedSame {
        return serverUpdateRequiredMessage
    }
    return t.isEmpty ? "Failed to load squawks" : t
}

private let serverUpdateRequiredMessage =
    "Squawks API is not on the server yet. On the VPS run: git pull && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build platform_py"

/// Production FastAPI first (malfunctiondz.com), then .php aliases.
private func rigSquawksCandidateURLs(status: String?) -> [URL] {
    var urls: [URL] = []
    for usePhp in [false, true] {
        for endpoint in ["dz_rigs", "rig_squawks"] {
            let leaf = usePhp ? "\(endpoint).php" : endpoint
            var c = URLComponents(string: "\(kServerURL)/api/loft/\(leaf)")
            var items = [URLQueryItem(name: "limit", value: "500")]
            if endpoint == "dz_rigs" {
                items.insert(URLQueryItem(name: "squawks", value: "1"), at: 0)
            }
            if let s = status, !s.isEmpty {
                items.append(URLQueryItem(name: "status", value: s))
            }
            c?.queryItems = items
            if let u = c?.url { urls.append(u) }
        }
    }
    return urls
}

struct RigSquawksResponse: Codable {
    let ok: Bool
    let squawks: [RigSquawk]?
    let total: Int?
    let error: String?
}

enum RigSquawkFilter: String, CaseIterable, Identifiable {
    case all, open, deferred, closed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .open: return "Open"
        case .deferred: return "Deferred"
        case .closed: return "Closed"
        }
    }

    var apiStatus: String? {
        switch self {
        case .all: return nil
        default: return rawValue
        }
    }
}

@MainActor
class RigSquawksViewModel: ObservableObject {
    @Published var squawks: [RigSquawk] = []
    @Published var total = 0
    @Published var filter: RigSquawkFilter = .all
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken() else {
            error = "Not configured"
            return
        }
        let urls = rigSquawksCandidateURLs(status: filter.apiStatus)
        guard !urls.isEmpty else {
            error = "Not configured"
            return
        }
        var sawUnsupportedRigsPayload = false
        do {
            attemptLoop: for (index, url) in urls.enumerated() {
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: req)
                let http = response as? HTTPURLResponse
                if let code = http?.statusCode, code == 404, index + 1 < urls.count {
                    continue attemptLoop
                }
                let slice = rigSquawksExtractJsonPrefix(data)
                if let http, !(200 ... 299).contains(http.statusCode) {
                    if http.statusCode == 404, index + 1 < urls.count {
                        continue attemptLoop
                    }
                    let parsedErr = (try? JSONDecoder().decode(RigSquawksResponse.self, from: slice))?.error
                    let combined = rigSquawksApiErrorMessage(slice) ?? parsedErr
                    error = humanizeRigSquawksApiMessage(combined ?? "Server error (HTTP \(http.statusCode))")
                    return
                }
                if responseHasRigsWithoutSquawks(slice) {
                    sawUnsupportedRigsPayload = true
                    if index + 1 < urls.count { continue attemptLoop }
                    error = serverUpdateRequiredMessage
                    return
                }
                let decoded = try JSONDecoder().decode(RigSquawksResponse.self, from: slice)
                guard decoded.ok else {
                    error = humanizeRigSquawksApiMessage(decoded.error)
                    return
                }
                if decoded.squawks != nil {
                    squawks = decoded.squawks ?? []
                    total = decoded.total ?? squawks.count
                    error = nil
                    return
                }
                if index + 1 < urls.count { continue attemptLoop }
            }
            error = sawUnsupportedRigsPayload ? serverUpdateRequiredMessage : humanizeRigSquawksApiMessage("Not Found")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setFilter(_ f: RigSquawkFilter) async {
        filter = f
        await load()
    }
}
