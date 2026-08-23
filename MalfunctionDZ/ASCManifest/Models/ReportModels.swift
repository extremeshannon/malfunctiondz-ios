import Foundation

struct ManifestReportItem: Codable, Identifiable, Equatable, Hashable {
    let key: String
    let title: String
    let description: String
    let path: String

    var id: String { key }
}

struct ManifestReportsResponse: Decodable {
    let ok: Bool
    let error: String?
    let reports: [ManifestReportItem]?
}
