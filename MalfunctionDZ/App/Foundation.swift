// File: ASC/App/Foundation.swift
// THE single source of truth for all shared types, colors, and services.
// Every other file in the project depends on this one.

import SwiftUI
import Security

// MARK: - Server URL
let kServerURL = "https://malfunctiondz.com"

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
            let resp = try JSONDecoder().decode(LoginResponse.self, from: data)
            guard resp.ok, let token = resp.token, let user = resp.user else {
                errorMessage = resp.error ?? "Login failed."; return
            }
            print("✅ LOGIN SUCCESS: user=\(user.username) roles=\(user.roles ?? []) sessionID will be: \(token.prefix(20))")
            KeychainHelper.deleteToken()
            KeychainHelper.saveToken(token)
            currentUser = user
            isAuthenticated = true
            sessionID = token
            print("✅ SESSION ID SET: \(sessionID.prefix(20))")
            await refreshCurrentUser()
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
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
        if let resp = try? JSONDecoder().decode(LoginResponse.self, from: data), resp.ok, let u = resp.user {
            print("✅ REFRESH SUCCESS: user=\(u.username) roles=\(u.roles ?? []) currentSessionID=\(sessionID.prefix(20))")
            currentUser = u
            isAuthenticated = true
            await autoEnroll(token: token)
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
