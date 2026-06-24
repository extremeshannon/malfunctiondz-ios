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
    let signaturePath: String?
    let readyForSignoff: Bool?

    enum CodingKeys: String, CodingKey {
        case initials
        case userId = "user_id"
        case displayName = "display_name"
        case licenseNumber = "license_number"
        case signatureUrl = "signature_url"
        case signaturePath = "signature_path"
        case readyForSignoff = "ready_for_signoff"
    }
}

struct InstructorProfileResponse: Codable {
    let ok: Bool
    let profile: InstructorProfilePayload?
    let error: String?
}

enum InstructorProfileURL {
    static func absolute(_ path: String, cacheBuster: Int = 0) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        let base = kServerURL.hasSuffix("/") ? String(kServerURL.dropLast()) : kServerURL
        let p = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        var urlString = "\(base)\(p)"
        if cacheBuster > 0 {
            urlString += p.contains("?") ? "&v=\(cacheBuster)" : "?v=\(cacheBuster)"
        }
        return URL(string: urlString)
    }
}

func signatureImageFromCanvas(_ canvas: PKCanvasView) -> UIImage? {
    let rect = canvas.drawing.bounds
    guard !rect.isEmpty else { return nil }
    let padded = rect.insetBy(dx: -24, dy: -16)
    return canvas.drawing.image(from: padded, scale: 2)
}

@MainActor
final class InstructorProfileViewModel: ObservableObject {
    @Published var licenseNumber = ""
    @Published var initials = ""
    @Published var signatureUrl = ""
    @Published var signaturePath = ""
    @Published var readyForSignoff = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var saved = false
    @Published var error: String?

    var resolvedSignaturePath: String {
        let url = signatureUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty { return url }
        return signaturePath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/profile.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                error = "Session expired — sign in again."
                return
            }
            let resp = try JSONDecoder().decode(InstructorProfileResponse.self, from: data)
            guard resp.ok, let p = resp.profile else {
                error = resp.error ?? "Could not load instructor profile"
                return
            }
            applyProfile(p)
            error = nil
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
            let (data, response) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(InstructorProfileResponse.self, from: data)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 || !resp.ok {
                error = resp.error ?? "Could not save profile (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))"
                return false
            }
            guard let p = resp.profile else {
                error = resp.error ?? "Could not save profile"
                return false
            }
            applyProfile(p)
            saved = true
            error = nil
            return true
        } catch {
            self.error = "Could not save profile."
            return false
        }
    }

    private func applyProfile(_ p: InstructorProfilePayload) {
        licenseNumber = p.licenseNumber ?? licenseNumber
        initials = p.initials ?? initials
        signatureUrl = p.signatureUrl ?? ""
        signaturePath = p.signaturePath ?? ""
        readyForSignoff = p.readyForSignoff ?? false
    }
}

private struct InstructorSignaturePreview: View {
    let localImage: UIImage?
    let remotePath: String
    let cacheBuster: Int
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current signature")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)

            Group {
                if let localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 90)
                } else if !remotePath.isEmpty {
                    InstructorRemoteSignatureImage(path: remotePath, cacheBuster: cacheBuster)
                        .frame(maxHeight: 90)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.35), lineWidth: 1))
        }
    }
}

private struct InstructorRemoteSignatureImage: View {
    let path: String
    let cacheBuster: Int
    @Environment(\.mdzColors) private var colors
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                Text("Could not load saved signature")
                    .font(.system(size: 11))
                    .foregroundColor(colors.danger)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .tint(colors.amber)
            }
        }
        .task(id: "\(path)-\(cacheBuster)") {
            await load()
        }
    }

    private func load() async {
        image = nil
        failed = false
        guard let url = InstructorProfileURL.absolute(path, cacheBuster: cacheBuster) else {
            failed = true
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let img = UIImage(data: data) else {
                failed = true
                return
            }
            image = img
        } catch {
            failed = true
        }
    }
}

struct InstructorProfileView: View {
    @StateObject private var vm = InstructorProfileViewModel()
    @State private var canvasView = PKCanvasView()
    @State private var drewNewSignature = false
    @State private var showSignaturePad = false
    @State private var localSignaturePreview: UIImage?
    @State private var signatureCacheBuster = 0
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private var hasSignatureOnFile: Bool {
        localSignaturePreview != nil || !vm.resolvedSignaturePath.isEmpty
    }

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
                            if hasSignatureOnFile {
                                InstructorSignaturePreview(
                                    localImage: localSignaturePreview,
                                    remotePath: vm.resolvedSignaturePath,
                                    cacheBuster: signatureCacheBuster
                                )
                            }

                            if drewNewSignature, localSignaturePreview == nil {
                                Text("New signature captured — tap Save profile to upload.")
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
                                        Text(hasSignatureOnFile ? "Update signature" : "Add signature")
                                            .font(.system(size: 15, weight: .bold))
                                        Text("Opens full-screen signing pad")
                                            .font(.system(size: 11))
                                            .foregroundColor(colors.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "pencil.and.scribble")
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

            if showSignaturePad {
                InstructorFullScreenSignatureView(
                    canvasView: $canvasView,
                    drewNewSignature: $drewNewSignature,
                    localSignaturePreview: $localSignaturePreview,
                    signatureCacheBuster: $signatureCacheBuster,
                    vm: vm,
                    onDismiss: { showSignaturePad = false }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSignaturePad)
        .navigationTitle("Instructor Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .task { await vm.load() }
    }

    private func saveProfileFromForm() async {
        var sigB64: String?
        if drewNewSignature {
            guard let img = localSignaturePreview ?? signatureImageFromCanvas(canvasView),
                  let b64 = img.pngData()?.base64EncodedString() else {
                vm.error = "Draw your signature on the pad."
                return
            }
            sigB64 = b64
        } else if !hasSignatureOnFile {
            vm.error = "Add your signature first."
            return
        }
        if await vm.save(signatureBase64: sigB64) {
            drewNewSignature = false
            if sigB64 != nil {
                signatureCacheBuster += 1
            }
            await vm.load()
        }
    }

    private var licenseEmpty: Bool {
        vm.licenseNumber.isEmpty && vm.initials.isEmpty && !hasSignatureOnFile
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

// MARK: - Full-screen signature pad (overlay — survives rotation)

struct InstructorFullScreenSignatureView: View {
    @Binding var canvasView: PKCanvasView
    @Binding var drewNewSignature: Bool
    @Binding var localSignaturePreview: UIImage?
    @Binding var signatureCacheBuster: Int
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
                            localSignaturePreview = nil
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

        guard let img = signatureImageFromCanvas(canvasView),
              let b64 = img.pngData()?.base64EncodedString() else {
            localError = "Draw your signature on the line."
            return
        }

        if await vm.save(signatureBase64: b64) {
            localSignaturePreview = img
            drewNewSignature = false
            signatureCacheBuster += 1
            await vm.load()
            onDismiss()
        }
    }
}
