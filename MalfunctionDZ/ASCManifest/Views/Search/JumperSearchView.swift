import SwiftUI

struct JumperSearchView: View {
    @EnvironmentObject private var session: ManifestSessionStore

    @State private var query = ""
    @State private var results: [SearchPerson] = []
    @State private var isSearching = false
    @State private var selectedPerson: SearchPerson?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(NightOps.textMuted)
                TextField("Search jumper or student", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding()
            .background(NightOps.navy)

            List {
                if results.isEmpty && !query.isEmpty && !isSearching {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(results) { person in
                    Button {
                        selectedPerson = person
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.displayName)
                                .font(.headline)
                            HStack {
                                if let kind = person.kind {
                                    Text(kind.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(NightOps.accent)
                                }
                                if let email = person.email, !email.isEmpty {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .onChange(of: query) { _, newValue in
            guard newValue.count >= 2 else {
                results = []
                return
            }
            Task { await search() }
        }
        .sheet(item: $selectedPerson) { person in
            AccountDetailView(target: person.accountTarget)
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await session.apiClient.searchJumpers(query: q)
            results = response.people ?? []
        } catch {
            results = []
        }
    }
}

extension SearchPerson: Hashable {
    static func == (lhs: SearchPerson, rhs: SearchPerson) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
