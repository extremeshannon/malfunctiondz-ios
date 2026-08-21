import Foundation
import MalfunctionDZCore

@MainActor
final class ManifestSessionStore: ObservableObject {
    private static let tokenKey = "auth_token"
    private static let environmentKey = "manifest_app_environment_v2"

    /// When true, use MalfunctionDZ AuthManager token / kServerURL; Sign Out exits module only.
    let isEmbedded: Bool

    /// Suppress host-change logout during `init` property assignment.
    private var acceptsEnvironmentChanges = false

    @Published private(set) var token: String?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: ManifestUserProfile?
    @Published var environment: ManifestAppEnvironment = ManifestAppConfig.activeEnvironment {
        didSet {
            guard acceptsEnvironmentChanges, oldValue != environment else { return }
            UserDefaults.standard.set(environment.rawValue, forKey: Self.environmentKey)
            // Keep shared staff `kServerURL` in sync so Manifest + ASCStaff hit the same host.
            MDZServerEnvironment.current = environment.asSharedEnvironment
            // Tokens are host-specific — never reuse Local auth against Live (or the reverse).
            clearAuthForEnvironmentChange()
            configureAPIClient()
        }
    }

    /// Called when embedded Sign Out / Exit is tapped.
    var onExitEmbedded: (() -> Void)?

    private(set) lazy var apiClient = makeClient()

    init(embedded: Bool = false) {
        self.isEmbedded = embedded
        if embedded {
            // ASC Staff login owns demo/live; don't let a stale Manifest-only default override it.
            environment = ManifestAppEnvironment(shared: MDZServerEnvironment.current)
            adoptSharedAuthToken()
        } else if let savedEnv = UserDefaults.standard.string(forKey: Self.environmentKey),
                  let env = ManifestAppEnvironment(rawValue: savedEnv) {
            environment = env
            if let savedToken = ManifestKeychainHelper.load(account: Self.tokenKey) {
                token = savedToken
                isAuthenticated = true
            }
        } else {
            environment = ManifestAppEnvironment(shared: MDZServerEnvironment.current)
            if let savedToken = ManifestKeychainHelper.load(account: Self.tokenKey) {
                token = savedToken
                isAuthenticated = true
            }
        }
        configureAPIClient()
        acceptsEnvironmentChanges = true
    }

    func syncEnvironmentFromSharedServer() {
        let next = ManifestAppEnvironment(shared: MDZServerEnvironment.current)
        if next != environment {
            environment = next
        } else {
            // Still refresh client/token when host label matches but AuthManager re-logged in.
            adoptSharedAuthToken()
        }
    }

    func adoptSharedAuthToken() {
        if let tok = KeychainHelper.readToken(), !tok.isEmpty {
            token = tok
            isAuthenticated = true
        } else {
            token = nil
            isAuthenticated = false
            currentUser = nil
        }
        configureAPIClient()
    }

    func configureAPIClient() {
        apiClient = makeClient()
    }

    private func makeClient() -> ManifestAPIClient {
        let client = ManifestAPIClient(environment: environment, token: token)
        client.onUnauthorized = { [weak self] in
            Task { @MainActor in self?.handleUnauthorized() }
        }
        return client
    }

    /// Drop Keychain/session when the API host changes so Live can't show Local seed data.
    private func clearAuthForEnvironmentChange() {
        token = nil
        isAuthenticated = false
        currentUser = nil
        if !isEmbedded {
            ManifestKeychainHelper.delete(account: Self.tokenKey)
        } else {
            // Shared staff session must re-auth against the new host.
            AuthManager.shared.logout()
            AuthManager.shared.serverEnvironment = environment.asSharedEnvironment
        }
    }

    func signIn(token: String, user: ManifestUserProfile? = nil) {
        self.token = token
        isAuthenticated = true
        currentUser = user
        if !isEmbedded {
            ManifestKeychainHelper.save(token, account: Self.tokenKey)
        }
        configureAPIClient()
    }

    func signOut() {
        if isEmbedded {
            onExitEmbedded?()
            return
        }
        token = nil
        isAuthenticated = false
        currentUser = nil
        ManifestKeychainHelper.delete(account: Self.tokenKey)
        configureAPIClient()
    }

    private func handleUnauthorized() {
        if isEmbedded {
            // Shared MDZ session expired — exit module; ContentRootView will show login.
            onExitEmbedded?()
            return
        }
        signOut()
    }

    func refreshProfile() async {
        guard isAuthenticated else { return }
        do {
            let me = try await apiClient.fetchMe()
            if me.ok, let user = me.user {
                currentUser = user
            }
        } catch {
            if case ManifestAPIError.unauthorized = error {
                handleUnauthorized()
            }
        }
    }
}

extension ManifestAppEnvironment {
    init(shared: MDZServerEnvironment) {
        switch shared {
        case .local: self = .local
        case .demo: self = .demo
        case .production: self = .production
        }
    }

    var asSharedEnvironment: MDZServerEnvironment {
        switch self {
        case .local: return .local
        case .demo: return .demo
        case .production: return .production
        }
    }

    /// Login picker cases — Local only in DEBUG (matches staff login).
    static var loginCases: [ManifestAppEnvironment] {
        #if DEBUG
        return [.local, .demo, .production]
        #else
        return [.demo, .production]
        #endif
    }
}
