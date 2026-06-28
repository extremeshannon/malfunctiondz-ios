// File: ASC/Views/Profile/ProfileView.swift
// iPad: Content max-width capped and centred, larger typography.
import SwiftUI
import MalfunctionDZCore

struct ProfileView: View {
    @EnvironmentObject private var auth:   AuthManager
    @EnvironmentObject private var config: AppConfig
    @Environment(\.appShell) private var appShell
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @Environment(\.mdzThemeKey) private var themeKey
    @ObservedObject private var pushReg  = PushRegistration.shared
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }
    private var isMemberShell: Bool { appShell.isMemberShell }
    private var mountainTheme: Bool { MDZTheme.usesMountainBackground(themeKey) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: isWide ? 20 : 16) {

                    // ── Hero avatar card ───────────────────────────────
                    VStack(spacing: isWide ? 18 : 14) {
                        MDZAvatarRing(initials: initials, size: isWide ? 100 : 88)
                        VStack(spacing: 8) {
                            Text(displayName)
                                .font(.system(size: isWide ? 28 : 22, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    mountainTheme
                                        ? LinearGradient(
                                            colors: [.white, Color(hex: "5EC8F2")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(colors: [colors.text, colors.text], startPoint: .leading, endPoint: .trailing)
                                )
                            Text(auth.currentUser?.roleDisplayLabel ?? "Member")
                                .font(.system(size: isWide ? 13 : 12, weight: .bold))
                                .foregroundColor(colors.accent)
                                .padding(.horizontal, 16).padding(.vertical, 6)
                                .background(colors.accent.opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(colors.accent.opacity(0.35), lineWidth: 1))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isWide ? 28 : 24)
                    .padding(.horizontal, isWide ? 32 : 20)
                    .mdzContentCard(gloryBar: mountainTheme, glass: mountainTheme)

                    // ── Account Info ───────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        MDZSectionLabel("ACCOUNT", icon: "person.crop.circle")
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 6)
                        if let user = auth.currentUser {
                            profileRow(label: "Username", value: user.username)
                            Divider().background(colors.border.opacity(0.5)).padding(.leading, 16)
                            if let email = user.email {
                                profileRow(label: "Email", value: email)
                                Divider().background(colors.border.opacity(0.5)).padding(.leading, 16)
                            }
                            profileRow(label: "Role", value: user.roleDisplayLabel)
                        }
                    }
                    .mdzContentCard(accent: colors.primary, glass: mountainTheme)

                    NavigationLink(destination: MemberProfileEditView()) {
                        MDZNavRow(
                            icon: "person.text.rectangle",
                            title: "My Profile",
                            subtitle: "Licenses, address, DOB, contact — same as web",
                            accent: colors.primary
                        )
                    }
                    .buttonStyle(.plain)
                    .mdzContentCard(accent: colors.primary, glass: mountainTheme)

                    if auth.currentUser?.isInstructorRole == true {
                        NavigationLink(destination: InstructorProfileView()) {
                            MDZNavRow(
                                icon: "signature",
                                title: "Instructor Profile",
                                subtitle: "Initials and signature for sign-offs",
                                accent: colors.accent
                            )
                        }
                        .buttonStyle(.plain)
                        .mdzContentCard(accent: colors.accent, glass: mountainTheme)
                    }

                    if auth.currentUser?.canManageLMS == true && appShell.isStaffShell {
                        NavigationLink(destination: LMSEditRootView()) {
                            MDZNavRow(
                                icon: "pencil.and.list.clipboard",
                                title: "Manage LMS",
                                subtitle: "Edit courses, modules, lessons & quizzes",
                                accent: colors.groundSchool
                            )
                        }
                        .buttonStyle(.plain)
                        .mdzContentCard(accent: colors.groundSchool, glass: mountainTheme)
                    }

                    if !isMemberShell {
                        NavigationLink(destination: NotificationsView()) {
                            MDZNavRow(
                                icon: "bell.badge.fill",
                                title: "Notifications",
                                subtitle: "View status notes & announcements",
                                accent: colors.amber
                            )
                        }
                        .buttonStyle(.plain)
                        .mdzContentCard(accent: colors.amber, glass: mountainTheme)
                    }

                    if !isMemberShell {
                        VStack(alignment: .leading, spacing: 0) {
                            MDZSectionLabel("PUSH NOTIFICATIONS", icon: "bell.fill")
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 6)
                            HStack {
                                Text("Status")
                                    .font(.system(size: isWide ? 15 : 14))
                                    .foregroundColor(colors.muted)
                                Spacer()
                                Group {
                                    if let s = pushReg.lastStatus {
                                        switch s {
                                        case "sent": Text("Registered ✓").foregroundColor(colors.green)
                                        case "received": Text("Token received…").foregroundColor(colors.primary)
                                        case "skipped": Text("Skipped").foregroundColor(colors.muted)
                                        case "denied": Text("Denied").foregroundColor(colors.muted)
                                        case "failed": Text("Failed").foregroundColor(colors.danger)
                                        default: Text(s).foregroundColor(colors.muted)
                                        }
                                    } else {
                                        Text("Checking…").foregroundColor(colors.muted)
                                    }
                                }
                                .font(.system(size: isWide ? 15 : 14))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, isWide ? 14 : 10)
                            if let err = pushReg.lastError, !err.isEmpty {
                                Text(err)
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.danger)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                            }
                        }
                        .mdzContentCard(accent: colors.primary, glass: mountainTheme)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        MDZSectionLabel("DROPZONE", icon: "mappin.and.ellipse")
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 6)
                        profileRow(label: "Name",     value: config.dzName)
                        Divider().background(colors.border.opacity(0.5)).padding(.leading, 16)
                        profileRow(label: "Platform", value: config.poweredBy)
                    }
                    .mdzContentCard(accent: colors.dz, glass: mountainTheme)

                    AppearanceThemeSection(config: config)

                    if !isMemberShell {
                        ApiBaseUrlSection()
                    }

                    Button { auth.logout() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(.system(size: isWide ? 18 : 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isWide ? 56 : 52)
                        .background(
                            LinearGradient(
                                colors: [colors.danger, colors.danger.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: colors.danger.opacity(0.35), radius: 12, y: 4)
                    }

                    Text(config.poweredBy)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(colors.muted).tracking(1)

                    if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Build \(build)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(colors.muted.opacity(0.8))
                            .padding(.top, 4)
                    }

                    Spacer().frame(height: 8)
                }
                .padding(isWide ? 32 : 16)
                .frame(maxWidth: isWide ? 900 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await auth.refreshCurrentUser() }
            .mdzScreenBackground()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.navyMid.opacity(0.92), for: .navigationBar)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign Out", action: { auth.logout() })
                        .foregroundColor(colors.danger)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .onAppear {
                PushRegistration.shared.requestPermissionAndRegister()
            }
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: isWide ? 15 : 14))
                .foregroundColor(colors.muted)
            Spacer()
            Text(value)
                .font(.system(size: isWide ? 15 : 14, weight: .medium))
                .foregroundColor(colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isWide ? 14 : 10)
    }

    private var displayName: String {
        guard let u = auth.currentUser else { return "User" }
        if let first = u.firstName, let last = u.lastName, !first.isEmpty { return "\(first) \(last)" }
        return u.username.prefix(1).uppercased() + u.username.dropFirst()
    }

    private var initials: String {
        guard let u = auth.currentUser else { return "?" }
        if let first = u.firstName, let last = u.lastName, !first.isEmpty {
            return "\(first.prefix(1))\(last.prefix(1))".uppercased()
        }
        return String(u.username.prefix(2)).uppercased()
    }
}

struct AppearanceThemeSection: View {
    @ObservedObject var config: AppConfig
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey

    private var mountainTheme: Bool { MDZTheme.usesMountainBackground(themeKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MDZSectionLabel("APPEARANCE", icon: "paintbrush.fill")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)
            ForEach(MDZTheme.selectableKeys, id: \.self) { key in
                Button {
                    config.theme = key
                    UserDefaults.standard.set(key, forKey: "cfg_theme")
                } label: {
                    HStack {
                        Text(MDZTheme.displayName(for: key))
                            .font(.system(size: 15, weight: config.theme == key ? .bold : .regular))
                            .foregroundColor(colors.text)
                        Spacer()
                        if config.theme == key {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(colors.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                if key != MDZTheme.selectableKeys.last {
                    Divider().background(colors.border.opacity(0.5)).padding(.leading, 16)
                }
            }
            Text("ASC Midnight matches the app icons. ASC Colors is the original light theme. Old Glory uses flag red, white, and blue.")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .mdzContentCard(accent: colors.accent, glass: mountainTheme)
    }
}

struct SectionHeader: View {
    let title: String
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    var body: some View {
        MDZSectionLabel(title)
            .padding(.horizontal, 16)
            .padding(.vertical, hSizeClass == .regular ? 14 : 10)
    }
}

private let kApiBaseUrlKey = "api_base_url"

struct ApiBaseUrlSection: View {
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey
    @State private var urlInput: String = ""
    @State private var savedMessage: String?

    private var mountainTheme: Bool { MDZTheme.usesMountainBackground(themeKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MDZSectionLabel("API BASE URL", icon: "link")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)
            Text("Debug builds default to http://localhost:8000. Set a custom URL to override (e.g. http://YOUR_MAC_IP:8000 on device, or https://malfunctiondz.com for VPS). Leave empty to use the default for this build.")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            HStack(spacing: 8) {
                TextField("e.g. http://localhost:8000 or https://malfunctiondz.com", text: $urlInput)
                    .font(.system(size: 14))
                    .foregroundColor(colors.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(colors.navyMid.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                Button("Save") {
                    let value = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    UserDefaults.standard.set(value.isEmpty ? nil : value, forKey: kApiBaseUrlKey)
                    savedMessage = value.isEmpty ? "Using default URL for this build." : "Saved. Restart or retry requests."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedMessage = nil }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colors.accent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            if let msg = savedMessage {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(colors.green)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            HStack {
                Text("Current")
                    .font(.system(size: 14))
                    .foregroundColor(colors.muted)
                Spacer()
                Text(currentDisplay)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colors.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .mdzContentCard(accent: colors.primary, glass: mountainTheme)
        .onAppear {
            urlInput = UserDefaults.standard.string(forKey: kApiBaseUrlKey) ?? ""
        }
    }

    private var currentDisplay: String {
        if let custom = UserDefaults.standard.string(forKey: kApiBaseUrlKey), !custom.isEmpty {
            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.hasSuffix("/") ? String(t.dropLast()) : t
        }
        #if DEBUG
        return "http://localhost:8000 (Debug default)"
        #else
        return "https://malfunctiondz.com (default)"
        #endif
    }
}
