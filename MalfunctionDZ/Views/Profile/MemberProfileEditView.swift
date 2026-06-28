// Member profile — edit contact, address, USPA licenses (same fields as web manifest user edit).
import SwiftUI
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

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && vm.firstName.isEmpty && vm.lastName.isEmpty {
                ProgressView().tint(colors.amber)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Same fields as the drop zone user profile on the web. USPA licenses A–D are used for instructor sign-offs (D is highest).")
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
