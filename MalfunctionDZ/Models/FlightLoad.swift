// File: ASC/Models/FlightLoad.swift
import Foundation
import MalfunctionDZCore

// MARK: - StringDouble
// PHP PDO returns decimal columns as strings. This decodes both "1234.5" and 1234.5.
struct StringDouble: Codable {
    let value: Double?
    init(_ v: Double?) { value = v }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = nil }
        else if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self)  { value = Double(s) }
        else { value = nil }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let v = value { try c.encode(v) } else { try c.encodeNil() }
    }
}

// MARK: - FlightLoad
struct FlightLoad: Codable, Identifiable {
    let id: Int
    let flightId: Int
    let loadNumber: Int
    let paxCount: Int
    let altitude: Int?
    let hobbsTime: StringDouble?
    let tachTime: StringDouble?
    let fuelAdded: StringDouble?
    let oilAdded: StringDouble?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, altitude, notes
        case flightId   = "flight_id"
        case loadNumber = "load_number"
        case paxCount   = "pax_count"
        case hobbsTime  = "hobbs_time"
        case tachTime   = "tach_time"
        case fuelAdded  = "fuel_added"
        case oilAdded   = "oil_added"
    }
}

// MARK: - Flight
struct Flight: Codable, Identifiable {
    let id: Int
    let aircraftId: Int
    let pilotUserId: Int?
    let flightDateOnly: String?
    let hobbsStart: StringDouble?
    let hobbsEnd: StringDouble?
    let tachStart: StringDouble?
    let tachEnd: StringDouble?
    let status: String
    let tailNumber: String?
    /// Session-level totals from flight start / flight log (optional on older payloads).
    let paxCount: Int?
    let altitudeFtAgl: Int?
    let fuelPumped: StringDouble?
    let oilUsed: StringDouble?
    let flightNotes: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case aircraftId     = "aircraft_id"
        case pilotUserId    = "pilot_user_id"
        case flightDateOnly = "flight_date_only"
        case hobbsStart     = "hobbs_start"
        case hobbsEnd       = "hobbs_end"
        case tachStart      = "tach_start"
        case tachEnd        = "tach_end"
        case tailNumber     = "tail_number"
        case paxCount       = "pax_count"
        case altitudeFtAgl  = "altitude_ft_agl"
        case fuelPumped     = "fuel_pumped"
        case oilUsed        = "oil_used"
        case flightNotes    = "notes"
    }

    var isOpen:   Bool { status == "open" }
    var isClosed: Bool { status == "closed" }
}

// MARK: - Pilot picker (PAX flight start)
struct PaxPilot: Codable, Identifiable {
    let userId: Int
    let displayName: String
    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
    }
}

// MARK: - PaxAircraft
struct PaxAircraft: Codable, Identifiable {
    let id: Int
    let tailNumber: String
    let make: String?
    let model: String?
    let currentHobbs: StringDouble?
    let currentTach: StringDouble?

    enum CodingKeys: String, CodingKey {
        case id, make, model
        case tailNumber   = "tail_number"
        case currentHobbs = "current_hobbs"
        case currentTach  = "current_tach"
    }

    init(id: Int, tailNumber: String, make: String?, model: String?,
         currentHobbs: Double?, currentTach: Double?) {
        self.id = id; self.tailNumber = tailNumber
        self.make = make; self.model = model
        self.currentHobbs = StringDouble(currentHobbs)
        self.currentTach  = StringDouble(currentTach)
    }

    var displayName: String {
        var name = tailNumber
        if let m = model, !m.isEmpty { name += " — \(m)" }
        return name
    }
}

// MARK: - PaxStateResponse
struct PaxStateResponse: Codable {
    let flight: Flight?
    let loads: [FlightLoad]
    let aircraft: [PaxAircraft]
}
