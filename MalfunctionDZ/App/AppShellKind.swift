import SwiftUI

/// Staff = full operations app (MalfunctionDZ). Member = ASC. Pilot / Packer / HHIO = focused apps.
enum AppShellKind: Equatable {
    case staff
    case member
    case pilot
    case packer
    case hhio

    var hidesStaffOpsUI: Bool { self != .staff }
    var isStaffShell: Bool { self == .staff }
    var isMemberShell: Bool { self == .member }
    var isPilotShell: Bool { self == .pilot }
    var isPackerShell: Bool { self == .packer }
    var isHHIOShell: Bool { self == .hhio }

    var groundSchoolScope: GroundSchoolScope {
        switch self {
        case .pilot: return .pilotTrainingOnly
        default:     return .all
        }
    }
}

/// Which LMS courses to show in Ground School.
enum GroundSchoolScope {
    case all
    case pilotTrainingOnly
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
