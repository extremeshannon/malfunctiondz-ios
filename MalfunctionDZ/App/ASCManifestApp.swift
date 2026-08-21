// ASC Manifest — standalone Night Ops desk ops app (loads, check-in, ID scan).
import SwiftUI
import MalfunctionDZCore

@main
struct ASCManifestApp: App {
    @StateObject private var session = ManifestSessionStore(embedded: false)

    var body: some Scene {
        WindowGroup {
            ManifestRootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // Keep shared staff demo/live picker in sync when launched standalone.
                    session.syncEnvironmentFromSharedServer()
                }
        }
    }
}
