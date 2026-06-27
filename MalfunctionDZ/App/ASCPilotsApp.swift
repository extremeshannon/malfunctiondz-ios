// ASC Pilots — aviation-focused app for pilots, chief pilot, and admin (testing & training).
import SwiftUI
import UIKit
import UserNotifications
import MalfunctionDZCore

@main
struct ASCPilotsApp: App {
    @UIApplicationDelegateAdaptor(ASCPilotsAppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthManager.shared
    @StateObject private var config = AppConfig()
    @StateObject private var tabSelect = TabSelection.shared
    @StateObject private var pushNav = PushNavigationTarget.shared

    var body: some Scene {
        WindowGroup {
            ASCPilotsContentRootView()
                .environmentObject(auth)
                .environmentObject(config)
                .environmentObject(tabSelect)
                .environmentObject(pushNav)
        }
    }
}

// MARK: - Content root

struct ASCPilotsContentRootView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var pushNav: PushNavigationTarget
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isAuthenticated {
                if auth.currentUser?.canAccessASCPilotsApp == true {
                    ASCPilotsTabView()
                        .id(auth.sessionID)
                } else {
                    PilotAppAccessDeniedView()
                }
            } else {
                LoginView()
            }
        }
        .environment(\.appShell, .pilot)
        .mdzThemed(config.theme)
        .task { await config.loadConfig() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, auth.isAuthenticated, auth.currentUser?.canAccessASCPilotsApp == true {
                PushRegistration.shared.requestPermissionAndRegister()
            }
        }
    }
}

// MARK: - Access denied

struct PilotAppAccessDeniedView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(spacing: 28) {
            MDZIconChip("airplane", color: colors.aviation, size: 72)
            VStack(spacing: 12) {
                Text("ASC Pilots")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, colors.primary], startPoint: .leading, endPoint: .trailing)
                    )
                Text("This app is for ASC pilots, chief pilot, and admin training. Use the ASC app for student and skydiver features, or MalfunctionDZ for full operations.")
                    .font(.system(size: 15))
                    .foregroundColor(colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            if let user = auth.currentUser {
                Text("Signed in as \(user.username) — roles: \((user.roles ?? [user.role ?? "none"]).joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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

// MARK: - Pilot tabs

struct ASCPilotsTabView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @EnvironmentObject private var pushNav: PushNavigationTarget
    @Environment(\.mdzColors) private var colors

    init() {
        MDZChrome.applyTabBar()
    }

    var body: some View {
        TabView(selection: $tabSelect.selected) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            if auth.currentUser?.canAccessAviation == true {
                AviationRootView()
                    .tabItem { Label(config.moduleAviation, systemImage: "airplane") }
                    .tag(1)
            }

            if auth.currentUser?.canAccessASCPilotsApp == true {
                GroundSchoolView()
                    .tabItem { Label("Training", systemImage: "graduationcap.fill") }
                    .tag(3)
            }

            if auth.currentUser?.canAccessASCPilotsApp == true {
                PilotCardRootView()
                    .tabItem { Label("Pilot Card", systemImage: "person.text.rectangle.fill") }
                    .tag(7)
            }

            if auth.currentUser?.canAccessCalendar == true {
                CalendarRootView()
                    .tabItem { Label("Events", systemImage: "calendar") }
                    .tag(5)
            }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(9)
        }
        .accentColor(colors.accent)
        .preferredColorScheme(MDZTheme.colorScheme(for: config.theme))
        .task { await config.loadConfig() }
        .onChange(of: pushNav.pendingTap?.id) { _, _ in
            if pushNav.pendingTap != nil { tabSelect.selected = 0 }
        }
        .sheet(item: $pushNav.pendingTap) { tap in
            NotificationDetailSheet(tap: tap) { pushNav.dismiss() }
        }
    }
}

// MARK: - App delegate (push)

final class ASCPilotsAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        ASC.role = .pilot
        #if DEBUG
        ASCFontDiagnostics.logRegisteredASCFonts()
        #endif
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let type = (userInfo["type"] as? String) ?? ""
        if type == "dz_status" {
            NotificationCenter.default.post(name: .dzStatusDidUpdateFromPush, object: nil)
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let type = (userInfo["type"] as? String) ?? ""
        if type == "dz_status" {
            NotificationCenter.default.post(name: .dzStatusDidUpdateFromPush, object: nil)
        }
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any] else { return }
        let title = (alert["title"] as? String) ?? "Notification"
        let body = (alert["body"] as? String) ?? ""
        var payload: [String: Any] = [:]
        for (k, v) in userInfo {
            if let key = k as? String, key != "aps" {
                payload[key] = v
            }
        }
        let pushType = type.isEmpty ? "unknown" : type
        await MainActor.run {
            PushNavigationTarget.shared.handleTap(type: pushType, title: title, body: body, payload: payload)
        }
    }
}
