// File: ASC/Views/Auth/LoginView.swift
import SwiftUI
import MalfunctionDZCore

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
    @State private var username = ""
    @State private var password = ""
    @State private var mfaCode = ""

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo ──────────────────────────────────────
                Image(AppBranding.loginLogoName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 32)

                // ── Fields ────────────────────────────────────
                VStack(spacing: 14) {
                    if auth.pendingMfaToken != nil {
                        mfaStep
                    } else {
                        credentialStep
                    }

                    // Error
                    if let err = auth.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(colors.danger)
                                .font(.caption)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(colors.danger)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()

                // ── Footer ────────────────────────────────────
                VStack(spacing: 2) {
                    Text("Powered by MalfunctionDZ")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(colors.muted)
                        .tracking(1)
                    if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Build \(build)")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(colors.muted.opacity(0.8))
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var credentialStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USERNAME")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(2)
            HStack {
                Image(systemName: "person")
                    .foregroundColor(colors.muted)
                    .frame(width: 20)
                TextField("", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(colors.text)
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 1))
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("PASSWORD")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(2)
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(colors.muted)
                    .frame(width: 20)
                SecureField("", text: $password)
                    .foregroundColor(colors.text)
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 1))
        }

        Button {
            Task { await auth.login(username: username, password: password) }
        } label: {
            ZStack {
                if auth.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(colors.accent)
            .cornerRadius(12)
        }
        .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var mfaStep: some View {
        Text("Two-factor authentication")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(colors.text)
            .frame(maxWidth: .infinity, alignment: .leading)
        Text("Enter the 6-digit code from your authenticator app.")
            .font(.caption)
            .foregroundColor(colors.muted)
            .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 6) {
            Text("AUTHENTICATOR CODE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(2)
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(colors.muted)
                    .frame(width: 20)
                TextField("", text: $mfaCode)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .foregroundColor(colors.text)
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 1))
        }

        Button {
            Task { await auth.completeMfaLogin(code: mfaCode) }
        } label: {
            ZStack {
                if auth.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Verify")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(colors.accent)
            .cornerRadius(12)
        }
        .disabled(auth.isLoading || mfaCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6)
        .padding(.top, 4)

        Button {
            mfaCode = ""
            auth.cancelMfaChallenge()
        } label: {
            Text("Back to sign in")
                .font(.subheadline.weight(.medium))
                .foregroundColor(colors.primary)
        }
        .padding(.top, 4)
    }
}
