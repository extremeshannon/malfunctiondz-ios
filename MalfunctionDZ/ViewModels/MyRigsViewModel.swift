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
            guard !data.isEmpty, let first = data.first, first == UInt8(ascii: "{") else {
                return // Non-JSON response, skip silently (e.g. HTML error page)
            }
            let resp = try JSONDecoder().decode(RigsResponse.self, from: data)
            if resp.ok {
                rigs = resp.rigs ?? []
            }
        } catch {
            // Don't set error for my rigs — RigsView shows DZ rigs as primary
            rigs = []
        }
    }
}
