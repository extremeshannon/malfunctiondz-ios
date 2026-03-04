// File: MalfunctionDZ/Services/CalendarAPIService.swift
// API client for calendar events and staff shifts.

import Foundation

actor CalendarAPIService {
    static let shared = CalendarAPIService()

    private func baseURL() -> String { kServerURL }

    // MARK: - Events (no auth)
    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        let fromStr = df.string(from: from)
        let toStr = df.string(from: to)
        let path = "/api/calendar/events.php?from=\(fromStr)&to=\(toStr)"
        return try await requestEvents(path: path, requiresAuth: false)
    }

    // MARK: - Shifts (auth required)
    func fetchShifts(from: Date, to: Date) async throws -> [StaffShift] {
        guard let token = KeychainHelper.readToken(), !token.isEmpty else {
            throw APIError.notAuthenticated
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        let fromStr = df.string(from: from)
        let toStr = df.string(from: to)
        let path = "/api/calendar/shifts.php?from=\(fromStr)&to=\(toStr)"
        return try await requestShifts(path: path, token: token)
    }

    // MARK: - Claim shift
    func claimShift(shiftId: Int) async throws -> String {
        let body = ShiftClaimRequest(shiftId: shiftId)
        return try await postMessage(path: "/api/calendar/shift_claim.php", body: body)
    }

    // MARK: - Request release
    func requestRelease(shiftId: Int) async throws -> String {
        let body = ShiftClaimRequest(shiftId: shiftId)
        return try await postMessage(path: "/api/calendar/shift_request_release.php", body: body)
    }

    // MARK: - Internal request helpers
    private func requestEvents(path: String, requiresAuth: Bool) async throws -> [CalendarEvent] {
        guard let url = URL(string: baseURL() + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth, let token = KeychainHelper.readToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            await AuthManager.shared.logout()
            throw APIError.notAuthenticated
        }
        // Try Codable first, then raw JSON
        if let decoded = try? JSONDecoder().decode(EventsAPIResponse.self, from: data),
           decoded.ok, let events = decoded.events { return events }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.serverError("Invalid response from server.")
        }
        if let ok = json["ok"] as? Bool, !ok, let err = json["error"] as? String {
            throw APIError.serverError(err)
        }
        var arr: [[String: Any]]?
        if let a = json["events"] as? [[String: Any]] { arr = a }
        else if let d = json["data"] as? [String: Any], let a = d["events"] as? [[String: Any]] { arr = a }
        let events = (arr ?? []).compactMap { CalendarEvent(from: $0) }
        return events
    }

    private func requestShifts(path: String, token: String) async throws -> [StaffShift] {
        guard let url = URL(string: baseURL() + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            await AuthManager.shared.logout()
            throw APIError.notAuthenticated
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 {
                throw APIError.serverError("Shifts API not found. The calendar feature may need to be deployed.")
            }
            if http.statusCode != 200 {
                throw APIError.serverError("Server returned \(http.statusCode)")
            }
        }
        // Parse raw JSON to handle format variations
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data.prefix(100), encoding: .utf8) ?? ""
            let isHtml = preview.trimmingCharacters(in: .whitespaces).hasPrefix("<")
            throw APIError.serverError(isHtml
                ? "Shifts API not available on this server yet."
                : "Invalid response from server.")
        }
        if let ok = json["ok"] as? Bool, !ok, let err = json["error"] as? String {
            throw APIError.serverError(err)
        }
        // Get shifts array (direct or nested under data)
        var shiftsArray: [[String: Any]] = []
        if let arr = json["shifts"] as? [[String: Any]] { shiftsArray = arr }
        else if let dataObj = json["data"] as? [String: Any],
                let arr = dataObj["shifts"] as? [[String: Any]] { shiftsArray = arr }
        return shiftsArray.compactMap { StaffShift(from: $0) }
    }

    private func postMessage(path: String, body: Encodable) async throws -> String {
        guard let token = KeychainHelper.readToken(), !token.isEmpty else {
            throw APIError.notAuthenticated
        }
        guard let url = URL(string: baseURL() + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                await AuthManager.shared.logout()
                throw APIError.notAuthenticated
            }
            if http.statusCode == 403 {
                let decoded = (try? JSONDecoder().decode(MessageAPIResponse.self, from: data))
                throw APIError.serverError(decoded?.error ?? "Forbidden")
            }
            if http.statusCode == 409 {
                let decoded = (try? JSONDecoder().decode(MessageAPIResponse.self, from: data))
                throw APIError.serverError(decoded?.error ?? "Shift no longer available")
            }
        }
        let decoded = try JSONDecoder().decode(MessageAPIResponse.self, from: data)
        if decoded.ok, let msg = decoded.message { return msg }
        throw APIError.serverError(decoded.error ?? "Unknown error")
    }
}
