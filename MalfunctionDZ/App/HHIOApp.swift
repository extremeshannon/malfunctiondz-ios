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
        .environment(\.mdzColors, MDZColorSet.for(config.theme))
        .environment(\.mdzColorScheme, config.theme == "slate_fire" ? .light : .dark)
        .task { await config.loadConfig() }
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
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "backpack.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(colors.loft)
                Text("HHIO Loft")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(colors.text)
                Text("This app is for parachute loft staff — riggers and master riggers. Use MalfunctionDZ for dropzone operations or ASC Packers for DZ pack jobs.")
                    .font(.system(size: 15))
                    .foregroundColor(colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Sign Out") { auth.logout() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(colors.loft)
                    .clipShape(Capsule())
            }
        }
    }
}

struct HHIOTabView: View {
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.mdzColors) private var colors

    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Color(hex: "1E2D38"))
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
        TabSelection.shared.selected = 0
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

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(9)
        }
        .accentColor(colors.loft)
        .preferredColorScheme(config.theme == "slate_fire" ? .light : .dark)
        .task { await config.loadConfig() }
    }
}

final class HHIOAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 12/255, green: 29/255, blue: 53/255, alpha: 1)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
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
