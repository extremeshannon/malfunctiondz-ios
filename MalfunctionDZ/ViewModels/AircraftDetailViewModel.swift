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
            error = friendlyError(e)
        }
    }

    private func friendlyError(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("not found") || lower.contains("404") {
            return "Squawks, logbook, or ADs could not be loaded (404). In More → Profile, check API Base URL and ensure the server provides /api/aircraft/ endpoints (squawks, logbook, ads)."
        }
        return message
    }

    func loadLogbook(aircraftId: Int, bookType: String) async {
        let result = await fetchLogbook(aircraftId: aircraftId, bookType: bookType)
        logbook = result.entries
        if let e = result.error { error = friendlyError(e) }
    }

    func loadLogbookEntryDetail(aircraftId: Int, entryId: Int) async {
        logbookDetailLoading = true
        logbookDetail = nil
        defer { logbookDetailLoading = false }
        guard let data = await fetch(path: "/api/aircraft/logbook_entry.php?id=\(aircraftId)&entry_id=\(entryId)").data else { return }
        logbookDetail = (try? JSONDecoder().decode(DetailSingleWrapper<LogbookEntryDetail>.self, from: data))?.data
    }

    private func fetchSquawks(aircraftId: Int) async -> (entries: [Squawk], error: String?) {
        let (data, statusCode) = await fetch(path: "/api/aircraft/squawks.php?id=\(aircraftId)")
        if statusCode == 404 {
            return ([], "Squawks endpoint not found (404). Check API Base URL in Profile.")
        }
        guard let data = data else {
            return ([], "Could not reach server. Check API Base URL in More → Profile.")
        }
        if let wrapper = try? JSONDecoder().decode(DetailListWrapper<Squawk>.self, from: data) {
            if !(wrapper.ok) { return ([], wrapper.error ?? "Server error") }
            return (wrapper.data ?? [], nil)
        }
        return ([], "Invalid response from squawks API.")
    }

    private func fetchLogbook(aircraftId: Int, bookType: String = "all") async -> (entries: [LogbookEntry], error: String?) {
        let encoded = bookType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bookType
        let (data, statusCode) = await fetch(path: "/api/aircraft/logbook.php?id=\(aircraftId)&book_type=\(encoded)")
        if statusCode == 404 {
            return ([], "Logbook endpoint not found (404). Check API Base URL in Profile.")
        }
        guard let data = data else {
            return ([], "Could not reach server.")
        }
        if let wrapper = try? JSONDecoder().decode(DetailListWrapper<LogbookEntry>.self, from: data) {
            if !(wrapper.ok) { return ([], wrapper.error ?? "Server error") }
            return (wrapper.data ?? [], nil)
        }
        return ([], "Invalid response from logbook API.")
    }

    private func fetchAds(aircraftId: Int) async -> (entries: [AirworthinessDirective], error: String?) {
        let (data, statusCode) = await fetch(path: "/api/aircraft/ads.php?id=\(aircraftId)")
        if statusCode == 404 {
            return ([], "ADs endpoint not found (404). Check API Base URL in Profile.")
        }
        guard let data = data else {
            return ([], "Could not reach server.")
        }
        if let wrapper = try? JSONDecoder().decode(DetailListWrapper<AirworthinessDirective>.self, from: data) {
            if !(wrapper.ok) { return ([], wrapper.error ?? "Server error") }
            return (wrapper.data ?? [], nil)
        }
        return ([], "Invalid response from ADs API.")
    }

    private func fetch(path: String) async -> (data: Data?, statusCode: Int?) {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)\(path)") else { return (nil, nil) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else { return (nil, nil) }
        return (data, http.statusCode)
    }
}
