// File: ASC/ViewModels/LogbookViewModel.swift
// Purpose: Load skydiver logbook entries — for a course (LMS) or all entries (standalone).
import Foundation
import MalfunctionDZCore

@MainActor
class LogbookViewModel: ObservableObject {
    @Published var entries: [SkydiverLogbookEntry] = []
    @Published var rigs: [JumperRig] = []
    @Published var rigCatalog: RigCatalogResponse?
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
    @Published var totalJumps: Int = 0
    @Published var isStudent: Bool = false
    @Published var isSkydiver: Bool = false
    @Published var nextJumpNumber: Int = 1
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    private var currentCourseId: Int?

    /// Load logbook. Pass courseId to filter by course (LMS flow); pass nil for all entries (standalone, skydivers without LMS).
    func load(courseId: Int? = nil, userId: Int? = nil) async {
        isLoading = true
        error = nil
        currentCourseId = courseId
        defer { isLoading = false }

        var components = URLComponents(string: "\(kServerURL)/api/lms/logbook.php")
        var items: [URLQueryItem] = []
        if let cid = courseId, cid > 0 {
            items.append(URLQueryItem(name: "course_id", value: "\(cid)"))
        }
        if let uid = userId {
            items.append(URLQueryItem(name: "user_id", value: "\(uid)"))
        }
        if !items.isEmpty { components?.queryItems = items }

        guard let token = KeychainHelper.readToken(),
              let url = components?.url else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 404 {
                entries = []
                otherTrainingNotes = ""
                priorFreefallSeconds = 0
                totalFreefallSeconds = 0
                return
            }
            let decoded = try? JSONDecoder().decode(SkydiverLogbookResponse.self, from: data)
            if let resp = decoded, resp.ok {
                entries = resp.entries ?? []
                otherTrainingNotes = resp.otherTrainingNotes ?? ""
                priorJumpCount = resp.priorJumpCount ?? 0
                priorFreefallSeconds = resp.priorFreefallSeconds ?? 0
                totalFreefallSeconds = resp.totalFreefallSeconds ?? 0
                startFreefallTime = resp.startFreefallTime ?? ""
                defaultJumpType = resp.defaultJumpType ?? ""
                homeDropzone = resp.homeDropzone ?? ""
                totalJumps = resp.totalJumps ?? priorJumpCount
                isStudent = resp.isStudent ?? false
                isSkydiver = resp.isSkydiver ?? false
                nextJumpNumber = resp.nextJumpNumber ?? (priorJumpCount + 1)
            } else {
                entries = []
                otherTrainingNotes = ""
                priorJumpCount = 0
                priorFreefallSeconds = 0
                totalFreefallSeconds = 0
                startFreefallTime = ""
                defaultJumpType = ""
                homeDropzone = ""
                totalJumps = 0
                isStudent = false
                isSkydiver = false
                nextJumpNumber = 1
            }
        } catch {
            entries = []
            otherTrainingNotes = ""
            priorFreefallSeconds = 0
            totalFreefallSeconds = 0
            startFreefallTime = ""
            defaultJumpType = ""
            homeDropzone = ""
            self.error = error.localizedDescription
        }
    }

    /// Saves all logbook settings in one request (recommended for the config screen).
    func saveLogbookSettings(
        priorJumpCount: Int,
        priorFreefallSeconds: Int,
        startFreefallTime: String,
        defaultJumpType: String,
        homeDropzone: String
    ) async -> Bool {
        let pj = max(0, min(priorJumpCount, 50000))
        let pff = max(0, min(priorFreefallSeconds, 1_000_000_000))
        isSaving = true
        error = nil
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_settings.php") else { return false }
        var body: [String: Any] = [
            "prior_jump_count": pj,
            "prior_freefall_seconds": pff,
            "start_freefall_time": startFreefallTime.isEmpty ? NSNull() : startFreefallTime,
            "home_dropzone": homeDropzone.isEmpty ? NSNull() : homeDropzone,
            "default_jump_type": defaultJumpType.isEmpty ? NSNull() : defaultJumpType,
        ]
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
                self.priorJumpCount = pj
                self.priorFreefallSeconds = pff
                self.startFreefallTime = startFreefallTime
                self.defaultJumpType = defaultJumpType
                self.homeDropzone = homeDropzone
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
                isStudent = totalJumps < 25
                isSkydiver = totalJumps >= 25
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
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/rig_catalog.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try? JSONDecoder().decode(RigCatalogResponse.self, from: data)
            rigCatalog = decoded
        } catch {
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

    /// Remove a jumper-owned rig (`delete: true` in JSON body). Reloads rigs on success.
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

    /// Add a jump entry. Skydivers only (total >= 25).
    /// Backend computes total_time (cumulative freefall) from prior entries + this jump's delay.
    func addEntry(dz: String?, altitude: String?, delay: String?, date: String?, aircraft: String?,
                  equipment: String?, rigId: Int?, jumpType: String?, comments: String?) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_add.php") else { return }

        var body: [String: Any?] = [
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
        guard let jsonData = try? JSONSerialization.data(withJSONObject: clean) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if statusCode == 403 {
                error = json?["error"] as? String ?? "You need 25 jumps to add entries."
                return
            }
            if (json?["ok"] as? Bool) == true {
                await load(courseId: currentCourseId, userId: nil)
            } else {
                error = json?["error"] as? String ?? "Failed to add entry"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Sign and lock a logbook entry. Pass signature as base64 PNG.
    func signEntry(entryId: Int, signatureBase64: String) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/logbook_sign.php") else { return }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: [
            "entry_id": entryId,
            "signature": signatureBase64,
        ]) else { return }

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
            } else {
                error = json?["error"] as? String ?? "Failed to sign"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
