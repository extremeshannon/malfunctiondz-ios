import SwiftUI

struct CheckInPickerSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    @State private var filter = ""
    @State private var selectedUser: EligibleUser?

    private var filtered: [EligibleUser] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.eligibleUsers }
        return store.eligibleUsers.filter { ($0.name ?? "").lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Prep ID / affidavit / briefing, then check them in. The load board stays visible behind this sheet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Filter by name", text: $filter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Jumpers & staff") {
                    ForEach(filtered.prefix(150)) { user in
                        Button {
                            selectedUser = user
                        } label: {
                            HStack {
                                Text(user.name ?? "User \(user.id)")
                                Spacer()
                                if store.checkedIn.contains(where: { $0.id == user.id }) {
                                    Text("In")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Check someone in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedUser) { user in
                CheckInUserSheet(user: user) {
                    Task { await store.refreshCheckIns() }
                }
            }
            .task {
                await store.refreshCheckIns()
            }
        }
    }
}

extension EligibleUser: Hashable {
    static func == (lhs: EligibleUser, rhs: EligibleUser) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
