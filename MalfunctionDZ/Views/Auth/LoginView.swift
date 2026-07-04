// File: ASC/Views/Auth/LoginView.swift
import SwiftUI
import MalfunctionDZCore

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey
    @State private var username = ""
    @State private var password = ""
    @State private var mfaCode = ""

    private var mountainTheme: Bool { MDZTheme.usesMountainBackground(themeKey) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(AppBranding.loginLogoName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: mountainTheme ? 280 : 320)
                .padding(.horizontal, 30)
                .padding(.bottom, 28)
                .shadow(color: mountainTheme ? Color(hex: "5EC8F2").opacity(0.35) : .clear, radius: 28, y: 10)
                .shadow(color: mountainTheme ? Color(hex: "F2B705").opacity(0.15) : .clear, radius: 40, y: 16)

            VStack(spacing: 18) {
                if auth.pendingMfaToken != nil {
                    mfaPanel
                } else {
                    credentialPanel
                }

                if let err = auth.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(colors.danger)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(colors.danger)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(colors.danger.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(22)
            .mdzContentCard(gloryBar: mountainTheme, glass: mountainTheme)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 2) {
                Text("Powered by MalfunctionDZ")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                Text(MDZAppVersion.displayFull)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(colors.muted.opacity(0.8))
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mdzScreenBackground()
    }

    @ViewBuilder
    private var credentialPanel: some View {
        VStack(spacing: 14) {
            MDZGlassField(label: "USERNAME") {
                Image(systemName: "person.fill")
                    .foregroundColor(colors.primary.opacity(0.8))
                    .frame(width: 20)
                TextField("", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            MDZGlassField(label: "PASSWORD") {
                Image(systemName: "lock.fill")
                    .foregroundColor(colors.primary.opacity(0.8))
                    .frame(width: 20)
                SecureField("", text: $password)
            }
            MDZPrimaryButton(
                "Sign In",
                loading: auth.isLoading,
                disabled: username.isEmpty || password.isEmpty
            ) {
                Task { await auth.login(username: username, password: password) }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var mfaPanel: some View {
        VStack(spacing: 14) {
            Text("Two-factor authentication")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Enter the 6-digit code from your authenticator app.")
                .font(.caption)
                .foregroundColor(colors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            MDZGlassField(label: "AUTHENTICATOR CODE") {
                Image(systemName: "key.fill")
                    .foregroundColor(colors.primary.opacity(0.8))
                    .frame(width: 20)
                TextField("", text: $mfaCode)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
            }

            MDZPrimaryButton(
                "Verify",
                loading: auth.isLoading,
                disabled: mfaCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6
            ) {
                Task { await auth.completeMfaLogin(code: mfaCode) }
            }

            Button {
                mfaCode = ""
                auth.cancelMfaChallenge()
            } label: {
                Text("Back to sign in")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(colors.primary)
            }
        }
    }
}
