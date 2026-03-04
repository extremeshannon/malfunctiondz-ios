// File: MalfunctionDZ/Models/CalendarModels.swift
// Calendar events and staff shifts for Alaska Skydive Center.

import Foundation

// MARK: - Calendar Event (public, no auth)
struct CalendarEvent: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let eventDate: String
    let startTime: String?
    let endTime: String?
    let location: String?
    let isPublic: Bool
    let notifyPush: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, location
        case eventDate = "event_date"
        case startTime = "start_time"
        case endTime = "end_time"
        case isPublic = "is_public"
        case notifyPush = "notify_push"
    }

    /// Build from raw JSON dictionary
    init?(from dict: [String: Any]) {
        guard let idVal = dict["id"] else { return nil }
        if let i = idVal as? Int { id = i }
        else if let s = idVal as? String, let i = Int(s) { id = i }
        else { return nil }
        title = dict["title"] as? String ?? ""
        description = dict["description"] as? String
        eventDate = dict["event_date"] as? String ?? ""
        startTime = dict["start_time"] as? String
        endTime = dict["end_time"] as? String
        location = dict["location"] as? String
        let ip = dict["is_public"]
        isPublic = (ip as? Bool) ?? ((ip as? Int).map { $0 != 0 }) ?? true
        let np = dict["notify_push"]
        notifyPush = (np as? Bool) ?? ((np as? Int).map { $0 != 0 }) ?? false
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        eventDate = try c.decode(String.self, forKey: .eventDate)
        startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(String.self, forKey: .endTime)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        if let b = try? c.decode(Bool.self, forKey: .isPublic) { isPublic = b }
        else if let i = try? c.decode(Int.self, forKey: .isPublic) { isPublic = i != 0 }
        else { isPublic = true }
        if let b = try? c.decode(Bool.self, forKey: .notifyPush) { notifyPush = b }
        else if let i = try? c.decode(Int.self, forKey: .notifyPush) { notifyPush = i != 0 }
        else { notifyPush = false }
    }

    var formattedDate: String {
        guard let d = CalendarEvent.dateFormatter.date(from: eventDate) else { return eventDate }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    var timeRange: String {
        guard let start = startTime, let end = endTime else { return "" }
        return "\(formatTime(start)) – \(formatTime(end))"
    }

    private func formatTime(_ t: String) -> String {
        let parts = t.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return t }
        let period = h >= 12 ? "PM" : "AM"
        let hour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %s", hour, m, period)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Staff Shift (lenient decoding for PHP/MySQL type variations)
struct StaffShift: Codable, Identifiable {
    let id: Int
    let shiftDate: String
    let positionKey: String
    let slotKey: String
    let userId: Int?
    let status: String
    let fullName: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case shiftDate = "shift_date"
        case positionKey = "position_key"
        case slotKey = "slot_key"
        case userId = "user_id"
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
    }

    /// Build from raw JSON dictionary (handles PHP/MySQL type variations)
    init?(from dict: [String: Any]) {
        guard let idVal = dict["id"] else { return nil }
        if let i = idVal as? Int { id = i }
        else if let s = idVal as? String, let i = Int(s) { id = i }
        else { return nil }
        shiftDate = (dict["shift_date"] as? String) ?? ""
        positionKey = (dict["position_key"] as? String) ?? ""
        slotKey = (dict["slot_key"] as? String) ?? ""
        status = (dict["status"] as? String) ?? "available"
        fullName = dict["full_name"] as? String
        firstName = dict["first_name"] as? String
        lastName = dict["last_name"] as? String
        if let uid = dict["user_id"] as? Int, uid > 0 { userId = uid }
        else if let s = dict["user_id"] as? String, let uid = Int(s), uid > 0 { userId = uid }
        else if let n = dict["user_id"] as? NSNumber, n.intValue > 0 { userId = n.intValue }
        else { userId = nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        shiftDate = (try? c.decode(String.self, forKey: .shiftDate)) ?? ""
        positionKey = (try? c.decode(String.self, forKey: .positionKey)) ?? ""
        slotKey = (try? c.decode(String.self, forKey: .slotKey)) ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? "available"
        fullName = try? c.decodeIfPresent(String.self, forKey: .fullName)
        firstName = try? c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try? c.decodeIfPresent(String.self, forKey: .lastName)
        if let uid = try? c.decode(Int.self, forKey: .userId) { userId = uid }
        else if let uidStr = try? c.decode(String.self, forKey: .userId), let uid = Int(uidStr) { userId = uid }
        else { userId = nil }
    }

    var displayAssignee: String {
        switch status {
        case "available":
            return "Open"
        case "pending":
            return (fullName ?? "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)) + " (pending)"
        case "approved":
            return fullName ?? "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)
        case "release_requested":
            return (fullName ?? "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)) + " (release requested)"
        default:
            return fullName ?? "—"
        }
    }

    var positionLabel: String { CalendarLabels.positionLabel(for: positionKey) }
    var slotLabel: String { CalendarLabels.slotLabel(for: slotKey) }
}

// MARK: - Labels (slot and position display names)
enum CalendarLabels {
    static func slotLabel(for key: String) -> String {
        switch key {
        case "half_am": return "Half Day AM (8am–12pm)"
        case "half_pm": return "Half Day PM (12pm–6pm)"
        case "full": return "Full Day (8am–6pm)"
        default: return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func positionLabel(for key: String) -> String {
        switch key {
        case "pilot": return "Pilot"
        case "tandem_instructor": return "Tandem Instructor"
        case "packer": return "Packer"
        case "manifest": return "Manifest"
        case "videographer": return "Videographer"
        case "aff_instructor": return "AFF Instructor"
        case "coach": return "Coach"
        case "truck_driver": return "Truck Driver"
        case "rigger": return "Rigger"
        default: return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - API Request/Response wrappers
struct ShiftClaimRequest: Encodable {
    let shiftId: Int
    enum CodingKeys: String, CodingKey { case shiftId = "shift_id" }
}

struct EventsAPIResponse: Decodable {
    let ok: Bool
    let events: [CalendarEvent]?
}

struct ShiftsAPIResponse: Decodable {
    let ok: Bool
    let shifts: [StaffShift]?
}

struct MessageAPIResponse: Decodable {
    let ok: Bool
    let message: String?
    let error: String?
}

// MARK: - DZ Status API response
struct DZStatusAPIResponse: Decodable {
    let ok: Bool
    let status: DZStatus?
}

// MARK: - DZ Status (open/closed/announcement)
struct DZStatus: Codable {
    let id: Int
    let status: String
    let announcement: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, announcement
        case updatedAt = "updated_at"
    }
}
