// File: ASC/ViewModels/DzRigsViewModel.swift
// DZ Rigs — DZ-owned rigs for packers + 25+ jump users. Packers can mark as packed.
import Foundation
import SwiftUI
import MalfunctionDZCore

/// Leading PHP notices/HTML — slice from first `{` so JSONDecoder can run.
private func dzRigsExtractJsonPrefix(_ data: Data) -> Data {
    if let first = data.first, first == UInt8(ascii: "{") { return data }
    if let str = String(data: data, encoding: .utf8),
       let start = str.firstIndex(of: "{"),
       let extracted = str[start...].data(using: .utf8) {
        return extracted
    }
    return data
}

/// FastAPI: `error`, `detail` (string), or `detail` (validation array with `msg`).
private func apiJSONErrorMessage(_ slice: Data) -> String? {
    guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else { return nil }
    if let e = obj["error"] as? String, !e.isEmpty { return e }
    if let d = obj["detail"] as? String, !d.isEmpty { return d }
    if let arr = obj["detail"] as? [[String: Any]] {
        let parts = arr.compactMap { $0["msg"] as? String }.filter { !$0.isEmpty }
        if let first = parts.first { return first }
    }
    return nil
}

/// Servers often return `"Not Found"` / `"error":"Not Found"`; never show that raw in alerts.
private func humanizeDzRigsApiMessage(_ raw: String?) -> String {
    let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if t.caseInsensitiveCompare("not found") == .orderedSame {
        return "DZ rigs API not found. In Profile, set API Base URL to your MalfunctionDZ server (e.g. https://malfunctiondz.com). The backend must expose GET /api/loft/dz_rigs."
    }
    return t
}

private func dzRigsListURL(usePhpExtension: Bool) -> URL? {
    let leaf = usePhpExtension ? "dz_rigs.php" : "dz_rigs"
    var c = URLComponents(string: "\(kServerURL)/api/loft/\(leaf)")
    c?.queryItems = [URLQueryItem(name: "packable_only", value: "0")]
    return c?.url
}

private func dzRigsDetailURL(rigId: Int, usePhpExtension: Bool) -> URL? {
    let leaf = usePhpExtension ? "dz_rigs.php" : "dz_rigs"
    var c = URLComponents(string: "\(kServerURL)/api/loft/\(leaf)")
    c?.queryItems = [URLQueryItem(name: "rig_id", value: "\(rigId)")]
    return c?.url
}

private func dzRigsPostURL(usePhpExtension: Bool) -> URL? {
    let leaf = usePhpExtension ? "dz_rigs.php" : "dz_rigs"
    return URL(string: "\(kServerURL)/api/loft/\(leaf)")
}

private func decodeErrorMessage(_ e: DecodingError) -> String {
    switch e {
    case .typeMismatch(let type, let context):
        return "Data type mismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
    case .valueNotFound(let type, let context):
        return "Missing value for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
    case .keyNotFound(let key, let context):
        return "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
    case .dataCorrupted(let context):
        return "Invalid data: \(context.debugDescription)"
    @unknown default:
        return "The data couldn't be read because it isn't in the correct format."
    }
}

struct DzRigsResponse: Codable {
    let ok: Bool
    let summary: LoftSummary?
    let rigs: [LoftRig]?
    let canMarkPacked: Bool?
    let canEditRecords: Bool?
    let canInspect: Bool?
    /// Present when `ok` is false (API / PHP error message).
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, summary, rigs, error
        case canMarkPacked = "can_mark_packed"
        case canEditRecords = "can_edit_records"
        case canInspect = "can_inspect"
    }
}

struct DzRigDetailResponse: Codable {
    let ok: Bool
    let rig: LoftRig?
    let records: [PackRecord]?
    let canMarkPacked: Bool?
    let canEditRecords: Bool?
    let canInspect: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, rig, records, error
        case canMarkPacked = "can_mark_packed"
        case canEditRecords = "can_edit_records"
        case canInspect = "can_inspect"
    }
}

struct PackRecord: Codable, Identifiable {
    let id: Int
    let packDate: String
    let dueDate: String?
    let packJobCount: Int?
    let packedBy: String?
    let isLocked: Bool?
    let isExpired: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case packDate = "pack_date"
        case dueDate = "due_date"
        case packJobCount = "pack_job_count"
        case packedBy = "packed_by"
        case isLocked = "is_locked"
        case isExpired = "is_expired"
    }
}

@MainActor
class DzRigsViewModel: ObservableObject {
    @Published var rigs:          [LoftRig] = []
    @Published var summary:       LoftSummary?
    @Published var canMarkPacked  = false
    @Published var canEditRecords = false
    @Published var canInspect     = false
    @Published var isLoading      = false
    @Published var error:         String?
    @Published var markingRigId:  Int?

    var overdueRigs:  [LoftRig] { rigs.filter { $0.status == "overdue" } }
    var dueSoonRigs:  [LoftRig] { rigs.filter { $0.status == "due_soon" } }
    var currentRigs:  [LoftRig] { rigs.filter { $0.status == "current" } }
    var unknownRigs:  [LoftRig] { rigs.filter { $0.status == "unknown" } }
    /// At 25 pack jobs — locked until inspection (Pic 2: OUT OF SERVICE card)
    var outOfServiceRigs: [LoftRig] { rigs.filter { $0.outOfService == true } }
    /// 20–24 pack jobs, not yet locked (Pic 2: APPROACHING LIMIT card)
    var approachingLimitRigs: [LoftRig] {
        rigs.filter { rig in
            guard rig.outOfService != true else { return false }
            let n = rig.packJobsSinceInspection ?? 0
            return n >= 20 && n < 25
        }
    }
    /// Reserve due soon — 180-day repack within 30 days (Pic 2: REPACK DUE SOON)
    var repackDueSoonRigs: [LoftRig] { dueSoonRigs }
    /// In service, current, not approaching limit (Pic 2: ALL CLEAR)
    var allClearRigs: [LoftRig] {
        rigs.filter { rig in
            rig.status == "current" && rig.outOfService != true && ((rig.packJobsSinceInspection ?? 0) < 20)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken() else {
            error = "Not configured"
            return
        }
        // Try .php first (MAMP/legacy), then bare path (some FastAPI proxies only register /api/loft/dz_rigs).
        let listCandidates: [URL?] = [dzRigsListURL(usePhpExtension: true), dzRigsListURL(usePhpExtension: false)]
        let urls = listCandidates.compactMap { $0 }
        guard !urls.isEmpty else {
            error = "Not configured"
            return
        }
        var responseData = Data()
        do {
            attemptLoop: for (index, url) in urls.enumerated() {
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: req)
                responseData = data
                let http = response as? HTTPURLResponse
                if let code = http?.statusCode, code == 404, index + 1 < urls.count {
                    continue attemptLoop
                }
                if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? String {
                        error = humanizeDzRigsApiMessage(err)
                    } else {
                        error = "Access denied"
                    }
                    return
                }
                if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                    let slice = dzRigsExtractJsonPrefix(data)
                    // 404 first: bodies like `{"detail":"Not Found"}` or `{"ok":false,"error":"Not Found"}` must not hit DzRigsResponse-only branch.
                    if http.statusCode == 404 {
                        let parsedErr = (try? JSONDecoder().decode(DzRigsResponse.self, from: slice))?.error
                        let combined = apiJSONErrorMessage(slice) ?? parsedErr
                        error = humanizeDzRigsApiMessage(combined ?? "Not Found")
                        return
                    }
                    if let parsed = try? JSONDecoder().decode(DzRigsResponse.self, from: slice),
                       let msg = parsed.error, !msg.isEmpty {
                        error = humanizeDzRigsApiMessage(msg)
                        return
                    }
                    if let msg = apiJSONErrorMessage(slice) {
                        error = humanizeDzRigsApiMessage(msg)
                        return
                    }
                    error = "Server error (HTTP \(http.statusCode))"
                    return
                }
                guard !data.isEmpty else {
                    error = "Server returned empty response."
                    return
                }
                let jsonData = dzRigsExtractJsonPrefix(data)
                if jsonData.isEmpty || (jsonData.first != UInt8(ascii: "{")) {
                    if let str = String(data: data, encoding: .utf8), str.contains("<html") || str.contains("<!DOCTYPE") {
                        error = "API returned HTML (wrong URL?). Check kServerURL."
                    } else {
                        error = "Server returned invalid response. Check API URL and server logs."
                    }
                    return
                }
                let resp = try JSONDecoder().decode(DzRigsResponse.self, from: jsonData)
                if resp.ok {
                    rigs = resp.rigs ?? []
                    summary = resp.summary
                    canMarkPacked = resp.canMarkPacked ?? false
                    canEditRecords = resp.canEditRecords ?? false
                    canInspect = resp.canInspect ?? false
                } else {
                    if let e = resp.error, !e.isEmpty { error = humanizeDzRigsApiMessage(e) }
                    else { error = "Failed to load DZ rigs" }
                }
                return
            }
        } catch let dec as DecodingError {
            let msg = decodeErrorMessage(dec)
            if msg.contains("valid JSON") || msg.contains("correct format") {
                if let str = String(data: responseData, encoding: .utf8) {
                    if str.contains("<html") || str.contains("<!DOCTYPE") {
                        self.error = "API returned HTML — wrong URL or 404. Check kServerURL and server config."
                    } else if str.hasPrefix("<?")
                        || str.contains("Fatal error")
                        || str.contains("Parse error")
                        || str.contains("Unknown column") {
                        self.error = "PHP/DB error in response. Run migration 024 on server. Raw: \(String(str.prefix(120)))..."
                    } else {
                        let preview = String(str.prefix(150)).replacingOccurrences(of: "\n", with: " ")
                        self.error = "Invalid JSON from DZ rigs API. First 150 chars: \(preview)"
                    }
                } else {
                    self.error = "Invalid JSON (empty or non-UTF8). Size: \(responseData.count) bytes."
                }
            } else {
                self.error = msg
            }
        } catch {
            self.error = humanizeDzRigsApiMessage(error.localizedDescription)
        }
    }

    func markPacked(rigId: Int, packDate: String? = nil, packJobCount: Int = 1, notes: String? = nil) async {
        markingRigId = rigId
        defer { markingRigId = nil }
        guard let token = KeychainHelper.readToken() else { return }
        var body: [String: Any] = ["rig_id": rigId, "action": "pack"]
        if let d = packDate, !d.isEmpty { body["pack_date"] = d }
        body["pack_job_count"] = max(1, min(25, packJobCount))
        if let n = notes, !n.trimmingCharacters(in: .whitespaces).isEmpty { body["notes"] = n }
        let payload = try? JSONSerialization.data(withJSONObject: body)
        let postURLs = [dzRigsPostURL(usePhpExtension: true), dzRigsPostURL(usePhpExtension: false)].compactMap { $0 }
        guard !postURLs.isEmpty else { return }
        do {
            postLoop: for (index, url) in postURLs.enumerated() {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = payload
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 404, index + 1 < postURLs.count {
                    continue postLoop
                }
                let slice = dzRigsExtractJsonPrefix(data)
                if let json = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   (json["ok"] as? Bool) == true {
                    await load()
                } else if let json = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                          let err = json["error"] as? String {
                    error = humanizeDzRigsApiMessage(err)
                } else if let msg = apiJSONErrorMessage(slice) {
                    error = humanizeDzRigsApiMessage(msg)
                }
                return
            }
        } catch {
            self.error = humanizeDzRigsApiMessage(error.localizedDescription)
        }
    }

    // MARK: - Rig detail
    @Published var detailRig: LoftRig?
    @Published var detailRecords: [PackRecord] = []
    @Published var detailCanMarkPacked = false
    @Published var detailCanEditRecords = false
    @Published var detailCanInspect = false
    @Published var isLoadingDetail = false

    func loadDetail(rigId: Int) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        guard let token = KeychainHelper.readToken() else {
            error = "Not configured"
            return
        }
        let detailURLs = [
            dzRigsDetailURL(rigId: rigId, usePhpExtension: true),
            dzRigsDetailURL(rigId: rigId, usePhpExtension: false),
        ].compactMap { $0 }
        guard !detailURLs.isEmpty else { return }
        do {
            detailLoop: for (index, url) in detailURLs.enumerated() {
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 404, index + 1 < detailURLs.count {
                    continue detailLoop
                }
                if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? String { error = humanizeDzRigsApiMessage(err) }
                    else { error = "Access denied" }
                    return
                }
                let slice = dzRigsExtractJsonPrefix(data)
                let resp = try JSONDecoder().decode(DzRigDetailResponse.self, from: slice)
                if resp.ok {
                    detailRig = resp.rig
                    detailRecords = resp.records ?? []
                    detailCanMarkPacked = resp.canMarkPacked ?? false
                    detailCanEditRecords = resp.canEditRecords ?? false
                    detailCanInspect = resp.canInspect ?? false
                } else {
                    if let e = resp.error, !e.isEmpty { error = humanizeDzRigsApiMessage(e) }
                    else { error = "Failed to load rig detail" }
                }
                return
            }
        } catch let dec as DecodingError {
            self.error = decodeErrorMessage(dec)
        } catch {
            self.error = humanizeDzRigsApiMessage(error.localizedDescription)
        }
    }

    func inspect(rigId: Int) async {
        markingRigId = rigId
        defer { markingRigId = nil }
        guard let token = KeychainHelper.readToken() else { return }
        let body = try? JSONSerialization.data(withJSONObject: ["rig_id": rigId, "action": "inspect"])
        let postURLs = [dzRigsPostURL(usePhpExtension: true), dzRigsPostURL(usePhpExtension: false)].compactMap { $0 }
        guard !postURLs.isEmpty else { return }
        do {
            inspectLoop: for (index, url) in postURLs.enumerated() {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = body
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 404, index + 1 < postURLs.count {
                    continue inspectLoop
                }
                let slice = dzRigsExtractJsonPrefix(data)
                if let json = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   (json["ok"] as? Bool) == true {
                    await loadDetail(rigId: rigId)
                    await load()
                } else if let json = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                          let err = json["error"] as? String {
                    error = humanizeDzRigsApiMessage(err)
                } else if let msg = apiJSONErrorMessage(slice) {
                    error = humanizeDzRigsApiMessage(msg)
                }
                return
            }
        } catch {
            self.error = humanizeDzRigsApiMessage(error.localizedDescription)
        }
    }

    func clearDetail() {
        detailRig = nil
        detailRecords = []
    }
}
