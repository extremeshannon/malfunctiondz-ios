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
    @Published var stcEntries: [StcEntry] = []
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
        async let stc = fetchStc337(aircraftId: aircraftId)
        let (squawkResult, logbookResult, adsResult, stcResult) = await (sq, lb, ad, stc)

        // Only replace data when fetch succeeded; on failure keep previous so refresh doesn't wipe good data
        if squawkResult.error == nil { squawks = squawkResult.entries }
        if logbookResult.error == nil { logbook = logbookResult.entries }
        if adsResult.error == nil { ads = adsResult.entries }
        if stcResult.error == nil { stcEntries = stcResult.entries }

        let anyError = squawkResult.error ?? logbookResult.error ?? adsResult.error ?? stcResult.error
        if let e = anyError {
            let hasData = !squawks.isEmpty || !logbook.isEmpty || !ads.isEmpty || !stcEntries.isEmpty
            if hasData {
                error = "Could not refresh all data. Showing last loaded."
            } else {
                error = friendlyError(e)
            }
        }
    }

    private func friendlyError(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("not found") || lower.contains("404") {
            return "Squawks, logbook, ADs, or STC/337 could not be loaded (404). In More → Profile, check API Base URL and ensure the server provides /api/aircraft/ endpoints."
        }
        return message
    }

    func loadLogbook(aircraftId: Int, bookType: String) async {
        let result = await fetchLogbook(aircraftId: aircraftId, bookType: bookType)
        if result.error == nil {
            logbook = result.entries
        }
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

    private func fetchStc337(aircraftId: Int, typeFilter: String = "") async -> (entries: [StcEntry], error: String?) {
        var path = "/api/aircraft/stc337.php?id=\(aircraftId)"
        if !typeFilter.isEmpty {
            path += "&type_filter=\(typeFilter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? typeFilter)"
        }
        let (data, statusCode) = await fetch(path: path)
        if statusCode == 404 {
            return ([], "STC/337 endpoint not found (404). Check API Base URL in Profile.")
        }
        guard let data = data else {
            return ([], "Could not reach server.")
        }
        if let wrapper = try? JSONDecoder().decode(DetailListWrapper<StcEntry>.self, from: data) {
            if !(wrapper.ok) { return ([], wrapper.error ?? "Server error") }
            return (wrapper.data ?? [], nil)
        }
        return ([], "Invalid response from STC/337 API.")
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
