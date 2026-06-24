// Instructor profile — license, initials, and signature for logbook / progression sign-offs.
import SwiftUI
import PencilKit
import MalfunctionDZCore

struct InstructorProfilePayload: Codable {
    let userId: Int?
    let displayName: String?
    let licenseNumber: String?
    let initials: String?
    let signatureUrl: String?
    let readyForSignoff: Bool?

    enum CodingKeys: String, CodingKey {
        case initials
        case userId = "user_id"
        case displayName = "display_name"
        case licenseNumber = "license_number"
        case signatureUrl = "signature_url"
        case readyForSignoff = "ready_for_signoff"
    }
}

struct InstructorProfileResponse: Codable {
    let ok: Bool
    let profile: InstructorProfilePayload?
    let error: String?
}

@MainActor
final class InstructorProfileViewModel: ObservableObject {
    @Published var licenseNumber = ""
    @Published var initials = ""
    @Published var signatureUrl = ""
    @Published var readyForSignoff = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var saved = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/profile.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(InstructorProfileResponse.self, from: data)
            guard resp.ok, let p = resp.profile else {
                error = resp.error ?? "Could not load instructor profile"
                return
            }
            licenseNumber = p.licenseNumber ?? ""
            initials = p.initials ?? ""
            signatureUrl = p.signatureUrl ?? ""
            readyForSignoff = p.readyForSignoff ?? false
        } catch {
            self.error = "Could not load instructor profile."
        }
    }

    func save(signatureBase64: String?) async -> Bool {
        let lic = licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let initls = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if lic.isEmpty {
            error = "License number is required."
            return false
        }
        if initls.isEmpty {
            error = "Instructor initials are required."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/profile.php") else { return false }
        struct Body: Codable {
            let instructorLicenseNumber: String
            let instructorInitials: String
            let signatureData: String

            enum CodingKeys: String, CodingKey {
                case instructorLicenseNumber = "instructor_license_number"
                case instructorInitials = "instructor_initials"
                case signatureData = "signature_data"
            }
        }
        var sigData = ""
        if let b64 = signatureBase64, !b64.isEmpty {
            sigData = "data:image/png;base64,\(b64)"
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(Body(
            instructorLicenseNumber: lic,
            instructorInitials: initls,
            signatureData: sigData
        ))
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(InstructorProfileResponse.self, from: data)
            guard resp.ok, let p = resp.profile else {
                error = resp.error ?? "Could not save profile"
                return false
            }
            licenseNumber = p.licenseNumber ?? lic
            initials = p.initials ?? initls
            signatureUrl = p.signatureUrl ?? signatureUrl
            readyForSignoff = p.readyForSignoff ?? false
            saved = true
            error = nil
            return true
        } catch {
            self.error = "Could not save profile."
            return false
        }
    }
}

struct InstructorProfileView: View {
    @StateObject private var vm = InstructorProfileViewModel()
    @State private var canvasView = PKCanvasView()
    @State private var drewNewSignature = false
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && licenseEmpty {
                ProgressView().tint(colors.amber)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("License, initials, and signature are required before you can Pass or Retake jump sign-offs.")
                            .font(.system(size: 13))
                            .foregroundColor(colors.muted)

                        if vm.readyForSignoff {
                            Label("Profile complete", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.green)
                        }

                        if vm.saved {
                            Text("Profile saved.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.green)
                        }

                        if let err = vm.error {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(colors.danger)
                        }

                        fieldBlock("Instructor license number *") {
                            TextField("USPA instructor rating", text: $vm.licenseNumber)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(colors.card2)
                                .cornerRadius(8)
                                .foregroundColor(colors.text)
                        }

                        fieldBlock("Instructor initials *") {
                            TextField("e.g. SJ", text: $vm.initials)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(colors.card2)
                                .cornerRadius(8)
                                .foregroundColor(colors.text)
                                .frame(maxWidth: 120)
                        }

                        fieldBlock("Signature *") {
                            if !vm.signatureUrl.isEmpty {
                                Text("Current signature")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.muted)
                                AsyncImage(url: signatureImageURL) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFit().frame(maxHeight: 80)
                                            .padding(8)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.35), lineWidth: 1))
                                    default:
                                        EmptyView()
                                    }
                                }
                            }
                            InstructorSignaturePadRepresentable(canvas: $canvasView)
                                .frame(height: 140)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.35), lineWidth: 1))
                                .onChange(of: canvasView.drawing) { _, _ in
                                    drewNewSignature = !canvasView.drawing.bounds.isEmpty
                                }
                            Button("Clear pad") {
                                canvasView.drawing = PKDrawing()
                                drewNewSignature = false
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colors.amber)
                        }

                        Button {
                            Task {
                                var sigB64: String?
                                if drewNewSignature {
                                    let rect = canvasView.drawing.bounds
                                    guard !rect.isEmpty else {
                                        vm.error = "Draw your signature on the pad."
                                        return
                                    }
                                    let img = canvasView.drawing.image(from: rect, scale: 2)
                                    sigB64 = img.pngData()?.base64EncodedString()
                                } else if vm.signatureUrl.isEmpty {
                                    vm.error = "Draw your signature on the pad."
                                    return
                                }
                                if await vm.save(signatureBase64: sigB64) {
                                    drewNewSignature = false
                                }
                            }
                        } label: {
                            Text(vm.isSaving ? "Saving…" : "Save profile")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(colors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(vm.isSaving)
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Instructor Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .task { await vm.load() }
    }

    private var licenseEmpty: Bool {
        vm.licenseNumber.isEmpty && vm.initials.isEmpty && vm.signatureUrl.isEmpty
    }

    private var signatureImageURL: URL? {
        let path = vm.signatureUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "\(kServerURL)\(path)")
    }

    private func fieldBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
    }
}
