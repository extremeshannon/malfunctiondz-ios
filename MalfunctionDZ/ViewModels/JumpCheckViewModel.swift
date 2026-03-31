// File: ASC/ViewModels/JumpCheckViewModel.swift
// 25 Jump Check — Ops view of users with jump counts
import Foundation
import SwiftUI
import MalfunctionDZCore

struct JumpCheckUser: Identifiable, Codable {
    let id: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let totalJumps: Int

    enum CodingKeys: String, CodingKey {
        case id, username
        case firstName = "first_name"
        case lastName = "last_name"
        case totalJumps = "total_jumps"
    }

    var displayName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? username : name
    }

    var passed25: Bool { totalJumps >= 25 }
}

struct JumpCheckResponse: Codable {
    let ok: Bool
    let users: [JumpCheckUser]?
}

@MainActor
class JumpCheckViewModel: ObservableObject {
    @Published var users: [JumpCheckUser] = []
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken() else {
            error = "Not authenticated"
            return
        }
        var urlString = "\(kServerURL)/api/users/jump_check.php"
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            urlString += "?q=" + searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        }
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(JumpCheckResponse.self, from: data)
            if resp.ok {
                users = resp.users ?? []
            } else {
                error = "Failed to load"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
