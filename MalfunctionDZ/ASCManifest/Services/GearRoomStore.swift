import Foundation

@MainActor
final class GearRoomStore: ObservableObject {
    @Published private(set) var rigs: [GearRig] = []
    @Published private(set) var summary: GearSummary?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var session: ManifestSessionStore?

    func bind(session: ManifestSessionStore) {
        self.session = session
    }

    var sortedRigs: [GearRig] {
        rigs.sorted {
            if $0.sortRank != $1.sortRank { return $0.sortRank < $1.sortRank }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    func refresh() async {
        guard let session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await session.apiClient.fetchDzRigs()
            guard response.ok else {
                errorMessage = response.error ?? "Failed to load DZ gear."
                return
            }
            rigs = (response.rigs ?? []).filter(\.isDzRig)
            summary = response.summary
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
