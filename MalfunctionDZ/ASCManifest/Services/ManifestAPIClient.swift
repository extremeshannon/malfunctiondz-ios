import MalfunctionDZCore
import Foundation

enum ManifestAPIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case unauthorized
    case decodingFailed(String)
    case complianceBlocked(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid API URL."
        case .serverError(let message): message
        case .unauthorized: "Session expired. Please log in again."
        case .decodingFailed(let message): message
        case .complianceBlocked(let message): message
        }
    }
}

/// Bearer-authenticated client for MalfunctionDZ Manifest APIs.
final class ManifestAPIClient {
    var token: String?
    var environment: ManifestAppEnvironment
    var onUnauthorized: (() -> Void)?

    private let decoder: JSONDecoder = {
        JSONDecoder()
    }()

    init(environment: ManifestAppEnvironment = ManifestAppConfig.activeEnvironment, token: String? = nil) {
        self.environment = environment
        self.token = token
    }

    var baseURL: URL {
        // Prefer Manifest session environment; falls back to shared staff `kServerURL`.
        environment.baseURL
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> ManifestLoginResponse {
        try await postPublic(path: "/api/login.php", body: ["username": username, "password": password])
    }

    func loginMFA(mfaToken: String, code: String) async throws -> ManifestLoginResponse {
        try await postPublic(path: "/api/login/mfa.php", body: ["mfa_token": mfaToken, "code": code])
    }

    func fetchMe() async throws -> ManifestMeResponse {
        return try await get(path: "/api/me.php")
    }

    // MARK: - Manifest

    func fetchDayManifest(date: Date = Date(), includeSlots: Bool = true) async throws -> DayManifestResponse {
        let dateStr = Self.isoDate(date)
        let query = "date_str=\(dateStr)&include_slots=\(includeSlots ? "true" : "false")"
        do {
            let response: DayManifestResponse = try await get(path: "/api/manifest/day.php?\(query)")
            if !response.ok, let err = response.error, isMissingOrUnsupportedRoute(err) {
                return try await fetchDayManifestFallback(query: query, dateStr: dateStr)
            }
            return response
        } catch ManifestAPIError.serverError(let message) where isMissingOrUnsupportedRoute(message) {
            return try await fetchDayManifestFallback(query: query, dateStr: dateStr)
        }
    }

    /// Staff-only fallbacks when `/day.php` is missing. Never use public display for desk mutations.
    private func fetchDayManifestFallback(query: String, dateStr: String) async throws -> DayManifestResponse {
        if let day = try await fetchDayManifestIfPresent(path: "/api/manifest/day?\(query)") {
            return day
        }
        if let loads = try await fetchDayManifestIfPresent(path: "/api/manifest/loads?\(query)") {
            return loads
        }
        if let loadsPhp = try await fetchDayManifestIfPresent(path: "/api/manifest/loads.php?\(query)") {
            return loadsPhp
        }
        // Authenticated Load Manager requires staff day/loads — display lacks reliable ids + billing.
        return DayManifestResponse(ok: true, error: "day_list_unavailable", date: dateStr, loads: nil)
    }

    private func fetchDayManifestIfPresent(path: String) async throws -> DayManifestResponse? {
        do {
            let response: DayManifestResponse = try await get(path: path)
            if !response.ok, let err = response.error, isMissingOrUnsupportedRoute(err) {
                return nil
            }
            return response
        } catch ManifestAPIError.serverError(let message) where isMissingOrUnsupportedRoute(message) {
            return nil
        }
    }

    func fetchAircraft() async throws -> ManifestAircraftListResponse {
        try await get(path: "/api/manifest/aircraft.php")
    }

    /// DZ rigs for Gear Room (all active DZ rigs, not packable-only filter).
    func fetchDzRigs() async throws -> DzRigsAPIResponse {
        let query = "packable_only=0"
        do {
            return try await get(path: "/api/loft/dz_rigs.php?\(query)")
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await get(path: "/api/loft/dz_rigs?\(query)")
        }
    }

    /// Report catalog for Manifest desk — same list as web Reports hub.
    func fetchReportsCatalog() async throws -> ManifestReportsResponse {
        do {
            return try await get(path: "/api/manifest/reports.php")
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await get(path: "/api/manifest/reports")
        }
    }

    func createLoad(date: Date = Date(), aircraftID: Int? = nil) async throws -> CreateLoadResponse {
        let path = "/api/manifest/loads?date_str=\(Self.isoDate(date))"
        var body: [String: Any] = [:]
        if let aircraftID { body["aircraft_id"] = aircraftID }
        return try await post(path: path, body: body)
    }

    func fetchSlots(loadID: Int) async throws -> SlotsResponse {
        try await get(path: "/api/manifest/loads/\(loadID)/slots")
    }

    func addSlot(
        loadID: Int,
        displayName: String,
        jumpType: String,
        userID: Int? = nil,
        tandemStudentID: Int? = nil,
        instructorUserID: Int? = nil,
        secondInstructorUserID: Int? = nil,
        videographerUserID: Int? = nil,
        acknowledgeOverride: Bool = false,
        overrideNote: String = ""
    ) async throws -> GenericOKResponse {
        var body: [String: Any] = [
            "load_id": loadID,
            "display_name": displayName,
            "jump_type": jumpType,
        ]
        if let userID { body["user_id"] = userID }
        if let tandemStudentID { body["tandem_student_id"] = tandemStudentID }
        if let instructorUserID { body["tandem_instructor_user_id"] = instructorUserID }
        if let secondInstructorUserID { body["second_instructor_user_id"] = secondInstructorUserID }
        if let videographerUserID { body["videographer_user_id"] = videographerUserID }
        if acknowledgeOverride {
            body["acknowledge_override"] = true
            body["override_note"] = overrideNote
        }
        return try await postAllowCompliance409(path: "/api/manifest/slots", body: body)
    }

    func deleteSlot(slotID: Int) async throws -> GenericOKResponse {
        try await delete(path: "/api/manifest/slots/\(slotID)")
    }

    func advanceLoadStatus(loadID: Int, status: String) async throws -> GenericOKResponse {
        try await postJSONResult(path: "/api/manifest/loads/\(loadID)/status", body: ["status": status])
    }

    func fetchManifestPilots(date: Date = Date()) async throws -> ManifestPilotsResponse {
        let dateStr = Self.isoDate(date)
        do {
            return try await get(path: "/api/manifest/pilots.php?date_str=\(dateStr)")
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await get(path: "/api/manifest/pilots?date_str=\(dateStr)")
        }
    }

    func setLoadPilot(
        loadID: Int,
        userID: Int?,
        role: String = "pic",
        acknowledgeOverride: Bool = false,
        overrideNote: String = ""
    ) async throws -> GenericOKResponse {
        var body: [String: Any] = [
            "role": role,
            "pilot_user_id": userID ?? NSNull(),
        ]
        if acknowledgeOverride {
            body["acknowledge_override"] = true
            body["override_note"] = overrideNote
        }
        return try await patchJSONResult(
            path: "/api/manifest/loads/\(loadID)/pilot",
            body: body
        )
    }

    func deleteLoad(loadID: Int) async throws -> GenericOKResponse {
        try await delete(path: "/api/manifest/loads/\(loadID)")
    }

    func searchJumpers(query: String) async throws -> SearchJumpersResponse {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get(path: "/api/manifest/search-jumpers.php?q=\(q)&limit=20")
    }

    func searchTandemStudents(query: String) async throws -> SearchJumpersResponse {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        do {
            return try await get(path: "/api/manifest/search-tandem-students.php?q=\(q)&limit=20")
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await get(path: "/api/manifest/search-tandem-students?q=\(q)&limit=20")
        }
    }

    func createTandemStudent(
        firstName: String,
        lastName: String,
        email: String = "",
        weightLb: Int? = nil
    ) async throws -> CreateTandemStudentResponse {
        var body: [String: Any] = [
            "first_name": firstName.trimmingCharacters(in: .whitespaces),
            "last_name": lastName.trimmingCharacters(in: .whitespaces),
        ]
        if !email.isEmpty { body["email"] = email }
        if let weightLb { body["weight_lb"] = weightLb }
        do {
            return try await post(path: "/api/manifest/tandem-students.php", body: body)
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await post(path: "/api/manifest/tandem-students", body: body)
        }
    }

    func fetchNextLevel(userID: Int) async throws -> NextLevelResponse {
        try await get(path: "/api/manifest/users/\(userID)/next-level.php")
    }

    func fetchInstructors(jumpType: String, query: String = "", date: Date = Date()) async throws -> InstructorsResponse {
        let jt = jumpType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jumpType
        var path = "/api/manifest/instructors.php?jump_type=\(jt)&date_str=\(Self.isoDate(date))"
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            path += "&q=\(encoded)"
        }
        do {
            return try await get(path: path)
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await get(path: path.replacingOccurrences(of: ".php", with: ""))
        }
    }

    func fetchAccountDetail(userID: Int) async throws -> AccountDetailResponse {
        try await get(path: "/api/manifest/account/\(userID)")
    }

    func fetchTandemStudentDetail(studentID: Int) async throws -> AccountDetailResponse {
        try await get(path: "/api/manifest/tandem-students/\(studentID)")
    }

    func fetchAccountHistory(userID: Int) async throws -> AccountHistoryResponse {
        try await get(path: "/api/manifest/account/\(userID)/history")
    }

    func fetchAccountWaivers(userID: Int) async throws -> AccountWaiversResponse {
        try await get(path: "/api/manifest/account/\(userID)/waivers")
    }

    func postAccountLedger(userID: Int, amount: String, memo: String, paymentType: String) async throws -> GenericOKResponse {
        try await postJSONResult(
            path: "/api/manifest/account/\(userID)/ledger",
            body: ["amount": amount, "memo": memo, "payment_type": paymentType]
        )
    }

    // MARK: - Check-in

    func fetchCheckInPools(date: Date = Date()) async throws -> CheckInPoolsResponse {
        let dateStr = Self.isoDate(date)
        do {
            let response: CheckInPoolsResponse = try await get(path: "/api/checkin/pools.php?date_str=\(dateStr)")
            if response.ok == false, let err = response.error, isMissingRoute(err) {
                return try await get(path: "/api/checkin/pools?date_str=\(dateStr)")
            }
            return response
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await get(path: "/api/checkin/pools?date_str=\(dateStr)")
        }
    }

    func fetchCheckInList(date: Date = Date()) async throws -> CheckInListResponse {
        try await get(path: "/api/checkin/list?date_str=\(Self.isoDate(date))")
    }

    func fetchCheckedInTandemStudents(date: Date = Date()) async throws -> CheckedInTandemListResponse {
        try await get(path: "/api/checkin/tandem-students?date_str=\(Self.isoDate(date))")
    }

    func checkInTandemStudent(
        tandemStudentID: Int,
        date: Date = Date(),
        markPaid: Bool = false,
        acknowledgeOverride: Bool = false,
        overrideNote: String = ""
    ) async throws -> GenericOKResponse {
        var body: [String: Any] = [
            "tandem_student_id": tandemStudentID,
            "date_str": Self.isoDate(date),
        ]
        if markPaid { body["mark_paid"] = true }
        if acknowledgeOverride {
            body["acknowledge_override"] = true
            body["override_note"] = overrideNote
        }
        let query = "date_str=\(Self.isoDate(date))&tandem_student_id=\(tandemStudentID)"
        let phpPath = "/api/checkin/tandem-student.php?\(query)"
        do {
            let response = try await postJSONResult(path: phpPath, body: body)
            // Soft 404 payloads decode as {ok:false,error:"Not Found"} — retry without .php.
            if response.ok == false, let err = response.error, isMissingRoute(err) {
                return try await postJSONResult(
                    path: "/api/checkin/tandem-student?\(query)",
                    body: body
                )
            }
            return response
        } catch ManifestAPIError.serverError(let message) where isMissingRoute(message) {
            return try await postJSONResult(
                path: "/api/checkin/tandem-student?\(query)",
                body: body
            )
        }
    }

    func fetchEligibleUsers() async throws -> EligibleUsersResponse {
        try await get(path: "/api/checkin/eligible-users.php")
    }

    func checkInUser(
        userID: Int,
        date: Date = Date(),
        rentingDzRig: Bool = false
    ) async throws -> GenericOKResponse {
        var body: [String: Any] = [
            "user_id": userID,
            "date_str": Self.isoDate(date),
        ]
        if rentingDzRig { body["renting_dz_rig"] = true }
        return try await postJSONResult(path: "/api/checkin.php", body: body)
    }

    func updateCheckInPrep(
        userID: Int,
        idChecked: Bool? = nil,
        affidavitSigned: Bool? = nil,
        dzBriefing: Bool? = nil
    ) async throws -> CheckInPrepResponse {
        var body: [String: Any] = [:]
        if let idChecked { body["id_checked"] = idChecked }
        if let affidavitSigned { body["affidavit_signed"] = affidavitSigned }
        if let dzBriefing { body["dz_briefing"] = dzBriefing }
        return try await post(path: "/api/checkin/\(userID)/prep", body: body)
    }

    func updateTandemCheckInPrep(
        tandemStudentID: Int,
        waiverSigned: Bool? = nil,
        idChecked: Bool? = nil,
        videoWatched: Bool? = nil,
        affidavitSigned: Bool? = nil,
        trainingComplete: Bool? = nil
    ) async throws -> CheckInPrepResponse {
        var body: [String: Any] = [:]
        if let waiverSigned { body["waiver_signed"] = waiverSigned }
        if let idChecked { body["id_checked"] = idChecked }
        if let videoWatched { body["video_watched"] = videoWatched }
        if let affidavitSigned { body["affidavit_signed"] = affidavitSigned }
        if let trainingComplete { body["training_complete"] = trainingComplete }
        return try await post(
            path: "/api/checkin/tandem-student/\(tandemStudentID)/prep",
            body: body
        )
    }

    func checkOutAll(date: Date = Date()) async throws -> GenericOKResponse {
        try await post(path: "/api/checkin/check-out-all?date_str=\(Self.isoDate(date))", body: [:] as [String: Any])
    }

    func scanID(
        userID: Int? = nil,
        tandemStudentID: Int? = nil,
        barcodeText: String,
        imageData: Data? = nil,
        markChecked: Bool = false
    ) async throws -> IDScanResponse {
        let hasBarcode = !barcodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var fields: [String: String] = [
            "barcode_text": barcodeText,
            "apply_fields": "1",
            "mark_checked": markChecked ? "1" : "",
            "side": hasBarcode ? "barcode" : "front",
        ]
        if let userID, userID > 0 { fields["user_id"] = "\(userID)" }
        if let tandemStudentID, tandemStudentID > 0 {
            fields["tandem_student_id"] = "\(tandemStudentID)"
        }
        return try await uploadMultipart(
            path: "/api/checkin/id-scan",
            fields: fields,
            fileData: imageData,
            fileField: "file",
            fileName: "scan.jpg",
            mimeType: "image/jpeg"
        )
    }

    // MARK: - HTTP

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = ManifestAppConfig.opsCalendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = ManifestAppConfig.opsTimeZone
        return f.string(from: date)
    }

    private func isMissingRoute(_ message: String) -> Bool {
        let m = message.lowercased()
        return m == "not found" || m.contains("http 404")
    }

    /// 404 missing route, or 405 when GET is not deployed yet (POST-only `/loads` on older hosts).
    private func isMissingOrUnsupportedRoute(_ message: String) -> Bool {
        let m = message.lowercased()
        return isMissingRoute(m)
            || m.contains("method not allowed")
            || m.contains("http 405")
    }

    private func url(for path: String) throws -> URL {
        var base = baseURL.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let suffix = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: base + suffix) else {
            throw ManifestAPIError.invalidURL
        }
        return url
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let data = try await request(method: "GET", path: path, body: nil, authorized: true)
        return try decode(T.self, from: data)
    }

    private func post<T: Decodable>(path: String, body: [String: Any], authorized: Bool = true) async throws -> T {
        let data = try await request(method: "POST", path: path, body: body, authorized: authorized)
        return try decode(T.self, from: data)
    }

    /// Login/MFA — decode `{ok, error}` on 401 instead of treating it as an expired session.
    private func postPublic<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        applyHeaders(to: &request, authorized: false, contentType: "application/json")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401,
           let decoded = try? decode(T.self, from: data) {
            return decoded
        }
        try validate(response: response, data: data)
        return try decode(T.self, from: data)
    }

    private func postAllowCompliance409(path: String, body: [String: Any]) async throws -> GenericOKResponse {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        applyHeaders(to: &request, authorized: true, contentType: "application/json")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 409,
           let decoded = try? decode(GenericOKResponse.self, from: data),
           decoded.override_allowed == true {
            return decoded
        }
        try validate(response: response, data: data)
        return try decode(GenericOKResponse.self, from: data)
    }

    /// POST that returns `{ok, error}` even on 409/400 (status pipeline, compliance).
    private func postJSONResult(path: String, body: [String: Any]) async throws -> GenericOKResponse {
        try await sendJSONResult(method: "POST", path: path, body: body)
    }

    private func patchJSONResult(path: String, body: [String: Any]) async throws -> GenericOKResponse {
        try await sendJSONResult(method: "PATCH", path: path, body: body)
    }

    private func sendJSONResult(method: String, path: String, body: [String: Any]) async throws -> GenericOKResponse {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = method
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        applyHeaders(to: &request, authorized: true, contentType: "application/json")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let decoded = try? decoder.decode(GenericOKResponse.self, from: data) {
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                onUnauthorized?()
                throw ManifestAPIError.unauthorized
            }
            return decoded
        }
        try validate(response: response, data: data)
        return try decode(GenericOKResponse.self, from: data)
    }

    private func delete<T: Decodable>(path: String) async throws -> T {
        let data = try await request(method: "DELETE", path: path, body: nil, authorized: true)
        return try decode(T.self, from: data)
    }

    private func request(method: String, path: String, body: [String: Any]?, authorized: Bool) async throws -> Data {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        applyHeaders(to: &request, authorized: authorized, contentType: "application/json")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func uploadMultipart<T: Decodable>(
        path: String,
        fields: [String: String],
        fileData: Data?,
        fileField: String,
        fileName: String,
        mimeType: String
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = "POST"
        applyHeaders(to: &request, authorized: true, contentType: "multipart/form-data; boundary=\(boundary)")

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        if let fileData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decode(T.self, from: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8)?.prefix(180) ?? "non-text"
            throw ManifestAPIError.decodingFailed("Unexpected response from server. \(raw)")
        }
    }

    private func applyHeaders(to request: inout URLRequest, authorized: Bool, contentType: String = "application/json") {
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(ManifestAppConfig.dropzoneSlug, forHTTPHeaderField: "X-Dropzone-Slug")
        if authorized, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 {
            onUnauthorized?()
            throw ManifestAPIError.unauthorized
        }
        if http.statusCode == 409,
           let envelope = try? decoder.decode(GenericOKResponse.self, from: data) {
            if envelope.override_allowed == true {
                throw ManifestAPIError.complianceBlocked(envelope.error ?? "Compliance block")
            }
            if let error = envelope.error, !error.isEmpty {
                throw ManifestAPIError.serverError(error)
            }
        }
        if http.statusCode >= 400 {
            if let envelope = try? decoder.decode(ManifestAPIEnvelope.self, from: data),
               let error = envelope.error, !error.isEmpty {
                throw ManifestAPIError.serverError(error)
            }
            if let detail = try? JSONDecoder().decode(FastAPIError.self, from: data),
               !detail.detail.isEmpty {
                throw ManifestAPIError.serverError(detail.detail)
            }
            throw ManifestAPIError.serverError("HTTP \(http.statusCode)")
        }
    }
}

private struct FastAPIError: Decodable {
    let detail: String
}
