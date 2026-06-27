// ASC Skydiver — Home · Today (mockup-aligned layout for member shell).
import SwiftUI
import MalfunctionDZCore

struct ASCSkydiverHomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var tabSelect: TabSelection
    @ObservedObject var vm: HomeViewModel
    @Environment(\.mdzThemeKey) private var themeKey

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ASC.Space.xxl) {
                ascLargeTitle
                welcomeBanner
                statRow
                nextLessonCard
                upNextSection
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.top, ASC.Space.md)
            .padding(.bottom, ASC.Space.xxxl)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Large title

    private var ascLargeTitle: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("TODAY")
                .font(ASC.Typography.display(34))
                .foregroundStyle(ASC.Text.primary)
            Text(dateSubtitle)
                .font(ASC.Typography.bodyMedium(14))
                .foregroundStyle(ASC.Text.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateSubtitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    // MARK: - Welcome banner

    private var welcomeBanner: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back")
                    .font(ASC.Typography.eyebrow(11))
                    .tracking(1.2)
                    .foregroundStyle(ASC.Text.muted)
                Text(displayFirstName)
                    .font(ASC.Typography.display(22))
                    .foregroundStyle(ASC.Text.primary)
            }
            Spacer(minLength: 12)
            ASCStatusPill(kind: jumpReadyKind)
        }
        .padding(ASC.Space.lg)
        .background(ASC.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
        )
    }

    private var displayFirstName: String {
        let name = auth.currentUser?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        return auth.currentUser?.username ?? "Skydiver"
    }

    private var jumpReadyKind: ASCStatusPill.Kind {
        if let dz = vm.dzStatus, dz.status.lowercased() == "closed" { return .caution }
        return .ready
    }

    // MARK: - Stat tiles

    private var statRow: some View {
        HStack(spacing: ASC.Space.sm) {
            statTile(label: "Level", value: levelLabel, accent: ASC.role.accent)
            statTile(label: "Currency", value: currencyLabel, accent: ASC.Palette.jumpReady, unit: currencyUnit)
            statTile(label: "Jumps", value: jumpsLabel, accent: ASC.Palette.beacon)
        }
    }

    private func statTile(label: String, value: String, accent: Color, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(ASC.Typography.eyebrow(10))
                .tracking(1.6)
                .foregroundStyle(ASC.Text.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(ASC.Typography.numeric(26))
                    .foregroundStyle(ASC.Text.primary)
                if let unit {
                    Text(unit)
                        .font(ASC.Typography.caption(14))
                        .foregroundStyle(ASC.Text.tertiary)
                }
            }
        }
        .ascStatTile(accent)
    }

    private var levelLabel: String {
        if let d = vm.studentData, d.currentLevel > 0 { return "AFF \(d.currentLevel)" }
        return "—"
    }

    private var currencyLabel: String {
        // Placeholder until jump-currency API is wired on HomeViewModel.
        "—"
    }

    private var currencyUnit: String? { nil }

    private var jumpsLabel: String {
        if let n = auth.currentUser?.totalJumps { return "\(n)" }
        return "—"
    }

    // MARK: - Next lesson

    private var nextLessonCard: some View {
        HStack(alignment: .top, spacing: ASC.Space.lg) {
            VStack(alignment: .leading, spacing: ASC.Space.md) {
                ASCWingHeader(title: "Next Lesson")
                if let d = vm.studentData {
                    Text(nextLessonTitle(d))
                        .font(ASC.Typography.display(20))
                        .foregroundStyle(ASC.Text.primary)
                    Text(nextLessonDescription(d))
                        .font(ASC.Typography.body(14))
                        .foregroundStyle(ASC.Text.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    ASCPrimaryButton(title: "Begin →") {
                        tabSelect.selected = 3
                    }
                    .padding(.top, ASC.Space.sm)
                } else {
                    Text("Loading your course…")
                        .font(ASC.Typography.body(14))
                        .foregroundStyle(ASC.Text.muted)
                }
            }
            if let d = vm.studentData {
                ASCAltimeter(
                    progress: d.progressPct / 100,
                    label: "Done",
                    size: 90
                )
            }
        }
        .ascCard()
    }

    private func nextLessonTitle(_ d: StudentDashData) -> String {
        if let next = d.nextModuleTitle { return next.uppercased() }
        return d.courseTitle.uppercased()
    }

    private func nextLessonDescription(_ d: StudentDashData) -> String {
        "\(d.completedLessons) of \(d.totalLessons) lessons complete · Level \(d.currentLevel)"
    }

    // MARK: - Up next

    @ViewBuilder
    private var upNextSection: some View {
        if let alert = vm.alerts.first(where: { $0.category == "Ground School" }) {
            VStack(alignment: .leading, spacing: ASC.Space.md) {
                HStack {
                    Text("UP NEXT")
                        .font(ASC.Typography.sectionLabel(12))
                        .tracking(2)
                        .foregroundStyle(ASC.Text.muted)
                    Spacer()
                    Button { tabSelect.selected = 3 } label: {
                        Text("See all →")
                            .font(ASC.Typography.eyebrow(11))
                            .foregroundStyle(ASC.Text.link)
                    }
                }
                Button { tabSelect.selected = 3 } label: {
                    HStack(spacing: ASC.Space.md) {
                        Text("—")
                            .font(ASC.Typography.numeric(18))
                            .foregroundStyle(ASC.Palette.daylight)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.message)
                                .font(ASC.Typography.bodyMedium(13))
                                .foregroundStyle(ASC.Text.primary)
                                .multilineTextAlignment(.leading)
                            Text("Ground School")
                                .font(ASC.Typography.caption(11))
                                .foregroundStyle(ASC.Text.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ASC.Text.muted)
                    }
                    .padding(ASC.Space.md)
                    .background(ASC.Surface.card)
                    .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ASC.Radius.lg, style: .continuous)
                            .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
