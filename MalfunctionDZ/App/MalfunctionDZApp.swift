// File: ASC/App/MalfunctionDZApp.swift
// iPad: Uses NavigationSplitView sidebar+detail on regular width,
//       falls back to TabView on compact (iPhone) automatically.
//       Supports all devices (iPhone + iPad); operations can be run from iPad.
import SwiftUI
import UIKit
import UserNotifications

@main
struct MalfunctionDZApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth       = AuthManager.shared
    @StateObject private var config     = AppConfig()
    @StateObject private var tabSelect  = TabSelection.shared
    @StateObject private var pushNav    = PushNavigationTarget.shared

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(auth)
                .environmentObject(config)
                .environmentObject(tabSelect)
                .environmentObject(pushNav)
        }
    }
}

// MARK: - Push navigation (notification tap → show content)
struct PendingPushTap: Identifiable {
    let id = UUID()
    let type: String
    let title: String
    let body: String
    let announcement: String?
    let payload: [String: Any]?
}

@MainActor
final class PushNavigationTarget: ObservableObject {
    static let shared = PushNavigationTarget()
    @Published var pendingTap: PendingPushTap?
    func handleTap(type: String, title: String, body: String, payload: [String: Any]) {
        let announcement = payload["announcement"] as? String
        pendingTap = PendingPushTap(type: type, title: title, body: body, announcement: announcement, payload: payload)
    }
    func dismiss() { pendingTap = nil }
}

// MARK: - Content Root
struct ContentRootView: View {
    @EnvironmentObject private var auth:    AuthManager
    @EnvironmentObject private var pushNav: PushNavigationTarget
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if auth.isAuthenticated {
                MDZRootView()
                    .id(auth.sessionID)
            } else {
                LoginView()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active, auth.isAuthenticated {
                PushRegistration.shared.requestPermissionAndRegister()
            }
        }
    }
}

// MARK: - Root: adapts to size class
struct MDZRootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @EnvironmentObject private var auth:      AuthManager
    @EnvironmentObject private var config:    AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @EnvironmentObject private var pushNav:   PushNavigationTarget

    var body: some View {
        Group {
            if hSizeClass == .regular {
                MDZSplitView()
            } else {
                MDZTabView()
            }
        }
        .task { await config.loadConfig() }
        .onChange(of: pushNav.pendingTap?.id) { _ in
            if pushNav.pendingTap != nil { tabSelect.selected = 0 }
        }
        .sheet(item: $pushNav.pendingTap) { tap in
            NotificationDetailSheet(tap: tap) { pushNav.dismiss() }
        }
    }
}

// MARK: - iPad: NavigationSplitView
struct MDZSplitView: View {
    @EnvironmentObject private var auth:      AuthManager
    @EnvironmentObject private var config:    AppConfig
    @EnvironmentObject private var tabSelect: TabSelection

    // Maps our tab tags to a stable selection type
    @State private var selectedModule: AppModule = .home

    var body: some View {
        NavigationSplitView {
            // ── Sidebar ──────────────────────────────────────
            List {
                // DZ name header
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.dzName.uppercased())
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.mdzText.opacity(0.9))
                            .tracking(1)
                        if let user = auth.currentUser {
                            Text(user.roleDisplayLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.mdzMuted)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section("OPERATIONS") {
                    SidebarButton(icon: "house.fill",         title: "Home",                  selected: selectedModule == .home)        { selectedModule = .home }
                    if auth.currentUser?.canAccessAviation == true {
                        SidebarButton(icon: "airplane",       title: config.moduleAviation,   selected: selectedModule == .aviation)    { selectedModule = .aviation }
                    }
                    if auth.currentUser?.canAccessLoft == true {
                        SidebarButton(icon: "backpack.fill",  title: config.moduleLoft,       selected: selectedModule == .loft)        { selectedModule = .loft }
                    }
                    if auth.currentUser?.canAccessMyRigs == true {
                        SidebarButton(icon: "briefcase.fill", title: "My Rigs",               selected: selectedModule == .myRigs)     { selectedModule = .myRigs }
                    }
                    if auth.currentUser?.canAccessDzRigs == true {
                        SidebarButton(icon: "square.stack.3d.up.fill", title: "DZ Rigs",       selected: selectedModule == .dzRigs)     { selectedModule = .dzRigs }
                    }
                    if auth.currentUser?.canAccess25JumpCheck == true {
                        SidebarButton(icon: "figure.fall", title: "25 Jump Check", selected: selectedModule == .jumpCheck) { selectedModule = .jumpCheck }
                    }
                    if auth.currentUser?.canAccessGroundSchool == true {
                        SidebarButton(icon: "graduationcap.fill", title: config.moduleGroundSchool, selected: selectedModule == .groundSchool) { selectedModule = .groundSchool }
                    }
                    if auth.currentUser?.canAccessLogbook == true {
                        SidebarButton(icon: "book.closed.fill", title: "Logbook", selected: selectedModule == .logbook) { selectedModule = .logbook }
                    }
                    if auth.currentUser?.canAccessCalendar == true {
                        SidebarButton(icon: "calendar", title: "Calendar", selected: selectedModule == .calendar) { selectedModule = .calendar }
                    }
                    if auth.currentUser?.canManageUsers == true {
                        SidebarButton(icon: "person.2.fill", title: "Users", selected: selectedModule == .users) { selectedModule = .users }
                    }
                    if auth.currentUser?.canManageLMS == true {
                        SidebarButton(icon: "pencil.and.list.clipboard", title: "Manage LMS", selected: selectedModule == .manageLMS) { selectedModule = .manageLMS }
                    }
                }

                Section("ACCOUNT") {
                    SidebarButton(icon: "person.fill", title: "Profile", selected: selectedModule == .profile) { selectedModule = .profile }
                    Button {
                        auth.logout()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.mdzDanger)
                                .frame(width: 22)
                            Text("Sign Out")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.mdzDanger)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("MalfunctionDZ")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.mdzBackground)
            .scrollContentBackground(.hidden)

        } detail: {
            // ── Detail pane ──────────────────────────────────
            Group {
                switch selectedModule {
                case .home:         HomeView()
                case .aviation:     AviationRootView()
                case .loft:         LoftRootView()
                case .myRigs:       MyRigsView()
                case .dzRigs:       DzRigsView()
                case .jumpCheck:    JumpCheckView()
                case .groundSchool: GroundSchoolView()
                case .logbook:      LogbookRootView()
                case .calendar:     CalendarRootView()
                case .users:        UsersView()
                case .manageLMS:    LMSEditRootView()
                case .profile:      ProfileView()
                }
            }
            // Sync tab selection from home-screen tile taps
            .onChange(of: tabSelect.selected) { tag in
                selectedModule = AppModule(tag: tag) ?? .home
            }
        }
        .accentColor(.mdzRed)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sidebar button
struct SidebarButton: View {
    let icon:     String
    let title:    String
    let selected: Bool
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selected ? .mdzRed : .mdzMuted)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? .mdzText : .mdzMuted)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(selected ? Color.mdzRed.opacity(0.12) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}

// MARK: - AppModule enum (maps tab tags)
enum AppModule: Hashable {
    case home, aviation, loft, myRigs, dzRigs, groundSchool, logbook, jumpCheck, calendar, users, manageLMS, profile

    /// Map fixed tab tags → module
    init?(tag: Int) {
        switch tag {
        case 0:  self = .home
        case 1:  self = .aviation
        case 2:  self = .loft
        case 6:  self = .myRigs
        case 7:  self = .dzRigs
        case 3:  self = .groundSchool
        case 4:  self = .logbook
        case 11: self = .jumpCheck
        case 5:  self = .calendar
        case 8:  self = .users
        case 10: self = .manageLMS
        case 9:  self = .profile
        default: return nil
        }
    }

    var tag: Int {
        switch self {
        case .home:         return 0
        case .aviation:     return 1
        case .loft:         return 2
        case .myRigs:       return 6
        case .dzRigs:       return 7
        case .groundSchool: return 3
        case .logbook:      return 4
        case .jumpCheck:    return 11
        case .calendar:     return 5
        case .users:        return 8
        case .manageLMS:    return 10
        case .profile:      return 9
        }
    }
}

// MARK: - iPhone: TabView (unchanged behaviour)
struct MDZTabView: View {
    @EnvironmentObject private var auth:      AuthManager
    @EnvironmentObject private var config:    AppConfig
    @EnvironmentObject private var tabSelect: TabSelection

    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Color.mdzNavyMid)
        UITabBar.appearance().standardAppearance   = a
        UITabBar.appearance().scrollEdgeAppearance = a
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

            if auth.currentUser?.canAccessLoft == true {
                LoftRootView()
                    .tabItem { Label(config.moduleLoft, systemImage: "backpack.fill") }
                    .tag(2)
            }

            if auth.currentUser?.canAccessMyRigs == true {
                MyRigsView()
                    .tabItem { Label("My Rigs", systemImage: "briefcase.fill") }
                    .tag(6)
            }

            if auth.currentUser?.canAccessDzRigs == true {
                DzRigsView()
                    .tabItem { Label("DZ Rigs", systemImage: "square.stack.3d.up.fill") }
                    .tag(7)
            }

            if auth.currentUser?.canAccess25JumpCheck == true {
                JumpCheckView()
                    .tabItem { Label("25 Jump", systemImage: "figure.fall") }
                    .tag(11)
            }

            if auth.currentUser?.canAccessGroundSchool == true {
                GroundSchoolView()
                    .tabItem { Label(config.moduleGroundSchool, systemImage: "graduationcap.fill") }
                    .tag(3)
            }

            if auth.currentUser?.canAccessLogbook == true {
                LogbookRootView()
                    .tabItem { Label("Logbook", systemImage: "book.closed.fill") }
                    .tag(4)
            }

            if auth.currentUser?.canAccessCalendar == true {
                CalendarRootView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(5)
            }

            if auth.currentUser?.canManageUsers == true {
                UsersView()
                    .tabItem { Label("Users", systemImage: "person.2.fill") }
                    .tag(8)
            }

            if auth.currentUser?.canManageLMS == true {
                LMSEditRootView()
                    .tabItem { Label("Manage LMS", systemImage: "pencil.and.list.clipboard") }
                    .tag(10)
            }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(9)
        }
        .accentColor(.mdzRed)
    }
}

// MARK: - App Delegate (push notifications, nav bar appearance)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Brighter navigation titles on dark backgrounds
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
        print("📲 PUSH: Device token received (\(tokenString.count) chars), sending to backend...")
        Task { await PushRegistration.shared.sendTokenToBackend(tokenString) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ Push registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any] else { return }
        let title = (alert["title"] as? String) ?? "Notification"
        let body  = (alert["body"]  as? String) ?? ""
        var payload: [String: Any] = [:]
        for (k, v) in userInfo {
            if let key = k as? String, key != "aps" {
                payload[key] = v
            }
        }
        let type = (payload["type"] as? String) ?? "unknown"
        await MainActor.run {
            PushNavigationTarget.shared.handleTap(type: type, title: title, body: body, payload: payload)
        }
    }
}

// MARK: - Notification detail sheet (shown when user taps push)
struct NotificationDetailSheet: View {
    let tap: PendingPushTap
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tap.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.mdzText)
                        if !tap.body.isEmpty {
                            Text(tap.body)
                                .font(.system(size: 15))
                                .foregroundColor(.mdzText)
                        }
                        if let ann = tap.announcement, !ann.isEmpty {
                            Text(ann)
                                .font(.system(size: 15))
                                .foregroundColor(.mdzMuted)
                                .padding(.top, 8)
                        }
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundColor(.mdzRed)
                }
            }
        }
    }
}
