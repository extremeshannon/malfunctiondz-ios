// File: ASC/Views/Profile/ProfileView.swift
// iPad: Content max-width capped and centred, larger typography.
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth:   AuthManager
    @EnvironmentObject private var config: AppConfig
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: isWide ? 20 : 16) {

                        // ── Avatar + Name ──────────────────────────────────
                        VStack(spacing: isWide ? 16 : 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.mdzBlue.opacity(0.2))
                                    .frame(width: isWide ? 110 : 80, height: isWide ? 110 : 80)
                                Text(initials)
                                    .font(.system(size: isWide ? 44 : 32, weight: .black))
                                    .foregroundColor(.mdzBlue)
                            }
                            VStack(spacing: 6) {
                                Text(displayName)
                                    .font(.system(size: isWide ? 28 : 20, weight: .black))
                                    .foregroundColor(.mdzText)
                                Text(auth.currentUser?.roleDisplayLabel ?? "Member")
                                    .font(.system(size: isWide ? 14 : 12, weight: .semibold))
                                    .foregroundColor(.mdzBlue)
                                    .padding(.horizontal, 14).padding(.vertical, 5)
                                    .background(Color.mdzBlue.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(isWide ? 32 : 24)
                        .background(Color.mdzCard).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))

                        // ── Account Info ───────────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "ACCOUNT")
                            if let user = auth.currentUser {
                                profileRow(label: "Username", value: user.username)
                                Divider().background(Color.mdzBorder).padding(.leading, 16)
                                if let email = user.email {
                                    profileRow(label: "Email", value: email)
                                    Divider().background(Color.mdzBorder).padding(.leading, 16)
                                }
                                profileRow(label: "Role", value: user.roleDisplayLabel)
                            }
                        }
                        .background(Color.mdzCard).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))

                        // ── DZ Info ────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "DROPZONE")
                            profileRow(label: "Name",     value: config.dzName)
                            Divider().background(Color.mdzBorder).padding(.leading, 16)
                            profileRow(label: "Platform", value: config.poweredBy)
                        }
                        .background(Color.mdzCard).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))

                        // ── Sign Out ───────────────────────────────────────
                        Button { auth.logout() } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                    .font(.system(size: isWide ? 18 : 16, weight: .bold))
                            }
                            .foregroundColor(.mdzDanger)
                            .frame(maxWidth: .infinity)
                            .frame(height: isWide ? 60 : 52)
                            .background(Color.mdzDanger.opacity(0.12))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzDanger.opacity(0.3), lineWidth: 1))
                        }

                        Text(config.poweredBy)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.mdzMuted).tracking(1)

                        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Build \(build)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.mdzMuted.opacity(0.8))
                                .padding(.top, 4)
                        }

                        Spacer().frame(height: 8)
                    }
                    .padding(isWide ? 32 : 16)
                    // Cap width on iPad so content doesn't stretch across the full 12.9"
                    .frame(maxWidth: isWide ? 900 : .infinity)
                    .frame(maxWidth: .infinity)          // centre it
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Helpers
    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: isWide ? 15 : 14))
                .foregroundColor(.mdzMuted)
            Spacer()
            Text(value)
                .font(.system(size: isWide ? 15 : 14))
                .foregroundColor(.mdzText)
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
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.mdzMuted).tracking(2)
            .padding(.horizontal, 16)
            .padding(.vertical, hSizeClass == .regular ? 14 : 10)
    }
}
