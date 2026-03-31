// MalfunctionDZCore — shared networking, auth, theme, and UI primitives.
import SwiftUI
import Security
import UserNotifications
import UIKit


// MARK: - Server URL
// Debug (run from Xcode): default = http://localhost:8000 for local testing.
// Release (Archive / TestFlight / App Store): default = https://malfunctiondz.com.
// Override: set "API Base URL" in Profile to point at any backend (e.g. Mac IP for device, or production).
public var kServerURL: String {
    if let custom = UserDefaults.standard.string(forKey: "api_base_url"), !custom.isEmpty {
        let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasSuffix("/") ? String(t.dropLast()) : t
    }
    #if DEBUG
    return "http://localhost:8000"
    #else
    return "https://malfunctiondz.com"
    #endif
}

// MARK: - Keychain
public struct KeychainHelper {
    private static var service: String {
        (Bundle.main.bundleIdentifier ?? "com.malfunctiondz.unknown") + ".mdz.auth"
    }
    private static let account = "auth_token"

    @discardableResult
    public static func saveToken(_ token: String) -> Bool {
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

    public static func readToken() -> String? {
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
    public static func deleteToken() -> Bool {
        // Delete ALL generic password items for this service
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                 kSecAttrService as String: service]
        let s = SecItemDelete(q as CFDictionary)
        print("🔑 KEYCHAIN DELETE: \(s == errSecSuccess || s == errSecItemNotFound)")
        return s == errSecSuccess || s == errSecItemNotFound
    }
}

// MARK: - Colors
public extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
    }
    public static let mdzNavy       = Color(hex:"0A2240")
    public static let mdzNavyMid    = Color(hex:"0C1D35")
    public static let mdzNavyLift   = Color(hex:"14406E")
    public static let mdzRed        = Color(hex:"C8102E")
    public static let mdzRedDark    = Color(hex:"8B0B1E")
    public static let mdzBlue       = Color(hex:"8DC8FF")
    public static let mdzBlueLight  = Color(hex:"B8D9F5")
    public static let mdzBackground = Color(hex:"060D1A")
    public static let mdzCard       = Color(hex:"0C1D35")
    public static let mdzCard2      = Color(hex:"0F2540")
    public static let mdzText       = Color(hex:"E8EDF5")
    public static let mdzMuted      = Color(hex:"6B8CAE")
    public static let mdzGreen      = Color(hex:"2ECC71")
    public static let mdzAmber      = Color(hex:"F39C12")
    public static let mdzDanger     = Color(hex:"E74C3C")
    public static let mdzBorder     = Color(hex:"1A3A5C")
    public static let mdzTeal       = Color(hex:"0D9488")
    public static let mdzOrange     = Color(hex:"F06020")
    public static let mdzPurple     = Color(hex:"7C3AED")

    // Login screen — Alaska Skydive Center logo palette (cream, orange, warm earth)
    public static let ascLoginBackground = Color(hex:"F5F0E8")
    public static let ascLoginCard       = Color(hex:"FDFBF7")
    public static let ascLoginBorder    = Color(hex:"D4C4A8")
    public static let ascLoginText      = Color(hex:"2C2419")
    public static let ascLoginMuted     = Color(hex:"7A6F5C")
    public static let ascLoginOrange    = Color(hex:"D94E1F")
    public static let ascLoginOrangeDark = Color(hex:"B83D12")
}

// MARK: - Theme-based color set (from server: theme "slate_fire" vs "old_glory")
public struct MDZColorSet {
    public let background: Color
    public let card: Color
    public let card2: Color
    public let text: Color
    public let muted: Color
    public let primary: Color
    public let accent: Color
    public let border: Color
    public let green: Color
    public let amber: Color
    public let danger: Color
    public let navy: Color
    public let navyMid: Color
    /// Aviation module — blue
    public let aviation: Color
    /// Loft module — teal
    public let loft: Color
    /// Dropzone / DZ Rigs — orange
    public let dz: Color
    /// Ground School — purple
    public let groundSchool: Color

    public static let oldGlory = MDZColorSet(
        background: .mdzBackground,
        card: .mdzCard,
        card2: .mdzCard2,
        text: .mdzText,
        muted: .mdzMuted,
        primary: .mdzBlue,
        accent: .mdzRed,
        border: .mdzBorder,
        green: .mdzGreen,
        amber: .mdzAmber,
        danger: .mdzDanger,
        navy: .mdzNavy,
        navyMid: .mdzNavyMid,
        aviation: Color(hex: "5B9BD5"),
        loft: Color(hex: "0D9488"),
        dz: Color(hex: "E85D04"),
        groundSchool: Color(hex: "7C3AED")
    )

    public static let slateFire = MDZColorSet(
        background: Color(hex: "D6DCE3"),
        card: Color(hex: "E8ECF0"),
        card2: Color(hex: "EFF2F5"),
        text: Color(hex: "1A2830"),
        muted: Color(hex: "6A8090"),
        primary: Color(hex: "5AACCA"),
        accent: Color(hex: "F06020"),
        border: Color(hex: "2A3A47").opacity(0.12),
        green: Color(hex: "2EAA72"),
        amber: Color(hex: "D4920A"),
        danger: Color(hex: "D63C3C"),
        navy: Color(hex: "2A3A47"),
        navyMid: Color(hex: "1E2D38"),
        aviation: Color(hex: "2563EB"),
        loft: Color(hex: "0D9488"),
        dz: Color(hex: "F06020"),
        groundSchool: Color(hex: "7C3AED")
    )

    public static func `for`(_ theme: String) -> MDZColorSet {
        theme == "old_glory" ? .oldGlory : .slateFire
    }

    public init(
        background: Color, card: Color, card2: Color, text: Color, muted: Color,
        primary: Color, accent: Color, border: Color, green: Color, amber: Color, danger: Color,
        navy: Color, navyMid: Color, aviation: Color, loft: Color, dz: Color, groundSchool: Color
    ) {
        self.background = background
        self.card = card
        self.card2 = card2
        self.text = text
        self.muted = muted
        self.primary = primary
        self.accent = accent
        self.border = border
        self.green = green
        self.amber = amber
        self.danger = danger
        self.navy = navy
        self.navyMid = navyMid
        self.aviation = aviation
        self.loft = loft
        self.dz = dz
        self.groundSchool = groundSchool
    }
}

private struct MDZColorsKey: EnvironmentKey {
    static let defaultValue = MDZColorSet.slateFire
}
public extension EnvironmentValues {
    public var mdzColors: MDZColorSet {
        get { self[MDZColorsKey.self] }
        set { self[MDZColorsKey.self] = newValue }
    }
    public var mdzColorScheme: ColorScheme {
        get { self[MDZColorSchemeKey.self] }
        set { self[MDZColorSchemeKey.self] = newValue }
    }
}
private struct MDZColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

// MARK: - View Modifiers
public struct MDZCardModifier: ViewModifier {
    @Environment(\.mdzColors) private var colors
    public func body(content: Content) -> some View {
        content.background(colors.card).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(colors.border, lineWidth:1))
    }
}
public struct MDZPillModifier: ViewModifier {
    var color: Color
    public func body(content: Content) -> some View {
        content.font(.caption.weight(.semibold)).foregroundColor(.white)
            .padding(.horizontal,10).padding(.vertical,4).background(color).clipShape(Capsule())
    }
}
public struct MDZInputStyleModifier: ViewModifier {
    @Environment(\.mdzColors) private var colors
    public func body(content: Content) -> some View {
        content
            .padding(10)
            .background(colors.navyMid)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
            .foregroundColor(colors.text)
            .font(.system(size: 15))
    }
}
public extension View {
    public func mdzCard() -> some View { modifier(MDZCardModifier()) }
    public func mdzPill(_ color: Color = Color(hex: "5AACCA")) -> some View { modifier(MDZPillModifier(color: color)) }
    public func mdzInputStyle() -> some View { modifier(MDZInputStyleModifier()) }
}

// MARK: - Shared UI Components
public struct StatusPill: View {
    let label: String
    let color: Color
    public init(label: String, color: Color) {
        self.label = label
        self.color = color
    }
    public var body: some View { Text(label).mdzPill(color) }
}

// Stat cell used in Aviation and Home dashboard widgets
public struct PilotStatCell: View {
    let label: String
    let value: String
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    public var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: hSizeClass == .regular ? 24 : 20, weight: .black))
                .foregroundColor(colors.text)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
        }
    }
}

// NOTE: StringDouble is defined in FlightLoad.swift — do not redeclare here

public struct LoadingOverlay: View {
    var message: String
    @Environment(\.mdzColors) private var colors
    public init(message: String = "Loading…") {
        self.message = message
    }
    public var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing:16) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.primary)).scaleEffect(1.4)
                Text(message).foregroundColor(colors.muted).font(.subheadline)
            }
        }
    }
}

public struct EmptyStateView: View {
    var icon: String
    var title: String
    var subtitle: String?
    @Environment(\.mdzColors) private var colors
    public init(icon: String = "tray", title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
    public var body: some View {
        VStack(spacing:12) {
            Image(systemName:icon).font(.system(size:40)).foregroundColor(colors.muted)
            Text(title).font(.headline).foregroundColor(colors.text)
            if let s = subtitle {
                Text(s).font(.subheadline).foregroundColor(colors.muted).multilineTextAlignment(.center)
            }
        }.padding(32)
    }
}

public struct InfoRow: View {
    let label: String
    let value: String
    @Environment(\.mdzColors) private var colors
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    public var body: some View {
        HStack {
            Text(label).foregroundColor(colors.muted)
            Spacer()
            Text(value).foregroundColor(colors.text)
        }.font(.subheadline)
    }
}

// MARK: - Models
public struct User: Codable, Identifiable {
    public let id: Int
    public let username: String
    public let firstName: String?
    public let lastName: String?
    public let email: String?
    public let role: String?
    public let roles: [String]?
    public let totalRigs: Int?
    public let totalJumps: Int?
    public enum CodingKeys: String, CodingKey {
        case id, username, email, role, roles
        case firstName = "first_name"; case lastName = "last_name"
        case totalRigs = "total_rigs"; case totalJumps = "total_jumps"
    }

    /// Build from raw JSON (handles PHP/MySQL type variations)
    public init?(from dict: [String: Any]) {
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
        totalRigs = (dict["total_rigs"] as? Int) ?? (dict["total_rigs"] as? String).flatMap(Int.init)
        totalJumps = (dict["total_jumps"] as? Int) ?? (dict["total_jumps"] as? String).flatMap(Int.init)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        roles = try c.decodeIfPresent([String].self, forKey: .roles)
        totalRigs = try c.decodeIfPresent(Int.self, forKey: .totalRigs)
        totalJumps = try c.decodeIfPresent(Int.self, forKey: .totalJumps)
    }
    public var fullName: String { "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in:.whitespaces) }
    public var displayInitials: String {
        (firstName?.first.map(String.init) ?? "") + (lastName?.first.map(String.init) ?? "")
    }
    private var allRoles: [String] {
        var r = roles ?? []; if let p = role { r.append(p) }; return r.map{$0.lowercased()}
    }
    public var isAdmin: Bool     { allRoles.contains(where:{["admin","master","godmode"].contains($0)}) }
    public var isPilot: Bool     { allRoles.contains("pilot") || isAdmin }
    public var isRigger: Bool    { allRoles.contains("rigger") || isAdmin }
    public var isInspector: Bool { allRoles.contains("inspector") || isAdmin }
    public var primaryRoleLabel: String {
        if isAdmin { return "Admin" }
        if isPilot { return "Pilot" }
        if isRigger { return "Rigger" }
        if isInspector { return "Inspector" }
        if allRoles.contains("manifest") { return "Manifest" }
        if allRoles.contains(where: { ["chief_pilot", "chief pilot"].contains($0) }) { return "Chief Pilot" }
        return role?.capitalized ?? "Member"
    }
}

public struct LoginRequest: Encodable {
    public let username: String
    public let password: String
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}
public struct LoginResponse: Decodable {
    public let ok: Bool
    public let token: String?
    public let user: User?
    public let error: String?
}
public struct MobileResponse<T: Decodable>: Decodable {
    public let ok: Bool
    public let data: T?
    public let error: String?
}

// MARK: - API Error
public enum APIError: LocalizedError {
    case invalidURL, notAuthenticated, serverError(String), decodingError(Error), networkError(Error)
    public var errorDescription: String? {
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
public actor APIClient {
    public static let shared = APIClient()
    public init() {}
    public func request<T:Decodable>(path:String, method:String="GET", body:Encodable?=nil, requiresAuth:Bool=true) async throws -> T {
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
    public func get<T:Decodable>(path:String) async throws -> T { try await request(path:path) }
    public func post<T:Decodable>(path:String, body:Encodable?=nil) async throws -> T { try await request(path:path,method:"POST",body:body) }
}

// MARK: - AppConfig
@MainActor public final class AppConfig: ObservableObject {
    public init() { restore() }
    @Published public var dzName             = "Alaska Skydive Center"
    @Published public var moduleAviation     = "Aviation"
    @Published public var moduleLoft         = "Rigs"
    @Published public var moduleGroundSchool = "Ground School"
    @Published public var moduleManifest     = "Manifest"
    @Published public var theme              = "slate_fire"
    public let poweredBy = "Alaska Skydive Center"
    public func loadConfig() async {
        guard let url = URL(string:"\(kServerURL)/api/config.php") else { return }
        guard let (data,_) = try? await URLSession.shared.data(from:url) else { return }
        struct R: Decodable { let ok:Bool; let data:D? }
        struct D: Decodable {
            let dzName:String?; let av:String?; let loft:String?; let gs:String?; let mf:String?; let theme:String?
            enum CodingKeys:String,CodingKey {
                case dzName="dz_name"; case av="module_aviation"; case loft="module_loft"
                case gs="module_ground_school"; case mf="module_manifest"; case theme="theme"
            }
        }
        if let r = try? JSONDecoder().decode(R.self, from:data), r.ok, let d = r.data {
            dzName = Self.normalizeDzName(d.dzName ?? dzName)
            moduleAviation = d.av ?? moduleAviation
            moduleLoft = d.loft ?? moduleLoft; moduleGroundSchool = d.gs ?? moduleGroundSchool
            moduleManifest = d.mf ?? moduleManifest
            // Keep app theme as Slate & Fire; do not overwrite from server
            let ud = UserDefaults.standard
            ud.set(dzName, forKey:"cfg_dz"); ud.set(moduleAviation, forKey:"cfg_av")
            ud.set(moduleLoft, forKey:"cfg_loft"); ud.set(moduleGroundSchool, forKey:"cfg_gs")
            ud.set(moduleManifest, forKey:"cfg_mf"); ud.set(theme, forKey:"cfg_theme")
        }
    }
    /// Replace legacy product default with dropzone branding.
    private static func normalizeDzName(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Alaska Skydive Center" }
        if t.lowercased() == "malfunction dz" { return "Alaska Skydive Center" }
        return t
    }

    private func restore() {
        let ud = UserDefaults.standard
        if let v = ud.string(forKey: "cfg_dz"), !v.isEmpty {
            dzName = Self.normalizeDzName(v)
            if dzName != v { ud.set(dzName, forKey: "cfg_dz") }
        }
        if let v=ud.string(forKey:"cfg_av"),!v.isEmpty{moduleAviation=v}
        if let v=ud.string(forKey:"cfg_loft"),!v.isEmpty{moduleLoft=v}
        if let v=ud.string(forKey:"cfg_gs"),!v.isEmpty{moduleGroundSchool=v}
        if let v=ud.string(forKey:"cfg_mf"),!v.isEmpty{moduleManifest=v}
        if let v=ud.string(forKey:"cfg_theme"),!v.isEmpty{theme=v}
    }
}

// MARK: - AuthManager
@MainActor public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    public init() {
        if let token = KeychainHelper.readToken(), !token.isEmpty {
            print("🚀 APP START: found existing token, restoring session")
            isAuthenticated = true
            sessionID = token
            Task { await refreshCurrentUser() }
        } else {
            print("🚀 APP START: no token found, showing login")
        }
    }

    @Published public var isAuthenticated = false
    @Published public var currentUser: User?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public private(set) var sessionID: String = UUID().uuidString

    public var isLoggedIn: Bool { isAuthenticated }

    public func login(username: String, password: String) async {
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

    public func logout() {
        print("🚪 LOGOUT: clearing session")
        KeychainHelper.deleteToken()
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        sessionID = UUID().uuidString
        print("🚪 LOGOUT: new sessionID=\(sessionID.prefix(20))")
    }

    public func refreshCurrentUser() async {
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
public final class PushRegistration: ObservableObject {
    public static let shared = PushRegistration()

    public init() {}

    /// For Profile diagnostics: "received" | "sent" | "skipped" | "failed" | "denied" | nil
    @Published public var lastStatus: String?
    @Published public var lastError: String?

    public func requestPermissionAndRegister() {
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
                DispatchQueue.main.async {
                    self.lastStatus = "denied"
                    self.lastError = "Enable in Settings"
                }
            @unknown default:
                break
            }
        }
    }

    public func sendTokenToBackend(_ deviceToken: String) async {
        lastStatus = "received"
        lastError = nil
        guard let token = KeychainHelper.readToken(), !token.isEmpty else {
            lastStatus = "skipped"
            lastError = "No auth token"
            print("⚠️ PUSH: Skipped — no auth token (user not logged in?)")
            return
        }
        guard let url = URL(string: "\(kServerURL)/api/push/register.php") else {
            lastStatus = "failed"
            lastError = "Invalid URL"
            return
        }
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
                lastStatus = "sent"
                lastError = nil
                print("✅ PUSH: Registered at \(kServerURL)/api/push/register.php (HTTP \(code))")
            } else {
                lastStatus = "failed"
                lastError = "HTTP \(code): \(body)"
                print("⚠️ PUSH: Register failed HTTP \(code): \(body)")
            }
        } catch {
            lastStatus = "failed"
            lastError = error.localizedDescription
            print("⚠️ PUSH: Register request failed: \(error.localizedDescription)")
        }
    }
}