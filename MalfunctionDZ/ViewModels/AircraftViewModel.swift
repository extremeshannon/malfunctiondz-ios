// File: ASC/ViewModels/AircraftViewModel.swift
import Foundation
import SwiftUI
import MalfunctionDZCore

// Server returns {"ok":true,"aircraft":[...]} not {"ok":true,"data":[...]}
private struct AircraftListResponse: Decodable {
    let ok: Bool
    let aircraft: [Aircraft]?
    let error: String?
}

@MainActor
class AircraftViewModel: ObservableObject {
    @Published var aircraft: [Aircraft] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/aircraft/list.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(AircraftListResponse.self, from: data)
            if resp.ok, let list = resp.aircraft {
                aircraft = list
            } else {
                self.error = resp.error ?? "Failed to load aircraft"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
