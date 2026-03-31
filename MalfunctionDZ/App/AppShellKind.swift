import SwiftUI

/// Staff = full operations app. Member = Alaska Skydive Center app (slim tabs, no ops destinations).
enum AppShellKind {
    case staff
    case member
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
