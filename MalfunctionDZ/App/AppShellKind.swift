import SwiftUI

/// Staff = full operations app (MalfunctionDZ). Member = Alaska Skydive Center (skydivers & students).
enum AppShellKind {
    case staff
    case member

    /// ASC app — ops/admin surfaces stay in the staff app.
    var hidesStaffOpsUI: Bool { self == .member }
}

private struct AppShellKindKey: EnvironmentKey {
    static let defaultValue: AppShellKind = .staff
}

extension EnvironmentValues {
    var appShell: AppShellKind {
        get { self[AppShellKindKey.self] }
        set { self[AppShellKindKey.self] = newValue }
    }
}
