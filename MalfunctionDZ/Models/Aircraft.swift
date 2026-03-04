// File: ASC/Models/Aircraft.swift
import Foundation
import SwiftUI

// Matches exactly what /api/aircraft/list.php returns
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
        case id, model, status
        case tailNumber    = "tail_number"
        case openSquawks   = "open_squawks"
        case dueSoon       = "due_soon"
        case overdue
        case next100hrDue  = "next_100hr_due"
        case annualDue     = "annual_due"
        case lastOilChange = "last_oil_change"
    }

    var statusColor: Color {
        switch status.lowercased() {
        case "airworthy": return .mdzGreen
        case "grounded":  return .mdzDanger
        case "maintenance": return .mdzAmber
        default:          return .mdzMuted
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
