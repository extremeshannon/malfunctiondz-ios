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
            if auth.isAuthenticated {
                ASCMemberTabView()
                    .id(auth.sessionID)
            } else {
                LoginView()
            }
        }
        .environment(\.appShell, .member)
        .environment(\.mdzColors, MDZColorSet.for(config.theme))
        .environment(\.mdzColorScheme, config.theme == "slate_fire" ? .light : .dark)
        .task { await config.loadConfig() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, auth.isAuthenticated {
                PushRegistration.shared.requestPermissionAndRegister()
            }
        }
    }
}

// MARK: - Member tabs (same tab tags as staff app where possible so HomeView tile taps work)
struct ASCMemberTabView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @EnvironmentObject private var pushNav: PushNavigationTarget
    @Environment(\.mdzColors) private var colors

    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Color(hex: "1E2D38"))
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        TabView(selection: $tabSelect.selected) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            if auth.currentUser?.canAccessLogbook == true {
                LogbookRootView()
                    .tabItem { Label("Logbook", systemImage: "book.closed.fill") }
                    .tag(4)
            }

            // Member app: personal rigs only — show tab for skydivers (logbook) even if login omitted totalRigs.
            if let u = auth.currentUser, u.canAccessLogbook || u.canAccessMyRigs {
                MyRigsView()
                    .tabItem { Label("My Rigs", systemImage: "briefcase.fill") }
                    .tag(6)
            }

            if auth.currentUser?.canAccessGroundSchool == true {
                GroundSchoolView()
                    .tabItem { Label(config.moduleGroundSchool, systemImage: "graduationcap.fill") }
                    .tag(3)
            }

            if auth.currentUser?.canAccessCalendar == true {
                CalendarRootView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(5)
            }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(9)
        }
        .accentColor(colors.accent)
        .preferredColorScheme(config.theme == "slate_fire" ? .light : .dark)
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

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        let type = (userInfo["type"] as? String) ?? ""
        if type == "dz_status" {
            NotificationCenter.default.post(name: .dzStatusDidUpdateFromPush, object: nil)
        }
        return [.banner, .sound, .badge]
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
