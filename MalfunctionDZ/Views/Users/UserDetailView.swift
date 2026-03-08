// File: ASC/Views/Users/UserDetailView.swift
// View/edit user. Chief Pilot/Ops: admin users are read-only + Send reset only.
import SwiftUI

struct UserDetailView: View {
    let user: PlatformUser
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = UserDetailViewModel()

    var body: some View {
        Group {
            if user.isAdminRole && (auth.currentUser?.canEditAdminUsers ?? true) == false {
                AdminReadOnlyView(user: user, onDismiss: { dismiss() })
            } else {
                UserEditView(
                    user: user,
                    userId: user.id,
                    onSave: { payload in
                        await vm.save(userId: user.id, payload: payload)
                        if vm.error == nil { dismiss() }
                    },
                    onDismiss: { dismiss() }
                )
            }
        }
        .alert("Error", isPresented: .init(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }
}

// MARK: - Admin read-only (Chief Pilot/Ops): view + Send reset only
struct AdminReadOnlyView: View {
    let user: PlatformUser
    let onDismiss: () -> Void
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @StateObject private var vm = UserDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("You can view admin users but cannot edit them.")
                    .font(.system(size: 14))
                    .foregroundColor(colors.muted)

                userInfoCard
                sendResetSection
            }
            .padding(20)
        }
        .background(colors.background)
        .navigationTitle(user.fullName?.isEmpty == false ? user.fullName! : user.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back", action: onDismiss)
                    .foregroundColor(colors.amber)
            }
        }
        .alert("Error", isPresented: .init(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    private var userInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(colors.accent.opacity(0.15)).frame(width: 50, height: 50)
                    Text(user.displayInitials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colors.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName?.isEmpty == false ? user.fullName! : user.username)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colors.text)
                    Text(user.username)
                        .font(.system(size: 13))
                        .foregroundColor(colors.muted)
                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundColor(colors.muted)
                    }
                }
                Spacer()
            }
            Text("Admin")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(colors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(colors.primary.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var sendResetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send password reset link to user's email.")
                .font(.system(size: 14))
                .foregroundColor(colors.muted)
            Button {
                Task { await vm.sendReset(userId: user.id) }
            } label: {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Send reset")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(colors.accent)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(vm.sendingReset)
            if vm.resetSent {
                Text("Reset link sent.")
                    .font(.system(size: 13))
                    .foregroundColor(colors.green)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }
}

// MARK: - User edit form (full admin or non-admin target)
struct UserEditView: View {
    let user: PlatformUser
    let userId: Int
    let onSave: (PlatformUserEditPayload) async -> Void
    let onDismiss: () -> Void
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @StateObject private var vm = UserDetailViewModel()
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var isActive: Bool = true
    @State private var selectedRoles: Set<String> = []
    @State private var availableRoles: [(role: String, label: String)] = []
    @State private var rolesLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                fieldsSection
                rolesSection
                if !user.isAdminRole {
                    sendResetSection
                }
            }
            .padding(20)
        }
        .background(colors.background)
        .navigationTitle(user.fullName?.isEmpty == false ? user.fullName! : user.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onDismiss)
                    .foregroundColor(colors.amber)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        let payload = PlatformUserEditPayload(
                            username: username,
                            first_name: firstName,
                            last_name: lastName,
                            email: email,
                            phone: phone,
                            is_active: isActive ? 1 : 0,
                            roles: Array(selectedRoles)
                        )
                        await onSave(payload)
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(colors.amber)
            }
        }
        .onAppear {
            username = user.username
            firstName = user.firstName ?? (user.fullName ?? "").components(separatedBy: " ").first ?? ""
            if let ln = user.lastName, !ln.isEmpty { lastName = ln }
            else if let fn = user.fullName, let sp = fn.range(of: " ") { lastName = String(fn[sp.upperBound...]) }
            email = user.email ?? ""
            phone = user.phone ?? ""
            isActive = user.isActive == 1
            selectedRoles = Set(user.roles ?? (user.role.map { [$0] } ?? []))
            Task { await loadRoles() }
        }
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldRow("Username", $username)
            HStack(spacing: 12) {
                fieldRow("First name", $firstName)
                fieldRow("Last name", $lastName)
            }
            fieldRow("Email", $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            fieldRow("Phone", $phone)
                .keyboardType(.phonePad)
            Toggle("Active", isOn: $isActive)
                .tint(colors.accent)
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
            Text("ROLES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
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
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var sendResetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send password reset link to user's email.")
                .font(.system(size: 14))
                .foregroundColor(colors.muted)
            Button {
                Task { await vm.sendReset(userId: user.id) }
            } label: {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Send reset")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(colors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(colors.primary.opacity(0.15))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(vm.sendingReset)
            if vm.resetSent {
                Text("Reset link sent.")
                    .font(.system(size: 13))
                    .foregroundColor(colors.green)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func loadRoles() async {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/roles.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONDecoder().decode(RolesResponse.self, from: data),
              json.ok else { return }
        availableRoles = json.roles.map { (role: $0.role, label: $0.label.isEmpty ? $0.role.capitalized : $0.label) }
        rolesLoaded = true
    }
}

struct RolesResponse: Decodable {
    let ok: Bool
    let roles: [RoleItem]
}
struct RoleItem: Decodable {
    let role: String
    let label: String
}

struct PlatformUserEditPayload {
    let username: String
    let first_name: String
    let last_name: String
    let email: String
    let phone: String
    let is_active: Int
    let roles: [String]
}

@MainActor
final class UserDetailViewModel: ObservableObject {
    @Published var error: String?
    @Published var sendingReset = false
    @Published var resetSent = false

    func save(userId: Int, payload: PlatformUserEditPayload) async {
        error = nil
        guard let token = KeychainHelper.readToken() else {
            error = "Not authenticated"
            return
        }
        guard let url = URL(string: "\(kServerURL)/api/user.php?id=\(userId)") else {
            error = "Invalid URL"
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "username": payload.username,
            "first_name": payload.first_name,
            "last_name": payload.last_name,
            "email": payload.email,
            "phone": payload.phone,
            "is_active": payload.is_active,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                await AuthManager.shared.logout()
                error = "Session expired"
                return
            }
            struct R: Decodable { let ok: Bool; let error: String? }
            let r = try JSONDecoder().decode(R.self, from: data)
            if !r.ok {
                error = r.error ?? "Save failed"
                return
            }
            // Also update roles via user_roles.php
            guard let rolesUrl = URL(string: "\(kServerURL)/api/user_roles.php?id=\(userId)") else { return }
            var rolesReq = URLRequest(url: rolesUrl)
            rolesReq.httpMethod = "PUT"
            rolesReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            rolesReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            rolesReq.httpBody = try? JSONEncoder().encode(["roles": payload.roles])
            let (rolesData, rolesResp) = try await URLSession.shared.data(for: rolesReq)
            if let h = rolesResp as? HTTPURLResponse, h.statusCode != 200 {
                struct R2: Decodable { let error: String? }
                let r2 = try? JSONDecoder().decode(R2.self, from: rolesData)
                error = r2?.error ?? "Failed to update roles"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendReset(userId: Int) async {
        sendingReset = true
        resetSent = false
        error = nil
        defer { sendingReset = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/user_send_reset.php") else {
            error = "Not authenticated"
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONEncoder().encode(["user_id": userId])

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                await AuthManager.shared.logout()
                error = "Session expired"
                return
            }
            struct R: Decodable { let ok: Bool; let error: String?; let message: String? }
            let r = try JSONDecoder().decode(R.self, from: data)
            if r.ok {
                resetSent = true
            } else {
                error = r.error ?? "Failed to send reset"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// Simple flow layout for role chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (idx, pt) in result.positions.enumerated() {
            subviews[idx].place(at: CGPoint(x: bounds.minX + pt.x, y: bounds.minY + pt.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, s.height)
            x += s.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
