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
    let ttsn: String?
    let smoh: String?
    let propTime: String?
    let slots: Int?
    let lastMic: String?
    /// Multi-engine (optional from API); when true, logbook has Left/Right engine.
    var isMultiEngine: Bool?
    /// Min/max slots for aircraft (e.g. pax); shown in header.
    let slotsMin: Int?
    let slotsMax: Int?

    enum CodingKeys: String, CodingKey {
        case id, model, status, make, year
        case tailNumber    = "tail_number"
        case openSquawks   = "open_squawks"
        case dueSoon       = "due_soon"
        case overdue
        case next100hrDue  = "next_100hr_due"
        case annualDue     = "annual_due"
        case lastOilChange = "last_oil_change"
        case ttsn, smoh, slots
        case lastMic       = "last_mic"
        case propTime      = "prop_time"
        case isMultiEngine = "multi_engine"
        case slotsMin      = "slots_min"
        case slotsMax      = "slots_max"
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
        ttsn = try? c.decodeIfPresent(String.self, forKey: .ttsn)
        smoh = try? c.decodeIfPresent(String.self, forKey: .smoh)
        slots = try? c.decodeIfPresent(Int.self, forKey: .slots)
        lastMic = try? c.decodeIfPresent(String.self, forKey: .lastMic)
        propTime = try? c.decodeIfPresent(String.self, forKey: .propTime)
        isMultiEngine = try? c.decodeIfPresent(Bool.self, forKey: .isMultiEngine)
        slotsMin = try? c.decodeIfPresent(Int.self, forKey: .slotsMin)
        slotsMax = try? c.decodeIfPresent(Int.self, forKey: .slotsMax)
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
        try c.encodeIfPresent(ttsn, forKey: .ttsn)
        try c.encodeIfPresent(smoh, forKey: .smoh)
        try c.encodeIfPresent(slots, forKey: .slots)
        try c.encodeIfPresent(lastMic, forKey: .lastMic)
        try c.encodeIfPresent(propTime, forKey: .propTime)
        try c.encodeIfPresent(isMultiEngine, forKey: .isMultiEngine)
        try c.encodeIfPresent(slotsMin, forKey: .slotsMin)
        try c.encodeIfPresent(slotsMax, forKey: .slotsMax)
    }

    var statusColor: Color {
        switch status.lowercased() {
        case "airworthy", "active": return .mdzBlue
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
        case "engine_left", "left_engine": return "Left Engine"
        case "engine_right", "right_engine": return "Right Engine"
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
        case "engine_left", "left_engine": return "Left Engine"
        case "engine_right", "right_engine": return "Right Engine"
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

struct StcEntry: Codable, Identifiable {
    let id: Int
    let recordType: String
    let entryDate: String
    let title: String
    let description: String
    let stcNumber: String?
    let form337Number: String?
    let approvalDate: String?
    let fieldApproval: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case recordType   = "record_type"
        case entryDate   = "entry_date"
        case stcNumber   = "stc_number"
        case form337Number = "form337_number"
        case approvalDate = "approval_date"
        case fieldApproval = "field_approval"
    }

    var recordTypeLabel: String {
        switch (recordType).lowercased() {
        case "form337": return "337"
        case "stc":    return "STC"
        default:       return recordType.uppercased()
        }
    }
}

/// Single STC/337 entry with images (from GET stc337_entry).
struct StcEntryDetail: Codable {
    let id: Int
    let recordType: String
    let entryDate: String
    let title: String
    let description: String
    let stcNumber: String?
    let form337Number: String?
    let approvalDate: String?
    let fieldApproval: String?
    let images: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, description, images
        case recordType   = "record_type"
        case entryDate   = "entry_date"
        case stcNumber   = "stc_number"
        case form337Number = "form337_number"
        case approvalDate = "approval_date"
        case fieldApproval = "field_approval"
    }

    var recordTypeLabel: String {
        switch (recordType).lowercased() {
        case "form337": return "337"
        case "stc":    return "STC"
        default:       return recordType.uppercased()
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
