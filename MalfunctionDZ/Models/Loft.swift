// File: ASC/Models/Loft.swift
import Foundation
import SwiftUI

struct LoftRig: Codable, Identifiable, Hashable {
    static func == (lhs: LoftRig, rhs: LoftRig) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: Int
    let label: String
    let manufacturer: String?
    let model: String?
    let isDzRig: Bool
    let harness: RigComponent
    let reserve: ReserveComponent
    let aad: RigComponent
    let lastPack: String?
    let dueDate: String?
    let daysLeft: Int?
    let status: String
    let packedBy: String?
    let packerCert: String?
    let notes: String?
    let packJobsSinceInspection: Int?
    let outOfService: Bool?
    let lastInspectionAt: String?
    let imageContainer: String?
    let imageReserve: String?
    let imageMain: String?

    enum CodingKeys: String, CodingKey {
        case id, label, manufacturer, model, harness, reserve, aad, notes, status
        case isDzRig   = "is_dz_rig"
        case lastPack  = "last_pack"
        case dueDate   = "due_date"
        case daysLeft  = "days_left"
        case packedBy  = "packed_by"
        case packerCert = "packer_cert"
        case packJobsSinceInspection = "pack_jobs_since_inspection"
        case outOfService = "out_of_service"
        case lastInspectionAt = "last_inspection_at"
        case imageContainer = "image_container"
        case imageReserve = "image_reserve"
        case imageMain = "image_main"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .id)).flatMap { Int($0) } ?? 0
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        manufacturer = try? c.decodeIfPresent(String.self, forKey: .manufacturer)
        model = try? c.decodeIfPresent(String.self, forKey: .model)
        if let b = try? c.decode(Bool.self, forKey: .isDzRig) { isDzRig = b }
        else if let i = try? c.decode(Int.self, forKey: .isDzRig) { isDzRig = i != 0 }
        else { isDzRig = true }
        harness = (try? c.decode(RigComponent.self, forKey: .harness)) ?? RigComponent(mfr: nil, model: nil, sn: nil)
        reserve = (try? c.decode(ReserveComponent.self, forKey: .reserve)) ?? ReserveComponent(mfr: nil, model: nil, sn: nil, dom: nil)
        aad = (try? c.decode(RigComponent.self, forKey: .aad)) ?? RigComponent(mfr: nil, model: nil, sn: nil)
        lastPack = try? c.decodeIfPresent(String.self, forKey: .lastPack)
        dueDate = try? c.decodeIfPresent(String.self, forKey: .dueDate)
        if let i = try? c.decode(Int.self, forKey: .daysLeft) { daysLeft = i }
        else if let s = try? c.decode(String.self, forKey: .daysLeft) { daysLeft = Int(s) }
        else { daysLeft = nil }
        status = (try? c.decode(String.self, forKey: .status)) ?? "unknown"
        packedBy = try? c.decodeIfPresent(String.self, forKey: .packedBy)
        packerCert = try? c.decodeIfPresent(String.self, forKey: .packerCert)
        notes = try? c.decodeIfPresent(String.self, forKey: .notes)
        packJobsSinceInspection = try? c.decodeIfPresent(Int.self, forKey: .packJobsSinceInspection)
        outOfService = try? c.decodeIfPresent(Bool.self, forKey: .outOfService)
        lastInspectionAt = try? c.decodeIfPresent(String.self, forKey: .lastInspectionAt)
        imageContainer = try? c.decodeIfPresent(String.self, forKey: .imageContainer)
        imageReserve = try? c.decodeIfPresent(String.self, forKey: .imageReserve)
        imageMain = try? c.decodeIfPresent(String.self, forKey: .imageMain)
    }

    var statusColor: Color {
        switch status {
        case "overdue":  return .mdzDanger
        case "due_soon": return .mdzAmber
        case "current":  return .mdzGreen
        default:         return .mdzMuted
        }
    }

    var statusLabel: String {
        switch status {
        case "overdue":  return "OVERDUE"
        case "due_soon": return "DUE SOON"
        case "current":  return "CURRENT"
        default:         return "UNKNOWN"
        }
    }

    var daysLeftText: String {
        guard let d = daysLeft else { return "—" }
        if d < 0 { return "\(abs(d))d overdue" }
        if d == 0 { return "Due today" }
        return "\(d)d left"
    }

    /// Reserve past due — rig cannot be used for 25 Jump Check.
    var isExpired: Bool { status == "overdue" || (daysLeft ?? 0) < 0 }

    /// In date (current or due_soon) — eligible for pack jobs. Overdue and unknown (no pack data) are not.
    var isEligibleFor25JumpCheck: Bool { status == "current" || status == "due_soon" }

    func imageURL(path: String?, base: String = kServerURL) -> URL? {
        guard let p = path, !p.isEmpty else { return nil }
        let b = base.hasSuffix("/") ? String(base.dropLast()) : base
        let clean = p.hasPrefix("/") ? p : "/" + p
        return URL(string: b + clean)
    }
}

struct RigComponent: Codable {
    let mfr: String?
    let model: String?
    let sn: String?
}

struct ReserveComponent: Codable {
    let mfr: String?
    let model: String?
    let sn: String?
    let dom: String?
}

struct LoftSummary: Codable {
    let total: Int
    let overdue: Int
    let dueSoon: Int
    let current: Int

    enum CodingKeys: String, CodingKey {
        case total, overdue, current
        case dueSoon = "due_soon"
    }
}

struct LoftListResponse: Codable {
    let ok: Bool
    let summary: LoftSummary?
    let rigs: [LoftRig]?
}
