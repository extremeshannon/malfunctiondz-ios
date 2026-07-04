// HHIO Pack Records — reserve repacks and loft record stats (not exposed in MalfunctionDZ).
import Foundation
import SwiftUI
import MalfunctionDZCore

private func recordsExtractJsonPrefix(_ data: Data) -> Data {
    if let first = data.first, first == UInt8(ascii: "{") { return data }
    if let str = String(data: data, encoding: .utf8),
       let start = str.firstIndex(of: "{"),
       let extracted = str[start...].data(using: .utf8) {
        return extracted
    }
    return data
}

private func recordsApiErrorMessage(_ data: Data) -> String? {
    let slice = recordsExtractJsonPrefix(data)
    guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else { return nil }
    if let e = obj["error"] as? String, !e.isEmpty { return e }
    if let d = obj["detail"] as? String, !d.isEmpty { return d }
    return nil
}

struct LoftRecordStats: Codable {
    let reserveTotal: Int?
    let packJobTotal: Int?
    let inspectionTotal: Int?
    let reserveOverdue: Int?
    let reserveDueSoon: Int?

    enum CodingKeys: String, CodingKey {
        case reserveTotal = "reserve_total"
        case packJobTotal = "pack_job_total"
        case inspectionTotal = "inspection_total"
        case reserveOverdue = "reserve_overdue"
        case reserveDueSoon = "reserve_due_soon"
    }
}

struct LoftRecordRow: Codable, Identifiable {
    let id: Int
    let rigId: Int?
    let packDate: String
    let dueDate: String?
    let recordType: String
    let byName: String?
    let packJobCount: Int?
    let servicePerformed: String?
    let notes: String?
    let rigLabel: String?
    let ownerName: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case rigId = "rig_id"
        case packDate = "pack_date"
        case dueDate = "due_date"
        case recordType = "record_type"
        case byName = "by_name"
        case packJobCount = "pack_job_count"
        case servicePerformed = "service_performed"
        case rigLabel = "rig_label"
        case ownerName = "owner_name"
    }

    var typeLabel: String {
        switch recordType {
        case "reserve": return "Reserve"
        case "inspection": return "Inspection"
        default: return "Pack job"
        }
    }
}

struct LoftRigPickerRow: Codable, Identifiable {
    let id: Int
    let rigLabel: String?
    let isDzRig: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case rigLabel = "rig_label"
        case isDzRig = "is_dz_rig"
    }

    var label: String { rigLabel ?? "Rig #\(id)" }
}

struct LoftRecordsListResponse: Codable {
    let ok: Bool
    let records: [LoftRecordRow]?
    let stats: LoftRecordStats?
    let canEditRecords: Bool?
    let reserveServiceOptions: [String]?
    let reserveRepackDays: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, records, stats, error
        case canEditRecords = "can_edit_records"
        case reserveServiceOptions = "reserve_service_options"
        case reserveRepackDays = "reserve_repack_days"
    }
}

struct LoftRigsPickerResponse: Codable {
    let ok: Bool
    let rigs: [LoftRigPickerRow]?
    let riggers: [String]?
}

@MainActor
final class LoftRecordsViewModel: ObservableObject {
    @Published var records: [LoftRecordRow] = []
    @Published var stats: LoftRecordStats?
    @Published var canEdit = false
    @Published var reserveServiceOptions: [String] = ["I&R", "A&P"]
    @Published var reserveRepackDays = 180
    @Published var rigs: [LoftRigPickerRow] = []
    @Published var riggers: [String] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    private static let listPaths = [
        "/api/hhio/records.php",
        "/api/hhio/records",
        "/api/loft/records.php",
        "/api/loft/records",
    ]

    private static let rigsPaths = [
        "/api/hhio/rigs.php",
        "/api/hhio/rigs",
        "/api/loft/rigs.php",
        "/api/loft/rigs",
    ]

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken() else { return }

        var lastMessage = "Pack Records API not found on server"
        for path in Self.listPaths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 401 {
                    AuthManager.shared.logout()
                    error = "Session expired"
                    return
                }
                if http.statusCode == 404 {
                    lastMessage = recordsApiErrorMessage(slice) ?? "Pack Records API not deployed (404)"
                    continue
                }
                let resp = try JSONDecoder().decode(LoftRecordsListResponse.self, from: slice)
                if resp.ok {
                    records = resp.records ?? []
                    stats = resp.stats
                    canEdit = resp.canEditRecords ?? false
                    if let opts = resp.reserveServiceOptions, !opts.isEmpty {
                        reserveServiceOptions = opts
                    }
                    if let days = resp.reserveRepackDays { reserveRepackDays = days }
                    error = nil
                    return
                }
                lastMessage = resp.error ?? "Failed to load records"
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        error = lastMessage
    }

    func loadRigsForPicker() async {
        guard let token = KeychainHelper.readToken() else { return }
        for path in Self.rigsPaths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                let resp = try JSONDecoder().decode(LoftRigsPickerResponse.self, from: slice)
                if resp.ok {
                    rigs = resp.rigs ?? []
                    riggers = resp.riggers ?? []
                    return
                }
            } catch {
                continue
            }
        }
    }

    func addReserveRepack(
        rigId: Int,
        packDate: Date,
        servicePerformed: String,
        byName: String,
        ownerName: String,
        ownerPhone: String
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken() else { return false }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let body: [String: Any] = [
            "record_type": "reserve",
            "rig_id": rigId,
            "pack_date": df.string(from: packDate),
            "service_performed": servicePerformed,
            "by_name": byName,
            "owner_name": ownerName,
            "owner_phone": ownerPhone,
        ]
        let bodyData = try? JSONSerialization.data(withJSONObject: body)

        for path in Self.listPaths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = bodyData
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 401 {
                    AuthManager.shared.logout()
                    error = "Session expired"
                    return false
                }
                if http.statusCode == 404 { continue }
                let resp = try JSONDecoder().decode(LoftRecordsListResponse.self, from: slice)
                if resp.ok {
                    records = resp.records ?? records
                    stats = resp.stats ?? stats
                    return true
                }
                error = resp.error ?? "Failed to add reserve repack"
                return false
            } catch {
                continue
            }
        }
        error = "Pack Records API not found on server"
        return false
    }
}
