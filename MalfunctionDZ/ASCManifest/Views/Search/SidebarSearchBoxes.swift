import SwiftUI

struct SidebarSearchBoxes: View {
    @EnvironmentObject private var session: ManifestSessionStore
    var onSelect: (SearchPerson) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SidebarLiveSearch(
                placeholder: "Search jumper",
                kind: .jumper,
                onSelect: onSelect
            )
            SidebarLiveSearch(
                placeholder: "Search tandem student",
                kind: .tandem,
                onSelect: onSelect
            )
        }
        .padding(.vertical, 4)
    }
}

private enum SidebarSearchKind {
    case jumper, tandem
}

private struct SidebarLiveSearch: View {
    @EnvironmentObject private var session: ManifestSessionStore
    let placeholder: String
    let kind: SidebarSearchKind
    var onSelect: (SearchPerson) -> Void

    @State private var query = ""
    @State private var results: [SearchPerson] = []
    @State private var isSearching = false
    @State private var showResults = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(NightOps.textMuted)
                TextField(placeholder, text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                if isSearching {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if showResults {
                VStack(alignment: .leading, spacing: 0) {
                    if results.isEmpty && query.trimmingCharacters(in: .whitespaces).count >= 2 && !isSearching {
                        Text(kind == .tandem ? "No tandem students match." : "No jumpers match.")
                            .font(.caption)
                            .foregroundStyle(NightOps.textMuted)
                            .padding(10)
                    }
                    ForEach(results.prefix(12)) { person in
                        Button {
                            onSelect(person)
                            query = ""
                            results = []
                            showResults = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                if let email = person.email, !email.isEmpty {
                                    Text(email)
                                        .font(.caption2)
                                        .foregroundStyle(NightOps.textMuted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(NightOps.navyLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onChange(of: query) { _, newValue in
            let q = newValue.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else {
                results = []
                showResults = !q.isEmpty
                return
            }
            Task { await search(q) }
        }
    }

    private func search(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let response: SearchJumpersResponse
            switch kind {
            case .jumper:
                response = try await session.apiClient.searchJumpers(query: q)
            case .tandem:
                response = try await session.apiClient.searchTandemStudents(query: q)
            }
            results = response.people ?? []
            showResults = true
        } catch {
            results = []
            showResults = true
        }
    }
}
