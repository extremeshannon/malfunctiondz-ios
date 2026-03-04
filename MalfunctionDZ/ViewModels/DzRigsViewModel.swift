// File: ASC/ViewModels/DzRigsViewModel.swift
// DZ Rigs — DZ-owned rigs for packers + 25+ jump users. Packers can mark as packed.
import Foundation
import SwiftUI

struct DzRigsResponse: Codable {
    let ok: Bool
    let summary: LoftSummary?
    let rigs: [LoftRig]?
    let canMarkPacked: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, summary, rigs
        case canMarkPacked = "can_mark_packed"
    }
}

@MainActor
class DzRigsViewModel: ObservableObject {
    @Published var rigs:         [LoftRig] = []
    @Published var summary:      LoftSummary?
    @Published var canMarkPacked = false
    @Published var isLoading     = false
    @Published var error:        String?
    @Published var markingRigId: Int?

    var overdueRigs:  [LoftRig] { rigs.filter { $0.status == "overdue" } }
    var dueSoonRigs:  [LoftRig] { rigs.filter { $0.status == "due_soon" } }
    var currentRigs:  [LoftRig] { rigs.filter { $0.status == "current" } }
    var unknownRigs:  [LoftRig] { rigs.filter { $0.status == "unknown" } }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/loft/dz_rigs.php") else {
            error = "Not configured"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(DzRigsResponse.self, from: data)
            if resp.ok {
                rigs = resp.rigs ?? []
                summary = resp.summary
                canMarkPacked = resp.canMarkPacked ?? false
            } else {
                error = "Failed to load DZ rigs"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markPacked(rigId: Int) async {
        markingRigId = rigId
        defer { markingRigId = nil }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/loft/dz_rigs.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["rig_id": rigId])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["ok"] as? Bool) == true {
                await load()
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let err = json["error"] as? String {
                error = err
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
