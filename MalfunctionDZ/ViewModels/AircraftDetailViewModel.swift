// File: ASC/ViewModels/AircraftDetailViewModel.swift
import Foundation

private struct DetailListWrapper<T: Decodable>: Decodable {
    let ok: Bool
    let data: [T]?
    let error: String?
}

private struct DetailSingleWrapper<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: String?
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
        error = nil
        defer { isLoading = false }
        async let sq = fetchSquawks(aircraftId: aircraftId)
        async let lb = fetchLogbook(aircraftId: aircraftId, bookType: "all")
        async let ad = fetchAds(aircraftId: aircraftId)
        let (squawkResult, logbookResult, adsResult) = await (sq, lb, ad)
        squawks = squawkResult.entries
        logbook = logbookResult.entries
        ads = adsResult.entries
        if let e = squawkResult.error ?? logbookResult.error ?? adsResult.error {
            error = e
        }
    }

    func loadLogbook(aircraftId: Int, bookType: String) async {
        let result = await fetchLogbook(aircraftId: aircraftId, bookType: bookType)
        logbook = result.entries
        if let e = result.error { error = e }
    }

    func loadLogbookEntryDetail(aircraftId: Int, entryId: Int) async {
        logbookDetailLoading = true
        logbookDetail = nil
        defer { logbookDetailLoading = false }
        guard let data = await fetch(path: "/api/aircraft/logbook_entry.php?id=\(aircraftId)&entry_id=\(entryId)") else { return }
        logbookDetail = (try? JSONDecoder().decode(DetailSingleWrapper<LogbookEntryDetail>.self, from: data))?.data
    }

    private func fetchSquawks(aircraftId: Int) async -> (entries: [Squawk], error: String?) {
        guard let data = await fetch(path: "/api/aircraft/squawks.php?id=\(aircraftId)") else {
            return ([], "Could not reach server. Check that the app is pointed at the correct API (e.g. MAMP).")
        }
        if let wrapper = try? JSONDecoder().decode(DetailListWrapper<Squawk>.self, from: data) {
            if !(wrapper.ok) { return ([], wrapper.error ?? "Server error") }
            return (wrapper.data ?? [], nil)
        }
        return ([], "Invalid response from squawks API.")
    }

    private func fetchLogbook(aircraftId: Int, bookType: String = "all") async -> (entries: [LogbookEntry], error: String?) {
        let encoded = bookType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bookType
        guard let data = await fetch(path: "/api/aircraft/logbook.php?id=\(aircraftId)&book_type=\(encoded)") else {
            return ([], "Could not reach server.")
        }
        if let wrapper = try? JSONDecoder().decode(DetailListWrapper<LogbookEntry>.self, from: data) {
            if !(wrapper.ok) { return ([], wrapper.error ?? "Server error") }
            return (wrapper.data ?? [], nil)
        }
        return ([], "Invalid response from logbook API.")
    }

    private func fetchAds(aircraftId: Int) async -> (entries: [AirworthinessDirective], error: String?) {
        guard let data = await fetch(path: "/api/aircraft/ads.php?id=\(aircraftId)") else {
            return ([], "Could not reach server.")
        }
        if let wrapper = try? JSONDecoder().decode(DetailListWrapper<AirworthinessDirective>.self, from: data) {
            if !(wrapper.ok) { return ([], wrapper.error ?? "Server error") }
            return (wrapper.data ?? [], nil)
        }
        return ([], "Invalid response from ADs API.")
    }

    private func fetch(path: String) async -> Data? {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try? await URLSession.shared.data(for: req).0
    }
}
