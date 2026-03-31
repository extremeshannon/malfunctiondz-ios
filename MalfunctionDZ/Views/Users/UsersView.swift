// File: ASC/Views/Users/UsersView.swift
// User management for Admin, Chief Pilot, Ops Manager.
// Search, filters, Add User, edit by tapping name. Chief Pilot/Ops: see admin, cannot edit, Send reset only.
import SwiftUI
import MalfunctionDZCore

struct PlatformUser: Identifiable, Codable, Hashable {
    let id: Int
    let username: String
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let isActive: Int
    let role: String?
    let roles: [String]?
    enum CodingKeys: String, CodingKey {
        case id, username, email, phone, role, roles
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case isActive = "is_active"
    }
}

extension PlatformUser {
    var displayInitials: String {
        let name = (fullName ?? "").trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2, let f = parts.first?.first, let l = parts.last?.first {
                return String(f).uppercased() + String(l).uppercased()
            }
            if let first = parts.first?.prefix(2) { return String(first).uppercased() }
        }
        return String(username.prefix(2)).uppercased()
    }

    var isAdminRole: Bool {
        let r = (roles ?? (role.map { [$0] } ?? [])).map { $0.lowercased() }
        return !r.isEmpty && !Set(r).isDisjoint(with: ["admin", "master", "godmode"])
    }
}

struct UsersListResponse: Decodable {
    let ok: Bool
    let total: Int
    let users: [PlatformUser]
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, total, users, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decode(Bool.self, forKey: .ok)
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        users = (try? c.decode([PlatformUser].self, forKey: .users)) ?? []
        error = try? c.decodeIfPresent(String.self, forKey: .error)
    }
}

@MainActor
final class UsersViewModel: ObservableObject {
    @Published var users: [PlatformUser] = []
    @Published var total = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchQuery = ""
    @Published var domainFilter = "all"
    @Published var perPage = 25

    private var searchWorkItem: DispatchWorkItem?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let token = KeychainHelper.readToken() else {
            error = "Not authenticated"
            return
        }
        guard var components = URLComponents(string: "\(kServerURL)/api/users.php") else {
            error = "Invalid URL"
            return
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(perPage)"),
            URLQueryItem(name: "offset", value: "0"),
        ]
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: searchQuery.trimmingCharacters(in: .whitespaces)))
        }
        if domainFilter != "all" {
            queryItems.append(URLQueryItem(name: "app", value: domainFilter))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            error = "Invalid URL"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                await AuthManager.shared.logout()
                error = "Session expired"
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                if let errBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = errBody["error"] as? String {
                    error = msg
                } else {
                    error = "You don't have permission to view users"
                }
                return
            }
            let decoded = try JSONDecoder().decode(UsersListResponse.self, from: data)
            guard decoded.ok else {
                error = decoded.error ?? "Failed to load users"
                return
            }
            users = decoded.users
            total = decoded.total
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyAndLoad() async {
        await load()
    }

    func deleteUser(_ user: PlatformUser) async -> Bool {
        guard let token = KeychainHelper.readToken() else {
            error = "Not authenticated"
            return false
        }
        guard let url = URL(string: "\(kServerURL)/api/user.php?id=\(user.id)") else {
            error = "Invalid URL"
            return false
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                await AuthManager.shared.logout()
                error = "Session expired"
                return false
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                error = "You don't have permission to delete users"
                return false
            }
            struct R: Decodable { let ok: Bool; let error: String? }
            let r = try JSONDecoder().decode(R.self, from: data)
            if r.ok {
                return true
            } else {
                error = r.error ?? "Delete failed"
                return false
            }
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

struct UsersView: View {
    @StateObject private var vm = UsersViewModel()
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var showAddUser = false
    @State private var userToDelete: PlatformUser?
    @State private var deletedUserName: String?

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Search + filters toolbar
                    toolbarSection

                    if vm.isLoading && vm.users.isEmpty {
                        Spacer()
                        VStack {
                            ProgressView().tint(colors.accent).scaleEffect(1.2)
                            Text("Loading users…")
                                .font(.system(size: 14))
                                .foregroundColor(colors.muted)
                                .padding(.top, 12)
                        }
                    } else if let err = vm.error {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(colors.amber)
                            Text(err)
                                .font(.system(size: 15))
                                .foregroundColor(colors.text)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Retry") { Task { await vm.load() } }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(colors.accent)
                        }
                    } else if vm.users.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 48))
                                .foregroundColor(colors.muted.opacity(0.5))
                            Text("No users found")
                                .font(.headline)
                                .foregroundColor(colors.muted)
                        }
                    } else {
                        List {
                            ForEach(vm.users) { u in
                                NavigationLink(value: u) {
                                    UserRow(user: u)
                                }
                                .listRowBackground(colors.card)
                                .listRowSeparatorTint(colors.border)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        userToDelete = u
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddUser = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .status) {
                    if vm.total > 0 {
                        Text("Total: \(vm.total)")
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                    }
                }
            }
            .navigationDestination(for: PlatformUser.self) { user in
                UserDetailView(user: user)
            }
            .sheet(isPresented: $showAddUser) {
                UserAddView(onDismiss: {
                    showAddUser = false
                    Task { await vm.load() }
                })
            }
            .alert("Delete User", isPresented: Binding(
                get: { userToDelete != nil },
                set: { if !$0 { userToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { userToDelete = nil }
                Button("Delete", role: .destructive) {
                    guard let u = userToDelete else { return }
                    Task {
                        let ok = await vm.deleteUser(u)
                        if ok {
                            deletedUserName = u.username
                            await vm.load()
                            userToDelete = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                deletedUserName = nil
                            }
                        } else {
                            userToDelete = nil
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete \(userToDelete?.username ?? "")? This cannot be undone.")
            }
            .overlay(alignment: .top) {
                if let name = deletedUserName {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(colors.green)
                        Text("\(name) was deleted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colors.text)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.green, lineWidth: 2))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.top, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    private var toolbarSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(colors.muted)
                TextField("username, name, email, phone", text: $vm.searchQuery)
                    .font(.system(size: 15))
                    .foregroundColor(colors.text)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(colors.card)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))

            HStack(spacing: 10) {
                Picker("Domain", selection: $vm.domainFilter) {
                    Text("All").tag("all")
                    Text("Ops").tag("ops")
                    Text("Aircraft").tag("aircraft")
                    Text("Loft").tag("loft")
                    Text("LMS").tag("lms")
                }
                .pickerStyle(.menu)

                Picker("Per page", selection: $vm.perPage) {
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                }
                .pickerStyle(.menu)

                Button("Apply") {
                    Task { await vm.applyAndLoad() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(colors.accent)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.navyMid)
    }
}

struct UserRow: View {
    let user: PlatformUser
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(colors.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(user.displayInitials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colors.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.fullName?.isEmpty == false ? user.fullName! : user.username)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colors.text)
                    if user.isActive != 1 {
                        Text("Inactive")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(colors.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colors.muted.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                Text(user.username)
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
                HStack(spacing: 4) {
                    ForEach(roleLabels, id: \.self) { r in
                        Text(r)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(colors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colors.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if roleLabels.isEmpty {
                        Text("No roles")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(colors.muted)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var roleLabels: [String] {
        let roles = user.roles ?? (user.role.map { [$0] } ?? [])
        return roles.prefix(5).map { roleLabel($0) }
    }

    private func roleLabel(_ r: String) -> String {
        switch r.lowercased() {
        case "admin", "master", "godmode": return "Admin"
        case "chief_pilot", "chief pilot": return "Chief Pilot"
        case "ops_admin", "ops": return "Ops"
        case "pilot": return "Pilot"
        case "instructor", "lms_instructor": return "Instructor"
        case "student", "lms_student": return "Student"
        case "manifest": return "Manifest"
        case "loft", "rigger", "rigs": return "Rigs"
        case "loft_customer": return "Loft Customer"
        default: return r.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
