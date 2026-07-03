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
        if let c = vm.jumpCurrency { return c.statusPillKind }
        return .ready
    }

    // MARK: - Stat tiles

    private var statRow: some View {
        HStack(spacing: ASC.Space.sm) {
            statTile(label: "Level", value: levelLabel, accent: ASC.role.accent)
            statTile(label: "Currency", value: currencyLabel, accent: currencyAccent, valueColor: currencyAccent, unit: currencyUnit)
            statTile(label: "Jumps", value: jumpsLabel, accent: ASC.Palette.beacon)
        }
    }

    private func statTile(label: String, value: String, accent: Color, valueColor: Color? = nil, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(ASC.Typography.eyebrow(9))
                .tracking(1.2)
                .foregroundStyle(ASC.Text.muted)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(ASC.Typography.numeric(17))
                    .foregroundStyle(valueColor ?? ASC.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                if let unit {
                    Text(unit)
                        .font(ASC.Typography.caption(11))
                        .foregroundStyle(ASC.Text.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .ascStatTile(accent)
    }

    private var levelLabel: String {
        if let d = vm.studentData, d.currentLevel > 0 { return "AFF \(d.currentLevel)" }
        if auth.currentUser?.isInstructorRole == true { return "INST" }
        return "—"
    }

    private var currencyLabel: String {
        vm.jumpCurrency?.displayLabel ?? "—"
    }

    private var currencyAccent: Color {
        vm.jumpCurrency?.accentColor ?? ASC.Text.muted
    }

    private var currencyUnit: String? {
        guard let days = vm.jumpCurrency?.daysSince else { return nil }
        return "\(days)d"
    }

    private var jumpsLabel: String {
        if let n = vm.homeTotalJumps { return "\(n)" }
        if let n = auth.currentUser?.totalJumps { return "\(n)" }
        return "—"
    }

    // MARK: - Next lesson

    private var nextLessonCard: some View {
        HStack(alignment: .top, spacing: ASC.Space.lg) {
            VStack(alignment: .leading, spacing: ASC.Space.md) {
                ASCWingHeader(title: nextLessonCardTitle)
                nextLessonCardBody
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

    private var nextLessonCardTitle: String {
        if vm.studentData != nil { return "Next Lesson" }
        if vm.instructorData != nil { return "Instructor" }
        return "Training"
    }

    @ViewBuilder
    private var nextLessonCardBody: some View {
        if let d = vm.studentData {
            Text(nextLessonTitle(d))
                .font(ASC.Typography.display(20))
                .foregroundStyle(ASC.Text.primary)
            Text(nextLessonDescription(d))
                .font(ASC.Typography.body(14))
                .foregroundStyle(ASC.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            ASCPrimaryButton(title: "Begin →") {
                openGroundSchoolResume()
            }
            .padding(.top, ASC.Space.sm)
        } else if let inst = vm.instructorData {
            Text(inst.pendingSignoffs > 0 ? "\(inst.pendingSignoffs) PENDING SIGN-OFF\(inst.pendingSignoffs == 1 ? "" : "S")" : "ALL CLEAR")
                .font(ASC.Typography.display(20))
                .foregroundStyle(ASC.Text.primary)
            Text("\(inst.activeStudents) active student\(inst.activeStudents == 1 ? "" : "s")")
                .font(ASC.Typography.body(14))
                .foregroundStyle(ASC.Text.tertiary)
            ASCPrimaryButton(title: inst.pendingSignoffs > 0 ? "Review →" : "Ground School →") {
                openInstructorGroundSchool()
            }
            .padding(.top, ASC.Space.sm)
        } else if vm.memberDashboardLoaded {
            Text(memberEmptyTrainingTitle)
                .font(ASC.Typography.display(20))
                .foregroundStyle(ASC.Text.primary)
            Text(memberEmptyTrainingSubtitle)
                .font(ASC.Typography.body(14))
                .foregroundStyle(ASC.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            if auth.currentUser?.canAccessLogbook == true {
                ASCPrimaryButton(title: "Open Logbook →") {
                    tabSelect.selected = 4
                }
                .padding(.top, ASC.Space.sm)
            }
        } else {
            Text("Loading your course…")
                .font(ASC.Typography.body(14))
                .foregroundStyle(ASC.Text.muted)
        }
    }

    private var memberEmptyTrainingTitle: String {
        if auth.currentUser?.isInstructorRole == true { return "INSTRUCTOR MODE" }
        if auth.currentUser?.canAccessGroundSchool == true { return "NO ACTIVE COURSE" }
        return "WELCOME"
    }

    private var memberEmptyTrainingSubtitle: String {
        if auth.currentUser?.isInstructorRole == true {
            return "Use Ground School to review student sign-offs and progress."
        }
        if auth.currentUser?.canAccessGroundSchool == true {
            return "You are not enrolled in a training course yet. Contact the DZ to get started."
        }
        return "Track jumps and currency from your logbook."
    }

    private func nextLessonTitle(_ d: StudentDashData) -> String {
        if let next = d.nextModuleTitle { return next.uppercased() }
        return d.courseTitle.uppercased()
    }

    private func nextLessonDescription(_ d: StudentDashData) -> String {
        if !d.progressSubtitle.isEmpty { return d.progressSubtitle }
        if let mod = d.currentModuleTitle {
            return "\(d.completedLessons) of \(d.totalLessons) lessons complete · \(mod)"
        }
        return "\(d.completedLessons) of \(d.totalLessons) lessons complete · Level \(d.currentLevel)"
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
                    Button { openGroundSchoolResume() } label: {
                        Text("See all →")
                            .font(ASC.Typography.eyebrow(11))
                            .foregroundStyle(ASC.Text.link)
                    }
                }
                Button { openGroundSchoolResume() } label: {
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

    private func openGroundSchoolResume() {
        if let resume = vm.studentData?.groundSchoolResume {
            tabSelect.openGroundSchool(resume: resume)
        } else {
            tabSelect.selected = 3
        }
    }

    private func openInstructorGroundSchool() {
        tabSelect.openInstructorReviews = true
        tabSelect.selected = 3
    }
}
