// File: ASC/ViewModels/LoftViewModel.swift
import Foundation
import SwiftUI
import MalfunctionDZCore

private func loftExtractJsonPrefix(_ data: Data) -> Data {
    if let first = data.first, first == UInt8(ascii: "{") { return data }
    if let str = String(data: data, encoding: .utf8),
       let start = str.firstIndex(of: "{"),
       let extracted = str[start...].data(using: .utf8) {
        return extracted
    }
    return data
}

private func loftApiErrorMessage(_ data: Data) -> String? {
    let slice = loftExtractJsonPrefix(data)
    guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else { return nil }
    if let e = obj["error"] as? String, !e.isEmpty { return e }
    if let d = obj["detail"] as? String, !d.isEmpty { return d }
    return nil
}

@MainActor
class LoftViewModel: ObservableObject {
    @Published var rigs:      [LoftRig] = []
    @Published var summary:   LoftSummary?
    @Published var isLoading  = false
    @Published var error:     String?

    var overdueRigs:  [LoftRig] { rigs.filter { $0.status == "overdue" } }
    var dueSoonRigs:  [LoftRig] { rigs.filter { $0.status == "due_soon" } }
    var currentRigs:  [LoftRig] { rigs.filter { $0.status == "current" } }
    var unknownRigs:  [LoftRig] { rigs.filter { $0.status == "unknown" } }

    /// Release/TestFlight: legacy loft list is live on production; HHIO paths are local-only until deploy.
    private static var listPaths: [String] {
        #if DEBUG
        return [
            "/api/hhio/loft/list.php",
            "/api/hhio/loft/list",
            "/api/loft/list.php",
            "/api/loft/list",
        ]
        #else
        return [
            "/api/loft/list.php",
            "/api/loft/list",
            "/api/hhio/loft/list.php",
            "/api/hhio/loft/list",
        ]
        #endif
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken() else { return }

        var lastMessage = "Failed to load loft data"
        for path in Self.listPaths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = loftExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 401 {
                    AuthManager.shared.logout()
                    error = "Session expired"
                    return
                }
                if http.statusCode == 404 {
                    lastMessage = loftApiErrorMessage(slice) ?? "Loft API not found"
                    continue
                }
                let resp = try JSONDecoder().decode(LoftListResponse.self, from: slice)
                if resp.ok {
                    rigs = resp.rigs ?? []
                    summary = resp.summary
                    error = nil
                    return
                }
                let apiErr = resp.error?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if http.statusCode == 403 {
                    error = apiErr.isEmpty ? "You don't have permission to view loft" : apiErr
                    return
                }
                if apiErr.caseInsensitiveCompare("not found") == .orderedSame {
                    lastMessage = apiErr
                    continue
                }
                lastMessage = apiErr.isEmpty ? "Failed to load loft data" : apiErr
            } catch let decodeError {
                lastMessage = decodeError.localizedDescription
            }
        }
        error = lastMessage
    }
}
