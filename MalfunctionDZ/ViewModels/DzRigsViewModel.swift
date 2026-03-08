// File: ASC/ViewModels/DzRigsViewModel.swift
// DZ Rigs — DZ-owned rigs for packers + 25+ jump users. Packers can mark as packed.
import Foundation
import SwiftUI

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

    enum CodingKeys: String, CodingKey {
        case ok, summary, rigs
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

    enum CodingKeys: String, CodingKey {
        case ok, rig, records
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
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/loft/dz_rigs.php") else {
            error = "Not configured"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var responseData = Data()
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            responseData = data
            if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? String {
                    error = err
                } else {
                    error = "Access denied"
                }
                return
            }
            guard !data.isEmpty else {
                error = "Server returned empty response."
                return
            }
            var jsonData = data
            if let first = data.first, first != UInt8(ascii: "{") {
                if let str = String(data: data, encoding: .utf8),
                   let start = str.firstIndex(of: "{"),
                   let extracted = str[start...].data(using: .utf8) {
                    jsonData = extracted
                } else {
                    if let str = String(data: data, encoding: .utf8), str.contains("<html") || str.contains("<!DOCTYPE") {
                        error = "API returned HTML (wrong URL?). Check kServerURL."
                    } else {
                        error = "Server returned invalid response. Check API URL and server logs."
                    }
                    return
                }
            }
            let resp = try JSONDecoder().decode(DzRigsResponse.self, from: jsonData)
            if resp.ok {
                rigs = resp.rigs ?? []
                summary = resp.summary
                canMarkPacked = resp.canMarkPacked ?? false
                canEditRecords = resp.canEditRecords ?? false
                canInspect = resp.canInspect ?? false
            } else {
                error = "Failed to load DZ rigs"
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
            self.error = error.localizedDescription
        }
    }

    func markPacked(rigId: Int, packDate: String? = nil, packJobCount: Int = 1, notes: String? = nil) async {
        markingRigId = rigId
        defer { markingRigId = nil }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/loft/dz_rigs.php") else { return }
        var body: [String: Any] = ["rig_id": rigId, "action": "pack"]
        if let d = packDate, !d.isEmpty { body["pack_date"] = d }
        body["pack_job_count"] = max(1, min(25, packJobCount))
        if let n = notes, !n.trimmingCharacters(in: .whitespaces).isEmpty { body["notes"] = n }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
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
        guard let token = KeychainHelper.readToken(),
              var components = URLComponents(string: "\(kServerURL)/api/loft/dz_rigs.php") else {
            error = "Not configured"
            return
        }
        components.queryItems = [URLQueryItem(name: "rig_id", value: "\(rigId)")]
        guard let url = components.url else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? String { error = err }
                else { error = "Access denied" }
                return
            }
            let resp = try JSONDecoder().decode(DzRigDetailResponse.self, from: data)
            if resp.ok {
                detailRig = resp.rig
                detailRecords = resp.records ?? []
                detailCanMarkPacked = resp.canMarkPacked ?? false
                detailCanEditRecords = resp.canEditRecords ?? false
                detailCanInspect = resp.canInspect ?? false
            } else {
                error = "Failed to load rig detail"
            }
        } catch let dec as DecodingError {
            self.error = decodeErrorMessage(dec)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func inspect(rigId: Int) async {
        markingRigId = rigId
        defer { markingRigId = nil }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/loft/dz_rigs.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["rig_id": rigId, "action": "inspect"])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["ok"] as? Bool) == true {
                await loadDetail(rigId: rigId)
                await load()
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let err = json["error"] as? String {
                error = err
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearDetail() {
        detailRig = nil
        detailRecords = []
    }
}
