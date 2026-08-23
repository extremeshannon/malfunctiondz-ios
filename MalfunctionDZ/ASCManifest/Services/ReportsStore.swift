import Foundation

@MainActor
final class ReportsStore: ObservableObject {
    @Published private(set) var reports: [ManifestReportItem] = []
    @Published var selectedReport: ManifestReportItem?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var session: ManifestSessionStore?

    func bind(session: ManifestSessionStore) {
        self.session = session
    }

    func refresh() async {
        guard let session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await session.apiClient.fetchReportsCatalog()
            guard response.ok else {
                reports = []
                selectedReport = nil
                errorMessage = response.error ?? "Reports are not available."
                return
            }
            reports = response.reports ?? []
            if let selected = selectedReport,
               !reports.contains(where: { $0.key == selected.key }) {
                selectedReport = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ report: ManifestReportItem) {
        selectedReport = report
    }
}
