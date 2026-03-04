// File: ASC/App/Foundation.swift
// THE single source of truth for all shared types, colors, and services.
// Every other file in the project depends on this one.

import SwiftUI
import Security
import UserNotifications

// MARK: - Server URL
// Production (HTTPS): "https://malfunctiondz.com"
// VPS direct (HTTP, for push testing): "http://51.81.210.212:8080" — requires NSAllowsArbitraryLoads in project
// Local MAMP: "http://localhost:8888"
let kServerURL = "http://51.81.210.212:8080"

// MARK: - Keychain
struct KeychainHelper {
    private static let service = "com.malfunctiondz.app"
    private static let account = "auth_token"

    @discardableResult
    static func saveToken(_ token: String) -> Bool {
        let data = Data(token.utf8)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrService as String: service,
                                 kSecAttrAccount as String: account,
                                 kSecValueData as String: data]
        SecItemDelete(q as CFDictionary)
        let result = SecItemAdd(q as CFDictionary, nil) == errSecSuccess
        print("🔑 KEYCHAIN SAVE: \(result) token prefix: \(token.prefix(20))")
        return result
    }

    static func readToken() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrService as String: service,
                                 kSecAttrAccount as String: account,
                                 kSecReturnData as String: true,
                                 kSecMatchLimit as String: kSecMatchLimitOne]
        var ref: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &ref) == errSecSuccess,
              let d = ref as? Data else { return nil }
        let token = String(data: d, encoding: .utf8)
        print("🔑 KEYCHAIN READ: \(token?.prefix(20) ?? "nil")")
        return token
    }

    @discardableResult
    static func deleteToken() -> Bool {
        // Delete ALL generic password items for this service
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrService as String: service]
        let s = SecItemDelete(q as CFDictionary)
        print("🔑 KEYCHAIN DELETE: \(s == errSecSuccess || s == errSecItemNotFound)")
        return s == errSecSuccess || s == errSecItemNotFound
    }
}

// MARK: - Colors
extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
    }
    static let mdzNavy       = Color(hex:"0A2240")
    static let mdzNavyMid    = Color(hex:"0C1D35")
    static let mdzNavyLift   = Color(hex:"14406E")
    static let mdzRed        = Color(hex:"C8102E")
    static let mdzRedDark    = Color(hex:"8B0B1E")
    static let mdzBlue       = Color(hex:"8DC8FF")
    static let mdzBlueLight  = Color(hex:"B8D9F5")
    static let mdzBackground = Color(hex:"060D1A")
    static let mdzCard       = Color(hex:"0C1D35")
    static let mdzCard2      = Color(hex:"0F2540")
    static let mdzText       = Color(hex:"E8EDF5")
    static let mdzMuted      = Color(hex:"6B8CAE")
    static let mdzGreen      = Color(hex:"2ECC71")
    static let mdzAmber      = Color(hex:"F39C12")
    static let mdzDanger     = Color(hex:"E74C3C")
    static let mdzBorder     = Color(hex:"1A3A5C")
}

// MARK: - View Modifiers
struct MDZCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.mdzCard).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(Color.mdzBorder, lineWidth:1))
    }
}
struct MDZPillModifier: ViewModifier {
    var color: Color
    func body(content: Content) -> some View {
        content.font(.caption.weight(.semibold)).foregroundColor(.white)
            .padding(.horizontal,10).padding(.vertical,4).background(color).clipShape(Capsule())
    }
}
extension View {
    func mdzCard() -> some View { modifier(MDZCardModifier()) }
    func mdzPill(_ color: Color = .mdzBlue) -> some View { modifier(MDZPillModifier(color: color)) }
}

// MARK: - Shared UI Components
struct StatusPill: View {
    let label: String
    let color: Color
    var body: some View { Text(label).mdzPill(color) }
}

// Stat cell used in Aviation and Home dashboard widgets
struct PilotStatCell: View {
    let label: String
    let value: String
    @Environment(\.horizontalSizeClass) private var hSizeClass
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: hSizeClass == .regular ? 24 : 20, weight: .black))
                .foregroundColor(.mdzText)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.mdzMuted)
                .tracking(1)
        }
    }
}

// NOTE: StringDouble is defined in FlightLoad.swift — do not redeclare here

struct LoadingOverlay: View {
    var message: String = "Loading…"
    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing:16) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint:.mdzBlue)).scaleEffect(1.4)
                Text(message).foregroundColor(.mdzMuted).font(.subheadline)
            }
        }
    }
}

struct EmptyStateView: View {
    var icon: String = "tray"
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(spacing:12) {
            Image(systemName:icon).font(.system(size:40)).foregroundColor(.mdzMuted)
            Text(title).font(.headline).foregroundColor(.mdzText)
            if let s = subtitle {
                Text(s).font(.subheadline).foregroundColor(.mdzMuted).multilineTextAlignment(.center)
            }
        }.padding(32)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.mdzMuted)
            Spacer()
            Text(value).foregroundColor(.mdzText)
        }.font(.subheadline)
    }
}

// MARK: - Models
struct User: Codable, Identifiable {
    let id: Int; let username: String; let firstName: String?; let lastName: String?
    let email: String?; let role: String?; let roles: [String]?
    enum CodingKeys: String, CodingKey {
        case id, username, email, role, roles
        case firstName = "first_name"; case lastName = "last_name"
    }

    /// Build from raw JSON (handles PHP/MySQL type variations)
    init?(from dict: [String: Any]) {
        guard let idVal = dict["id"] else { return nil }
        if let i = idVal as? Int { id = i }
        else if let s = idVal as? String, let i = Int(s) { id = i }
        else { return nil }
        username = dict["username"] as? String ?? ""
        firstName = dict["first_name"] as? String
        lastName = dict["last_name"] as? String
        email = dict["email"] as? String
        role = dict["role"] as? String
        if let r = dict["roles"] as? [String] { roles = r }
        else if let r = dict["roles"] as? [Any] { roles = r.compactMap { $0 as? String } }
        else { roles = nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        roles = try c.decodeIfPresent([String].self, forKey: .roles)
    }
    var fullName: String { "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in:.whitespaces) }
    var displayInitials: String {
        (firstName?.first.map(String.init) ?? "") + (lastName?.first.map(String.init) ?? "")
    }
    private var allRoles: [String] {
        var r = roles ?? []; if let p = role { r.append(p) }; return r.map{$0.lowercased()}
    }
    var isAdmin: Bool     { allRoles.contains(where:{["admin","master","godmode"].contains($0)}) }
    var isPilot: Bool     { allRoles.contains("pilot") || isAdmin }
    var isRigger: Bool    { allRoles.contains("rigger") || isAdmin }
    var isInspector: Bool { allRoles.contains("inspector") || isAdmin }
    var primaryRoleLabel: String {
        if isAdmin { return "Admin" }
        if isPilot { return "Pilot" }
        if isRigger { return "Rigger" }
        if isInspector { return "Inspector" }
        if allRoles.contains("manifest") { return "Manifest" }
        if allRoles.contains(where: { ["chief_pilot", "chief pilot"].contains($0) }) { return "Chief Pilot" }
        return role?.capitalized ?? "Member"
    }
}

struct LoginRequest: Encodable { let username: String; let password: String }
struct LoginResponse: Decodable { let ok: Bool; let token: String?; let user: User?; let error: String? }
struct MobileResponse<T: Decodable>: Decodable { let ok: Bool; let data: T?; let error: String? }

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL, notAuthenticated, serverError(String), decodingError(Error), networkError(Error)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .notAuthenticated: return "Not authenticated."
        case .serverError(let m): return m
        case .decodingError(let e): return "Data error: \(e.localizedDescription)"
        case .networkError(let e): return e.localizedDescription
        }
    }
}

// MARK: - API Client
actor APIClient {
    static let shared = APIClient()
    init() {}
    func request<T:Decodable>(path:String, method:String="GET", body:Encodable?=nil, requiresAuth:Bool=true) async throws -> T {
        guard let url = URL(string: kServerURL+path) else { throw APIError.invalidURL }
        var req = URLRequest(url:url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField:"Content-Type")
        if requiresAuth {
            guard let tok = KeychainHelper.readToken() else { throw APIError.notAuthenticated }
            req.setValue("Bearer \(tok)", forHTTPHeaderField:"Authorization")
        }
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        let (data, response): (Data, URLResponse)
        do { (data,response) = try await URLSession.shared.data(for:req) }
        catch { throw APIError.networkError(error) }
        if let h = response as? HTTPURLResponse, h.statusCode==401 {
            await AuthManager.shared.logout(); throw APIError.notAuthenticated
        }
        do {
            let d = try JSONDecoder().decode(MobileResponse<T>.self, from:data)
            if d.ok, let p = d.data { return p }
            throw APIError.serverError(d.error ?? "Unknown error.")
        } catch let e as APIError { throw e
        } catch { throw APIError.decodingError(error) }
    }
    func get<T:Decodable>(path:String) async throws -> T { try await request(path:path) }
    func post<T:Decodable>(path:String, body:Encodable?=nil) async throws -> T { try await request(path:path,method:"POST",body:body) }
}

// MARK: - AppConfig
@MainActor final class AppConfig: ObservableObject {
    init() {}
    @Published var dzName             = "Alaska Skydive Center"
    @Published var moduleAviation     = "Aviation"
    @Published var moduleLoft         = "Loft"
    @Published var moduleGroundSchool = "Ground School"
    @Published var moduleManifest     = "Manifest"
    let poweredBy                     = "Powered by MalfunctionDZ"
    func loadConfig() async {
        guard let url = URL(string:"\(kServerURL)/api/config.php") else { return }
        guard let (data,_) = try? await URLSession.shared.data(from:url) else { return }
        struct R: Decodable { let ok:Bool; let data:D? }
        struct D: Decodable {
            let dzName:String?; let av:String?; let loft:String?; let gs:String?; let mf:String?
            enum CodingKeys:String,CodingKey {
                case dzName="dz_name"; case av="module_aviation"; case loft="module_loft"
                case gs="module_ground_school"; case mf="module_manifest"
            }
        }
        if let r = try? JSONDecoder().decode(R.self, from:data), r.ok, let d = r.data {
            dzName = d.dzName ?? dzName; moduleAviation = d.av ?? moduleAviation
            moduleLoft = d.loft ?? moduleLoft; moduleGroundSchool = d.gs ?? moduleGroundSchool
            moduleManifest = d.mf ?? moduleManifest
            let ud = UserDefaults.standard
            ud.set(dzName, forKey:"cfg_dz"); ud.set(moduleAviation, forKey:"cfg_av")
            ud.set(moduleLoft, forKey:"cfg_loft"); ud.set(moduleGroundSchool, forKey:"cfg_gs")
            ud.set(moduleManifest, forKey:"cfg_mf")
        }
    }
    private func restore() {
        let ud = UserDefaults.standard
        if let v=ud.string(forKey:"cfg_dz"),!v.isEmpty{dzName=v}
        if let v=ud.string(forKey:"cfg_av"),!v.isEmpty{moduleAviation=v}
        if let v=ud.string(forKey:"cfg_loft"),!v.isEmpty{moduleLoft=v}
        if let v=ud.string(forKey:"cfg_gs"),!v.isEmpty{moduleGroundSchool=v}
        if let v=ud.string(forKey:"cfg_mf"),!v.isEmpty{moduleManifest=v}
    }
}

// MARK: - AuthManager
@MainActor final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    init() {
        if let token = KeychainHelper.readToken(), !token.isEmpty {
            print("🚀 APP START: found existing token, restoring session")
            isAuthenticated = true
            sessionID = token
            Task { await refreshCurrentUser() }
        } else {
            print("🚀 APP START: no token found, showing login")
        }
    }

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var sessionID: String = UUID().uuidString

    var isLoggedIn: Bool { isAuthenticated }

    func login(username: String, password: String) async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        guard let url = URL(string: "\(kServerURL)/api/login.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(LoginRequest(username: username, password: password))
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            print("📡 LOGIN RESPONSE: \(raw)")
            // Try Codable first, then raw JSON (handles PHP/MySQL type variations)
            if let resp = try? JSONDecoder().decode(LoginResponse.self, from: data),
               resp.ok, let token = resp.token, let user = resp.user {
                finishLogin(token: token, user: user)
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "Invalid response. Check API URL."
                return
            }
            guard let ok = json["ok"] as? Bool else {
                errorMessage = (json["error"] as? String) ?? "Login failed."
                return
            }
            if !ok {
                errorMessage = (json["error"] as? String) ?? "Invalid login"
                return
            }
            guard let token = json["token"] as? String, !token.isEmpty,
                  let userDict = json["user"] as? [String: Any],
                  let user = User(from: userDict) else {
                errorMessage = "Invalid response format."
                return
            }
            finishLogin(token: token, user: user)
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }

    private func finishLogin(token: String, user: User) {
        print("✅ LOGIN SUCCESS: user=\(user.username) roles=\(user.roles ?? [])")
        KeychainHelper.deleteToken()
        KeychainHelper.saveToken(token)
        currentUser = user
        isAuthenticated = true
        sessionID = token
        Task {
            await refreshCurrentUser()
            PushRegistration.shared.requestPermissionAndRegister()
        }
    }

    func logout() {
        print("🚪 LOGOUT: clearing session")
        KeychainHelper.deleteToken()
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        sessionID = UUID().uuidString
        print("🚪 LOGOUT: new sessionID=\(sessionID.prefix(20))")
    }

    func refreshCurrentUser() async {
        guard let token = KeychainHelper.readToken() else {
            print("🔄 REFRESH: no token, logging out")
            isAuthenticated = false
            return
        }
        guard let url = URL(string: "\(kServerURL)/api/me.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else {
            print("🔄 REFRESH: network error, logging out")
            logout()
            return
        }
        let raw = String(data: data, encoding: .utf8) ?? "nil"
        print("📡 ME RESPONSE: \(raw)")
        var user: User?
        if let resp = try? JSONDecoder().decode(LoginResponse.self, from: data), resp.ok { user = resp.user }
        else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                json["ok"] as? Bool == true, let uDict = json["user"] as? [String: Any] { user = User(from: uDict) }
        if let u = user {
            print("✅ REFRESH SUCCESS: user=\(u.username) roles=\(u.roles ?? [])")
            currentUser = u
            isAuthenticated = true
            await autoEnroll(token: token)
            PushRegistration.shared.requestPermissionAndRegister()
        } else {
            print("❌ REFRESH FAILED: logging out")
            logout()
        }
    }

    private func autoEnroll(token: String) async {
        guard let url = URL(string: "\(kServerURL)/api/lms/auto_enroll.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }
}

// MARK: - Push registration (sends token to backend)

@MainActor
final class PushRegistration: ObservableObject {
    static let shared = PushRegistration()

    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            case .denied, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    func sendTokenToBackend(_ deviceToken: String) async {
        guard let token = KeychainHelper.readToken(), !token.isEmpty else {
            print("⚠️ PUSH: Skipped — no auth token (user not logged in?)")
            return
        }
        guard let url = URL(string: "\(kServerURL)/api/push/register.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode([
            "device_token": deviceToken,
            "platform": "ios"
        ])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            if code == 200 || (200...299).contains(code) {
                print("✅ PUSH: Registered at \(kServerURL)/api/push/register.php (HTTP \(code))")
            } else {
                print("⚠️ PUSH: Register failed HTTP \(code): \(body)")
            }
        } catch {
            print("⚠️ PUSH: Register request failed: \(error.localizedDescription)")
        }
    }
}
