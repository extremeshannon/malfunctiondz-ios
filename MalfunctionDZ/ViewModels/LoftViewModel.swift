// File: ASC/ViewModels/LoftViewModel.swift
import Foundation
import SwiftUI
import MalfunctionDZCore

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

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/loft/list.php") else { return }
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
                error = "You don't have permission to view loft"
                return
            }
            let resp = try JSONDecoder().decode(LoftListResponse.self, from: data)
            if resp.ok {
                rigs    = resp.rigs ?? []
                summary = resp.summary
            } else {
                error = "Failed to load loft data"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
