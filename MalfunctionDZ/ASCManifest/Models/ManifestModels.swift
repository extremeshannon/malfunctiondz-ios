import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ManifestAPIEnvelope: Decodable {
    let ok: Bool
    let error: String?
}

struct ManifestLoginResponse: Decodable {
    let ok: Bool
    let error: String?
    let token: String?
    let mfa_required: Bool?
    let mfa_token: String?
    let user: ManifestUserProfile?
    let domains: [String]?
}

struct ManifestUserProfile: Decodable, Identifiable {
    let id: Int
    let username: String?
    let first_name: String?
    let last_name: String?
    let email: String?
    let role: String?
    let roles: [String]?
    let total_jumps: Int?
    let total_rigs: Int?
    let uspa_number: String?
    let phone: String?
    let highest_uspa_license: String?

    var displayName: String {
        let parts = [first_name, last_name].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return username ?? "User \(id)"
    }

    var canCheckInUsers: Bool {
        let allowed: Set<String> = ["admin", "ops_admin", "manifest"]
        let list = (roles ?? []).map { $0.lowercased().replacingOccurrences(of: " ", with: "_") }
        if list.contains(where: { allowed.contains($0) }) { return true }
        return allowed.contains((role ?? "").lowercased().replacingOccurrences(of: " ", with: "_"))
    }

    var isPilot: Bool {
        let list = (roles ?? []).map { $0.lowercased().replacingOccurrences(of: " ", with: "_") }
        return list.contains("pilot") || list.contains("chief_pilot") || (role ?? "").lowercased() == "pilot"
    }
}

struct ManifestMeResponse: Decodable {
    let ok: Bool
    let error: String?
    let user: ManifestUserProfile?
    let domains: [String]?
}

struct DayManifestResponse: Decodable {
    let ok: Bool
    let error: String?
    let date: String?
    let day_id: Int?
    let loads: [ManifestLoad]?
    /// Legacy flag; staff desk no longer builds the board from public display.
    let from_display_fallback: Bool?

    init(
        ok: Bool,
        error: String? = nil,
        date: String? = nil,
        day_id: Int? = nil,
        loads: [ManifestLoad]? = nil,
        from_display_fallback: Bool? = nil
    ) {
        self.ok = ok
        self.error = error
        self.date = date
        self.day_id = day_id
        self.loads = loads
        self.from_display_fallback = from_display_fallback
    }
}

struct ManifestLoad: Decodable, Identifiable, Hashable {
    let id: Int
    let time: String?
    let aircraft: String?
    let aircraft_id: Int?
    let kind: String?
    let filled: Int?
    let total: Int?
    let notes: String?
    let pilot_user_id: Int?
    let pilot_name: String?
    let pilot_pay_cents: Int?
    let pilot_pay_label: String?
    let second_pilot_user_id: Int?
    let second_pilot_name: String?
    let training_pilot_user_id: Int?
    let training_pilot_name: String?
    let status: String?
    let max_pax_per_load: Int?
    let slots: [ManifestSlot]?

    var statusKey: ManifestLoadStatus {
        ManifestLoadStatus(rawValue: status ?? "building") ?? .building
    }

    var slotCountLabel: String {
        "\(filled ?? slots?.count ?? 0)/\(total ?? max_pax_per_load ?? 0)"
    }

    var aircraftOccupancyLabel: String {
        let plane = (aircraft ?? "").trimmingCharacters(in: .whitespaces)
        let seats = slotCountLabel
        if plane.isEmpty { return seats }
        return "\(plane) · \(seats)"
    }

    func updating(slots: [ManifestSlot]? = nil, filled: Int? = nil, pilotUserId: Int? = nil, status: String? = nil) -> ManifestLoad {
        let nextSlots = slots ?? self.slots
        return ManifestLoad(
            id: id,
            time: time,
            aircraft: aircraft,
            aircraft_id: aircraft_id,
            kind: kind,
            filled: filled ?? nextSlots?.count ?? self.filled,
            total: total,
            notes: notes,
            pilot_user_id: pilotUserId ?? pilot_user_id,
            pilot_name: pilotUserId != nil ? nil : pilot_name,
            pilot_pay_cents: pilot_pay_cents,
            pilot_pay_label: pilot_pay_label,
            second_pilot_user_id: second_pilot_user_id,
            second_pilot_name: second_pilot_name,
            training_pilot_user_id: training_pilot_user_id,
            training_pilot_name: training_pilot_name,
            status: status ?? self.status,
            max_pax_per_load: max_pax_per_load,
            slots: nextSlots
        )
    }

    static func placeholder(id: Int, aircraft: ManifestAircraft?) -> ManifestLoad {
        ManifestLoad(
            id: id,
            time: nil,
            aircraft: aircraft?.tail_number ?? aircraft?.label,
            aircraft_id: aircraft?.id,
            kind: nil,
            filled: 0,
            total: aircraft?.max_pax_per_load,
            notes: nil,
            pilot_user_id: nil,
            pilot_name: nil,
            pilot_pay_cents: nil,
            pilot_pay_label: nil,
            second_pilot_user_id: nil,
            second_pilot_name: nil,
            training_pilot_user_id: nil,
            training_pilot_name: nil,
            status: "building",
            max_pax_per_load: aircraft?.max_pax_per_load,
            slots: []
        )
    }
}

struct ManifestSlot: Decodable, Identifiable, Hashable {
    let id: Int
    let slot_position: Int?
    let user_id: Int?
    let display_name: String?
    let jump_type: String?
    let tandem_student_id: Int?
    let tandem_instructor_user_id: Int?
    let second_instructor_user_id: Int?
    let videographer_user_id: Int?
    let payment_complete: Bool?
    let waiver_signed_at: String?
    let id_verified_at: String?
    let notes: String?
    let weight_lb: Int?
    let pay_label: String?
    let pay_state: String?
    let due_cents: Int?
    let price_cents: Int?
    let rig_label: String?
    let loft_rig_id: Int?

    var name: String {
        (display_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : (display_name ?? "—")
    }

    var isPilotSlot: Bool {
        (jump_type ?? "").lowercased() == "pilot"
    }

    var weightLabel: String {
        if let weight_lb { return "\(weight_lb) lb" }
        return "— lb"
    }

    var moneyLabel: String {
        let trimmed = (pay_label ?? "").trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        if payment_complete == true { return "Paid" }
        if let due_cents, due_cents > 0 {
            return String(format: "$%.2f", Double(due_cents) / 100.0)
        }
        if let price_cents, price_cents > 0 {
            return String(format: "$%.2f", Double(price_cents) / 100.0)
        }
        return "$ due"
    }

    var moneyIsPaidTone: Bool {
        let state = (pay_state ?? "").lowercased()
        if state == "due" || state == "out" { return false }
        if payment_complete == true { return true }
        if state == "in" { return true }
        return moneyLabel.lowercased() == "paid"
    }

    var gearLabel: String? {
        let rig = (rig_label ?? "").trimmingCharacters(in: .whitespaces)
        if !rig.isEmpty { return rig }
        let note = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? nil : note
    }

    var hasWarning: Bool {
        waiver_signed_at == nil || id_verified_at == nil || payment_complete != true || pay_state == "due"
    }
}

struct ManifestAircraftListResponse: Decodable {
    let ok: Bool
    let error: String?
    let aircraft: [ManifestAircraft]?
}

struct ManifestAircraft: Decodable, Identifiable {
    let id: Int
    let tail_number: String?
    let make: String?
    let model: String?
    let min_pax_per_load: Int?
    let default_pax_per_load: Int?
    let max_pax_per_load: Int?
    let is_jumpable: Bool?
    let status: String?
    let default_altitude_ft_agl: Int?
    let required_pilots: Int?

    var label: String {
        let tailText = (tail_number ?? "").trimmingCharacters(in: .whitespaces)
        let typeText = typeLabel
        if !tailText.isEmpty && !typeText.isEmpty { return "\(tailText) · \(typeText)" }
        return tailText.isEmpty ? typeText : tailText
    }

    var typeLabel: String {
        [make, model]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var isJumpPlane: Bool { is_jumpable ?? true }

    var isActiveForManifest: Bool {
        (status ?? "active").lowercased() == "active"
    }

    var statusLabel: String {
        let raw = (status ?? "active").trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? "Active" : raw.capitalized
    }

    var paxCapacityLabel: String {
        let minSeats = min_pax_per_load ?? 1
        let maxSeats = max_pax_per_load ?? 4
        let defaultSeats = default_pax_per_load ?? maxSeats
        if minSeats == maxSeats { return "\(maxSeats) jumpers/load" }
        return "\(minSeats)–\(maxSeats) jumpers (default \(defaultSeats))"
    }

    var altitudeLabel: String? {
        guard let default_altitude_ft_agl, default_altitude_ft_agl > 0 else { return nil }
        return "\(default_altitude_ft_agl.formatted()) ft AGL"
    }

    var pilotsRequiredLabel: String? {
        guard let required_pilots, required_pilots >= 2 else { return nil }
        return "\(required_pilots) pilots required"
    }
}

struct ManifestAircraftDaySummary {
    let loadCount: Int
    let filledSeats: Int
    let totalSeats: Int

    var loadsLabel: String {
        loadCount == 1 ? "1 load today" : "\(loadCount) loads today"
    }

    var occupancyLabel: String {
        guard totalSeats > 0 else {
            return loadCount == 0 ? "No loads today" : loadsLabel
        }
        return "\(loadsLabel) · \(filledSeats)/\(totalSeats) seats"
    }
}

struct SlotsResponse: Decodable {
    let ok: Bool
    let error: String?
    let slots: [ManifestSlot]?
}

struct CreateLoadResponse: Decodable {
    let ok: Bool
    let error: String?
    let load_id: Int?
}

struct GenericOKResponse: Decodable {
    let ok: Bool
    let error: String?
    let load_id: Int?
    let slot_id: Int?
    let blockers: [ComplianceBlocker]?
    let override_allowed: Bool?
    let compliance_reasons: [String]?
    let code: String?
    let prep_kind: String?
    let prep: CheckInPrepState?
    let renting_allowed: Bool?
    let needs_payment: Bool?
    let pay_label: String?
    let due_cents: Int?
    let waiver_signed: Bool?
}

struct CheckInPrepResponse: Decodable {
    let ok: Bool
    let error: String?
    let user_id: Int?
    let tandem_student_id: Int?
    let id_checked: Bool?
    let affidavit_signed: Bool?
    let dz_briefing: Bool?
    let waiver_signed: Bool?
    let video_watched: Bool?
    let training_complete: Bool?
    let compliance_reasons: [String]?
    let prep_kind: String?
    let prep: CheckInPrepState?
}

struct CheckInPrepState: Decodable {
    let prep_kind: String?
    let id_checked: Bool?
    let affidavit_signed: Bool?
    let dz_briefing: Bool?
    let dz_briefed_by_user_id: Int?
    let renting_dz_rig: Bool?
    let waiver_signed: Bool?
    let video_watched: Bool?
    let training_complete: Bool?
    let id_scan_preview: String?
}

/// Payload for the “Cannot check in” sheet (mirrors web Load Manager blocked modal).
struct CheckInBlockedContext: Identifiable {
    enum Kind: Equatable {
        case jumper(userID: Int)
        case tandem(tandemStudentID: Int)
    }

    let id = UUID()
    let kind: Kind
    let personName: String
    var reasons: [String]
    var overrideAllowed: Bool
    var needsPayment: Bool
    var payLabel: String?
    var rentingAllowed: Bool
    var showSkydiverPrep: Bool
    var showTandemPrep: Bool
    var idChecked: Bool
    var affidavitSigned: Bool
    var dzBriefing: Bool
    var rentingDzRig: Bool
    var waiverSigned: Bool
    var videoWatched: Bool
    var trainingComplete: Bool
    var markPaid: Bool
    var overrideNote: String
    var statusMessage: String?

    static func from(
        response: GenericOKResponse,
        kind: Kind,
        personName: String
    ) -> CheckInBlockedContext {
        let prep = response.prep
        let prepKind = (response.prep_kind ?? prep?.prep_kind ?? "").lowercased()
        let isTandem: Bool = {
            if case .tandem = kind { return true }
            return prepKind == "tandem"
        }()
        let isSkydiver = !isTandem && (prepKind == "skydiver" || prepKind == "user" || prepKind.isEmpty)
        let reasons = response.compliance_reasons ?? []
        let rentingHint = response.renting_allowed == true
            || reasons.contains { $0.localizedCaseInsensitiveContains("renting") || $0.localizedCaseInsensitiveContains("personal rig") }
        return CheckInBlockedContext(
            kind: kind,
            personName: personName,
            reasons: reasons.isEmpty ? [response.error ?? "Cannot check in."] : reasons,
            overrideAllowed: response.override_allowed == true,
            needsPayment: response.needs_payment == true,
            payLabel: response.pay_label,
            rentingAllowed: rentingHint,
            showSkydiverPrep: isSkydiver,
            showTandemPrep: isTandem,
            idChecked: prep?.id_checked ?? false,
            affidavitSigned: prep?.affidavit_signed ?? false,
            dzBriefing: prep?.dz_briefing ?? false,
            rentingDzRig: prep?.renting_dz_rig ?? false,
            waiverSigned: prep?.waiver_signed ?? response.waiver_signed ?? false,
            videoWatched: prep?.video_watched ?? false,
            trainingComplete: prep?.training_complete ?? false,
            markPaid: false,
            overrideNote: "",
            statusMessage: nil
        )
    }

    mutating func apply(response: GenericOKResponse) {
        let prep = response.prep
        if let reasons = response.compliance_reasons, !reasons.isEmpty {
            self.reasons = reasons
        } else if let err = response.error, !err.isEmpty {
            self.reasons = [err]
        }
        overrideAllowed = response.override_allowed == true
        needsPayment = response.needs_payment == true
        if let payLabel = response.pay_label { self.payLabel = payLabel }
        if let renting = response.renting_allowed { rentingAllowed = renting }
        if let prep {
            idChecked = prep.id_checked ?? idChecked
            affidavitSigned = prep.affidavit_signed ?? affidavitSigned
            dzBriefing = prep.dz_briefing ?? dzBriefing
            rentingDzRig = prep.renting_dz_rig ?? rentingDzRig
            waiverSigned = prep.waiver_signed ?? waiverSigned
            videoWatched = prep.video_watched ?? videoWatched
            trainingComplete = prep.training_complete ?? trainingComplete
        }
    }
}

struct ComplianceBlocker: Decodable {
    let gate: String?
    let message: String?
}

struct SearchJumpersResponse: Decodable {
    let ok: Bool
    let error: String?
    let people: [SearchPerson]?
}

struct SearchPerson: Decodable, Identifiable {
    let id: Int
    let user_id: Int?
    let tandem_student_id: Int?
    let name: String?
    let full_name: String?
    let username: String?
    let email: String?
    let phone: String?
    let kind: String?
    let weight_lb: Int?
    let roles: [String]?
    let next_jump_type: String?
    let next_jump_label: String?
    let needs_enrollment: Bool?

    var displayName: String {
        (full_name ?? name ?? username ?? "User \(id)").trimmingCharacters(in: .whitespaces)
    }

    var accountTarget: AccountTarget {
        if (kind ?? "").lowercased() == "tandem" {
            if let user_id { return .user(user_id) }
            return .tandem(tandem_student_id ?? id)
        }
        return .user(user_id ?? id)
    }
}

enum AccountTarget: Hashable, Identifiable {
    case user(Int)
    case tandem(Int)

    var id: String {
        switch self {
        case .user(let id): "user-\(id)"
        case .tandem(let id): "tandem-\(id)"
        }
    }
}

struct AccountDetailResponse: Decodable {
    let ok: Bool
    let error: String?
    let kind: String?
    let linked_user_id: Int?
    let account: AccountDetail?
    let permissions: AccountPermissions?
    let gear: [AccountGearItem]?
}

struct AccountDetail: Decodable {
    let user_id: Int?
    let tandem_student_id: Int?
    let display_name: String?
    let username: String?
    let weight: Int?
    let phone: String?
    let email: String?
    let uspa_number: String?
    let highest_uspa_license: String?
    let waiver_valid: Bool?
    let can_carry_balance: Bool?
    let starting_balance: String?
    let todays_balance: String?
    let total_paid: String?
    let total_payout: String?
    let total_balance: String?
}

struct AccountPermissions: Decodable {
    let can_check_in: Bool?
    let can_post_ledger: Bool?
}

struct AccountGearItem: Decodable, Identifiable {
    let id: Int
    let rig_label: String?
    let manufacturer: String?
    let harness_mfr: String?
    let harness_model: String?
    let main_model: String?
    let main_size_sqft: Int?
    let reserve_model: String?
    let loft_pack_locked: Bool?
    let pack_date: String?
    let container_photo_url: String?
    let main_photo_url: String?

    var summary: String {
        let container = [harness_mfr, harness_model].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        let main = [main_model, main_size_sqft.map { String($0) }].compactMap { $0 }.joined(separator: " ")
        let reserve = (reserve_model ?? "").trimmingCharacters(in: .whitespaces)
        var parts = ["Container \(container.isEmpty ? "—" : container)", "Main \(main.isEmpty ? "—" : main)"]
        if !reserve.isEmpty { parts.append("Reserve \(reserve)") }
        if let pack_date, !pack_date.isEmpty { parts.append("packed \(pack_date)") }
        return parts.joined(separator: " · ")
    }
}

struct AccountHistoryResponse: Decodable {
    let ok: Bool
    let error: String?
    let items: [AccountHistoryItem]?
}

struct AccountHistoryItem: Decodable, Identifiable {
    let id: Int
    let created_date: String?
    let txn_type: String?
    let note: String?
    let amount_display: String?
    let signed_display: String?
    let method: String?
    let jump_type: String?
}

struct NextLevelResponse: Decodable {
    let ok: Bool
    let error: String?
    let label: String?
    let module_title: String?
    let jump_type: String?
    let needs_enrollment: Bool?
    let enrolled: Bool?
    let instructor_mode: String?
    let complete: Bool?
}

struct InstructorsResponse: Decodable {
    let ok: Bool
    let error: String?
    let instructors: [InstructorCandidate]?
}

struct InstructorCandidate: Decodable, Identifiable {
    let id: Int
    let user_id: Int?
    let name: String?
    let roles: [String]?

    var displayName: String {
        (name ?? "User \(id)").trimmingCharacters(in: .whitespaces)
    }

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, roles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
            ?? c.decodeIfPresent(Int.self, forKey: .user_id)
            ?? 0
        user_id = try c.decodeIfPresent(Int.self, forKey: .user_id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        roles = try c.decodeIfPresent([String].self, forKey: .roles)
    }
}

struct AccountWaiversResponse: Decodable {
    let ok: Bool
    let error: String?
    let items: [AccountWaiverItem]?
}

struct AccountWaiverItem: Decodable, Identifiable {
    let id: Int
    let waiver_type: String?
    let version: Int?
    let source_label: String?
    let signed_at: String?
    let guest_name: String?
}

struct CreateTandemStudentResponse: Decodable {
    let ok: Bool
    let error: String?
    let tandem_student_id: Int?
    let person: SearchPerson?
}

struct CheckInListResponse: Decodable {
    let ok: Bool
    let error: String?
    let date: String?
    let users: [CheckedInUser]?
}

struct CheckedInTandemListResponse: Decodable {
    let ok: Bool
    let error: String?
    let date: String?
    let students: [CheckedInTandemStudent]?
}

struct CheckedInTandemStudent: Decodable, Identifiable {
    let id: Int
    let tandem_student_id: Int?
    let user_id: Int?
    let display_name: String?
    let first_name: String?
    let last_name: String?
    let email: String?
    let checked_in_at: String?
    let kind: String?
    let weight_lb: Int?
    let pay_state: String?
    let pay_label: String?
    let pay_tone: String?
    let due_cents: Int?

    init(
        id: Int,
        tandem_student_id: Int? = nil,
        user_id: Int? = nil,
        display_name: String? = nil,
        first_name: String? = nil,
        last_name: String? = nil,
        email: String? = nil,
        checked_in_at: String? = nil,
        kind: String? = nil,
        weight_lb: Int? = nil,
        pay_state: String? = nil,
        pay_label: String? = nil,
        pay_tone: String? = nil,
        due_cents: Int? = nil
    ) {
        self.id = id
        self.tandem_student_id = tandem_student_id
        self.user_id = user_id
        self.display_name = display_name
        self.first_name = first_name
        self.last_name = last_name
        self.email = email
        self.checked_in_at = checked_in_at
        self.kind = kind
        self.weight_lb = weight_lb
        self.pay_state = pay_state
        self.pay_label = pay_label
        self.pay_tone = pay_tone
        self.due_cents = due_cents
    }

    var tandemID: Int { tandem_student_id ?? id }

    var resolvedName: String {
        let joined = [first_name, last_name]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !joined.isEmpty { return joined }
        return (display_name ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            ? "Tandem student \(tandemID)"
            : (display_name ?? "Tandem student")
    }
}

struct CheckInPoolsResponse: Decodable {
    let ok: Bool
    let error: String?
    let date: String?
    let pools: CheckInPools?
}

struct CheckInPools: Decodable {
    let staff: [CheckInPoolPerson]?
    let jumpers: [CheckInPoolPerson]?
    let students: [CheckInPoolPerson]?
    let tandem: [CheckInPoolPerson]?

    var staffList: [CheckInPoolPerson] { staff ?? [] }
    var jumpersList: [CheckInPoolPerson] { jumpers ?? [] }
    var studentsList: [CheckInPoolPerson] { students ?? [] }
    var tandemList: [CheckInPoolPerson] { tandem ?? [] }
}

/// Checked-in row from v5 Load Manager pools API (staff / jumpers / students / tandem).
struct CheckInPoolPerson: Decodable, Identifiable, Hashable {
    let record_id: Int?
    let user_id: Int?
    let tandem_student_id: Int?
    let display_name: String?
    let first_name: String?
    let last_name: String?
    let username: String?
    let email: String?
    let roles: [String]?
    let kind: String?
    let weight_lb: Int?
    let pay_state: String?
    let pay_label: String?
    let pay_tone: String?
    let due_cents: Int?
    let next_jump_type: String?
    let next_jump_label: String?
    let needs_enrollment: Bool?
    let checked_in_at: String?

    enum CodingKeys: String, CodingKey {
        case record_id = "id"
        case user_id, tandem_student_id, display_name, first_name, last_name, username, email
        case roles, kind, weight_lb, pay_state, pay_label, pay_tone, due_cents
        case next_jump_type, next_jump_label, needs_enrollment, checked_in_at
    }

    var rowID: String {
        if let tid = tandem_student_id ?? (isTandem ? record_id : nil) {
            return "t-\(tid)"
        }
        let uid = user_id ?? record_id ?? 0
        return "u-\(uid)"
    }

    var id: String { rowID }

    var isTandem: Bool {
        (kind ?? "").lowercased() == "tandem" || tandem_student_id != nil
    }

    var resolvedUserID: Int? {
        user_id ?? (isTandem ? nil : record_id)
    }

    var resolvedTandemID: Int? {
        tandem_student_id ?? (isTandem ? record_id : nil)
    }

    var resolvedName: String {
        let joined = [first_name, last_name]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !joined.isEmpty { return joined }
        let named = (display_name ?? username ?? "").trimmingCharacters(in: .whitespaces)
        if !named.isEmpty { return named }
        if let uid = resolvedUserID { return "User \(uid)" }
        if let tid = resolvedTandemID { return "Tandem \(tid)" }
        return "—"
    }

    var lineTitle: String {
        let label = (next_jump_label ?? "").trimmingCharacters(in: .whitespaces)
        if !label.isEmpty { return "\(resolvedName) · \(label)" }
        return resolvedName
    }

    var weightLabel: String {
        guard let weight_lb, weight_lb > 0 else { return "— lb" }
        return "\(weight_lb) lb"
    }

    var weightMissing: Bool {
        weight_lb == nil || weight_lb ?? 0 <= 0
    }

    var payIsDue: Bool {
        (pay_state ?? "").lowercased() == "due"
    }

    var boardPerson: BoardPerson {
        if isTandem, let tid = resolvedTandemID {
            return .tandem(id: tid, name: resolvedName)
        }
        return .user(id: resolvedUserID ?? user_id ?? record_id ?? 0, name: resolvedName)
    }

    func eligibleUser() -> EligibleUser {
        EligibleUser(
            id: resolvedUserID ?? user_id ?? record_id ?? 0,
            name: resolvedName,
            display_name: display_name,
            username: username,
            roles: roles,
            weight_lb: weight_lb
        )
    }

    init(
        record_id: Int? = nil,
        user_id: Int? = nil,
        tandem_student_id: Int? = nil,
        display_name: String? = nil,
        first_name: String? = nil,
        last_name: String? = nil,
        username: String? = nil,
        email: String? = nil,
        roles: [String]? = nil,
        kind: String? = nil,
        weight_lb: Int? = nil,
        pay_state: String? = nil,
        pay_label: String? = nil,
        pay_tone: String? = nil,
        due_cents: Int? = nil,
        next_jump_type: String? = nil,
        next_jump_label: String? = nil,
        needs_enrollment: Bool? = nil,
        checked_in_at: String? = nil
    ) {
        self.record_id = record_id
        self.user_id = user_id
        self.tandem_student_id = tandem_student_id
        self.display_name = display_name
        self.first_name = first_name
        self.last_name = last_name
        self.username = username
        self.email = email
        self.roles = roles
        self.kind = kind
        self.weight_lb = weight_lb
        self.pay_state = pay_state
        self.pay_label = pay_label
        self.pay_tone = pay_tone
        self.due_cents = due_cents
        self.next_jump_type = next_jump_type
        self.next_jump_label = next_jump_label
        self.needs_enrollment = needs_enrollment
        self.checked_in_at = checked_in_at
    }
}

enum CheckInTab: String, CaseIterable, Identifiable {
    case staff, jumpers, tandem, students

    var id: String { rawValue }

    var label: String {
        switch self {
        case .staff: "Staff"
        case .jumpers: "Jumpers"
        case .tandem: "Tandem"
        case .students: "Students"
        }
    }
}

enum CheckInRoleBuckets {
    private static let staffRoles: Set<String> = [
        "pilot", "chief_pilot", "tandem_instructor", "aff_instructor", "coach",
        "packer", "rigger", "instructor", "iad_instructor", "sl_instructor",
    ]

    static func normRole(_ role: String) -> String {
        role.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    static func isStaff(_ roles: [String]) -> Bool {
        roles.contains { staffRoles.contains(normRole($0)) }
    }

    static func isStudent(_ roles: [String]) -> Bool {
        roles.contains {
            let n = normRole($0)
            return n == "student" || n == "lms_student"
        }
    }

    static func matchesTab(_ user: EligibleUser, tab: CheckInTab) -> Bool {
        tabForUser(user) == tab
    }

    static func tabForRoles(_ roles: [String]) -> CheckInTab {
        if isStaff(roles) { return .staff }
        if isStudent(roles) && !isStaff(roles) { return .students }
        return .jumpers
    }

    static func tabForUser(_ user: EligibleUser) -> CheckInTab {
        tabForRoles(user.roles ?? [])
    }

    static func tabForPoolPerson(_ person: CheckInPoolPerson) -> CheckInTab {
        if person.isTandem { return .tandem }
        return tabForRoles(person.roles ?? [])
    }

    static func alreadyCheckedUserID(_ userID: Int, pools: CheckInPools?) -> Bool {
        guard let pools else { return false }
        let buckets = pools.staffList + pools.jumpersList + pools.studentsList
        return buckets.contains { ($0.resolvedUserID ?? 0) == userID }
    }

    static func alreadyCheckedTandemID(_ tandemID: Int, pools: CheckInPools?) -> Bool {
        guard let pools else { return false }
        return pools.tandemList.contains { ($0.resolvedTandemID ?? 0) == tandemID }
    }
}

struct CheckedInUser: Decodable, Identifiable {
    let user_id: Int
    let display_name: String?
    let name: String?
    let username: String?
    let checked_in_at: String?
    let first_name: String?
    let last_name: String?
    let weight_lb: Int?
    let roles: [String]?
    let pay_state: String?
    let pay_label: String?
    let next_jump_label: String?

    init(
        user_id: Int,
        display_name: String? = nil,
        name: String? = nil,
        username: String? = nil,
        checked_in_at: String? = nil,
        first_name: String? = nil,
        last_name: String? = nil,
        weight_lb: Int? = nil,
        roles: [String]? = nil,
        pay_state: String? = nil,
        pay_label: String? = nil,
        next_jump_label: String? = nil
    ) {
        self.user_id = user_id
        self.display_name = display_name
        self.name = name
        self.username = username
        self.checked_in_at = checked_in_at
        self.first_name = first_name
        self.last_name = last_name
        self.weight_lb = weight_lb
        self.roles = roles
        self.pay_state = pay_state
        self.pay_label = pay_label
        self.next_jump_label = next_jump_label
    }

    var id: Int { user_id }

    var resolvedName: String {
        let joined = [first_name, last_name]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !joined.isEmpty { return joined }
        return display_name ?? name ?? username ?? "User \(user_id)"
    }

    enum CodingKeys: String, CodingKey {
        case user_id, id, display_name, name, username, checked_in_at
        case first_name, last_name, weight_lb, roles, pay_state, pay_label, next_jump_label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try c.decodeIfPresent(Int.self, forKey: .user_id)
            ?? c.decodeIfPresent(Int.self, forKey: .id)
            ?? 0
        display_name = try c.decodeIfPresent(String.self, forKey: .display_name)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        checked_in_at = try c.decodeIfPresent(String.self, forKey: .checked_in_at)
        first_name = try c.decodeIfPresent(String.self, forKey: .first_name)
        last_name = try c.decodeIfPresent(String.self, forKey: .last_name)
        weight_lb = try c.decodeIfPresent(Int.self, forKey: .weight_lb)
        roles = try c.decodeIfPresent([String].self, forKey: .roles)
        pay_state = try c.decodeIfPresent(String.self, forKey: .pay_state)
        pay_label = try c.decodeIfPresent(String.self, forKey: .pay_label)
        next_jump_label = try c.decodeIfPresent(String.self, forKey: .next_jump_label)
    }
}

struct EligibleUsersResponse: Decodable {
    let ok: Bool
    let error: String?
    let users: [EligibleUser]?
}

struct EligibleUser: Decodable, Identifiable {
    let id: Int
    let name: String?
    let display_name: String?
    let username: String?
    let roles: [String]?
    let weight_lb: Int?

    init(
        id: Int,
        name: String? = nil,
        display_name: String? = nil,
        username: String? = nil,
        roles: [String]? = nil,
        weight_lb: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.display_name = display_name
        self.username = username
        self.roles = roles
        self.weight_lb = weight_lb
    }

    var resolvedName: String {
        let named = (name ?? display_name ?? username ?? "").trimmingCharacters(in: .whitespaces)
        if !named.isEmpty { return named }
        return "User \(id)"
    }

    var suggestLabel: String {
        var parts = [resolvedName, weightLabel]
        if let pay = payHint { parts.append(pay) }
        return parts.joined(separator: " · ")
    }

    /// Lowercased haystack for desk search (name, username, display).
    var searchHaystack: String {
        [resolvedName, display_name, name, username]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private var weightLabel: String {
        guard let weight_lb, weight_lb > 0 else { return "— lb" }
        return "\(weight_lb) lb"
    }

    private var payHint: String? { nil }

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, display_name, username, roles, weight_lb
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
            ?? c.decodeIfPresent(Int.self, forKey: .user_id)
            ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name)
        display_name = try c.decodeIfPresent(String.self, forKey: .display_name)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        roles = try c.decodeIfPresent([String].self, forKey: .roles)
        weight_lb = try c.decodeIfPresent(Int.self, forKey: .weight_lb)
    }
}

struct IDScanResponse: Decodable {
    let ok: Bool
    let error: String?
    let parsed: IDScanParsed?
    let stored: Bool?
    let preview: String?
    let id_checked: Bool?
    let name_mismatch: Bool?
}

struct IDScanParsed: Decodable {
    let first_name: String?
    let last_name: String?
    let date_of_birth: String?
    let license_number: String?
    let address_line1: String?
    let city: String?
    let state: String?
}

struct ManifestPilotAssignment: Decodable, Identifiable, Hashable {
    let load_id: Int
    let load_num: Int?
    let role: String
    let aircraft_label: String?
    let status: String?

    var id: String { "\(load_id)-\(role)" }

    var roleLabel: String {
        switch role.lowercased() {
        case "second": "Second PIC"
        case "training": "Training"
        default: "PIC"
        }
    }
}

struct ManifestPilotDocRow: Decodable, Identifiable {
    let doc_key: String?
    let label: String?
    let tone: String?
    let status_text: String?
    let icon: String?
    let date_text: String?
    let expires_text: String?
    let is_waiver: Bool?

    var id: String { doc_key ?? label ?? UUID().uuidString }
}

struct ManifestPilotCard: Decodable, Identifiable {
    let user_id: Int
    let display_name: String?
    let username: String?
    let is_active: Bool?
    let ready_tone: String?
    let ready_label: String?
    let airworthy: Bool?
    let ready_to_fly: Bool?
    let cleared_to_solo: Bool?
    let checked_in: Bool?
    let assignments: [ManifestPilotAssignment]?
    let doc_rows: [ManifestPilotDocRow]?

    var id: Int { user_id }

    var resolvedName: String {
        let name = (display_name ?? "").trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        let un = (username ?? "").trimmingCharacters(in: .whitespaces)
        return un.isEmpty ? "Pilot #\(user_id)" : un
    }
}

struct ManifestPilotCounts: Decodable {
    let total: Int?
    let ok: Int?
    let warn: Int?
    let bad: Int?
}

struct ManifestPilotsResponse: Decodable {
    let ok: Bool
    let error: String?
    let pilots: [ManifestPilotCard]?
    let counts: ManifestPilotCounts?
    let can_manage: Bool?
    let date: String?
}

enum ManifestLoadStatus: String, CaseIterable, Identifiable {
    case building, manifesting, called, in_air, completed, cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .building: "Building"
        case .manifesting: "Manifesting"
        case .called: "Called"
        case .in_air: "In Air"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }

    var next: ManifestLoadStatus? {
        switch self {
        case .building: .manifesting
        case .manifesting: .called
        case .called: .in_air
        case .in_air: .completed
        default: nil
        }
    }
}

enum ManifestJumpType: String, CaseIterable, Identifiable {
    case tandem, aff, solo, fun, coach, wingsuit, pilot

    var id: String { rawValue }

    var label: String {
        rawValue.uppercased()
    }
}

/// Drag-and-drop payload for the Load Manager board.
struct BoardPerson: Codable, Hashable, Identifiable, Transferable {
    let id: Int
    let name: String
    let tandemStudentID: Int?

    var isTandem: Bool { tandemStudentID != nil }

    var dragPayload: String {
        if let tandemStudentID {
            return "t:\(tandemStudentID)\t\(name)"
        }
        return "u:\(id)\t\(name)"
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.dragPayload) { BoardPerson(payload: $0) }
    }

    init(id: Int, name: String, tandemStudentID: Int? = nil) {
        self.id = id
        self.name = name
        self.tandemStudentID = tandemStudentID
    }

    static func user(id: Int, name: String) -> BoardPerson {
        BoardPerson(id: id, name: name, tandemStudentID: nil)
    }

    static func tandem(id: Int, name: String) -> BoardPerson {
        BoardPerson(id: id, name: name, tandemStudentID: id)
    }

    init(payload: String) {
        let parts = payload.split(separator: "\t", maxSplits: 1).map(String.init)
        let head = parts.first ?? ""
        let resolvedName = parts.count > 1 ? parts[1] : payload
        if head.hasPrefix("t:"), let tandemID = Int(head.dropFirst(2)) {
            id = tandemID
            name = resolvedName
            tandemStudentID = tandemID
        } else if head.hasPrefix("u:"), let userID = Int(head.dropFirst(2)) {
            id = userID
            name = resolvedName
            tandemStudentID = nil
        } else {
            id = Int(head) ?? 0
            name = resolvedName
            tandemStudentID = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, tandemStudentID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        tandemStudentID = try c.decodeIfPresent(Int.self, forKey: .tandemStudentID)
    }
}
