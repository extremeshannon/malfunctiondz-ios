// File: ASC/ViewModels/HomeViewModel.swift
import Foundation
import SwiftUI

// MARK: - Shared Dashboard Models
struct DashBadge: Identifiable {
    let id    = UUID()
    let label: String
    let color: Color
}

struct DashAlert: Identifiable {
    let id       = UUID()
    let message:  String
    let category: String
    let color:    Color
}

// MARK: - METAR Model
struct MetarData {
    var rawText:        String  = ""
    var tempC:          Double? = nil
    var dewpC:          Double? = nil
    var windDir:        Int?    = nil
    var windSpeedKts:   Int?    = nil
    var windGustKts:    Int?    = nil
    var visibilitySM:   Double? = nil
    var altimInHg:      Double? = nil
    var flightCategory: String  = "UNKN"
    var clouds:         [CloudLayer] = []
    var observedTime:   String  = ""

    struct CloudLayer {
        let cover: String
        let base:  Int?
    }

    var flightCategoryColor: Color {
        switch flightCategory {
        case "VFR":  return .mdzGreen
        case "MVFR": return Color(hex: "0080FF")
        case "IFR":  return .mdzDanger
        case "LIFR": return Color(hex: "FF00FF")
        default:     return .mdzMuted
        }
    }

    var tempF: Double? {
        guard let c = tempC else { return nil }
        return c * 9/5 + 32
    }

    var windSummary: String {
        guard let spd = windSpeedKts, spd > 0 else { return "Calm" }
        let dir = windDir.map { "\($0)°" } ?? "VRB"
        if let gust = windGustKts { return "\(dir) \(spd)G\(gust)kt" }
        return "\(dir) \(spd)kt"
    }

    var skyCondition: String {
        guard let top = clouds.first else { return "Clear" }
        let alt = top.base.map { "\($0 * 100)ft" } ?? ""
        switch top.cover {
        case "SKC", "CLR", "CAVOK", "NSC": return "Clear"
        case "FEW": return "Few \(alt)"
        case "SCT": return "Scattered \(alt)"
        case "BKN": return "Broken \(alt)"
        case "OVC": return "Overcast \(alt)"
        default:    return top.cover
        }
    }
}

// MARK: - Role-specific data structs
struct PilotDashData {
    var flightCount:    Int    = 0
    var totalLoads:     Int    = 0
    var totalPax:       Int    = 0
    var hobbsDelta:     Double = 0
    var hasOpenFlight:  Bool   = false
    var openTailNumber: String? = nil
    var openFlightId:   Int?    = nil
}

struct StudentDashData {
    var courseTitle:      String  = ""
    var completedLessons: Int     = 0
    var totalLessons:     Int     = 0
    var progressPct:      Double  = 0
    var nextModuleTitle:  String? = nil
    var currentLevel:     Int     = 0
}

struct InstructorDashData {
    var pendingSignoffs: Int = 0
    var activeStudents:  Int = 0
}

struct AircraftBrief: Identifiable {
    let id:         Int
    let tailNumber: String
    let model:      String
    let status:     String
    var statusColor: Color {
        switch status.lowercased() {
        case "airworthy": return .mdzGreen
        case "grounded":  return .mdzDanger
        default:          return .mdzAmber
        }
    }
}

// MARK: - Private API response types
private struct AircraftSummaryResponse: Decodable {
    let ok: Bool; let summary: Summary?
    struct Summary: Decodable {
        let aircraft:    AircraftStats
        let maintenance: MaintenanceStats
        let pilots:      PilotStats
        struct AircraftStats:    Decodable { let total, airworthy, grounded: Int }
        struct MaintenanceStats: Decodable { let due_soon, overdue: Int }
        struct PilotStats:       Decodable { let total, current: Int }
    }
}

private struct ProxyMetarResponse: Decodable {
    let ok:    Bool
    let metar: RawMetar?
    struct RawMetar: Decodable {
        let temp:           Double?
        let dewp:           Double?
        let wdir:           Int?
        let wspd:           Int?
        let wgst:           Int?
        let visib:          String?
        let altim:          Double?
        let rawOb:          String?
        let reportTime:     String?
        let clouds:         [CloudEntry]?
        let flightCategory: String?
        struct CloudEntry: Decodable { let cover: String?; let base: Int? }
    }
}

// MARK: - ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    @Published var isLoading = false

    // Tile data
    @Published var aviationSummary      = "Loading…"
    @Published var aviationBadges:      [DashBadge] = []
    @Published var loftSummary          = "Loft Operations"
    @Published var loftBadges:          [DashBadge] = []
    @Published var groundSchoolSummary  = "Coming soon"
    @Published var groundSchoolBadges:  [DashBadge] = []
    @Published var manifestSummary      = "Coming soon"
    @Published var manifestBadges:      [DashBadge] = []
    @Published var alerts:              [DashAlert] = []

    // Role-specific
    @Published var pilotData:         PilotDashData?
    @Published var studentData:       StudentDashData?
    @Published var instructorData:    InstructorDashData?
    @Published var airworthyAircraft: [AircraftBrief] = []

    /// My rigs (reserve/AAD expiry for dashboard)
    @Published var myRigs: [JumperRig] = []

    /// Logbook config (Start Freefall Time, Home Dropzone) for dashboard
    @Published var startFreefallTime: String = ""
    @Published var homeDropzone: String = ""
    @Published var logbookSettingsLoading = false
    @Published var logbookSettingsSaving = false

    // Weather
    @Published var metar:        MetarData? = nil
    @Published var metarLoading: Bool       = false

    // MARK: - Load dashboard
    func loadDashboard(user: User?) async {
        isLoading = true; defer { isLoading = false }
        alerts    = []
        guard let user else { return }

        let all          = ((user.roles ?? []) + [user.role ?? ""]).map { $0.lowercased() }
        let isAdmin      = all.contains(where: { ["admin","master","godmode","ops"].contains($0) })
        let isPilot      = all.contains("pilot")
        let isInstructor = all.contains(where: { ["instructor","lms_instructor"].contains($0) })
        let isStudent    = all.contains(where: { ["student","lms_student"].contains($0) })
        let isManifest   = all.contains("manifest")
        let isChiefPilot = all.contains(where: { ["chief_pilot", "chief pilot"].contains($0) })

        // Weather for skydivers, students, Ops, manifest, chief pilot, instructors
        if isAdmin || isPilot || isInstructor || isStudent || isManifest || isChiefPilot { await loadMetar() }

        if isAdmin {
            await withTaskGroup(of: Void.self) {
                $0.addTask { await self.loadAviationSummary() }
                $0.addTask { await self.loadLoftSummary() }
            }
        } else if isPilot {
            await withTaskGroup(of: Void.self) {
                $0.addTask { await self.loadPilotDashboard(userId: user.id) }
                $0.addTask { await self.loadAirworthyAircraft() }
            }
        } else if isInstructor {
            await withTaskGroup(of: Void.self) {
                $0.addTask { await self.loadInstructorDashboard() }
                $0.addTask { await self.loadLoftSummary() }
            }
        } else if isStudent {
            await loadStudentDashboard(userId: user.id)
        }

        // Load my rigs for skydivers and loft customers (anyone who can have rigs)
        await loadMyRigs()

        // Load logbook config (Start Freefall, Home DZ) for skydivers / loft customers
        let hasLogbook = user.canAccessLogbook
        let hasGroundSchool = user.canAccessGroundSchool
        if hasLogbook || hasGroundSchool { await loadLogbookSettings() }
    }

    private func loadLogbookSettings() async {
        logbookSettingsLoading = true
        defer { logbookSettingsLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["ok"] as? Bool) == true else { return }
        startFreefallTime = (json["start_freefall_time"] as? String) ?? ""
        homeDropzone = (json["home_dropzone"] as? String) ?? ""
    }

    func setStartFreefallTime(_ value: String) async {
        logbookSettingsSaving = true
        defer { logbookSettingsSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "start_freefall_time": value.isEmpty ? NSNull() : value,
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["ok"] as? Bool) == true else { return }
        startFreefallTime = value
    }

    func setHomeDropzone(_ value: String) async {
        logbookSettingsSaving = true
        defer { logbookSettingsSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "home_dropzone": value.isEmpty ? NSNull() : value,
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["ok"] as? Bool) == true else { return }
        homeDropzone = value
    }

    private func loadMyRigs() async {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/rigs.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(RigsResponse.self, from: data),
              resp.ok else { myRigs = []; return }
        myRigs = resp.rigs ?? []
    }

    // MARK: - METAR via server proxy
    func loadMetar() async {
        metarLoading = true; defer { metarLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url   = URL(string: "\(kServerURL)/api/weather/metar.php?icao=PAAQ") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(ProxyMetarResponse.self, from: data),
              resp.ok, let m = resp.metar else { return }

        var result = MetarData()
        result.rawText        = m.rawOb ?? ""
        result.tempC          = m.temp
        result.dewpC          = m.dewp
        result.windDir        = m.wdir
        result.windSpeedKts   = m.wspd
        result.windGustKts    = m.wgst
        result.altimInHg      = m.altim
        result.flightCategory = m.flightCategory ?? "UNKN"
        result.observedTime   = m.reportTime ?? ""
        result.clouds = (m.clouds ?? []).compactMap {
            guard let cover = $0.cover else { return nil }
            return MetarData.CloudLayer(cover: cover, base: $0.base)
        }
        if let vis = m.visib, let d = Double(vis) { result.visibilitySM = d }
        metar = result
    }

    // MARK: - Airworthy aircraft
    private func loadAirworthyAircraft() async {
        guard let token = KeychainHelper.readToken(),
              let url   = URL(string: "\(kServerURL)/api/aircraft/list.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(MobileResponse<[Aircraft]>.self, from: data),
              resp.ok, let all = resp.data else { return }
        airworthyAircraft = all
            .filter { $0.status.lowercased() == "airworthy" }
            .map    { AircraftBrief(id: $0.id, tailNumber: $0.tailNumber, model: $0.model, status: $0.status) }
    }

    // MARK: - Admin: Aviation summary
    func loadAviationSummary() async {
        guard let token = KeychainHelper.readToken(),
              let url   = URL(string: "\(kServerURL)/api/aircraft/summary.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(AircraftSummaryResponse.self, from: data),
              resp.ok, let s = resp.summary else { aviationSummary = "Unavailable"; return }

        aviationSummary = "\(s.aircraft.total) Aircraft · \(s.pilots.current) Pilots Current"
        var b: [DashBadge] = []
        if s.aircraft.airworthy > 0 { b.append(.init(label: "\(s.aircraft.airworthy) Active",   color: .mdzGreen))  }
        if s.aircraft.grounded  > 0 { b.append(.init(label: "\(s.aircraft.grounded) Grounded", color: .mdzDanger)) }
        aviationBadges = b
        if s.maintenance.overdue  > 0 { alerts.append(.init(message: "\(s.maintenance.overdue) maintenance item\(s.maintenance.overdue == 1 ? "" : "s") overdue",   category: "Aviation", color: .mdzDanger)) }
        if s.maintenance.due_soon > 0 { alerts.append(.init(message: "\(s.maintenance.due_soon) maintenance item\(s.maintenance.due_soon == 1 ? "" : "s") due soon", category: "Aviation", color: .mdzAmber)) }
        let lapsed = s.pilots.total - s.pilots.current
        if lapsed > 0 { alerts.append(.init(message: "\(lapsed) pilot\(lapsed == 1 ? "" : "s") with lapsed currency", category: "Pilots", color: .mdzAmber)) }
    }

    // MARK: - Admin/Instructor: Loft
    func loadLoftSummary() async {
        guard let token = KeychainHelper.readToken(),
              let url   = URL(string: "\(kServerURL)/api/loft/list.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(LoftListResponse.self, from: data),
              resp.ok, let s = resp.summary else { loftSummary = "Loft Operations"; return }

        loftSummary = "\(s.total) Rigs"
        var b: [DashBadge] = []
        if s.overdue > 0 { b.append(.init(label: "\(s.overdue) Overdue", color: .mdzDanger)) }
        if s.dueSoon > 0 { b.append(.init(label: "\(s.dueSoon) Due Soon", color: .mdzAmber)) }
        if s.current > 0 { b.append(.init(label: "\(s.current) Current",  color: .mdzGreen)) }
        loftBadges = b
        if s.overdue > 0 { alerts.append(.init(message: "\(s.overdue) reserve\(s.overdue == 1 ? "" : "s") overdue for repack", category: "Loft", color: .mdzDanger)) }
    }

    // MARK: - Pilot dashboard
    private func loadPilotDashboard(userId: Int) async {
        guard let token = KeychainHelper.readToken() else { return }

        if let url = URL(string: "\(kServerURL)/api/flights/today.php?pilot_user_id=\(userId)") {
            var req = URLRequest(url: url); req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            struct TodayResp: Decodable {
                let ok: Bool; let data: TD?
                struct TD: Decodable { let flight_count, total_loads, total_pax: Int; let hobbs_delta: StringDouble }
            }
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let resp = try? JSONDecoder().decode(TodayResp.self, from: data), resp.ok, let d = resp.data {
                pilotData = PilotDashData(flightCount: d.flight_count, totalLoads: d.total_loads,
                                          totalPax: d.total_pax, hobbsDelta: d.hobbs_delta.value ?? 0)
            }
        }

        if let url = URL(string: "\(kServerURL)/api/flights/my_flights.php?pilot_user_id=\(userId)&limit=5") {
            var req = URLRequest(url: url); req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let resp = try? JSONDecoder().decode(MobileResponse<[PilotFlight]>.self, from: data),
               resp.ok, let flights = resp.data,
               let open = flights.first(where: { $0.status == "open" }) {
                pilotData?.hasOpenFlight  = true
                pilotData?.openTailNumber = open.tailNumber
                pilotData?.openFlightId   = open.id
            }
        }

        if let p = pilotData, p.flightCount > 0 {
            aviationSummary = "\(p.flightCount) flight\(p.flightCount == 1 ? "" : "s") · \(p.totalPax) pax today"
            aviationBadges  = [.init(label: "Hobbs Δ \(String(format: "%.1f", p.hobbsDelta))", color: .mdzBlue)]
        } else {
            aviationSummary = "No flights today"
            aviationBadges  = []
        }
        groundSchoolSummary = "Jump Pilot Training"
        groundSchoolBadges  = []
    }

    // MARK: - Student dashboard
    private func loadStudentDashboard(userId: Int) async {
        guard let token = KeychainHelper.readToken(),
              let url   = URL(string: "\(kServerURL)/api/lms/my_courses.php") else { return }
        var req = URLRequest(url: url); req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(LMSCoursesResponse.self, from: data),
              resp.ok, let course = resp.courses.first else { return }

        studentData = StudentDashData(
            courseTitle:      course.title,
            completedLessons: course.completedLessons,
            totalLessons:     course.totalLessons,
            progressPct:      course.progressPct,
            nextModuleTitle:  course.modules.first(where: { !$0.isComplete && !$0.isLocked })?.title,
            currentLevel:     course.modules.filter { $0.isComplete }.count
        )
        groundSchoolSummary = course.title
        let pct = Int(course.progressPct)
        groundSchoolBadges = [
            .init(label: "Level \(studentData!.currentLevel)", color: .mdzBlue),
            .init(label: "\(pct)%", color: pct == 100 ? .mdzGreen : .mdzAmber)
        ]
        if let next = studentData?.nextModuleTitle {
            alerts.append(.init(message: "Up next: \(next)", category: "Ground School", color: .mdzAmber))
        }
    }

    // MARK: - Instructor dashboard
    private func loadInstructorDashboard() async {
        guard let token = KeychainHelper.readToken(),
              let url   = URL(string: "\(kServerURL)/api/lms/pending_signoffs.php") else { return }
        var req = URLRequest(url: url); req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        struct PR: Decodable { let ok: Bool; let data: PD?; struct PD: Decodable { let pending_count, student_count: Int } }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(PR.self, from: data), resp.ok, let d = resp.data else {
            groundSchoolSummary = "Instructor View"; return
        }
        instructorData      = InstructorDashData(pendingSignoffs: d.pending_count, activeStudents: d.student_count)
        groundSchoolSummary = "\(d.student_count) Active Students"
        groundSchoolBadges  = d.pending_count > 0
            ? [.init(label: "\(d.pending_count) Pending Sign-off", color: .mdzAmber)]
            : [.init(label: "All Clear", color: .mdzGreen)]
        if d.pending_count > 0 {
            alerts.append(.init(message: "\(d.pending_count) student\(d.pending_count == 1 ? "" : "s") awaiting sign-off", category: "Ground School", color: .mdzAmber))
        }
    }
}
