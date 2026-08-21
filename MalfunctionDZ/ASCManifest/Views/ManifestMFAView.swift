import SwiftUI

struct ManifestMFAView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.dismiss) private var dismiss

    let mfaToken: String
    var onSuccess: () -> Void

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter the 6-digit code from your authenticator app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("123456", text: $code)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospacedDigit())
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(action: verify) {
                    Group {
                        if isLoading { ProgressView() }
                        else { Text("Verify").fontWeight(.semibold) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(NightOps.accent)
                .disabled(isLoading || code.count < 6)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Two-Factor Auth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func verify() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let response = try await session.apiClient.loginMFA(mfaToken: mfaToken, code: code.trimmingCharacters(in: .whitespaces))
                if response.ok, let token = response.token {
                    session.signIn(token: token, user: response.user)
                    dismiss()
                    onSuccess()
                } else {
                    errorMessage = response.error ?? "Invalid code."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
