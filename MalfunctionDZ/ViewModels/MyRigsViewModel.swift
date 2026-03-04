// File: ASC/ViewModels/MyRigsViewModel.swift
// My Rigs — read-only view of user's owned rigs from /api/lms/rigs.php
import Foundation
import SwiftUI

@MainActor
class MyRigsViewModel: ObservableObject {
    @Published var rigs:     [JumperRig] = []
    @Published var isLoading = false
    @Published var error:    String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/rigs.php") else {
            error = "Not configured"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(RigsResponse.self, from: data)
            if resp.ok {
                rigs = resp.rigs ?? []
            } else {
                error = "Failed to load rigs"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
