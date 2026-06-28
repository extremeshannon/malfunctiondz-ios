// Instructor profile — license, initials, and signature for logbook / progression sign-offs.
import SwiftUI
import PencilKit
import MalfunctionDZCore

struct InstructorProfilePayload: Codable {
    let userId: Int?
    let displayName: String?
    let licenseNumber: String?
    let highestLicense: String?
    let highestLicenseNumber: String?
    let highestLicenseDisplay: String?
    let licenseA: String?
    let licenseB: String?
    let licenseC: String?
    let licenseD: String?
    let initials: String?
    let signatureUrl: String?
    let signaturePath: String?
    let readyForSignoff: Bool?

    enum CodingKeys: String, CodingKey {
        case licenseA = "license_a"
        case licenseB = "license_b"
        case licenseC = "license_c"
        case licenseD = "license_d"
        case initials
        case userId = "user_id"
        case displayName = "display_name"
        case licenseNumber = "license_number"
        case highestLicense = "highest_license"
        case highestLicenseNumber = "highest_license_number"
        case highestLicenseDisplay = "highest_license_display"
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

func signatureImageFromDrawing(_ drawing: PKDrawing) -> UIImage? {
    let rect = drawing.bounds
    guard !rect.isEmpty else { return nil }
    let padded = rect.insetBy(dx: -24, dy: -16)
    return drawing.image(from: padded, scale: 2)
}

@MainActor
final class InstructorProfileViewModel: ObservableObject {
    @Published var initials = ""
    @Published var highestLicense = ""
    @Published var highestLicenseDisplay = "—"
    @Published var licenseA = ""
    @Published var licenseB = ""
    @Published var licenseC = ""
    @Published var licenseD = ""
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

    var highestLicenseDisplayText: String {
        let d = highestLicenseDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        if !d.isEmpty, d != "—" { return d }
        if !licenseD.isEmpty { return "D · \(licenseD)" }
        if !licenseC.isEmpty { return "C · \(licenseC)" }
        if !licenseB.isEmpty { return "B · \(licenseB)" }
        if !licenseA.isEmpty { return "A · \(licenseA)" }
        return "—"
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

    /// Save initials and/or signature independently (partial updates).
    func save(initials: String? = nil, signatureBase64: String? = nil) async -> Bool {
        let savingInitials = initials != nil
        let savingSignature = signatureBase64 != nil
        guard savingInitials || savingSignature else {
            error = "Nothing to save."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/profile.php") else { return false }

        var body: [String: Any] = [:]
        if savingInitials {
            body["instructor_initials"] = (initials ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        if savingSignature, let b64 = signatureBase64, !b64.isEmpty {
            body["signature_data"] = "data:image/png;base64,\(b64)"
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(InstructorProfileResponse.self, from: data)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 || !resp.ok {
                error = resp.error ?? "Could not save (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))"
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
        initials = p.initials ?? initials
        highestLicense = p.highestLicense ?? highestLicense
        licenseA = p.licenseA ?? licenseA
        licenseB = p.licenseB ?? licenseB
        licenseC = p.licenseC ?? licenseC
        licenseD = p.licenseD ?? licenseD
        if let disp = p.highestLicenseDisplay, !disp.isEmpty {
            highestLicenseDisplay = disp
        } else {
            highestLicenseDisplay = highestLicenseDisplayText
        }
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
    @EnvironmentObject private var auth: AuthManager
    @State private var signatureDrawing = PKDrawing()
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
            if vm.isLoading && vm.initials.isEmpty && !hasSignatureOnFile {
                ProgressView().tint(colors.amber)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your initials and signature for jump sign-offs. USPA licenses come from My Profile.")
                            .font(.system(size: 13))
                            .foregroundColor(colors.muted)

                        if vm.readyForSignoff {
                            Label("Ready to sign off jumps", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.green)
                        }

                        if vm.saved {
                            Text("Saved.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.green)
                        }

                        if let err = vm.error {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(colors.danger)
                        }

                        fieldBlock("USPA licenses (from My Profile)") {
                            licenseReadOnlyRow("A", value: vm.licenseA)
                            licenseReadOnlyRow("B", value: vm.licenseB)
                            licenseReadOnlyRow("C", value: vm.licenseC)
                            licenseReadOnlyRow("D", value: vm.licenseD)
                            HStack {
                                Text("Highest on file")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.muted)
                                Spacer()
                                Text(vm.highestLicenseDisplayText)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(colors.text)
                            }
                            .padding(.top, 4)
                            NavigationLink(destination: MemberProfileEditView()) {
                                Text("Edit licenses in My Profile →")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(colors.amber)
                            }
                        }

                        fieldBlock("Instructor initials") {
                            TextField("e.g. SJ", text: $vm.initials)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(colors.card2)
                                .cornerRadius(8)
                                .foregroundColor(colors.text)
                                .frame(maxWidth: 120)
                            Button {
                                Task { await saveInitialsOnly() }
                            } label: {
                                Text(vm.isSaving ? "Saving…" : "Save initials")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(colors.primary)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(vm.isSaving)
                            .padding(.top, 4)
                        }

                        fieldBlock("Signature") {
                            if hasSignatureOnFile {
                                InstructorSignaturePreview(
                                    localImage: localSignaturePreview,
                                    remotePath: vm.resolvedSignaturePath,
                                    cacheBuster: signatureCacheBuster
                                )
                            }

                            if drewNewSignature, localSignaturePreview == nil {
                                Text("New signature captured — save from the signing pad.")
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

                    }
                    .padding(16)
                }
            }

        }
        .fullScreenCover(isPresented: $showSignaturePad) {
            InstructorFullScreenSignatureView(
                signatureDrawing: $signatureDrawing,
                drewNewSignature: $drewNewSignature,
                localSignaturePreview: $localSignaturePreview,
                signatureCacheBuster: $signatureCacheBuster,
                vm: vm,
                onDismiss: { showSignaturePad = false }
            )
        }
        .onChange(of: showSignaturePad) { _, open in
            if open {
                signatureDrawing = PKDrawing()
                drewNewSignature = false
                localSignaturePreview = nil
            }
        }
        .onChange(of: signatureDrawing) { _, drawing in
            drewNewSignature = !drawing.strokes.isEmpty
        }
        .navigationTitle("Instructor Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .task { await vm.load() }
    }

    private func licenseReadOnlyRow(_ level: String, value: String) -> some View {
        HStack {
            Text("License \(level)")
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.text)
        }
    }

    private func saveInitialsOnly() async {
        vm.saved = false
        if await vm.save(initials: vm.initials) {
            await vm.load()
        }
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
    @Binding var signatureDrawing: PKDrawing
    @Binding var drewNewSignature: Bool
    @Binding var localSignaturePreview: UIImage?
    @Binding var signatureCacheBuster: Int
    @ObservedObject var vm: InstructorProfileViewModel
    let onDismiss: () -> Void

    @Environment(\.mdzColors) private var colors
    @State private var localError: String?

    private func clearPad() {
        signatureDrawing = PKDrawing()
        drewNewSignature = false
        localSignaturePreview = nil
        localError = nil
    }

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > geo.size.height

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
                    // Balance Cancel width
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.clear)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(colors.navyMid)

                ZStack(alignment: .bottom) {
                    Color.white

                    MDZSignaturePadRepresentable(
                        drawing: $signatureDrawing,
                        inkColor: .black,
                        lineWidth: 5
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 8) {
                        Text("Sign on the line")
                            .font(.system(size: isWide ? 14 : 13, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.5))
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 2)
                            .padding(.horizontal, isWide ? 48 : 28)
                    }
                    .padding(.bottom, isWide ? 40 : 32)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)

                VStack(spacing: 12) {
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

                    HStack(spacing: 12) {
                        Button(action: clearPad) {
                            Text("Clear")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(colors.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(colors.card2)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(colors.border, lineWidth: 1)
                                )
                        }
                        .disabled(vm.isSaving)

                        Button {
                            Task { await saveSignature() }
                        } label: {
                            Text(vm.isSaving ? "Saving…" : "Save")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(colors.green)
                                .cornerRadius(12)
                        }
                        .disabled(vm.isSaving)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, max(20, geo.safeAreaInsets.bottom + 8))
                .background(colors.navyMid)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(colors.background)
        }
        .onChange(of: signatureDrawing) { _, drawing in
            drewNewSignature = !drawing.strokes.isEmpty
            if drewNewSignature { localError = nil }
        }
    }

    private func saveSignature() async {
        localError = nil
        vm.error = nil

        guard let img = signatureImageFromDrawing(signatureDrawing),
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
