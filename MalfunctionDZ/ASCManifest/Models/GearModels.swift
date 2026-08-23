import Foundation

struct GearRig: Codable, Identifiable, Hashable {
    static func == (lhs: GearRig, rhs: GearRig) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: Int
    let label: String
    let manufacturer: String?
    let model: String?
    let isDzRig: Bool
    let harness: GearComponent
    let reserve: GearReserveComponent
    let aad: GearComponent
    let lastPack: String?
    let dueDate: String?
    let daysLeft: Int?
    let status: String
    let packedBy: String?
    let packJobsSinceInspection: Int?
    let outOfService: Bool?
    let lastInspectionAt: String?

    enum CodingKeys: String, CodingKey {
        case id, label, manufacturer, model, harness, reserve, aad, status
        case isDzRig = "is_dz_rig"
        case lastPack = "last_pack"
        case dueDate = "due_date"
        case daysLeft = "days_left"
        case packedBy = "packed_by"
        case packJobsSinceInspection = "pack_jobs_since_inspection"
        case outOfService = "out_of_service"
        case lastInspectionAt = "last_inspection_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id))
            ?? (try? c.decode(String.self, forKey: .id)).flatMap { Int($0) } ?? 0
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        manufacturer = try? c.decodeIfPresent(String.self, forKey: .manufacturer)
        model = try? c.decodeIfPresent(String.self, forKey: .model)
        if let b = try? c.decode(Bool.self, forKey: .isDzRig) { isDzRig = b }
        else if let i = try? c.decode(Int.self, forKey: .isDzRig) { isDzRig = i != 0 }
        else { isDzRig = true }
        harness = (try? c.decode(GearComponent.self, forKey: .harness)) ?? GearComponent(mfr: nil, model: nil, sn: nil)
        reserve = (try? c.decode(GearReserveComponent.self, forKey: .reserve))
            ?? GearReserveComponent(mfr: nil, model: nil, sn: nil, dom: nil)
        aad = (try? c.decode(GearComponent.self, forKey: .aad)) ?? GearComponent(mfr: nil, model: nil, sn: nil)
        lastPack = try? c.decodeIfPresent(String.self, forKey: .lastPack)
        dueDate = try? c.decodeIfPresent(String.self, forKey: .dueDate)
        if let i = try? c.decode(Int.self, forKey: .daysLeft) { daysLeft = i }
        else if let s = try? c.decode(String.self, forKey: .daysLeft) { daysLeft = Int(s) }
        else { daysLeft = nil }
        status = (try? c.decode(String.self, forKey: .status)) ?? "unknown"
        packedBy = try? c.decodeIfPresent(String.self, forKey: .packedBy)
        packJobsSinceInspection = try? c.decodeIfPresent(Int.self, forKey: .packJobsSinceInspection)
        outOfService = try? c.decodeIfPresent(Bool.self, forKey: .outOfService)
        lastInspectionAt = try? c.decodeIfPresent(String.self, forKey: .lastInspectionAt)
    }

    var usesSinceInspection: Int { packJobsSinceInspection ?? 0 }

    var gearCategory: GearDisplayCategory {
        if outOfService == true { return .inspection }
        let uses = usesSinceInspection
        if uses >= 20 && uses < 25 { return .twentyFiveDue }
        if status == "due_soon" || status == "overdue" { return .reserveDue }
        if let d = daysLeft, d <= 30 { return .reserveDue }
        if status == "unknown" { return .unknown }
        return .airworthy
    }

    var sortRank: Int {
        switch gearCategory {
        case .airworthy: return 0
        case .reserveDue: return 1
        case .twentyFiveDue: return 2
        case .inspection: return 3
        case .unknown: return 4
        }
    }

    var dueDateDisplay: String {
        guard let dueDate, !dueDate.isEmpty else { return "—" }
        if dueDate.count >= 10 { return String(dueDate.prefix(10)) }
        return dueDate
    }
}

struct GearComponent: Codable {
    let mfr: String?
    let model: String?
    let sn: String?
}

struct GearReserveComponent: Codable {
    let mfr: String?
    let model: String?
    let sn: String?
    let dom: String?
}

struct GearSummary: Codable {
    let total: Int
    let overdue: Int
    let dueSoon: Int
    let current: Int

    enum CodingKeys: String, CodingKey {
        case total, overdue, current
        case dueSoon = "due_soon"
    }
}

struct DzRigsAPIResponse: Codable {
    let ok: Bool
    let summary: GearSummary?
    let rigs: [GearRig]?
    let error: String?
}

enum GearDisplayCategory: String {
    case inspection = "Inspection"
    case twentyFiveDue = "25 Due"
    case reserveDue = "Reserve Due"
    case airworthy = "Airworthy"
    case unknown = "No Record"
}
