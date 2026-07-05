// HHIO — parachute loft: full rig inventory, reserve repacks, and pack record stats.
import SwiftUI
import UIKit
import UserNotifications
import MalfunctionDZCore

#if ASC_HHIO
@main
#endif
struct HHIOApp: App {
    @UIApplicationDelegateAdaptor(HHIOAppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthManager.shared
    @StateObject private var config = AppConfig()
    @StateObject private var tabSelect = TabSelection.shared
    @StateObject private var pushNav = PushNavigationTarget.shared

    var body: some Scene {
        WindowGroup {
            HHIOContentRootView()
                .environmentObject(auth)
                .environmentObject(config)
                .environmentObject(tabSelect)
                .environmentObject(pushNav)
        }
    }
}

struct HHIOContentRootView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isAuthenticated {
                if auth.currentUser?.canAccessHHIOApp == true {
                    HHIOTabView()
                        .id(auth.sessionID)
                } else {
                    HHIOAccessDeniedView()
                }
            } else {
                LoginView()
            }
        }
        .environment(\.appShell, .hhio)
        .mdzThemed(config.theme)
        .task { await config.loadConfig() }
        .onChange(of: auth.isAuthenticated) { wasAuthenticated, isAuthenticated in
            if isAuthenticated && !wasAuthenticated {
                tabSelect.selected = 0
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, auth.isAuthenticated, auth.currentUser?.canAccessHHIOApp == true {
                PushRegistration.shared.requestPermissionAndRegister()
            }
        }
    }
}

struct HHIOAccessDeniedView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(spacing: 28) {
            MDZIconChip("backpack.fill", color: colors.loft, size: 72)
            VStack(spacing: 12) {
                Text("HHIO Loft")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, colors.loft], startPoint: .leading, endPoint: .trailing)
                    )
                Text("This app is for parachute loft staff — riggers and master riggers. Use MalfunctionDZ for dropzone operations or ASC Packers for DZ pack jobs.")
                    .font(.system(size: 15))
                    .foregroundColor(colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            MDZPrimaryButton("Sign Out") { auth.logout() }
                .padding(.horizontal, 40)
        }
        .padding(28)
        .mdzContentCard(gloryBar: true, glass: true)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mdzScreenBackground()
    }
}

struct HHIOTabView: View {
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.mdzColors) private var colors

    init() {
        MDZChrome.applyTabBar()
    }

    var body: some View {
        TabView(selection: $tabSelect.selected) {
            NavigationStack {
                LoftRootView()
            }
            .tabItem { Label("Loft", systemImage: "backpack.fill") }
            .tag(0)

            NavigationStack {
                LoftRecordsRootView()
            }
            .tabItem { Label("Pack Records", systemImage: "doc.text.fill") }
            .tag(1)

            NavigationStack {
                LoftCustomersRootView()
            }
            .tabItem { Label("Customers", systemImage: "person.2.fill") }
            .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(9)
        }
        .accentColor(colors.loft)
        .preferredColorScheme(MDZTheme.colorScheme(for: config.theme))
        .task { await config.loadConfig() }
    }
}

final class HHIOAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        MDZChrome.applyNavigationBar()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { await PushRegistration.shared.sendTokenToBackend(tokenString) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ Push registration failed: \(error.localizedDescription)")
    }
}
