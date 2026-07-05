// HHIO — loft customers (users with loft role).
import Foundation
import SwiftUI
import MalfunctionDZCore

private func customersExtractJson(_ data: Data) -> Data {
    if let first = data.first, first == UInt8(ascii: "{") { return data }
    if let str = String(data: data, encoding: .utf8),
       let start = str.firstIndex(of: "{"),
       let extracted = str[start...].data(using: .utf8) {
        return extracted
    }
    return data
}

private func customersApiError(_ data: Data) -> String? {
    let slice = customersExtractJson(data)
    guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else { return nil }
    if let e = obj["error"] as? String, !e.isEmpty { return e }
    if let detail = obj["detail"] as? String, !detail.isEmpty { return detail }
    return nil
}

private func customersParseInt(_ value: Any?) -> Int? {
    if let i = value as? Int { return i }
    if let n = value as? NSNumber { return n.intValue }
    if let s = value as? String, let i = Int(s) { return i }
    if let d = value as? Double { return Int(d) }
    return nil
}

struct LoftCustomer: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let displayName: String
    let email: String?
    let phone: String?
    let firstName: String?
    let lastName: String?
    let isActive: Bool?
    let rigCount: Int?
    let createdAt: String?
    let lastLoginAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email, phone
        case displayName = "display_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case isActive = "is_active"
        case rigCount = "rig_count"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
    }
}

struct LoftCustomerRig: Codable, Identifiable, Hashable {
    let id: Int
    let rigLabel: String?
    let manufacturer: String?
    let model: String?
    let serialNumber: String?
    let notes: String?
    let isActive: Bool?
    let customerName: String?
    let canopyMain: String?
    let canopyReserve: String?
    let aad: String?
    let gearType: String?
    let isTandem: Bool?

    enum CodingKeys: String, CodingKey {
        case id, manufacturer, model, notes
        case rigLabel = "rig_label"
        case serialNumber = "serial_number"
        case isActive = "is_active"
        case customerName = "customer_name"
        case canopyMain = "canopy_main"
        case canopyReserve = "canopy_reserve"
        case aad
        case gearType = "gear_type"
        case isTandem = "is_tandem"
    }

    var label: String { rigLabel ?? "Rig #\(id)" }

    var gearTypeLabel: String {
        switch (gearType ?? "").lowercased() {
        case "tandem": return "Tandem"
        case "student": return "Sport / Student"
        case "pilot_rig": return "Pilot rig"
        case "rental": return "Rental"
        default: return "Not set"
        }
    }
}

struct LoftCustomerRigDetailResponse: Codable {
    let ok: Bool
    let rig: LoftCustomerRig?
    let records: [LoftRecordRow]?
    let canEdit: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, rig, records, error
        case canEdit = "can_edit"
    }
}

struct LoftCustomersListResponse: Codable {
    let ok: Bool
    let customers: [LoftCustomer]?
    let total: Int?
    let canEdit: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, customers, total, error
        case canEdit = "can_edit"
    }
}

struct LoftCustomerDetailResponse: Codable {
    let ok: Bool
    let customer: LoftCustomer?
    let rigs: [LoftCustomerRig]?
    let records: [LoftRecordRow]?
    let invoices: [LoftInvoice]?
    let canEdit: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, customer, rigs, records, invoices, error
        case canEdit = "can_edit"
    }
}

@MainActor
final class LoftCustomersViewModel: ObservableObject {
    @Published var customers: [LoftCustomer] = []
    @Published var total = 0
    @Published var canEdit = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""

    @Published var detailCustomer: LoftCustomer?
    @Published var detailRigs: [LoftCustomerRig] = []
    @Published var detailRecords: [LoftRecordRow] = []
    @Published var detailInvoices: [LoftInvoice] = []
    @Published var detailLoading = false
    @Published var lastMessage: String?

    @Published var rigDetail: LoftCustomerRig?
    @Published var rigRecords: [LoftRecordRow] = []
    @Published var rigDetailLoading = false

    private static let listPaths = [
        "/api/hhio/customers.php",
        "/api/hhio/customers",
    ]

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken() else { return }

        var q = ""
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            q = "?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }

        var lastMsg = "Failed to load customers"
        for base in Self.listPaths {
            guard let url = URL(string: "\(kServerURL)\(base)\(q)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 401 {
                    AuthManager.shared.logout()
                    error = "Session expired"
                    return
                }
                if http.statusCode == 404 { continue }
                let resp = try JSONDecoder().decode(LoftCustomersListResponse.self, from: slice)
                if resp.ok {
                    customers = resp.customers ?? []
                    total = resp.total ?? customers.count
                    canEdit = resp.canEdit ?? false
                    error = nil
                    return
                }
                lastMsg = resp.error ?? customersApiError(slice) ?? lastMsg
            } catch {
                lastMsg = error.localizedDescription
            }
        }
        error = lastMsg
    }

    func loadDetail(customerId: Int) async {
        detailLoading = true
        defer { detailLoading = false }
        guard let token = KeychainHelper.readToken() else { return }

        let paths = [
            "/api/hhio/customers/\(customerId).php",
            "/api/hhio/customers/\(customerId)",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let resp = try JSONDecoder().decode(LoftCustomerDetailResponse.self, from: slice)
                if resp.ok {
                    detailCustomer = resp.customer
                    detailRigs = resp.rigs ?? []
                    detailRecords = resp.records ?? []
                    detailInvoices = resp.invoices ?? []
                    canEdit = resp.canEdit ?? canEdit
                    return
                }
                lastMessage = resp.error
            } catch {
                lastMessage = error.localizedDescription
            }
        }
    }

    func addCustomer(
        username: String,
        password: String,
        firstName: String,
        lastName: String,
        email: String,
        phone: String
    ) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        let paths = ["/api/hhio/customers.php", "/api/hhio/customers"]
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "phone": phone,
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return false }

        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = json
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 200 || http.statusCode == 201 {
                    if let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                       obj["ok"] as? Bool == true {
                        await load()
                        return true
                    }
                }
                lastMessage = customersApiError(slice) ?? "Failed to add customer"
            } catch {
                lastMessage = error.localizedDescription
            }
        }
        return false
    }

    func addRig(customerId: Int, rigLabel: String, manufacturer: String, model: String) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        let paths = [
            "/api/hhio/customers/\(customerId)/rigs.php",
            "/api/hhio/customers/\(customerId)/rigs",
        ]
        let body: [String: Any] = [
            "rig_label": rigLabel,
            "manufacturer": manufacturer,
            "model": model,
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return false }

        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = json
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 200 {
                    let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any]
                    if obj?["ok"] as? Bool == true {
                        await loadDetail(customerId: customerId)
                        await load()
                        return true
                    }
                }
                lastMessage = customersApiError(slice) ?? "Failed to add rig"
            } catch {
                lastMessage = error.localizedDescription
            }
        }
        return false
    }

    func loadRigDetail(customerId: Int, rigId: Int) async {
        rigDetailLoading = true
        defer { rigDetailLoading = false }
        guard let token = KeychainHelper.readToken() else { return }
        let paths = [
            "/api/hhio/customers/\(customerId)/rigs/\(rigId).php",
            "/api/hhio/customers/\(customerId)/rigs/\(rigId)",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let resp = try JSONDecoder().decode(LoftCustomerRigDetailResponse.self, from: slice)
                if resp.ok {
                    rigDetail = resp.rig
                    rigRecords = resp.records ?? []
                    if let edit = resp.canEdit { canEdit = edit }
                    return
                }
                lastMessage = resp.error
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
    }

    func updateRig(
        customerId: Int,
        rigId: Int,
        rigLabel: String,
        manufacturer: String,
        model: String,
        serialNumber: String,
        notes: String,
        isActive: Bool,
        canopyMain: String = "",
        canopyReserve: String = "",
        aad: String = "",
        gearType: String = "",
        isTandem: Bool = false
    ) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        var body: [String: Any] = [
            "rig_label": rigLabel,
            "manufacturer": manufacturer,
            "model": model,
            "serial_number": serialNumber,
            "notes": notes,
            "is_active": isActive,
            "canopy_main": canopyMain,
            "canopy_reserve": canopyReserve,
            "aad": aad,
            "is_tandem": isTandem,
        ]
        if !gearType.isEmpty { body["gear_type"] = gearType }
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return false }
        let paths = [
            "/api/hhio/customers/\(customerId)/rigs/\(rigId).php",
            "/api/hhio/customers/\(customerId)/rigs/\(rigId)",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = json
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                if let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   obj["ok"] as? Bool == true {
                    await loadRigDetail(customerId: customerId, rigId: rigId)
                    await loadDetail(customerId: customerId)
                    return true
                }
                lastMessage = customersApiError(slice) ?? "Failed to update rig"
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    func createCustomerInvoice(
        customerId: Int,
        lines: [[String: Any]]
    ) async -> Int? {
        guard let token = KeychainHelper.readToken() else { return nil }
        let body: [String: Any] = ["lines": lines]
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        let paths = [
            "/api/hhio/customers/\(customerId)/invoices.php",
            "/api/hhio/customers/\(customerId)/invoices",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = json
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 404 { continue }
                guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else {
                    lastMessage = "Failed to create invoice"
                    return nil
                }
                if obj["ok"] as? Bool == true {
                    let invoiceId = customersParseInt(obj["invoice_id"])
                        ?? customersParseInt((obj["invoice"] as? [String: Any])?["id"])
                    if let invoiceId {
                        await loadDetail(customerId: customerId)
                        return invoiceId
                    }
                    lastMessage = "Invoice created but id missing"
                    return nil
                }
                lastMessage = customersApiError(slice) ?? "Failed to create invoice (HTTP \(http.statusCode))"
                return nil
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return nil
    }

    func addInvoiceLines(invoiceId: Int, customerId: Int, lines: [[String: Any]]) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        let body: [String: Any] = ["lines": lines]
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return false }
        let paths = [
            "/api/hhio/invoices/\(invoiceId)/lines.php",
            "/api/hhio/invoices/\(invoiceId)/lines",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = json
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 404 { continue }
                guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else {
                    lastMessage = "Failed to add line"
                    return false
                }
                if obj["ok"] as? Bool == true {
                    await loadDetail(customerId: customerId)
                    return true
                }
                lastMessage = customersApiError(slice) ?? "Failed to add line (HTTP \(http.statusCode))"
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    func loadInvoiceDetail(invoiceId: Int) async -> LoftInvoiceDetailResponse? {
        guard let token = KeychainHelper.readToken() else { return nil }
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
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let resp = try JSONDecoder().decode(LoftInvoiceDetailResponse.self, from: slice)
                if resp.ok { return resp }
                lastMessage = resp.error
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return nil
    }

    func sendInvoice(customerId: Int, invoiceId: Int) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        let paths = [
            "/api/hhio/invoices/\(invoiceId)/send.php",
            "/api/hhio/invoices/\(invoiceId)/send",
        ]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                if let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   obj["ok"] as? Bool == true {
                    await loadDetail(customerId: customerId)
                    return true
                }
                lastMessage = customersApiError(slice) ?? "Failed to send invoice"
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    func markInvoicePaid(customerId: Int, invoiceId: Int) async -> Bool {
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
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                if let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   obj["ok"] as? Bool == true {
                    await loadDetail(customerId: customerId)
                    return true
                }
                lastMessage = customersApiError(slice) ?? "Failed to mark paid"
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    func sendInvoiceReminder(customerId: Int, invoiceId: Int) async -> Bool {
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
                let slice = customersExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                if let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                   obj["ok"] as? Bool == true {
                    await loadDetail(customerId: customerId)
                    return true
                }
                lastMessage = customersApiError(slice) ?? "Failed to send reminder"
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }
}
