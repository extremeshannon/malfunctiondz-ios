import SwiftUI

struct ManifestLoginView: View {
    @EnvironmentObject private var session: ManifestSessionStore

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMFA = false
    @State private var mfaToken = ""

    var body: some View {
        NavigationStack {
            ZStack {
                NightOps.surface.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(NightOps.gradientBar)
                            .frame(height: 6)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("ASC Manifest")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("Alaska Skydive Center desk ops")
                            .font(.subheadline)
                            .foregroundStyle(NightOps.textMuted)
                    }
                    .padding(.top, 32)

                Picker("Environment", selection: $session.environment) {
                    ForEach(ManifestAppEnvironment.loginCases) { env in
                        Text(env.displayName).tag(env)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text(session.environment.loginHint)
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                    VStack(spacing: 16) {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(NightOps.card)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(NightOps.card)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(NightOps.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: signIn) {
                        Group {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NightOps.accent)
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showMFA) {
                ManifestMFAView(mfaToken: mfaToken) {}
            }
        }
    }

    private func signIn() {
        errorMessage = nil
        isLoading = true
        session.configureAPIClient()

        Task {
            defer { isLoading = false }
            do {
                let response = try await session.apiClient.login(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                if response.mfa_required == true, let token = response.mfa_token {
                    mfaToken = token
                    showMFA = true
                    return
                }
                guard response.ok, let token = response.token else {
                    errorMessage = response.error ?? "Invalid login."
                    return
                }
                session.signIn(token: token, user: response.user)
                await session.refreshProfile()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ManifestLoginView()
        .environmentObject(ManifestSessionStore())
}
