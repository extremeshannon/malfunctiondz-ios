// File: ASC/ViewModels/AircraftDetailViewModel.swift
import Foundation

// Top-level wrapper — cannot be nested in generic function
private struct DetailListWrapper<T: Decodable>: Decodable {
    let ok: Bool
    let data: [T]?
}

@MainActor
class AircraftDetailViewModel: ObservableObject {
    @Published var squawks: [Squawk] = []
    @Published var logbook: [LogbookEntry] = []
    @Published var ads: [AirworthinessDirective] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadDetail(aircraftId: Int) async {
        isLoading = true
        defer { isLoading = false }
        async let sq = fetchSquawks(aircraftId: aircraftId)
        async let lb = fetchLogbook(aircraftId: aircraftId)
        async let ad = fetchAds(aircraftId: aircraftId)
        squawks = await sq
        logbook = await lb
        ads     = await ad
    }

    private func fetchSquawks(aircraftId: Int) async -> [Squawk] {
        guard let data = await fetch(path: "/api/aircraft/squawks.php?id=\(aircraftId)") else { return [] }
        return (try? JSONDecoder().decode(DetailListWrapper<Squawk>.self, from: data))?.data ?? []
    }

    private func fetchLogbook(aircraftId: Int) async -> [LogbookEntry] {
        guard let data = await fetch(path: "/api/aircraft/logbook.php?id=\(aircraftId)") else { return [] }
        return (try? JSONDecoder().decode(DetailListWrapper<LogbookEntry>.self, from: data))?.data ?? []
    }

    private func fetchAds(aircraftId: Int) async -> [AirworthinessDirective] {
        guard let data = await fetch(path: "/api/aircraft/ads.php?id=\(aircraftId)") else { return [] }
        return (try? JSONDecoder().decode(DetailListWrapper<AirworthinessDirective>.self, from: data))?.data ?? []
    }

    private func fetch(path: String) async -> Data? {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try? await URLSession.shared.data(for: req).0
    }
}
