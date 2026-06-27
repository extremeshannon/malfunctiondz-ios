// File: ASC/App/ASCTheme.swift
// ASC Suite design system: tokens, components, and modifiers shared by every
// role-specific screen. Additive — does not replace the existing `mdz*` color
// extensions in Foundation.swift until individual screens are migrated.
import SwiftUI

// MARK: - Palette
enum Palette {
    static let navy        = Color(hex: "0A1628")
    static let navyMid     = Color(hex: "0C1D35")
    static let navyLift    = Color(hex: "14406E")
    static let gold        = Color(hex: "FCC628")
    static let beaconBlue  = Color(hex: "8DC8FF")
    static let danger      = Color(hex: "C8102E")
    static let warning     = Color(hex: "F39C12")
    static let success     = Color(hex: "2ECC71")
}

// MARK: - Surface
enum Surface {
    static let background = Palette.navy
    static let card        = Color(hex: "0F2540")
    static let cardAlt     = Color(hex: "0C1D35")
}

// MARK: - Text
enum AscText {
    static let primary = Color(hex: "E8EDF5")
    static let muted   = Color(hex: "6B8CAE")
    static let onGold  = Palette.navy
}

// MARK: - Border
enum Border {
    static let hairline = Color(hex: "1A3A5C")
    static let gold      = Palette.gold.opacity(0.4)
}

// MARK: - Space
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Radius
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 14
    static let pill: CGFloat = 999
}

// MARK: - Typography
// Falls back to the system font automatically if the named font isn't
// registered yet (e.g. before the .ttf files are bundled).
enum Typography {
    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .custom("BigShouldersDisplay-Black", size: size, relativeTo: .largeTitle)
            .weight(weight)
    }
    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("SairaCondensed-SemiBold", size: size, relativeTo: .caption)
            .weight(weight)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter-Regular", size: size, relativeTo: .body)
            .weight(weight)
    }
}

// MARK: - Wing chevron (structural device)
struct ASCWing: View {
    var color: Color = Palette.gold
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: "chevron.right.2")
            .font(.system(size: size, weight: .black))
            .foregroundColor(color)
    }
}

/// Section heading with a leading wing chevron — use in place of a plain
/// uppercase caption label whenever a screen needs a structural divider.
struct ASCWingHeader: View {
    let title: String
    var color: Color = AscText.muted

    var body: some View {
        HStack(spacing: Space.sm) {
            ASCWing(color: color, size: 10)
            Text(title.uppercased())
                .font(Typography.label(11, weight: .black))
                .foregroundColor(color)
                .tracking(2)
        }
    }
}

// MARK: - Altimeter (signature progress component)
struct ASCAltimeter: View {
    /// 0...1
    let progress: Double
    var label: String? = nil
    var size: CGFloat = 64
    var trackColor: Color = Border.hairline
    var fillColor: Color = Palette.gold

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(fillColor, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: clamped)
            VStack(spacing: 0) {
                Text("\(Int(clamped * 100))")
                    .font(Typography.display(size * 0.28))
                    .foregroundColor(AscText.primary)
                if let label {
                    Text(label.uppercased())
                        .font(.system(size: size * 0.1, weight: .bold))
                        .foregroundColor(AscText.muted)
                        .tracking(0.5)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status pill
struct ASCStatusPill: View {
    let label: String
    var color: Color = Palette.beaconBlue

    var body: some View {
        Text(label)
            .font(Typography.label(11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, Space.sm + 2)
            .padding(.vertical, Space.xs)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Primary button (gold — the only CTA color across all roles)
struct ASCPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let icon { Image(systemName: icon) }
                Text(title).font(Typography.label(15, weight: .bold))
            }
            .foregroundColor(AscText.onGold)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Palette.gold)
            .cornerRadius(Radius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary button (outline, navy surface)
struct ASCSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let icon { Image(systemName: icon) }
                Text(title).font(Typography.label(15, weight: .semibold))
            }
            .foregroundColor(AscText.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Surface.card)
            .cornerRadius(Radius.md)
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Border.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View modifiers
struct ASCCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Surface.card)
            .cornerRadius(Radius.lg)
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Border.hairline, lineWidth: 1))
    }
}

struct ASCStatTileModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Space.md)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(Surface.cardAlt)
            .cornerRadius(Radius.md)
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Border.hairline, lineWidth: 1))
    }
}

extension View {
    func ascCard() -> some View { modifier(ASCCardModifier()) }
    func ascStatTile() -> some View { modifier(ASCStatTileModifier()) }
}
