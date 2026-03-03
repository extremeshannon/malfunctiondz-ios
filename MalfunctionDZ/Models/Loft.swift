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

    enum CodingKeys: String, CodingKey {
        case id, label, manufacturer, model, harness, reserve, aad, notes, status
        case isDzRig   = "is_dz_rig"
        case lastPack  = "last_pack"
        case dueDate   = "due_date"
        case daysLeft  = "days_left"
        case packedBy  = "packed_by"
        case packerCert = "packer_cert"
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
