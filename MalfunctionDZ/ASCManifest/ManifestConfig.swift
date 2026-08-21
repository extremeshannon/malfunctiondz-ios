import Foundation

/// API environment. Demo uses a separate database on the same host (`/demo` prefix).
enum ManifestAppEnvironment: String, CaseIterable, Identifiable {
    case local
    case demo
    case production

    var id: String { rawValue }

    var baseURL: URL {
        switch self {
        case .local:
            URL(string: "http://127.0.0.1:8000")!
        case .production:
            URL(string: "https://malfunctiondz.com")!
        case .demo:
            URL(string: "https://malfunctiondz.com/demo")!
        }
    }

    var displayName: String {
        switch self {
        case .local: "Local (Mac Docker)"
        case .production: "Live"
        case .demo: "Demo"
        }
    }

    var loginHint: String {
        switch self {
        case .local:
            "Uses Docker on this Mac (:8000). admin / Adminpass1! after reset_admin_password."
        case .demo:
            "Separate demo DB on malfunctiondz.com — not your Mac password."
        case .production:
            "Live DZ — use your production staff credentials."
        }
    }
}

enum ManifestAppConfig {
    /// Alaska Skydive Center tenant slug (sent as `X-Dropzone-Slug` when set).
    static let dropzoneSlug = "alaska-skydive-center"

    /// Ops calendar day — matches `platform_dropzones.timezone` for ASC (not device/UTC drift).
    static let opsTimeZoneIdentifier = "America/Anchorage"

    static var opsTimeZone: TimeZone {
        TimeZone(identifier: opsTimeZoneIdentifier) ?? .current
    }

    static var opsCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = opsTimeZone
        return cal
    }

    /// Start of the current ops calendar day (Anchorage).
    static var opsToday: Date {
        let cal = opsCalendar
        return cal.startOfDay(for: Date())
    }

    /// Bundle ID — must match Signing & Capabilities and APNs topic when push is enabled.
    /// Docs: `com.alaskaskydivecenter.manifest` (see platform/docs/IPAD_MANIFEST_APP_MAC.md).
    static let bundleIdentifier = "com.alaskaskydivecenter.manifest"

    #if DEBUG
    /// Simulator on the same Mac → local Docker. Switch to Demo/Production for VPS.
    static var activeEnvironment: ManifestAppEnvironment = .local
    #else
    static var activeEnvironment: ManifestAppEnvironment = .production
    #endif

    static var baseURL: URL { activeEnvironment.baseURL }
}
