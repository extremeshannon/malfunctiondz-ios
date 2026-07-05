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

struct LoftRecordRow: Codable, Identifiable, Hashable {
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
    let gearType: String?
    let isTandem: Bool?

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
        case gearType = "gear_type"
        case isTandem = "is_tandem"
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

struct LoftInvoice: Codable, Identifiable, Hashable {
    let id: Int
    let loftRecordId: Int?
    let customerId: Int?
    let invoiceNumber: String
    let description: String?
    let amountCents: Int
    let status: String
    let dueDate: String?
    let paidAt: String?
    let customerName: String?
    let customerEmail: String?
    let rigLabel: String?
    let recordType: String?
    let packDate: String?
    let reminderCount: Int?
    let sentAt: String?
    let lastReminderAt: String?
    let lineType: String?

    enum CodingKeys: String, CodingKey {
        case id, status, description
        case loftRecordId = "loft_record_id"
        case customerId = "customer_id"
        case invoiceNumber = "invoice_number"
        case amountCents = "amount_cents"
        case dueDate = "due_date"
        case paidAt = "paid_at"
        case customerName = "customer_name"
        case customerEmail = "customer_email"
        case rigLabel = "rig_label"
        case recordType = "record_type"
        case packDate = "pack_date"
        case reminderCount = "reminder_count"
        case sentAt = "sent_at"
        case lastReminderAt = "last_reminder_at"
        case lineType = "line_type"
    }

    var amountDisplay: String {
        String(format: "$%.2f", Double(amountCents) / 100.0)
    }

    var statusLabel: String {
        switch status {
        case "paid": return "Paid"
        case "void": return "Void"
        case "draft": return "Draft"
        default: return "Open"
        }
    }

    var lineTypeLabel: String {
        switch lineType {
        case "pack_job": return "Pack job"
        case "sale": return "Sale"
        default: return "Service"
        }
    }
}

struct LoftInvoiceEvent: Codable, Identifiable {
    let id: Int
    let eventType: String
    let detail: String?
    let createdAt: String
    let byName: String?

    enum CodingKeys: String, CodingKey {
        case id, detail
        case eventType = "event_type"
        case createdAt = "created_at"
        case byName = "by_name"
    }

    var eventLabel: String {
        switch eventType {
        case "created": return "Created"
        case "sent": return "Emailed"
        case "reminder": return "Reminder sent"
        case "paid": return "Marked paid"
        default: return eventType.capitalized
        }
    }
}

struct LoftRecordDetailResponse: Codable {
    let ok: Bool
    let record: LoftRecordRow?
    let invoices: [LoftInvoice]?
    let canEdit: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, record, invoices, error
        case canEdit = "can_edit"
    }
}

struct LoftInvoiceLine: Codable, Identifiable {
    let id: Int
    let lineType: String
    let description: String
    let amountCents: Int
    let loftRecordId: Int?
    let rigId: Int?
    let rigLabel: String?
    let recordType: String?
    let packDate: String?

    enum CodingKeys: String, CodingKey {
        case id, description
        case lineType = "line_type"
        case amountCents = "amount_cents"
        case loftRecordId = "loft_record_id"
        case rigId = "rig_id"
        case rigLabel = "rig_label"
        case recordType = "record_type"
        case packDate = "pack_date"
    }

    var amountDisplay: String {
        String(format: "$%.2f", Double(amountCents) / 100.0)
    }

    var lineTypeLabel: String {
        switch lineType {
        case "pack_job": return "Pack job"
        case "sale": return "Sale"
        default: return "Service"
        }
    }
}

struct LoftInvoiceDetailResponse: Codable {
    let ok: Bool
    let invoice: LoftInvoice?
    let lines: [LoftInvoiceLine]?
    let events: [LoftInvoiceEvent]?
    let canEdit: Bool?
    let error: String?
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
    @Published var lastMessage: String?

    @Published var detailRecord: LoftRecordRow?
    @Published var detailInvoices: [LoftInvoice] = []
    @Published var detailEvents: [LoftInvoiceEvent] = []
    @Published var detailLoading = false

    private static let listPaths = [
        "/api/hhio/records.php",
        "/api/hhio/records",
        "/api/loft/records.php",
        "/api/loft/records",
    ]

    private static let rigsPaths = [
        "/api/hhio/rigs.php",
        "/api/hhio/rigs",
        "/api/loft/records/rigs.php",
        "/api/loft/records/rigs",
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
        await addRecord(
            recordType: "reserve",
            rigId: rigId,
            packDate: packDate,
            servicePerformed: servicePerformed,
            byName: byName,
            ownerName: ownerName,
            ownerPhone: ownerPhone
        )
    }

    func addRecord(
        recordType: String,
        rigId: Int,
        packDate: Date,
        servicePerformed: String = "",
        byName: String = "",
        ownerName: String = "",
        ownerPhone: String = "",
        packJobCount: Int = 1,
        notes: String = "",
        createInvoice: Bool = false,
        amountCents: Int = 0,
        sendInvoiceEmail: Bool = false
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken() else { return false }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var body: [String: Any] = [
            "record_type": recordType,
            "rig_id": rigId,
            "pack_date": df.string(from: packDate),
            "by_name": byName,
            "owner_name": ownerName,
            "owner_phone": ownerPhone,
            "notes": notes,
        ]
        if recordType == "reserve" {
            body["service_performed"] = servicePerformed
        } else if recordType == "pack_job" {
            body["pack_job_count"] = packJobCount
        } else if recordType == "inspection" {
            body["service_performed"] = servicePerformed.isEmpty ? "PASS" : servicePerformed
        }
        if createInvoice, amountCents > 0 {
            body["create_invoice"] = true
            body["amount_cents"] = amountCents
            if sendInvoiceEmail { body["send_invoice_email"] = true }
        }
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return false }

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
                if let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   obj["ok"] as? Bool == true {
                    if let recs = try? JSONDecoder().decode(LoftRecordsListResponse.self, from: slice) {
                        records = recs.records ?? records
                        stats = recs.stats ?? stats
                    } else {
                        await load()
                    }
                    return true
                }
                error = recordsApiErrorMessage(slice) ?? "Failed to add record"
                return false
            } catch {
                continue
            }
        }
        error = "Pack Records API not found on server"
        return false
    }

    func loadRecordDetail(recordId: Int) async {
        detailLoading = true
        defer { detailLoading = false }
        guard let token = KeychainHelper.readToken() else { return }
        let paths = [
            "/api/hhio/records/\(recordId).php",
            "/api/hhio/records/\(recordId)",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let resp = try JSONDecoder().decode(LoftRecordDetailResponse.self, from: slice)
                if resp.ok {
                    detailRecord = resp.record
                    detailInvoices = resp.invoices ?? []
                    if let edit = resp.canEdit { canEdit = edit }
                    return
                }
                lastMessage = resp.error
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
    }

    func createInvoice(
        recordId: Int?,
        amountCents: Int,
        description: String = "",
        sendEmail: Bool = false
    ) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        var body: [String: Any] = ["amount_cents": amountCents]
        if let recordId { body["loft_record_id"] = recordId }
        if !description.isEmpty { body["description"] = description }
        if sendEmail { body["send_email"] = true }
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return false }

        let paths = ["/api/hhio/invoices.php", "/api/hhio/invoices"]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = json
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                if let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   obj["ok"] as? Bool == true {
                    if let rid = recordId { await loadRecordDetail(recordId: rid) }
                    await load()
                    return true
                }
                lastMessage = recordsApiErrorMessage(slice) ?? "Failed to create invoice"
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    func markInvoicePaid(invoiceId: Int, recordId: Int?) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        let paths = [
            "/api/hhio/invoices/\(invoiceId)/mark-paid.php",
            "/api/hhio/invoices/\(invoiceId)/mark-paid",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = "{}".data(using: .utf8)
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                let resp = try JSONDecoder().decode(LoftInvoiceDetailResponse.self, from: slice)
                if resp.ok {
                    if let rid = recordId { await loadRecordDetail(recordId: rid) }
                    await load()
                    return true
                }
                lastMessage = resp.error ?? recordsApiErrorMessage(slice)
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    func sendInvoiceReminder(invoiceId: Int, recordId: Int?) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        let paths = [
            "/api/hhio/invoices/\(invoiceId)/send-reminder.php",
            "/api/hhio/invoices/\(invoiceId)/send-reminder",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                let resp = try JSONDecoder().decode(LoftInvoiceDetailResponse.self, from: slice)
                if resp.ok {
                    detailEvents = resp.events ?? []
                    if let rid = recordId { await loadRecordDetail(recordId: rid) }
                    return true
                }
                lastMessage = resp.error ?? recordsApiErrorMessage(slice)
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    func loadInvoiceHistory(invoiceId: Int) async {
        guard let token = KeychainHelper.readToken() else { return }
        let paths = [
            "/api/hhio/invoices/\(invoiceId).php",
            "/api/hhio/invoices/\(invoiceId)",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = recordsExtractJsonPrefix(data)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let resp = try JSONDecoder().decode(LoftInvoiceDetailResponse.self, from: slice)
                if resp.ok {
                    detailEvents = resp.events ?? []
                    return
                }
            } catch {
                continue
            }
        }
    }
}
