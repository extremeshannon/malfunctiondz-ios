// File: ASC/ViewModels/PaxViewModel.swift
import Foundation
import MalfunctionDZCore

// MARK: - Response wrappers (top-level, not nested in generic functions)
private struct PaxOkWrapper: Decodable { let ok: Bool; let error: String? }

private struct PaxStateWrapper: Decodable {
    let ok: Bool; let error: String?
    let data: PaxStateResponse?
}
private struct PaxFlightWrapper: Decodable {
    let ok: Bool; let error: String?
    struct Inner: Decodable { let flight: Flight?; let loads: [FlightLoad] }
    let data: Inner?
}
private struct PaxLoadsWrapper: Decodable {
    let ok: Bool; let error: String?
    struct Inner: Decodable { let loads: [FlightLoad] }
    let data: Inner?
}

private struct PilotsListResponse: Decodable {
    let ok: Bool
    let pilots: [PaxPilot]?
}

// MARK: - Phase
enum PaxPhase {
    case loading
    case noFlight
    case openFlight
    case closedFlight
    case error(String)
}

// MARK: - ViewModel
@MainActor
class PaxViewModel: ObservableObject {

    @Published var phase: PaxPhase = .loading
    @Published var flight: Flight?
    @Published var loads: [FlightLoad] = []
    @Published var availableAircraft: [PaxAircraft] = []
    @Published var isSaving = false
    @Published var errorMessage: String?
    /// Dropzone check-in for the selected flight date (required before PAX actions).
    @Published var isCheckedInForFlightDate: Bool = true

    // Log flight form (meter **end** readings — server computes time vs aircraft current Hobbs/Tach)
    @Published var selectedAircraftId: Int = 0
    @Published var flightDate: String = PaxViewModel.todayString()
    @Published var logHobbsEnd: String = ""
    @Published var logTachEnd: String = ""

    // Add load form
    @Published var loadPax: String = ""
    @Published var loadAltitude: String = ""
    @Published var loadHobbs: String = ""
    @Published var loadTach: String = ""
    @Published var loadFuel: String = ""
    @Published var loadOil: String = ""
    @Published var loadNotes: String = ""

    /// Same optional fields as web Flight log row.
    @Published var pilots: [PaxPilot] = []
    @Published var selectedPilotUserId: Int = 0
    @Published var altitudeFtAgl: String = "10000"
    @Published var fuelSession: String = ""
    @Published var oilSession: String = ""
    @Published var paxSession: String = "0"
    @Published var sessionNotes: String = ""

    // Close flight form
    @Published var hobbsEnd: String = ""
    @Published var tachEnd: String = ""

    // Always read live from AuthManager — never stale
    private var currentPilotId: Int {
        AuthManager.shared.currentUser?.id ?? 0
    }

    // MARK: - Load State
    func loadState() async {
        phase = .loading
        errorMessage = nil

        guard let token = KeychainHelper.readToken() else {
            phase = .error("Not logged in"); return
        }

        // Load aircraft list independently first
        await loadAircraftList(token: token)
        await refreshCheckInStatus()
        await loadPilotsForStart(token: token)

        // Ensure we have a user ID — refresh if needed
        var pid = currentPilotId
        if pid <= 0 {
            await AuthManager.shared.refreshCurrentUser()
            pid = currentPilotId
        }
        guard pid > 0 else { phase = .noFlight; return }
        if selectedPilotUserId <= 0 {
            selectedPilotUserId = pid
        }

        // Load flight state
        guard let url = URL(string: "\(kServerURL)/api/aircraft/flights.php?pilot_user_id=\(pid)") else {
            phase = .noFlight; return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let wrapper = try JSONDecoder().decode(PaxStateWrapper.self, from: data)
            guard wrapper.ok, let state = wrapper.data else {
                phase = .noFlight; return
            }
            if !state.aircraft.isEmpty {
                // Merge hobbs/tach into availableAircraft
                availableAircraft = state.aircraft
            }
            if let f = state.flight {
                flight = f
                loads  = state.loads
                phase  = f.isOpen ? .openFlight : .closedFlight
            } else {
                phase = .noFlight
            }
        } catch {
            phase = .noFlight
        }
    }

    func refreshCheckInStatus() async {
        let d = flightDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !d.isEmpty else { isCheckedInForFlightDate = false; return }
        isCheckedInForFlightDate = await CheckinAPI.isCheckedIn(dateStr: d)
    }

    private func loadPilotsForStart(token: String) async {
        guard let url = URL(string: "\(kServerURL)/api/aircraft/pilots.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(PilotsListResponse.self, from: data),
              resp.ok, let list = resp.pilots else { return }
        pilots = list
        let pid = currentPilotId
        if selectedPilotUserId <= 0 || !pilots.contains(where: { $0.userId == selectedPilotUserId }) {
            selectedPilotUserId = pid
        }
    }

    // MARK: - Aircraft list (independent of pilot)
    private func loadAircraftList(token: String) async {
        guard let url = URL(string: "\(kServerURL)/api/aircraft/list.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }

        struct AcItem: Decodable {
            let id: Int
            let tailNumber: String
            let model: String?
            let currentHobbs: Double?
            let currentTach: Double?
            enum CodingKeys: String, CodingKey {
                case id, model
                case tailNumber = "tail_number"
                case currentHobbs = "current_hobbs"
                case currentTach = "current_tach"
            }
        }
        struct AcResp: Decodable { let ok: Bool; let aircraft: [AcItem]? }

        guard let resp = try? JSONDecoder().decode(AcResp.self, from: data),
              resp.ok, let list = resp.aircraft else { return }

        availableAircraft = list.map {
            PaxAircraft(id: $0.id, tailNumber: $0.tailNumber,
                        make: nil, model: $0.model,
                        currentHobbs: $0.currentHobbs, currentTach: $0.currentTach)
        }
    }

    // MARK: - Log flight (meter end — same logic as web Flight log)

    var baselineAircraftHobbs: Double? {
        availableAircraft.first(where: { $0.id == selectedAircraftId })?.currentHobbs?.value
    }

    var baselineAircraftTach: Double? {
        availableAircraft.first(where: { $0.id == selectedAircraftId })?.currentTach?.value
    }

    /// Preview only — mirrors server `create_flight_log_meter_end` (one meter may be inferred from the other).
    func meterPreviewDeltas() -> (hobbsHrs: Double?, tachHrs: Double?) {
        guard let bh = baselineAircraftHobbs, let bt = baselineAircraftTach else { return (nil, nil) }
        let he = parsedMeterEnd(logHobbsEnd)
        let te = parsedMeterEnd(logTachEnd)
        if let he, let te {
            let dh = he - bh
            let dt = te - bt
            return (dh >= 0 ? dh : nil, dt >= 0 ? dt : nil)
        }
        if let he {
            let dh = he - bh
            guard dh >= 0 else { return (nil, nil) }
            return (dh, dh)
        }
        if let te {
            let dt = te - bt
            guard dt >= 0 else { return (nil, nil) }
            return (dt, dt)
        }
        return (nil, nil)
    }

    private func parsedMeterEnd(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        guard !s.isEmpty, let v = Double(s) else { return nil }
        return v
    }

    func logFlight() async {
        guard selectedAircraftId > 0 else { errorMessage = "Select an aircraft"; return }
        let hobbsTrim = logHobbsEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        let tachTrim = logTachEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hobbsTrim.isEmpty || !tachTrim.isEmpty else {
            errorMessage = "Enter Hobbs and/or Tach meter end (total hours)"
            return
        }

        let selfId = currentPilotId
        guard selfId > 0 else { errorMessage = "User session expired — please log out and back in"; return }
        let pilotForFlight = selectedPilotUserId > 0 ? selectedPilotUserId : selfId

        isSaving = true; defer { isSaving = false }
        errorMessage = nil

        var params: [String: Any] = [
            "aircraft_id": selectedAircraftId,
            "pilot_user_id": pilotForFlight,
            "flight_date": flightDate,
            "altitude_ft_agl": altitudeFtAgl.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        if !hobbsTrim.isEmpty { params["hobbs_end"] = hobbsTrim }
        if !tachTrim.isEmpty { params["tach_end"] = tachTrim }
        if !fuelSession.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            params["fuel_pumped"] = fuelSession.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !oilSession.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            params["oil_used"] = oilSession.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !paxSession.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            params["pax_count"] = paxSession.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            params["notes"] = sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        do {
            let data = try await postJSON(path: "/api/aircraft/flight_log.php", body: params)
            let resp = try JSONDecoder().decode(PaxOkWrapper.self, from: data)
            guard resp.ok else {
                errorMessage = resp.error ?? "Could not log flight"
                await refreshCheckInStatus()
                return
            }
            logHobbsEnd = ""
            logTachEnd = ""
            await loadState()
            await refreshCheckInStatus()
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Add Load
    func addLoad() async {
        guard let f = flight else { return }
        let pax = Int(loadPax) ?? 0
        guard pax >= 1          else { errorMessage = "Pax count required (min 1)"; return }
        guard !loadHobbs.isEmpty else { errorMessage = "Hobbs time required"; return }
        guard !loadTach.isEmpty  else { errorMessage = "Tach time required"; return }

        isSaving = true; defer { isSaving = false }
        errorMessage = nil

        var params: [String: Any] = [
            "flight_id":  f.id,
            "pax_count":  pax,
            "hobbs_time": loadHobbs,
            "tach_time":  loadTach,
        ]
        if !loadAltitude.isEmpty { params["altitude"]   = loadAltitude }
        if !loadFuel.isEmpty     { params["fuel_added"] = loadFuel }
        if !loadOil.isEmpty      { params["oil_added"]  = loadOil }
        if !loadNotes.isEmpty    { params["notes"]      = loadNotes }

        do {
            let data = try await postJSON(path: "/api/aircraft/load_add.php", body: params)
            let resp = try JSONDecoder().decode(PaxLoadsWrapper.self, from: data)
            guard resp.ok, let inner = resp.data else {
                errorMessage = resp.error ?? "Failed to add load"
                await refreshCheckInStatus()
                return
            }
            loads = inner.loads
            clearLoadForm()
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Delete Load
    func deleteLoad(_ load: FlightLoad) async {
        guard let f = flight else { return }
        isSaving = true; defer { isSaving = false }
        let params: [String: Any] = ["load_id": load.id, "flight_id": f.id]
        do {
            let data = try await postJSON(path: "/api/aircraft/load_delete.php", body: params)
            let resp = try JSONDecoder().decode(PaxLoadsWrapper.self, from: data)
            if resp.ok, let inner = resp.data { loads = inner.loads }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Close Flight
    func closeFlight() async {
        guard let f = flight   else { return }
        guard !hobbsEnd.isEmpty else { errorMessage = "Hobbs end required"; return }
        guard !tachEnd.isEmpty  else { errorMessage = "Tach end required"; return }

        isSaving = true; defer { isSaving = false }
        errorMessage = nil

        let params: [String: Any] = [
            "flight_id": f.id,
            "hobbs_end": hobbsEnd,
            "tach_end":  tachEnd,
        ]
        do {
            let data = try await postJSON(path: "/api/aircraft/flight_close.php", body: params)
            let resp = try JSONDecoder().decode(PaxFlightWrapper.self, from: data)
            guard resp.ok, let inner = resp.data else {
                errorMessage = resp.error ?? "Failed to close flight"
                await refreshCheckInStatus()
                return
            }
            flight = inner.flight
            loads  = inner.loads
            phase  = .closedFlight
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Computed
    var totalPax: Int { loads.reduce(0) { $0 + $1.paxCount } }

    var hobbsElapsed: String? {
        guard let start = flight?.hobbsStart?.value,
              let end = Double(hobbsEnd), end >= start else { return nil }
        return String(format: "%.1f hrs", end - start)
    }

    var tachElapsed: String? {
        guard let start = flight?.tachStart?.value,
              let end = Double(tachEnd), end >= start else { return nil }
        return String(format: "%.1f hrs", end - start)
    }

    func autoFillFromAircraft(_ ac: PaxAircraft) {
        selectedAircraftId = ac.id
        logHobbsEnd = ""
        logTachEnd = ""
    }

    // MARK: - Helpers
    private func clearLoadForm() {
        loadPax = ""; loadAltitude = ""; loadHobbs = ""
        loadTach = ""; loadFuel = ""; loadOil = ""; loadNotes = ""
    }

    private func postJSON(path: String, body: [String: Any]) async throws -> Data {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)\(path)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private static func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
