// File: ASC/Views/Profile/ProfileView.swift
// iPad: Content max-width capped and centred, larger typography.
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth:   AuthManager
    @EnvironmentObject private var config: AppConfig
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @ObservedObject private var pushReg  = PushRegistration.shared
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: isWide ? 20 : 16) {

                        // ── Avatar + Name ──────────────────────────────────
                        VStack(spacing: isWide ? 16 : 12) {
                            ZStack {
                                Circle()
                                    .fill(colors.primary.opacity(0.2))
                                    .frame(width: isWide ? 110 : 80, height: isWide ? 110 : 80)
                                Text(initials)
                                    .font(.system(size: isWide ? 44 : 32, weight: .black))
                                    .foregroundColor(colors.primary)
                            }
                            VStack(spacing: 6) {
                                Text(displayName)
                                    .font(.system(size: isWide ? 28 : 20, weight: .black))
                                    .foregroundColor(colors.text)
                                Text(auth.currentUser?.roleDisplayLabel ?? "Member")
                                    .font(.system(size: isWide ? 14 : 12, weight: .semibold))
                                    .foregroundColor(colors.primary)
                                    .padding(.horizontal, 14).padding(.vertical, 5)
                                    .background(colors.primary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(isWide ? 32 : 24)
                        .background(colors.card).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))

                        // ── Account Info ───────────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "ACCOUNT")
                            if let user = auth.currentUser {
                                profileRow(label: "Username", value: user.username)
                                Divider().background(colors.border).padding(.leading, 16)
                                if let email = user.email {
                                    profileRow(label: "Email", value: email)
                                    Divider().background(colors.border).padding(.leading, 16)
                                }
                                profileRow(label: "Role", value: user.roleDisplayLabel)
                            }
                        }
                        .background(colors.card).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))

                        // ── Manage LMS (admin/instructor) ─────────────────────
                        if auth.currentUser?.canManageLMS == true {
                            NavigationLink(destination: LMSEditRootView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "pencil.and.list.clipboard")
                                        .font(.system(size: 18))
                                        .foregroundColor(colors.accent)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Manage LMS")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(colors.text)
                                        Text("Edit courses, modules, lessons & quizzes")
                                            .font(.system(size: 12))
                                            .foregroundColor(colors.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colors.muted)
                                }
                                .padding(16)
                            }
                            .buttonStyle(.plain)
                            .background(colors.card).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
                        }

                        // ── Notifications history ────────────────────────────
                        NavigationLink(destination: NotificationsView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 18))
                                    .foregroundColor(colors.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notifications")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(colors.text)
                                    Text("View status notes & announcements")
                                        .font(.system(size: 12))
                                        .foregroundColor(colors.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(colors.muted)
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                        .background(colors.card).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))

                        // ── Push status (diagnostics) ──────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "PUSH NOTIFICATIONS")
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
                        .background(colors.card).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))

                        // ── DZ Info ────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "DROPZONE")
                            profileRow(label: "Name",     value: config.dzName)
                            Divider().background(colors.border).padding(.leading, 16)
                            profileRow(label: "Platform", value: config.poweredBy)
                        }
                        .background(colors.card).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))

                        // ── API URL (for local PHP / MAMP) ─────────────────
                        ApiBaseUrlSection()

                        // ── Sign Out ───────────────────────────────────────
                        Button { auth.logout() } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                    .font(.system(size: isWide ? 18 : 16, weight: .bold))
                            }
                            .foregroundColor(colors.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: isWide ? 60 : 52)
                            .background(colors.danger.opacity(0.12))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.danger.opacity(0.3), lineWidth: 1))
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
                    // Cap width on iPad so content doesn't stretch across the full 12.9"
                    .frame(maxWidth: isWide ? 900 : .infinity)
                    .frame(maxWidth: .infinity)          // centre it
                }
                .refreshable { await auth.refreshCurrentUser() }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
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

    // MARK: - Helpers
    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: isWide ? 15 : 14))
                .foregroundColor(colors.muted)
            Spacer()
            Text(value)
                .font(.system(size: isWide ? 15 : 14))
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

struct SectionHeader: View {
    let title: String
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(colors.muted).tracking(2)
            .padding(.horizontal, 16)
            .padding(.vertical, hSizeClass == .regular ? 14 : 10)
    }
}

// MARK: - API Base URL (override for local MAMP / PHP backend)
private let kApiBaseUrlKey = "api_base_url"

struct ApiBaseUrlSection: View {
    @Environment(\.mdzColors) private var colors
    @State private var urlInput: String = ""
    @State private var savedMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "API BASE URL")
            Text("For local testing (e.g. MAMP), set this to your PHP backend. Leave empty for production.")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            HStack(spacing: 8) {
                TextField("e.g. http://localhost:8888", text: $urlInput)
                    .font(.system(size: 14))
                    .foregroundColor(colors.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(colors.background)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
                Button("Save") {
                    let value = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    UserDefaults.standard.set(value.isEmpty ? nil : value, forKey: kApiBaseUrlKey)
                    savedMessage = value.isEmpty ? "Using production URL." : "Saved. Retry aircraft data."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedMessage = nil }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colors.amber)
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
            .padding(.bottom, 12)
        }
        .background(colors.card).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
        .onAppear {
            urlInput = UserDefaults.standard.string(forKey: kApiBaseUrlKey) ?? ""
        }
    }

    private var currentDisplay: String {
        if let custom = UserDefaults.standard.string(forKey: kApiBaseUrlKey), !custom.isEmpty {
            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.hasSuffix("/") ? String(t.dropLast()) : t
        }
        return "https://malfunctiondz.com (default)"
    }
}
