// MDZPremiumUI — glass cards, hero headers, and ASC-branded components.
import SwiftUI

// MARK: - Old Glory accent bar (web parity: red → white → blue)
public struct MDZOldGloryBar: View {
    public var height: CGFloat = 5
    public init(height: CGFloat = 5) { self.height = height }

    public var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "C8102E"),
                Color(hex: "FFFFFF"),
                Color(hex: "0A2240"),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: height)
    }
}

// MARK: - Ice → gold accent bar (ASC icon palette)
public struct MDZAscAccentBar: View {
    public var height: CGFloat = 4
    public init(height: CGFloat = 4) { self.height = height }

    public var body: some View {
        LinearGradient(
            colors: [Color(hex: "5EC8F2"), Color(hex: "F2B705")],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: height)
    }
}

// MARK: - Content card (glass + gradient border + optional accent / glory bar)
public struct MDZContentCardModifier: ViewModifier {
    public var accent: Color?
    public var gloryBar: Bool
    public var glass: Bool
    public var radius: CGFloat

    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey

    public init(accent: Color? = nil, gloryBar: Bool = false, glass: Bool = true, radius: CGFloat = 16) {
        self.accent = accent
        self.gloryBar = gloryBar
        self.glass = glass
        self.radius = radius
    }

    private var mountain: Bool { MDZTheme.usesMountainBackground(themeKey) }

    public func body(content: Content) -> some View {
        content
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderGradient, lineWidth: mountain ? 1.5 : 1)
            )
            .shadow(color: shadowColor, radius: mountain ? 14 : 6, y: mountain ? 6 : 3)
            .overlay(alignment: .top) { topAccent }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if glass && mountain {
            ZStack {
                colors.card.opacity(0.82)
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.white.opacity(0.06), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            LinearGradient(
                colors: [colors.card, colors.card2.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderGradient: LinearGradient {
        let a = accent ?? colors.primary
        if mountain {
            return LinearGradient(
                colors: [a.opacity(0.45), colors.primary.opacity(0.25), colors.border.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(colors: [colors.border, colors.border], startPoint: .top, endPoint: .bottom)
    }

    private var shadowColor: Color {
        (accent ?? colors.primary).opacity(mountain ? 0.18 : 0.06)
    }

    @ViewBuilder
    private var topAccent: some View {
        if gloryBar {
            MDZOldGloryBar(height: 5)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else if let accent {
            accent
                .frame(height: 4)
                .shadow(color: accent.opacity(0.65), radius: 8, y: 2)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

// MARK: - Glass text field
public struct MDZGlassField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey

    public init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    private var mountain: Bool { MDZTheme.usesMountainBackground(themeKey) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(2)
            HStack(spacing: 10) {
                content()
                    .foregroundColor(colors.text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        mountain ? colors.primary.opacity(0.35) : colors.border,
                        lineWidth: mountain ? 1.5 : 1
                    )
            )
        }
    }

    @ViewBuilder
    private var fieldBackground: some View {
        if mountain {
            ZStack {
                colors.card2.opacity(0.7)
                Rectangle().fill(.ultraThinMaterial)
            }
        } else {
            colors.card
        }
    }
}

// MARK: - Primary CTA button (gold gradient on mountain theme)
public struct MDZPrimaryButton: View {
    let title: String
    var loading: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey

    public init(_ title: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.loading = loading
        self.disabled = disabled
        self.action = action
    }

    private var mountain: Bool { MDZTheme.usesMountainBackground(themeKey) }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(mountain ? Color(hex: "071628") : .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: mountain ? colors.accent.opacity(0.5) : .clear, radius: 14, y: 5)
        }
        .disabled(disabled || loading)
        .opacity(disabled ? 0.55 : 1)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if mountain {
            LinearGradient(
                colors: [Color(hex: "F2B705"), Color(hex: "E89B00"), Color(hex: "F2B705")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            colors.accent
        }
    }
}

// MARK: - Section label
public struct MDZSectionLabel: View {
    let title: String
    var icon: String? = nil
    var color: Color?

    @Environment(\.mdzColors) private var colors

    public init(_ title: String, icon: String? = nil, color: Color? = nil) {
        self.title = title
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .black))
            }
            Text(title)
                .font(.system(size: 10, weight: .black))
                .tracking(2)
        }
        .foregroundColor(color ?? colors.muted)
    }
}

// MARK: - Icon chip (nav rows, headers)
public struct MDZIconChip: View {
    let systemName: String
    var color: Color
    var size: CGFloat = 40

    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey

    public init(_ systemName: String, color: Color, size: CGFloat = 40) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }

    private var mountain: Bool { MDZTheme.usesMountainBackground(themeKey) }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(mountain ? 0.28 : 0.18), color.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(color.opacity(mountain ? 0.35 : 0.2), lineWidth: 1)
        )
    }
}

// MARK: - Profile / settings nav row
public struct MDZNavRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var accent: Color?

    @Environment(\.mdzColors) private var colors

    public init(icon: String, title: String, subtitle: String? = nil, accent: Color? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: 14) {
            MDZIconChip(icon, color: accent ?? colors.accent, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colors.muted.opacity(0.7))
        }
        .padding(16)
    }
}

// MARK: - Avatar with gold + ice ring
public struct MDZAvatarRing: View {
    let initials: String
    var size: CGFloat = 88

    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzThemeKey) private var themeKey

    public init(initials: String, size: CGFloat = 88) {
        self.initials = initials
        self.size = size
    }

    private var mountain: Bool { MDZTheme.usesMountainBackground(themeKey) }

    public var body: some View {
        ZStack {
            if mountain {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "F2B705"), Color(hex: "5EC8F2"), Color(hex: "F2B705")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: size + 8, height: size + 8)
                    .shadow(color: Color(hex: "F2B705").opacity(0.35), radius: 12)
            }
            Circle()
                .fill(
                    LinearGradient(
                        colors: [colors.card2, colors.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                .foregroundColor(colors.primary)
        }
    }
}

// MARK: - Status capsule with glow
public struct MDZStatusCapsule: View {
    let label: String
    let color: Color
    var pulse: Bool = false

    @State private var glow = false

    public init(_ label: String, color: Color, pulse: Bool = false) {
        self.label = label
        self.color = color
        self.pulse = pulse
    }

    public var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: color.opacity(pulse ? (glow ? 0.7 : 0.35) : 0.4), radius: pulse ? (glow ? 14 : 8) : 6, y: 2)
            .onAppear {
                guard pulse else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

// MARK: - View extensions
public extension View {
    func mdzContentCard(accent: Color? = nil, gloryBar: Bool = false, glass: Bool = true, radius: CGFloat = 16) -> some View {
        modifier(MDZContentCardModifier(accent: accent, gloryBar: gloryBar, glass: glass, radius: radius))
    }
}
