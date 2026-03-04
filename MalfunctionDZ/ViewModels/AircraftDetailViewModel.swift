// File: ASC/ViewModels/AircraftDetailViewModel.swift
import Foundation

// Top-level wrapper — cannot be nested in generic function
private struct DetailListWrapper<T: Decodable>: Decodable {
    let ok: Bool
    let data: [T]?
}

private struct DetailSingleWrapper<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
}

@MainActor
class AircraftDetailViewModel: ObservableObject {
    @Published var squawks: [Squawk] = []
    @Published var logbook: [LogbookEntry] = []
    @Published var ads: [AirworthinessDirective] = []
    @Published var logbookDetail: LogbookEntryDetail?
    @Published var logbookDetailLoading = false
    @Published var isLoading = false
    @Published var error: String?

    func loadDetail(aircraftId: Int) async {
        isLoading = true
        defer { isLoading = false }
        async let sq = fetchSquawks(aircraftId: aircraftId)
        async let lb = fetchLogbook(aircraftId: aircraftId, bookType: "all")
        async let ad = fetchAds(aircraftId: aircraftId)
        squawks = await sq
        logbook = await lb
        ads     = await ad
    }

    func loadLogbook(aircraftId: Int, bookType: String) async {
        let entries = await fetchLogbook(aircraftId: aircraftId, bookType: bookType)
        logbook = entries
    }

    func loadLogbookEntryDetail(aircraftId: Int, entryId: Int) async {
        logbookDetailLoading = true
        logbookDetail = nil
        defer { logbookDetailLoading = false }
        guard let data = await fetch(path: "/api/aircraft/logbook_entry.php?id=\(aircraftId)&entry_id=\(entryId)") else { return }
        logbookDetail = (try? JSONDecoder().decode(DetailSingleWrapper<LogbookEntryDetail>.self, from: data))?.data
    }

    private func fetchSquawks(aircraftId: Int) async -> [Squawk] {
        guard let data = await fetch(path: "/api/aircraft/squawks.php?id=\(aircraftId)") else { return [] }
        return (try? JSONDecoder().decode(DetailListWrapper<Squawk>.self, from: data))?.data ?? []
    }

    private func fetchLogbook(aircraftId: Int, bookType: String = "all") async -> [LogbookEntry] {
        let encoded = bookType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bookType
        guard let data = await fetch(path: "/api/aircraft/logbook.php?id=\(aircraftId)&book_type=\(encoded)") else { return [] }
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
