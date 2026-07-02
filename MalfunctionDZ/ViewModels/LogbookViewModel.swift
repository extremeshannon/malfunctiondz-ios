// File: ASC/ViewModels/LogbookViewModel.swift
// Purpose: Load skydiver logbook entries — for a course (LMS) or all entries (standalone).
import Foundation
import MalfunctionDZCore

@MainActor
class LogbookViewModel: ObservableObject {
    @Published var entries: [SkydiverLogbookEntry] = []
    @Published var rigs: [JumperRig] = []
    @Published var rigCatalog: RigCatalogResponse?
    @Published var rigCatalogLoading = false
    @Published var rigCatalogError: String?
    @Published var otherTrainingNotes: String = ""
    @Published var priorJumpCount: Int = 0
    /// Pre-platform freefall total (seconds), from server settings.
    @Published var priorFreefallSeconds: Int = 0
    /// Cumulative freefall (prior + all logged jumps), seconds.
    @Published var totalFreefallSeconds: Int = 0
    @Published var startFreefallTime: String = ""
    /// Canonical jump type prefilled for new jumps (e.g. rw, freefly).
    @Published var defaultJumpType: String = ""
    @Published var homeDropzone: String = ""
    @Published var defaultAircraft: String = ""
    @Published var dropzoneOptions: [String] = LogbookPickerDefaults.dropzones
    @Published var aircraftOptions: [String] = LogbookPickerDefaults.aircraft
    @Published var lastDropzoneName: String = ""
    @Published var lastAircraftLabel: String = ""
    @Published var totalJumps: Int = 0
    @Published var isStudent: Bool = false
    @Published var isSkydiver: Bool = false
    @Published var nextJumpNumber: Int = 1
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var savedSignatureUrl = ""
    @Published var canCounterSignEntries = false

    private var currentCourseId: Int?

    private static let logbookLoadPaths = [
        "/api/lms/logbook",
        "/api/lms/logbook.php",
    ]

    private static let logbookAddPaths = [
        "/api/lms/logbook_add",
        "/api/lms/logbook_add.php",
    ]

    private static let logbookSettingsPaths = [
        "/api/lms/logbook_settings",
        "/api/lms/logbook_settings.php",
    ]

    /// Load logbook. Pass courseId to filter by course (LMS flow); pass nil for all entries (standalone, skydivers without LMS).
    func load(courseId: Int? = nil, userId: Int? = nil) async {
        isLoading = true
        error = nil
        currentCourseId = courseId
        defer { isLoading = false }

        guard let token = KeychainHelper.readToken() else { return }
        await loadSavedSignature(token: token)

        var queryItems: [URLQueryItem] = []
        if let cid = courseId, cid > 0 {
            queryItems.append(URLQueryItem(name: "course_id", value: "\(cid)"))
        }
        if let uid = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: "\(uid)"))
        }

        var lastStatus = 0
        for path in Self.logbookLoadPaths {
            var components = URLComponents(string: "\(kServerURL)\(path)")
            if !queryItems.isEmpty { components?.queryItems = queryItems }
            guard let url = components?.url else { continue }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                lastStatus = statusCode
                if statusCode == 404 { continue }
                if statusCode == 401 {
                    AuthManager.shared.logout()
                    error = "Session expired"
                    return
                }
                if statusCode == 403 {
                    error = "You don't have permission to view this logbook"
                    return
                }
                let decoded = try? JSONDecoder().decode(SkydiverLogbookResponse.self, from: data)
                if let resp = decoded, resp.ok {
                    applyLogbookResponse(resp)
                    return
                }
                entries = []
                resetLogbookFields()
            } catch {
                self.error = error.localizedDescription
                return
            }
        }

        entries = []
        resetLogbookFields()
        if lastStatus == 404 {
            error = "Logbook API not found — the server needs a platform update. Try again after deploy."
        }
    }

    private func applyLogbookResponse(_ resp: SkydiverLogbookResponse) {
        entries = resp.entries ?? []
        otherTrainingNotes = resp.otherTrainingNotes ?? ""
        priorJumpCount = resp.priorJumpCount ?? 0
        priorFreefallSeconds = resp.priorFreefallSeconds ?? 0
        totalFreefallSeconds = resp.totalFreefallSeconds ?? 0
        startFreefallTime = resp.startFreefallTime ?? ""
        defaultJumpType = resp.defaultJumpType ?? ""
        homeDropzone = resp.homeDropzone ?? ""
        defaultAircraft = resp.defaultAircraft ?? ""
        dropzoneOptions = LogbookPickerDefaults.mergedOptions(resp.dropzoneOptions, defaults: LogbookPickerDefaults.dropzones)
        aircraftOptions = LogbookPickerDefaults.mergedOptions(resp.aircraftOptions, defaults: LogbookPickerDefaults.aircraft)
        lastDropzoneName = resp.lastDropzoneName ?? ""
        lastAircraftLabel = resp.lastAircraftLabel ?? ""
        totalJumps = resp.totalJumps ?? priorJumpCount
        isStudent = resp.isStudent ?? false
        isSkydiver = resp.isSkydiver ?? false
        nextJumpNumber = resp.nextJumpNumber ?? (priorJumpCount + 1)
        canCounterSignEntries = (resp.entries ?? []).contains { $0.canWitnessSign == true || $0.canCounterSign == true }
        error = nil
    }

    private func resetLogbookFields() {
        otherTrainingNotes = ""
        priorJumpCount = 0
        priorFreefallSeconds = 0
        totalFreefallSeconds = 0
        startFreefallTime = ""
        defaultJumpType = ""
        homeDropzone = ""
        defaultAircraft = ""
        dropzoneOptions = LogbookPickerDefaults.dropzones
        aircraftOptions = LogbookPickerDefaults.aircraft
        lastDropzoneName = ""
        lastAircraftLabel = ""
        totalJumps = 0
        isStudent = false
        isSkydiver = false
        nextJumpNumber = 1
    }

    /// Saves all logbook settings in one request (recommended for the config screen).
    func saveLogbookSettings(
        priorJumpCount: Int,
        priorFreefallSeconds: Int,
        startFreefallTime: String,
        defaultJumpType: String,
        homeDropzone: String,
        defaultAircraft: String
    ) async -> Bool {
        let pj = max(0, min(priorJumpCount, 50000))
        let pff = max(0, min(priorFreefallSeconds, 1_000_000_000))
        isSaving = true
        error = nil
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken() else { return false }
        let body: [String: Any] = [
            "prior_jump_count": pj,
            "prior_freefall_seconds": pff,
            "start_freefall_time": startFreefallTime.isEmpty ? NSNull() : startFreefallTime,
            "home_dropzone": homeDropzone.isEmpty ? NSNull() : homeDropzone,
            "default_jump_type": defaultJumpType.isEmpty ? NSNull() : defaultJumpType,
            "default_aircraft": defaultAircraft.isEmpty ? NSNull() : defaultAircraft,
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }
        for path in Self.logbookSettingsPaths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = jsonData
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 404 { continue }
                if status != 200 {
                    let msg = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
                    error = String(msg.prefix(200))
                    return false
                }
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if (json?["ok"] as? Bool) == true {
                    self.priorJumpCount = pj
                    self.priorFreefallSeconds = pff
                    self.startFreefallTime = startFreefallTime
                    self.defaultJumpType = defaultJumpType
                    self.homeDropzone = homeDropzone
                    self.defaultAircraft = defaultAircraft
                    await load(courseId: currentCourseId, userId: nil)
                    return true
                }
                error = (json?["error"] as? String) ?? "Failed to save settings"
                return false
            } catch {
                self.error = error.localizedDescription
                return false
            }
        }
        error = "Logbook settings API not found — the server needs a platform update."
        return false
    }

    /// Set prior jump count (jumps before this system). Standalone only.
    func setPriorJumpCount(_ count: Int) async {
        guard count >= 0 else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["prior_jump_count": count])

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                priorJumpCount = count
                totalJumps = max(priorJumpCount, totalJumps)
                nextJumpNumber = totalJumps + 1
            } else {
                error = (json?["error"] as? String) ?? "Failed to save"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Set start freefall time (default when adding a jump).
    func setStartFreefallTime(_ value: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "prior_jump_count": priorJumpCount,
            "start_freefall_time": (value.isEmpty ? NSNull() : value) as Any,
        ])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                startFreefallTime = value
            } else {
                error = json?["error"] as? String ?? "Failed to save"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Set home dropzone (used to prefill DZ in Add Jump).
    func setHomeDropzone(_ value: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "prior_jump_count": priorJumpCount,
            "home_dropzone": (value.isEmpty ? NSNull() : value) as Any,
        ])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                homeDropzone = value
            } else {
                error = json?["error"] as? String ?? "Failed to save"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Total freefall seconds logged before this app (baseline for cumulative totals).
    func setPriorFreefallSeconds(_ seconds: Int) async {
        let s = max(0, min(seconds, 1_000_000_000))
        isSaving = true
        error = nil
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["prior_freefall_seconds": s])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                priorFreefallSeconds = s
                await load(courseId: currentCourseId, userId: nil)
            } else {
                error = json?["error"] as? String ?? "Failed to save"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Default jump type when adding a jump (canonical value, e.g. rw).
    func setDefaultJumpType(_ value: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "default_jump_type": value.isEmpty ? NSNull() : value,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                defaultJumpType = value
            } else {
                error = json?["error"] as? String ?? "Failed to save"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Load rig catalog (AAD/reserve dropdowns) for Add Rig form.
    func loadRigCatalog() async {
        rigCatalogError = nil
        rigCatalogLoading = true
        defer { rigCatalogLoading = false }
        guard let token = KeychainHelper.readToken() else {
            rigCatalogError = "Not signed in"
            rigCatalog = nil
            return
        }
        /// Prefer `/rig_catalog` (no .php): nginx often routes `*.php` to PHP; a missing file 404s before FastAPI.
        let catalogURLStrings = [
            "\(kServerURL)/api/lms/rig_catalog",
            "\(kServerURL)/api/lms/rig_catalog.php",
        ]
        do {
            var lastStatus = 0
            var lastData = Data()
            for urlString in catalogURLStrings {
                guard let url = URL(string: urlString) else { continue }
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: req)
                lastData = data
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                lastStatus = status
                if status == 200 {
                    if let parsed = RigCatalogResponse.parseFromCatalogPayload(data) {
                        rigCatalog = parsed
                    } else {
                        rigCatalogError = "Could not read catalog"
                        rigCatalog = nil
                    }
                    return
                }
                if status != 404 {
                    break
                }
            }
            let status = lastStatus
            var detail = "Catalog request failed (HTTP \(status))"
            if status == 404 {
                detail += ". Deploy FastAPI (GET /api/lms/rig_catalog or /rig_catalog.php) or add legacy api/lms/rig_catalog.php for PHP. If nginx sends *.php to PHP only, use the no-.php path (now tried first)."
            }
            if let obj = try? JSONSerialization.jsonObject(with: lastData) as? [String: Any],
               let err = obj["error"] as? String, !err.isEmpty {
                detail += " \(err)"
            } else if let s = String(data: lastData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !s.isEmpty, s.count < 280, status != 404 {
                detail += " — \(s)"
            }
            if status == 0 {
                detail += " (not an HTTP response — check Profile → API Base URL)"
            }
            rigCatalogError = detail
            rigCatalog = nil
        } catch {
            rigCatalogError = error.localizedDescription
            rigCatalog = nil
        }
    }

    /// Load my rigs for Add Jump selector.
    func loadRigs() async {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/rigs.php") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try? JSONDecoder().decode(RigsResponse.self, from: data)
            if let resp = decoded, resp.ok {
                rigs = resp.rigs ?? []
            } else {
                rigs = []
            }
        } catch {
            rigs = []
        }
    }

    /// Create or update a rig. Pass `rigId` to update an existing one. On success, reloads rigs.
    func createRig(
        rigId: Int? = nil,
        rigLabel: String,
        harnessMfr: String?, harnessModel: String?, harnessSn: String?, harnessDom: String?,
        mainMfr: String?, mainModel: String?, mainSizeSqft: Int?, mainSn: String?, mainDom: String?,
        reserveMfr: String?, reserveModel: String?, reserveSizeSqft: Int?, reserveSn: String?, reserveDom: String?,
        aadMfr: String?, aadModel: String?, aadSn: String?, aadDom: String?,
        notes: String?
    ) async -> Bool {
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/rigs.php") else { return false }

        // Build [String: Any] explicitly — do not use compactMapValues on [String: Any?],
        // or rig_id and other keys can be dropped and every save creates a new rig.
        var body: [String: Any] = ["rig_label": rigLabel]
        if let rid = rigId, rid > 0 {
            body["rig_id"] = rid
        }
        if let v = harnessMfr, !v.isEmpty { body["harness_mfr"] = v }
        if let v = harnessModel, !v.isEmpty { body["harness_model"] = v }
        if let v = harnessSn, !v.isEmpty { body["harness_sn"] = v }
        if let v = harnessDom, !v.isEmpty { body["harness_dom"] = v }
        if let v = mainMfr, !v.isEmpty { body["main_mfr"] = v }
        if let v = mainModel, !v.isEmpty { body["main_model"] = v }
        if let v = mainSizeSqft, v > 0 { body["main_size_sqft"] = v }
        if let v = mainSn, !v.isEmpty { body["main_sn"] = v }
        if let v = mainDom, !v.isEmpty { body["main_dom"] = v }
        if let v = reserveMfr, !v.isEmpty { body["reserve_mfr"] = v }
        if let v = reserveModel, !v.isEmpty { body["reserve_model"] = v }
        if let v = reserveSizeSqft, v > 0 { body["reserve_size_sqft"] = v }
        if let v = reserveSn, !v.isEmpty { body["reserve_sn"] = v }
        if let v = reserveDom, !v.isEmpty { body["reserve_dom"] = v }
        if let v = aadMfr, !v.isEmpty { body["aad_mfr"] = v }
        if let v = aadModel, !v.isEmpty { body["aad_model"] = v }
        if let v = aadSn, !v.isEmpty { body["aad_sn"] = v }
        if let v = aadDom, !v.isEmpty { body["aad_dom"] = v }
        if let v = notes, !v.isEmpty { body["notes"] = v }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 200 {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
                error = String(msg.prefix(200))
                return false
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                await loadRigs()
                return true
            } else {
                error = json?["error"] as? String ?? "Failed to create rig"
                return false
            }
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Soft-delete a jumper-owned rig. Uses `rigs.php` with query + JSON so it works on PHP (MAMP)
    /// and FastAPI without a separate `rig_delete.php` route (404 if that file/route is missing).
    func deleteRig(rigId: Int) async -> Bool {
        guard rigId > 0 else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken() else { return false }
        var components = URLComponents(string: "\(kServerURL)/api/lms/rigs.php")
        components?.queryItems = [
            URLQueryItem(name: "delete", value: "1"),
            URLQueryItem(name: "rig_id", value: "\(rigId)"),
        ]
        guard let url = components?.url else { return false }
        let body: [String: Any] = ["delete": true, "rig_id": rigId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 200 {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
                error = String(msg.prefix(200))
                return false
            }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                await loadRigs()
                return true
            }
            error = json?["error"] as? String ?? "Failed to delete rig"
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func rememberPickerOption(dropzone: String? = nil, aircraft: String? = nil) {
        if let dz = dropzone?.trimmingCharacters(in: .whitespacesAndNewlines), !dz.isEmpty {
            if !dropzoneOptions.contains(where: { $0.caseInsensitiveCompare(dz) == .orderedSame }) {
                dropzoneOptions.append(dz)
            }
            lastDropzoneName = dz
        }
        if let ac = aircraft?.trimmingCharacters(in: .whitespacesAndNewlines), !ac.isEmpty {
            if !aircraftOptions.contains(where: { $0.caseInsensitiveCompare(ac) == .orderedSame }) {
                aircraftOptions.append(ac)
            }
            lastAircraftLabel = ac
        }
    }

    /// Add a jump entry. Skydivers only (total >= 25).
    /// Backend computes total_time (cumulative freefall) from prior entries + this jump's delay.
    func addEntry(dz: String?, altitude: String?, delay: String?, date: String?, aircraft: String?,
                  equipment: String?, rigId: Int?, jumpType: String?, comments: String?) async -> Bool {
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken() else {
            error = "Not signed in"
            return false
        }

        let body: [String: Any?] = [
            "dz": dz?.isEmpty == true ? nil : dz,
            "altitude": altitude?.isEmpty == true ? nil : altitude,
            "delay": delay?.isEmpty == true ? nil : delay,
            "date": date?.isEmpty == true ? nil : date,
            "aircraft": aircraft?.isEmpty == true ? nil : aircraft,
            "equipment": equipment?.isEmpty == true ? nil : equipment,
            "rig_id": (rigId != nil && rigId! > 0) ? rigId : nil,
            "jump_type": jumpType?.isEmpty == true ? nil : jumpType,
            "comments": comments?.isEmpty == true ? nil : comments,
        ]
        let clean = body.compactMapValues { $0 }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: clean) else {
            error = "Could not encode jump"
            return false
        }

        for path in Self.logbookAddPaths {
            guard let url = URL(string: "\(kServerURL)\(path)") else { continue }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = jsonData

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if statusCode == 404 { continue }
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if statusCode == 403 {
                    error = json?["error"] as? String ?? "You need 25 jumps to add entries."
                    return false
                }
                if (json?["ok"] as? Bool) == true {
                    rememberPickerOption(dropzone: dz, aircraft: aircraft)
                    await load(courseId: currentCourseId, userId: nil)
                    return true
                }
                error = json?["error"] as? String ?? "Failed to add entry"
                return false
            } catch {
                self.error = error.localizedDescription
                return false
            }
        }

        error = "Logbook add API not found — the server needs a platform update."
        return false
    }

    /// Sign and lock a logbook entry. Pass signature as base64 PNG, or use saved profile signature.
    func signEntry(entryId: Int, signatureBase64: String? = nil, useSavedSignature: Bool = false) async -> Bool {
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_sign.php") else { return false }

        var payload: [String: Any] = ["entry_id": entryId]
        if useSavedSignature {
            payload["use_saved_signature"] = true
        } else if let b64 = signatureBase64, !b64.isEmpty {
            payload["signature"] = b64
        } else {
            error = "Signature required"
            return false
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                await load(courseId: currentCourseId, userId: nil)
                return true
            } else {
                error = json?["error"] as? String ?? "Failed to sign"
                return false
            }
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Counter-sign someone else's entry (saved profile signature).
    func witnessSignEntry(entryId: Int, useSavedSignature: Bool = true) async -> Bool {
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_witness_sign.php") else { return false }

        let payload: [String: Any] = [
            "entry_id": entryId,
            "use_saved_signature": useSavedSignature,
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if (json?["ok"] as? Bool) == true {
                await load(courseId: currentCourseId, userId: nil)
                return true
            }
            error = json?["error"] as? String ?? "Could not witness-sign entry"
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    struct SigningChallengeResult {
        let entryId: Int
        let nonce: String
        let qrPayload: String
        let summary: String
    }

    /// Create a short-lived nonce for QR or Multipeer witness flow.
    func createSigningChallenge(entryId: Int, summary: String) async -> SigningChallengeResult? {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/logbook/\(entryId)/challenge.php") else { return nil }

        let body: [String: Any] = ["summary": summary]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let nonce = json["nonce"] as? String,
                  let qr = json["qr_payload"] as? String else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    error = json["error"] as? String ?? json["detail"] as? String
                }
                return nil
            }
            return SigningChallengeResult(
                entryId: entryId,
                nonce: nonce,
                qrPayload: qr,
                summary: (json["summary"] as? String) ?? summary
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private func loadSavedSignature(token: String) async {
        guard let url = URL(string: "\(kServerURL)/api/me.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let user = json["user"] as? [String: Any] else { return }
            let urlStr = (user["signature_url"] as? String)
                ?? (user["jumper_signature_url"] as? String)
                ?? ""
            let pathStr = (user["jumper_signature_path"] as? String) ?? ""
            savedSignatureUrl = !urlStr.isEmpty ? urlStr : pathStr
        } catch {
            savedSignatureUrl = ""
        }
    }

    var hasSavedSignature: Bool {
        !savedSignatureUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
