// Alaska Skydive Center member app — same API/auth as the staff app; slim tab shell only.
import SwiftUI
import UIKit
import UserNotifications
import MalfunctionDZCore

@main
struct AlaskaSkydiveCenterApp: App {
    @UIApplicationDelegateAdaptor(ASCAppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthManager.shared
    @StateObject private var config = AppConfig()
    @StateObject private var tabSelect = TabSelection.shared
    @StateObject private var pushNav = PushNavigationTarget.shared

    var body: some Scene {
        WindowGroup {
            ASCContentRootView()
                .environmentObject(auth)
                .environmentObject(config)
                .environmentObject(tabSelect)
                .environmentObject(pushNav)
        }
    }
}

// MARK: - Content root
struct ASCContentRootView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var pushNav: PushNavigationTarget
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isRestoringSession {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(config.theme == "asc_midnight" ? .white : nil)
                    Text("Restoring session…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mdzThemed(config.theme)
            } else if auth.isAuthenticated {
                ASCMemberTabView()
                    .id(auth.sessionID)
            } else {
                LoginView()
            }
        }
        .environment(\.appShell, .member)
        .mdzThemed(config.theme)
        .task { await config.loadConfig() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, auth.isAuthenticated {
                PushRegistration.shared.requestPermissionAndRegister()
            }
        }
    }
}

// MARK: - Member tabs (skydivers & students — role-gated, same tags as staff app for Home tiles)

struct ASCMemberTabView: View {
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

            if auth.currentUser?.showsASCMemberGroundSchoolTab == true {
                GroundSchoolView()
                    .tabItem { Label(config.moduleGroundSchool, systemImage: "graduationcap.fill") }
                    .tag(3)
            }

            if auth.currentUser?.showsASCMemberTrainingTabs == true {
                ALicenseProgressView()
                    .tabItem { Label("A-License", systemImage: "checklist.checked") }
                    .tag(2)
            }

            if auth.currentUser?.canAccessLogbook == true {
                LogbookRootView()
                    .tabItem { Label("Logbook", systemImage: "book.closed.fill") }
                    .tag(4)
            }

            if auth.currentUser?.canAccessGearRoom == true {
                MyRigsView()
                    .tabItem { Label("Gear Room", systemImage: "briefcase.fill") }
                    .tag(6)
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
final class ASCAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        ASC.role = .skydiver
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
