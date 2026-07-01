// Member profile — edit contact, address, USPA licenses (same fields as web manifest user edit).
import SwiftUI
import UIKit
import MalfunctionDZCore

@MainActor
final class MemberProfileViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var uspaNumber = ""
    @Published var licenseA = ""
    @Published var licenseB = ""
    @Published var licenseC = ""
    @Published var licenseD = ""
    @Published var addressLine1 = ""
    @Published var addressLine2 = ""
    @Published var city = ""
    @Published var state = ""
    @Published var postalCode = ""
    @Published var dateOfBirth = ""
    @Published var weightLb = ""
    @Published var mainCanopySqft = ""
    @Published var signatureUrl = ""
    @Published var signaturePath = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var saved = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/me.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool == true,
                  let user = json["user"] as? [String: Any] else {
                error = "Could not load profile"
                return
            }
            apply(user)
            error = nil
        } catch {
            self.error = "Could not load profile"
        }
    }

    func save(auth: AuthManager) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        saved = false
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/me/profile.php") else { return false }
        let body: [String: String] = [
            "first_name": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "last_name": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "uspa_number": uspaNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "license_a": licenseA.trimmingCharacters(in: .whitespacesAndNewlines),
            "license_b": licenseB.trimmingCharacters(in: .whitespacesAndNewlines),
            "license_c": licenseC.trimmingCharacters(in: .whitespacesAndNewlines),
            "license_d": licenseD.trimmingCharacters(in: .whitespacesAndNewlines),
            "address_line1": addressLine1.trimmingCharacters(in: .whitespacesAndNewlines),
            "address_line2": addressLine2.trimmingCharacters(in: .whitespacesAndNewlines),
            "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
            "state": state.trimmingCharacters(in: .whitespacesAndNewlines),
            "postal_code": postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            "date_of_birth": dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines),
            "weight_lb": weightLb.trimmingCharacters(in: .whitespacesAndNewlines),
            "main_canopy_sqft": mainCanopySqft.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool == true else {
                error = "Could not save profile"
                return false
            }
            if let user = json["user"] as? [String: Any], let u = User(from: user) {
                auth.currentUser = u
            } else {
                await auth.refreshCurrentUser()
            }
            saved = true
            error = nil
            return true
        } catch {
            self.error = "Could not save profile"
            return false
        }
    }

    private func apply(_ user: [String: Any]) {
        func str(_ key: String) -> String {
            if let s = user[key] as? String { return s }
            if let n = user[key] as? Int { return String(n) }
            if let n = user[key] as? Double { return String(Int(n)) }
            return ""
        }
        firstName = str("first_name")
        lastName = str("last_name")
        email = str("email")
        phone = str("phone")
        uspaNumber = str("uspa_number")
        licenseA = str("license_a")
        licenseB = str("license_b")
        licenseC = str("license_c")
        licenseD = str("license_d")
        addressLine1 = str("address_line1")
        addressLine2 = str("address_line2")
        city = str("city")
        state = str("state")
        postalCode = str("postal_code")
        dateOfBirth = str("date_of_birth")
        weightLb = str("weight_lb")
        mainCanopySqft = str("main_canopy_sqft")
        signatureUrl = str("jumper_signature_url")
        signaturePath = str("jumper_signature_path")
    }

    var resolvedSignaturePath: String {
        let url = signatureUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty { return url }
        return signaturePath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSignatureOnFile: Bool {
        !resolvedSignaturePath.isEmpty
    }

    func saveSignature(base64: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        saved = false
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/me/profile.php") else { return false }
        let body: [String: String] = [
            "signature_data": "data:image/png;base64,\(base64)",
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool == true else {
                error = "Could not save signature"
                return false
            }
            if let user = json["user"] as? [String: Any] {
                apply(user)
            }
            saved = true
            error = nil
            return true
        } catch {
            self.error = "Could not save signature"
            return false
        }
    }

    var highestLicenseSummary: String {
        if !licenseD.isEmpty { return "D · \(licenseD)" }
        if !licenseC.isEmpty { return "C · \(licenseC)" }
        if !licenseB.isEmpty { return "B · \(licenseB)" }
        if !licenseA.isEmpty { return "A · \(licenseA)" }
        return "—"
    }
}

struct MemberProfileEditView: View {
    @StateObject private var vm = MemberProfileViewModel()
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var showSignaturePad = false
    @State private var signatureCacheBuster = 0
    @State private var localSignaturePreview: UIImage?

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && vm.firstName.isEmpty && vm.lastName.isEmpty {
                ProgressView().tint(colors.amber)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Same fields as the drop zone user profile on the web. Save a signature here to sign logbook jumps quickly.")
                            .font(.system(size: 13))
                            .foregroundColor(colors.muted)

                        if vm.saved {
                            Text("Profile saved.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.green)
                        }
                        if let err = vm.error {
                            Text(err).font(.system(size: 12)).foregroundColor(colors.danger)
                        }

                        profileSection("Name & contact") {
                            profileField("First name", text: $vm.firstName)
                            profileField("Last name", text: $vm.lastName)
                            profileField("Email", text: $vm.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            profileField("Phone", text: $vm.phone)
                                .keyboardType(.phonePad)
                            profileField("USPA #", text: $vm.uspaNumber)
                        }

                        profileSection("USPA licenses") {
                            profileField("License A", text: $vm.licenseA)
                            profileField("License B", text: $vm.licenseB)
                            profileField("License C", text: $vm.licenseC)
                            profileField("License D", text: $vm.licenseD)
                            if vm.highestLicenseSummary != "—" {
                                Text("Highest on file: \(vm.highestLicenseSummary)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(colors.green)
                            }
                        }

                        profileSection("Address") {
                            profileField("Street", text: $vm.addressLine1)
                            profileField("Street line 2", text: $vm.addressLine2)
                            profileField("City", text: $vm.city)
                            profileField("State", text: $vm.state)
                            profileField("ZIP", text: $vm.postalCode)
                        }

                        profileSection("Logbook signature") {
                            if vm.hasSignatureOnFile || localSignaturePreview != nil {
                                MDZSignaturePreview(
                                    localImage: localSignaturePreview,
                                    remotePath: vm.resolvedSignaturePath,
                                    cacheBuster: signatureCacheBuster
                                )
                            }
                            Button {
                                showSignaturePad = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "signature")
                                    Text(vm.hasSignatureOnFile ? "Update signature" : "Add signature")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "pencil.and.scribble")
                                }
                                .foregroundColor(colors.text)
                                .padding(14)
                                .background(colors.card2)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            Text("Used when you sign jumps in your logbook.")
                                .font(.system(size: 12))
                                .foregroundColor(colors.muted)
                        }

                        profileSection("Physical & gear") {
                            profileField("Date of birth", text: $vm.dateOfBirth, placeholder: "YYYY-MM-DD")
                            profileField("Weight (lb)", text: $vm.weightLb)
                                .keyboardType(.numberPad)
                            profileField("Main canopy (sq ft)", text: $vm.mainCanopySqft)
                                .keyboardType(.numberPad)
                        }

                        Button {
                            Task { _ = await vm.save(auth: auth) }
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
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .fullScreenCover(isPresented: $showSignaturePad) {
            MemberSignaturePadView(
                localSignaturePreview: $localSignaturePreview,
                signatureCacheBuster: $signatureCacheBuster,
                onSave: { b64 in await vm.saveSignature(base64: b64) },
                onDismiss: { showSignaturePad = false }
            )
        }
    }

    private func profileSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

    private func profileField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
            TextField(placeholder.isEmpty ? label : placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(colors.text)
                .padding(12)
                .background(colors.card2)
                .cornerRadius(8)
        }
    }
}

private struct MemberSignaturePadView: View {
    @Binding var localSignaturePreview: UIImage?
    @Binding var signatureCacheBuster: Int
    let onSave: (String) async -> Bool
    let onDismiss: () -> Void
    @State private var strokes: [MDZSignatureStroke] = []
    @State private var localError: String?
    @Environment(\.mdzColors) private var colors

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Draw your logbook signature")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(colors.text)
                    MDZFingerSignaturePad(
                        strokes: $strokes,
                        inkColor: .white,
                        lineWidth: 3,
                        paperColor: Color(red: 12 / 255, green: 29 / 255, blue: 53 / 255)
                    )
                    .frame(height: 220)
                    .cornerRadius(10)
                    if let localError {
                        Text(localError).font(.caption).foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveFromPad() }
                    }
                    .foregroundColor(colors.amber)
                }
            }
        }
    }

    private func saveFromPad() async {
        guard let img = signatureImageFromStrokes(strokes),
              let b64 = img.pngData()?.base64EncodedString() else {
            localError = "Draw your signature on the line."
            return
        }
        if await onSave(b64) {
            localSignaturePreview = img
            signatureCacheBuster += 1
            onDismiss()
        } else {
            localError = "Could not save signature."
        }
    }
}
