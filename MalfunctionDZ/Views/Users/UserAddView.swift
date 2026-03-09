// File: ASC/Views/Users/UserAddView.swift
// Add new user. Chief Pilot/Ops cannot assign admin role.
import SwiftUI

struct UserAddView: View {
    let onDismiss: () -> Void
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var selectedRoles: Set<String> = []
    @State private var availableRoles: [(role: String, label: String)] = []
    @State private var rolesLoading = true
    @State private var rolesLoadError: String?
    @State private var saving = false
    @State private var error: String?
    @State private var created = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    fieldsSection
                    rolesSection
                }
                .padding(20)
            }
            .background(colors.background)
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createUser() }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.amber)
                    .disabled(saving || selectedRoles.isEmpty || rolesLoadError != nil)
                }
            }
            .task { await loadRoles() }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
            .alert("User Created", isPresented: $created) {
                Button("OK") { onDismiss() }
            } message: { Text("The new user has been created.") }
        }
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldRow("Username", $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            fieldRow("Email", $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            fieldRow("Password", $password)
                .textContentType(.password)
            fieldRow("Confirm password", $confirmPassword)
                .textContentType(.password)
            HStack(spacing: 12) {
                fieldRow("First name", $firstName)
                fieldRow("Last name", $lastName)
            }
            fieldRow("Phone", $phone)
                .keyboardType(.phonePad)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func fieldRow(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
            TextField("", text: binding)
                .font(.system(size: 16))
                .foregroundColor(colors.text)
                .padding(12)
                .background(colors.background)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        }
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ROLES (at least one required)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
            if rolesLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.primary))
                        .scaleEffect(0.9)
                    Text("Loading roles…")
                        .font(.system(size: 14))
                        .foregroundColor(colors.muted)
                }
                .padding(.vertical, 8)
            } else if let err = rolesLoadError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundColor(colors.danger)
                    Button {
                        Task { await loadRoles() }
                    } label: {
                        Text("Retry")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colors.amber)
                    }
                }
                .padding(.vertical, 8)
            } else {
            let allowed = availableRoles.filter { r in
                guard (auth.currentUser?.canEditAdminUsers ?? false) else {
                    return !["admin", "master", "godmode"].contains(r.role.lowercased())
                }
                return true
            }
            FlowLayout(spacing: 8) {
                ForEach(allowed, id: \.role) { r in
                    let isSel = selectedRoles.contains(r.role)
                    Button {
                        if isSel { selectedRoles.remove(r.role) }
                        else { selectedRoles.insert(r.role) }
                    } label: {
                        Text(r.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSel ? .white : colors.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSel ? colors.accent : colors.navyMid)
                            .overlay(Capsule().strokeBorder(isSel ? colors.accent : colors.border, lineWidth: isSel ? 2 : 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func loadRoles() async {
        rolesLoading = true
        rolesLoadError = nil
        defer { rolesLoading = false }

        guard let token = KeychainHelper.readToken() else {
            rolesLoadError = "Not signed in."
            return
        }

        let urls = ["\(kServerURL)/api/roles", "\(kServerURL)/api/roles.php"]
        for base in urls {
            guard let url = URL(string: base) else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                    rolesLoadError = "Session expired. Sign in again."
                    return
                }
                let json = try JSONDecoder().decode(RolesResponse.self, from: data)
                if json.ok {
                    availableRoles = json.roles.map { (role: $0.role, label: $0.label.isEmpty ? $0.role.capitalized : $0.label) }
                    rolesLoadError = nil
                    return
                }
            } catch {
                continue
            }
        }
        rolesLoadError = "Could not load roles. Check connection and retry."
    }

    private func createUser() async {
        error = nil
        saving = true
        defer { saving = false }

        let u = username.trimmingCharacters(in: .whitespaces)
        let e = email.trimmingCharacters(in: .whitespaces)
        let p = password
        let fn = firstName.trimmingCharacters(in: .whitespaces)
        let ln = lastName.trimmingCharacters(in: .whitespaces)

        if u.isEmpty { error = "Username is required"; return }
        if e.isEmpty { error = "Email is required"; return }
        if p.isEmpty { error = "Password is required"; return }
        if p.count < 6 { error = "Password must be at least 6 characters"; return }
        if password != confirmPassword { error = "Passwords do not match"; return }
        if fn.isEmpty { error = "First name is required"; return }
        if ln.isEmpty { error = "Last name is required"; return }
        if selectedRoles.isEmpty { error = "At least one role is required"; return }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/users.php") else {
            error = "Not authenticated"
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "username": u,
            "email": e,
            "password": p,
            "first_name": fn,
            "last_name": ln,
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "roles": Array(selectedRoles),
            "is_active": 1,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                await AuthManager.shared.logout()
                error = "Session expired"
                return
            }
            struct R: Decodable { let ok: Bool; let error: String?; let id: Int? }
            let r = try JSONDecoder().decode(R.self, from: data)
            if r.ok {
                created = true
            } else {
                error = r.error ?? "Create failed"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
