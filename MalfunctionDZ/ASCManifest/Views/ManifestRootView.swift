import SwiftUI

struct ManifestRootView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @State private var bootstrapped = false

    var body: some View {
        Group {
            if session.isAuthenticated {
                ManifestMainShellView()
            } else {
                ManifestLoginView()
            }
        }
        .animation(.easeInOut, value: session.isAuthenticated)
        .task {
            guard !bootstrapped else { return }
            bootstrapped = true
            if session.isAuthenticated {
                await session.refreshProfile()
            }
        }
    }
}

#Preview {
    ManifestRootView()
        .environmentObject(ManifestSessionStore())
}
