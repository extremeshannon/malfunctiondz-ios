import SwiftUI

enum NightOps {
    static let navy = Color(red: 0.141, green: 0.204, blue: 0.302)       // #24344d
    static let navyLight = Color(red: 0.173, green: 0.247, blue: 0.361) // #2c3f5c
    static let surface = Color(red: 0.106, green: 0.118, blue: 0.180)   // #1b1e2e
    static let accent = Color(red: 1.0, green: 0.416, blue: 0.122)      // #ff6a1f
    static let card = Color(red: 0.125, green: 0.145, blue: 0.220)
    static let textMuted = Color.white.opacity(0.72)
    static let danger = Color.red.opacity(0.85)
    static let success = Color.green.opacity(0.85)

    static let gradientBar = LinearGradient(
        colors: [.red, .white, .blue],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct NightOpsCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(NightOps.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func nightOpsCard() -> some View { modifier(NightOpsCard()) }
}

struct ManifestStatusPill: View {
    let status: ManifestLoadStatus

    var color: Color {
        switch status {
        case .building: .gray
        case .manifesting: .blue
        case .called: NightOps.accent
        case .in_air: .purple
        case .completed: NightOps.success
        case .cancelled: NightOps.danger
        }
    }

    var body: some View {
        Text(status.label.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.25))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct JumpTypeBadge: View {
    let jumpType: String

    var color: Color {
        switch jumpType.lowercased() {
        case "pilot": .blue
        case "tandem": .green
        case "aff": .orange
        case "coach": .teal
        case "wingsuit": NightOps.accent
        default: .gray
        }
    }

    var body: some View {
        Text(jumpType.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
    }
}
