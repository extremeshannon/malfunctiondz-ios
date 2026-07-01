//
//  ASCTheme.swift
//  ASC Suite — iOS Design Tokens
//
//  Alaska Skydive Center · Palmer, AK
//  Shared across Skydiver, Packers, Pilot, and Staff targets via MalfunctionDZCore.
//
//  REQUIRED FONTS — add .ttf files to MalfunctionDZ/Fonts/ and register in Info.plist:
//    BigShouldersDisplay-Black.ttf, BigShouldersDisplay-Bold.ttf
//    SairaCondensed-SemiBold.ttf, SairaCondensed-Bold.ttf, SairaCondensed-ExtraBold.ttf
//    Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Theme namespace

public enum ASC {

  // MARK: Role (per-app accent)

  public enum Role: String {
    case skydiver, packers, pilot, staff

    public var accent: Color {
      switch self {
      case .skydiver, .packers, .staff: return ASC.Palette.hiVis
      case .pilot:                       return ASC.Palette.hiVis
      }
    }

    public var label: String {
      switch self {
      case .skydiver: return "Skydiver"
      case .packers:  return "Packers"
      case .pilot:    return "Pilot"
      case .staff:    return "Staff"
      }
    }
  }

  /// Set once at app launch in each `@main` entry point.
  public static var role: Role = .skydiver

  // MARK: Palette

  public enum Palette {
    public static let midnight  = Color(red: 0.039, green: 0.086, blue: 0.157) // #0A1628
    public static let hangar    = Color(red: 0.071, green: 0.133, blue: 0.216) // #122237
    public static let cordura   = Color(red: 0.122, green: 0.196, blue: 0.325) // #1F3253
    public static let horizon   = Color(red: 0.180, green: 0.353, blue: 0.541) // #2E5A8A
    public static let beacon    = Color(red: 0.180, green: 0.561, blue: 0.910) // #2E8FE8
    public static let daylight  = Color(red: 0.420, green: 0.714, blue: 0.910) // #6BB6E8
    public static let hiVis     = Color(red: 0.988, green: 0.776, blue: 0.157) // #FCC628
    public static let hiVisDeep = Color(red: 0.847, green: 0.608, blue: 0.000) // #D89B00
    public static let snowcap   = Color.white
    public static let riser     = Color(red: 0.580, green: 0.659, blue: 0.761) // #94A8C2
    public static let shadow    = Color(red: 0.435, green: 0.518, blue: 0.627) // #6F84A0

    public static let jumpReady = Color(red: 0.239, green: 0.859, blue: 0.498) // #3DDB7F
    public static let caution   = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
    public static let cutaway   = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
  }

  public enum Surface {
    public static var page:     Color { Palette.midnight }
    public static var card:     Color { Palette.hangar }
    public static var elevated: Color { Color(red: 0.059, green: 0.114, blue: 0.196) }
    public static var deep:     Color { Color(red: 0.047, green: 0.102, blue: 0.176) }
  }

  public enum Text {
    public static var primary:   Color { Palette.snowcap }
    public static var secondary: Color { Color(red: 0.910, green: 0.933, blue: 0.965) }
    public static var tertiary:  Color { Palette.riser }
    public static var muted:     Color { Palette.shadow }
    public static var accent:    Color { ASC.role.accent }
    public static var link:      Color { Palette.daylight }
  }

  public enum Border {
    public static var hair:   Color { Palette.cordura.opacity(0.7) }
    public static var strong: Color { Palette.horizon }
    public static var accent: Color { ASC.role.accent }
  }

  public enum Typography {
    public static func hero(_ size: CGFloat = 48) -> Font {
      .custom("BigShouldersDisplay-Black", size: size)
    }
    public static func display(_ size: CGFloat = 28) -> Font {
      .custom("BigShouldersDisplay-Black", size: size)
    }
    public static func numeric(_ size: CGFloat = 26) -> Font {
      .custom("BigShouldersDisplay-Bold", size: size)
    }
    public static func sectionLabel(_ size: CGFloat = 13) -> Font {
      .custom("SairaCondensed-Bold", size: size)
    }
    public static func eyebrow(_ size: CGFloat = 11) -> Font {
      .custom("SairaCondensed-SemiBold", size: size)
    }
    public static func body(_ size: CGFloat = 15) -> Font {
      .custom("Inter-Regular", size: size)
    }
    public static func bodyMedium(_ size: CGFloat = 15) -> Font {
      .custom("Inter-Medium", size: size)
    }
    public static func caption(_ size: CGFloat = 12) -> Font {
      .custom("Inter-Regular", size: size)
    }
  }

  public enum Space {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
  }

  public enum Radius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 18
    public static let card: CGFloat = 16
    public static let pill: CGFloat = 999
  }
}

// MARK: - Screen background (flat midnight vs mountain gradient)

public struct ASCScreenBackground: View {
  @Environment(\.mdzThemeKey) private var themeKey

  public init() {}

  public var body: some View {
    Group {
      if MDZTheme.usesMountainBackground(themeKey) {
        ASCMountainBackground()
      } else {
        ASC.Surface.page.ignoresSafeArea()
      }
    }
  }
}

public struct ASCScreenBackgroundModifier: ViewModifier {
  public func body(content: Content) -> some View {
    ZStack {
      ASCScreenBackground()
      content
    }
  }
}

extension View {
  public func ascScreenBackground() -> some View {
    modifier(ASCScreenBackgroundModifier())
  }
}

// MARK: - View Modifiers

public struct ASCCardStyle: ViewModifier {
  public init() {}
  public func body(content: Content) -> some View {
    content
      .padding(ASC.Space.lg)
      .background(ASC.Surface.card)
      .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
          .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
      )
  }
}

public struct ASCStatTileStyle: ViewModifier {
  public var accent: Color
  public init(accent: Color = ASC.role.accent) { self.accent = accent }
  public func body(content: Content) -> some View {
    content
      .padding(ASC.Space.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(ASC.Surface.card)
      .clipShape(
        UnevenRoundedRectangle(
          topLeadingRadius: 0, bottomLeadingRadius: ASC.Radius.lg,
          bottomTrailingRadius: ASC.Radius.lg, topTrailingRadius: 0
        )
      )
      .overlay(alignment: .top) {
        Rectangle().fill(accent).frame(height: 2)
      }
  }
}

extension View {
  public func ascCard() -> some View { modifier(ASCCardStyle()) }
  public func ascStatTile(_ accent: Color = ASC.role.accent) -> some View {
    modifier(ASCStatTileStyle(accent: accent))
  }
}

// MARK: - Components

public struct ASCWing: View {
  public enum Direction { case left, right }
  public var direction: Direction = .left
  public var width: CGFloat = 56

  public init(direction: Direction = .left, width: CGFloat = 56) {
    self.direction = direction
    self.width = width
  }

  public var body: some View {
    Canvas { context, size in
      let w = size.width, h = size.height
      var top = Path()
      top.move(to: CGPoint(x: 0, y: h * 0.07))
      top.addLine(to: CGPoint(x: w * 0.94, y: h * 0.07))
      top.addLine(to: CGPoint(x: w, y: h * 0.32))
      top.addLine(to: CGPoint(x: 0, y: h * 0.32))
      top.closeSubpath()
      context.fill(top, with: .color(ASC.Palette.beacon))

      var mid = Path()
      mid.move(to: CGPoint(x: w * 0.17, y: h * 0.43))
      mid.addLine(to: CGPoint(x: w * 0.96, y: h * 0.43))
      mid.addLine(to: CGPoint(x: w, y: h * 0.64))
      mid.addLine(to: CGPoint(x: w * 0.17, y: h * 0.64))
      mid.closeSubpath()
      context.fill(mid, with: .color(Color(red: 0.106, green: 0.435, blue: 0.761)))

      var bot = Path()
      bot.move(to: CGPoint(x: w * 0.35, y: h * 0.75))
      bot.addLine(to: CGPoint(x: w * 0.97, y: h * 0.75))
      bot.addLine(to: CGPoint(x: w, y: h * 0.93))
      bot.addLine(to: CGPoint(x: w * 0.35, y: h * 0.93))
      bot.closeSubpath()
      context.fill(bot, with: .color(Color(red: 0.059, green: 0.298, blue: 0.561)))
    }
    .frame(width: width, height: width * 0.22)
    .scaleEffect(x: direction == .right ? -1 : 1)
  }
}

public struct ASCWingHeader: View {
  public let title: String
  public init(title: String) { self.title = title }

  public var body: some View {
    HStack(spacing: ASC.Space.md) {
      ASCWing(direction: .left, width: 56)
      Text(title.uppercased())
        .font(ASC.Typography.sectionLabel(13))
        .tracking(2.0)
        .foregroundStyle(ASC.Text.primary)
      ASCWing(direction: .right, width: 56)
    }
  }
}

public struct ASCAltimeter: View {
  public var progress: Double
  public var readout: String
  public var label: String
  public var color: Color
  public var size: CGFloat

  public init(
    progress: Double,
    readout: String = "",
    label: String = "",
    color: Color = ASC.Palette.hiVis,
    size: CGFloat = 140
  ) {
    self.progress = progress
    self.readout = readout
    self.label = label
    self.color = color
    self.size = size
  }

  private var needleAngle: Angle { .degrees(-135 + (progress * 270)) }

  public var body: some View {
    VStack(spacing: ASC.Space.sm) {
      ZStack {
        Circle()
          .fill(ASC.Surface.page)
          .overlay(Circle().strokeBorder(ASC.Border.hair, lineWidth: 1))
        Circle()
          .strokeBorder(ASC.Palette.cordura.opacity(0.5), lineWidth: 1)
          .padding(6)
        ForEach(0..<4, id: \.self) { i in
          Rectangle()
            .fill(ASC.Palette.daylight)
            .frame(width: 2, height: 10)
            .offset(y: -(size / 2) + 12)
            .rotationEffect(.degrees(Double(i) * 90))
        }
        ForEach(Array(stride(from: 30, to: 360, by: 30)), id: \.self) { deg in
          if deg.isMultiple(of: 90) == false {
            Rectangle()
              .fill(ASC.Palette.horizon)
              .frame(width: 1, height: 6)
              .offset(y: -(size / 2) + 10)
              .rotationEffect(.degrees(Double(deg)))
          }
        }
        Rectangle()
          .fill(color)
          .frame(width: 3, height: (size / 2) - 18)
          .offset(y: -(size / 4) - 5)
          .rotationEffect(needleAngle)
          .animation(.easeInOut(duration: 0.6), value: progress)
        Circle().fill(color).frame(width: 10, height: 10)
        Circle().fill(ASC.Surface.page).frame(width: 4, height: 4)
      }
      .frame(width: size, height: size)

      if !readout.isEmpty {
        Text(readout)
          .font(ASC.Typography.numeric(26))
          .foregroundStyle(ASC.Text.primary)
      }
      if !label.isEmpty {
        Text(label.uppercased())
          .font(ASC.Typography.eyebrow(10))
          .tracking(2.0)
          .foregroundStyle(ASC.Palette.daylight)
      }
    }
  }
}

public struct ASCStatusPill: View {
  public enum Kind {
    case ready, caution, cutaway, notCurrent, training, level(String)

    public var color: Color {
      switch self {
      case .ready:       return ASC.Palette.jumpReady
      case .caution:     return ASC.Palette.caution
      case .cutaway:     return ASC.Palette.cutaway
      case .notCurrent:  return ASC.Palette.cutaway
      case .training:    return ASC.Palette.daylight
      case .level:       return ASC.Palette.hiVis
      }
    }

    public var text: String {
      switch self {
      case .ready:        return "Jump-Ready"
      case .caution:      return "Caution"
      case .cutaway:      return "Cutaway"
      case .notCurrent:   return "Not Current"
      case .training:     return "In Training"
      case .level(let l): return l
      }
    }
  }

  public let kind: Kind
  public init(kind: Kind) { self.kind = kind }

  public var body: some View {
    HStack(spacing: 6) {
      Circle().fill(kind.color).frame(width: 6, height: 6)
      Text(kind.text.uppercased())
        .font(ASC.Typography.eyebrow(10))
        .tracking(1.4)
        .foregroundStyle(kind.color)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 5)
    .background(kind.color.opacity(0.12))
    .overlay(Capsule().strokeBorder(kind.color.opacity(0.35), lineWidth: 0.5))
    .clipShape(Capsule())
  }
}

public struct ASCPrimaryButton: View {
  public let title: String
  public let action: () -> Void

  public init(title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Text(title.uppercased())
        .font(ASC.Typography.sectionLabel(12))
        .tracking(1.2)
        .foregroundStyle(ASC.Palette.midnight)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(ASC.role.accent)
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.md, style: .continuous))
    }
  }
}

public struct ASCSecondaryButton: View {
  public let title: String
  public let action: () -> Void

  public init(title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Text(title.uppercased())
        .font(ASC.Typography.sectionLabel(12))
        .tracking(1.2)
        .foregroundStyle(ASC.Palette.daylight)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .overlay(
          RoundedRectangle(cornerRadius: ASC.Radius.md, style: .continuous)
            .strokeBorder(ASC.Palette.horizon, lineWidth: 0.5)
        )
    }
  }
}

#if DEBUG
public enum ASCFontDiagnostics {
  public static func logRegisteredASCFonts() {
    let expected = [
      "BigShouldersDisplay-Black", "BigShouldersDisplay-Bold",
      "SairaCondensed-SemiBold", "SairaCondensed-Bold", "SairaCondensed-ExtraBold",
      "Inter-Regular", "Inter-Medium", "Inter-SemiBold",
    ]
    for name in expected {
      let ok = UIFont(name: name, size: 12) != nil
      print("ASC font \(name): \(ok ? "OK" : "MISSING — add to bundle + Info.plist")")
    }
  }
}
#endif
