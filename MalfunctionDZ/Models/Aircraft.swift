// File: ASC/Models/Aircraft.swift
import Foundation
import SwiftUI

// Compatible with FastAPI /api/aircraft/list (id, tail_number, make, model, year, status, ...)
// and legacy PHP (adds open_squawks, due_soon, overdue, next_100hr_due, annual_due, last_oil_change).
struct Aircraft: Codable, Identifiable, Hashable {
    static func == (lhs: Aircraft, rhs: Aircraft) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: Int
    let tailNumber: String
    let model: String
    let status: String
    let openSquawks: Int
    let dueSoon: Int
    let overdue: Int
    let next100hrDue: String?
    let annualDue: String?
    let lastOilChange: String?

    enum CodingKeys: String, CodingKey {
        case id, model, status, make, year
        case tailNumber    = "tail_number"
        case openSquawks   = "open_squawks"
        case dueSoon       = "due_soon"
        case overdue
        case next100hrDue  = "next_100hr_due"
        case annualDue     = "annual_due"
        case lastOilChange = "last_oil_change"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        tailNumber = (try? c.decode(String.self, forKey: .tailNumber)) ?? ""
        let make = try? c.decode(String.self, forKey: .make)
        let modelVal = try? c.decode(String.self, forKey: .model)
        let combined = [make, modelVal].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        model = combined.isEmpty ? "Aircraft" : combined
        status = (try? c.decode(String.self, forKey: .status)) ?? "active"
        openSquawks = (try? c.decode(Int.self, forKey: .openSquawks)) ?? 0
        dueSoon = (try? c.decode(Int.self, forKey: .dueSoon)) ?? 0
        overdue = (try? c.decode(Int.self, forKey: .overdue)) ?? 0
        next100hrDue = try? c.decodeIfPresent(String.self, forKey: .next100hrDue)
        annualDue = try? c.decodeIfPresent(String.self, forKey: .annualDue)
        lastOilChange = try? c.decodeIfPresent(String.self, forKey: .lastOilChange)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(tailNumber, forKey: .tailNumber)
        try c.encode(model, forKey: .model)
        try c.encode(status, forKey: .status)
        try c.encode(openSquawks, forKey: .openSquawks)
        try c.encode(dueSoon, forKey: .dueSoon)
        try c.encode(overdue, forKey: .overdue)
        try c.encodeIfPresent(next100hrDue, forKey: .next100hrDue)
        try c.encodeIfPresent(annualDue, forKey: .annualDue)
        try c.encodeIfPresent(lastOilChange, forKey: .lastOilChange)
    }

    var statusColor: Color {
        switch status.lowercased() {
        case "airworthy", "active": return .mdzGreen
        case "grounded", "inactive": return .mdzDanger
        case "maintenance": return .mdzAmber
        default: return .mdzMuted
        }
    }

    var hasAlerts: Bool { openSquawks > 0 || dueSoon > 0 || overdue > 0 }
}

// Squawk model for detail view
struct Squawk: Codable, Identifiable {
    let id: Int
    let description: String
    let status: String
    let reportedBy: String?
    let reportedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, description, status
        case reportedBy = "reported_by"
        case reportedAt = "reported_at"
    }

    var statusColor: Color {
        switch status.lowercased() {
        case "open":     return .mdzDanger
        case "deferred": return .mdzAmber
        case "closed":   return .mdzGreen
        default:         return .mdzMuted
        }
    }
}

struct LogbookEntry: Codable, Identifiable {
    let id: Int
    let date: String
    let description: String
    let tachTime: Double?
    let hobbsTime: Double?
    let performedBy: String?
    let bookType: String?
    let thumbnailPath: String?

    enum CodingKeys: String, CodingKey {
        case id, date, description
        case tachTime       = "tach_time"
        case hobbsTime      = "hobbs_time"
        case performedBy    = "performed_by"
        case bookType       = "book_type"
        case thumbnailPath  = "thumbnail_path"
    }

    var bookTypeLabel: String {
        switch (bookType ?? "airframe").lowercased() {
        case "engine": return "Engine"
        case "prop":   return "Prop"
        default:      return "Aircraft"
        }
    }

    func thumbnailURL(base: String = kServerURL) -> URL? {
        guard let path = thumbnailPath, !path.isEmpty else { return nil }
        let baseClean = base.hasSuffix("/") ? String(base.dropLast()) : base
        let pathClean = path.hasPrefix("/") ? path : "/" + path
        return URL(string: baseClean + pathClean)
    }
}

struct LogbookEntryDetail: Codable {
    let id: Int
    let date: String
    let description: String
    let tachTime: Double?
    let hobbsTime: Double?
    let performedBy: String?
    let bookType: String?
    let images: [String]

    enum CodingKeys: String, CodingKey {
        case id, date, description, images
        case tachTime    = "tach_time"
        case hobbsTime   = "hobbs_time"
        case performedBy = "performed_by"
        case bookType   = "book_type"
    }

    var bookTypeLabel: String {
        switch (bookType ?? "airframe").lowercased() {
        case "engine": return "Engine"
        case "prop":   return "Prop"
        default:      return "Aircraft"
        }
    }

    func imageURLs(base: String = kServerURL) -> [URL] {
        let baseClean = base.hasSuffix("/") ? String(base.dropLast()) : base
        return images.compactMap { path in
            guard !path.isEmpty else { return nil }
            let pathClean = path.hasPrefix("/") ? path : "/" + path
            return URL(string: baseClean + pathClean)
        }
    }
}

struct AirworthinessDirective: Codable, Identifiable {
    let id: Int
    let adNumber: String
    let description: String
    let dueDate: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, description, status
        case adNumber = "ad_number"
        case dueDate  = "due_date"
    }
}
