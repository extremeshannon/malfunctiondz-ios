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
    @State private var showSignaturePad = false
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass

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

                            if drewNewSignature {
                                Text("New signature captured — save profile or open the pad again to change it.")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.green)
                            }

                            Button {
                                showSignaturePad = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "signature")
                                        .font(.system(size: 18, weight: .semibold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vm.signatureUrl.isEmpty ? "Add signature" : "Update signature")
                                            .font(.system(size: 15, weight: .bold))
                                        Text("Turn phone sideways for full-screen signing")
                                            .font(.system(size: 11))
                                            .foregroundColor(colors.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(colors.text)
                                .padding(14)
                                .background(colors.card2)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.primary.opacity(0.45), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Task { await saveProfileFromForm() }
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
        .onChange(of: verticalSizeClass) { _, sizeClass in
            if sizeClass == .compact, !showSignaturePad, !vm.isLoading {
                showSignaturePad = true
            }
        }
        .fullScreenCover(isPresented: $showSignaturePad) {
            InstructorFullScreenSignatureView(
                canvasView: $canvasView,
                drewNewSignature: $drewNewSignature,
                vm: vm,
                onDismiss: { showSignaturePad = false }
            )
        }
    }

    private func saveProfileFromForm() async {
        var sigB64: String?
        if drewNewSignature {
            guard let b64 = signatureBase64FromCanvas() else {
                vm.error = "Draw your signature on the pad."
                return
            }
            sigB64 = b64
        } else if vm.signatureUrl.isEmpty {
            vm.error = "Add your signature first."
            return
        }
        if await vm.save(signatureBase64: sigB64) {
            drewNewSignature = false
        }
    }

    private func signatureBase64FromCanvas() -> String? {
        let rect = canvasView.drawing.bounds
        guard !rect.isEmpty else { return nil }
        let img = canvasView.drawing.image(from: rect, scale: 2)
        return img.pngData()?.base64EncodedString()
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

// MARK: - Full-screen landscape signature pad

struct InstructorFullScreenSignatureView: View {
    @Binding var canvasView: PKCanvasView
    @Binding var drewNewSignature: Bool
    @ObservedObject var vm: InstructorProfileViewModel
    let onDismiss: () -> Void

    @Environment(\.mdzColors) private var colors
    @State private var localError: String?

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > geo.size.height

            ZStack {
                colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") { onDismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.amber)
                        Spacer()
                        Text("INSTRUCTOR SIGNATURE")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(colors.muted)
                            .tracking(1.2)
                        Spacer()
                        Button("Clear") {
                            canvasView.drawing = PKDrawing()
                            drewNewSignature = false
                            localError = nil
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colors.amber)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(colors.navyMid)

                    ZStack(alignment: .bottom) {
                        Color.white

                        InstructorSignaturePadRepresentable(canvas: $canvasView)
                            .onChange(of: canvasView.drawing) { _, _ in
                                drewNewSignature = !canvasView.drawing.bounds.isEmpty
                                localError = nil
                            }

                        VStack(spacing: 8) {
                            Text("Sign on the line")
                                .font(.system(size: isWide ? 14 : 13, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.45))
                            Rectangle()
                                .fill(Color.black.opacity(0.55))
                                .frame(height: 2)
                                .padding(.horizontal, isWide ? 48 : 28)
                        }
                        .padding(.bottom, isWide ? 36 : 28)
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 10) {
                        if let localError {
                            Text(localError)
                                .font(.system(size: 12))
                                .foregroundColor(colors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let err = vm.error {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(colors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await saveSignature() }
                        } label: {
                            Text(vm.isSaving ? "Saving…" : "Save signature")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(colors.green)
                                .cornerRadius(12)
                        }
                        .disabled(vm.isSaving)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colors.navyMid)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func saveSignature() async {
        localError = nil
        vm.error = nil

        let lic = vm.licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let initls = vm.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if lic.isEmpty {
            localError = "Enter your instructor license number on the profile screen first."
            return
        }
        if initls.isEmpty {
            localError = "Enter your instructor initials on the profile screen first."
            return
        }

        let rect = canvasView.drawing.bounds
        guard !rect.isEmpty else {
            localError = "Draw your signature on the line."
            return
        }
        let img = canvasView.drawing.image(from: rect, scale: 2)
        guard let b64 = img.pngData()?.base64EncodedString() else {
            localError = "Could not capture signature."
            return
        }

        if await vm.save(signatureBase64: b64) {
            drewNewSignature = false
            onDismiss()
        }
    }
}
