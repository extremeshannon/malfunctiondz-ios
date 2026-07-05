// HHIO loft settings — shared with web /config/loft.
import Foundation
import SwiftUI
import MalfunctionDZCore

struct HHIOPackJobPrices: Codable, Equatable {
    let tandemCents: Int
    let studentCents: Int
    let pilotRigCents: Int

    enum CodingKeys: String, CodingKey {
        case tandemCents = "tandem_cents"
        case studentCents = "student_cents"
        case pilotRigCents = "pilot_rig_cents"
    }

    static let defaults = HHIOPackJobPrices(tandemCents: 12500, studentCents: 10000, pilotRigCents: 10000)

    func priceText(gearType: String?, isTandem: Bool) -> String? {
        let gt = (gearType ?? "").lowercased()
        let cents: Int
        if isTandem || gt == "tandem" {
            cents = tandemCents
        } else if gt == "student" || gt == "rental" {
            cents = studentCents
        } else if gt == "pilot_rig" {
            cents = pilotRigCents
        } else {
            return nil
        }
        guard cents > 0 else { return nil }
        return String(format: "%.2f", Double(cents) / 100.0)
    }
}

@MainActor
final class HHIOSettingsStore: ObservableObject {
    @Published var loftName = "HHIO Loft"
    @Published var invoiceFrom = ""
    @Published var prices = HHIOPackJobPrices.defaults
    @Published var canEdit = false
    @Published var loading = false
    @Published var saving = false
    @Published var lastMessage: String?

    func load() async {
        guard let token = KeychainHelper.readToken() else { return }
        loading = true
        defer { loading = false }
        let paths = ["/api/hhio/settings.php", "/api/hhio/settings"]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = hhioSettingsExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { continue }
                guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any],
                      obj["ok"] as? Bool == true else { continue }
                loftName = (obj["loft_name"] as? String) ?? loftName
                invoiceFrom = (obj["invoice_from"] as? String) ?? ""
                canEdit = obj["can_edit"] as? Bool ?? false
                if let raw = obj["pack_job_prices"] as? [String: Any] {
                    prices = HHIOPackJobPrices(
                        tandemCents: raw["tandem_cents"] as? Int ?? HHIOPackJobPrices.defaults.tandemCents,
                        studentCents: raw["student_cents"] as? Int ?? HHIOPackJobPrices.defaults.studentCents,
                        pilotRigCents: raw["pilot_rig_cents"] as? Int ?? HHIOPackJobPrices.defaults.pilotRigCents
                    )
                }
                return
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
    }

    func save(loftName: String, invoiceFrom: String, tandemText: String, studentText: String, pilotRigText: String) async -> Bool {
        guard let token = KeychainHelper.readToken() else { return false }
        saving = true
        defer { saving = false }

        let body: [String: Any] = [
            "loft_name": loftName.trimmingCharacters(in: .whitespaces),
            "invoice_from": invoiceFrom.trimmingCharacters(in: .whitespaces),
            "pack_job_prices": [
                "tandem_cents": parseCents(tandemText),
                "student_cents": parseCents(studentText),
                "pilot_rig_cents": parseCents(pilotRigText),
            ],
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return false }

        let paths = ["/api/hhio/settings.php", "/api/hhio/settings"]
        for path in paths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = json
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let slice = hhioSettingsExtractJson(data)
                guard let http = response as? HTTPURLResponse, http.statusCode != 404 else { continue }
                guard let obj = try? JSONSerialization.jsonObject(with: slice) as? [String: Any] else {
                    lastMessage = "Failed to save settings"
                    return false
                }
                if obj["ok"] as? Bool == true {
                    await load()
                    lastMessage = "Settings saved"
                    return true
                }
                lastMessage = (obj["error"] as? String) ?? "Failed to save settings"
                return false
            } catch let err {
                lastMessage = err.localizedDescription
            }
        }
        return false
    }

    private func parseCents(_ text: String) -> Int {
        let cleaned = text.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard let val = Double(cleaned) else { return 0 }
        return Int((val * 100).rounded())
    }
}

private func hhioSettingsExtractJson(_ data: Data) -> Data {
    if let first = data.first, first == UInt8(ascii: "{") { return data }
    if let str = String(data: data, encoding: .utf8),
       let start = str.firstIndex(of: "{"),
       let extracted = str[start...].data(using: .utf8) {
        return extracted
    }
    return data
}

enum LoftGearType {
    static let choices: [(id: String, label: String)] = [
        ("student", "Sport / Student"),
        ("tandem", "Tandem"),
        ("pilot_rig", "Pilot rig"),
        ("rental", "Rental"),
    ]

    static func resolved(gearType: String?, isTandem: Bool, rigLabel: String?) -> String? {
        let gt = (gearType ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if !gt.isEmpty { return gt }
        if isTandem { return "tandem" }
        let lbl = (rigLabel ?? "").lowercased()
        if lbl.contains("tandem") { return "tandem" }
        if lbl.contains("pilot") || lbl.contains("butler") || lbl.contains("national") { return "pilot_rig" }
        if lbl.contains("student") || lbl.contains("sport") { return "student" }
        if lbl.contains("rental") { return "rental" }
        return nil
    }
}
