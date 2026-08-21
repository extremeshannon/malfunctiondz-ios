import SwiftUI
import MalfunctionDZCore

/// Full-screen ASC Manifest ops module hosted inside MalfunctionDZ / ASCStaff.
/// Preserves Night Ops `ManifestMainShellView` layout and behavior as-is.
/// Standalone desk app: scheme **ASCManifest** (`ASCManifestApp` / `ManifestRootView`).
struct ManifestHostView: View {
    var onExit: (() -> Void)? = nil

    @StateObject private var session = ManifestSessionStore(embedded: true)

    var body: some View {
        Group {
            if session.isAuthenticated {
                ManifestMainShellView()
            } else {
                ManifestLoginView()
            }
        }
        .environmentObject(session)
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            session.onExitEmbedded = onExit
            session.syncEnvironmentFromSharedServer()
            session.adoptSharedAuthToken()
        }
        .onReceive(NotificationCenter.default.publisher(for: .manifestExitRequested)) { _ in
            onExit?()
        }
    }
}

extension Notification.Name {
    static let manifestExitRequested = Notification.Name("manifestExitRequested")
}
