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
    @StateObject private var auth      = AuthManager.shared
    @StateObject private var config    = AppConfig()
    @StateObject private var tabSelect = TabSelection.shared

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(auth)
                .environmentObject(config)
                .environmentObject(tabSelect)
        }
    }
}

// MARK: - Content Root
struct ContentRootView: View {
    @EnvironmentObject private var auth: AuthManager
    var body: some View {
        if auth.isAuthenticated {
            MDZRootView()
                .id(auth.sessionID)
        } else {
            LoginView()
        }
    }
}

// MARK: - Root: adapts to size class
struct MDZRootView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @EnvironmentObject private var auth:      AuthManager
    @EnvironmentObject private var config:    AppConfig
    @EnvironmentObject private var tabSelect: TabSelection

    var body: some View {
        Group {
            if hSizeClass == .regular {
                MDZSplitView()
            } else {
                MDZTabView()
            }
        }
        .task { await config.loadConfig() }
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
                            .foregroundColor(.mdzNavy)
                            .tracking(1)
                        if let user = auth.currentUser {
                            Text(user.roleDisplayLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.mdzBlue)
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
                    if auth.currentUser?.canAccessGroundSchool == true {
                        SidebarButton(icon: "graduationcap.fill", title: config.moduleGroundSchool, selected: selectedModule == .groundSchool) { selectedModule = .groundSchool }
                    }
                    if auth.currentUser?.canAccessLogbook == true {
                        SidebarButton(icon: "book.closed.fill", title: "Logbook", selected: selectedModule == .logbook) { selectedModule = .logbook }
                    }
                }

                Section("ACCOUNT") {
                    SidebarButton(icon: "person.fill", title: "Profile", selected: selectedModule == .profile) { selectedModule = .profile }
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
                case .groundSchool: GroundSchoolView()
                case .logbook:      LogbookRootView()
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
    case home, aviation, loft, groundSchool, logbook, profile

    /// Map fixed tab tags → module
    init?(tag: Int) {
        switch tag {
        case 0:  self = .home
        case 1:  self = .aviation
        case 2:  self = .loft
        case 3:  self = .groundSchool
        case 4:  self = .logbook
        case 9:  self = .profile
        default: return nil
        }
    }

    var tag: Int {
        switch self {
        case .home:         return 0
        case .aviation:     return 1
        case .loft:         return 2
        case .groundSchool: return 3
        case .logbook:      return 4
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

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(9)
        }
        .accentColor(.mdzRed)
    }
}

// MARK: - App Delegate (push notifications)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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
        return [.banner, .sound, .badge]
    }
}
