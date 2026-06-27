// ASC Packers — loft & DZ rig packing for packers, riggers, and master riggers.
import SwiftUI
import UIKit
import UserNotifications
import MalfunctionDZCore

@main
struct ASCPackersApp: App {
    @UIApplicationDelegateAdaptor(ASCPackersAppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthManager.shared
    @StateObject private var config = AppConfig()
    @StateObject private var tabSelect = TabSelection.shared
    @StateObject private var pushNav = PushNavigationTarget.shared

    var body: some Scene {
        WindowGroup {
            ASCPackersContentRootView()
                .environmentObject(auth)
                .environmentObject(config)
                .environmentObject(tabSelect)
                .environmentObject(pushNav)
        }
    }
}

// MARK: - Content root

struct ASCPackersContentRootView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var pushNav: PushNavigationTarget
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isAuthenticated {
                if auth.currentUser?.canAccessASCPackersApp == true {
                    ASCPackersTabView()
                        .id(auth.sessionID)
                } else {
                    PackerAppAccessDeniedView()
                }
            } else {
                LoginView()
            }
        }
        .environment(\.appShell, .packer)
        .mdzThemed(config.theme)
        .task { await config.loadConfig() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, auth.isAuthenticated, auth.currentUser?.canAccessASCPackersApp == true {
                PushRegistration.shared.requestPermissionAndRegister()
            }
        }
    }
}

// MARK: - Access denied

struct PackerAppAccessDeniedView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(spacing: 28) {
            MDZIconChip("backpack.fill", color: colors.loft, size: 72)
            VStack(spacing: 12) {
                Text("ASC Packers")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, colors.loft], startPoint: .leading, endPoint: .trailing)
                    )
                Text("This app is for ASC packers, riggers, and inspectors. Use ASC Staff for full operations, or the ASC app if you are a student or skydiver.")
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

// MARK: - Packer tabs

struct ASCPackersTabView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var config: AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @EnvironmentObject private var pushNav: PushNavigationTarget
    @Environment(\.mdzColors) private var colors

    init() {
        MDZChrome.applyTabBar()
        TabSelection.shared.selected = 0
    }

    var body: some View {
        TabView(selection: $tabSelect.selected) {
            NavigationStack {
                PackerGearRoomRootView()
            }
            .tabItem { Label("Gear Room", systemImage: "square.stack.3d.up.fill") }
            .tag(0)

            NavigationStack {
                PackerSquawksView()
            }
            .tabItem { Label("Squawks", systemImage: "exclamationmark.triangle.fill") }
            .tag(1)

            if auth.currentUser?.canInspectDzRigs == true {
                NavigationStack {
                    PackerJumpCheckRootView()
                }
                .tabItem { Label("25 Jump Check", systemImage: "figure.fall") }
                .tag(2)
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

final class ASCPackersAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        ASC.role = .packers
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
