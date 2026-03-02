// File: ASC/Views/Home/HomeView.swift
// iPad: Multi-column grid, wider METAR layout, NavigationStack instead of NavigationView.
import SwiftUI

// MARK: - Tab Selection (shared singleton for programmatic navigation)
class TabSelection: ObservableObject {
    @Published var selected: Int = 0
    static let shared = TabSelection()
}

struct HomeView: View {
    @EnvironmentObject private var auth:      AuthManager
    @EnvironmentObject private var config:    AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @StateObject private var vm = HomeViewModel()
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // iPad uses more columns and wider padding
    private var isWide: Bool { hSizeClass == .regular }
    private var gridColumns: [GridItem] {
        let count = isWide ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }
    private var hPad: CGFloat { isWide ? 32 : 20 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ──────────────────────────────────
                        headerSection
                            .padding(.horizontal, hPad)
                            .padding(.top, isWide ? 28 : 20)
                            .padding(.bottom, 20)

                        // ── METAR ────────────────────────────────────
                        if showMetar {
                            MetarWidget(
                                metar: vm.metar,
                                isLoading: vm.metarLoading,
                                wide: isWide
                            ) { Task { await vm.loadMetar() } }
                            .padding(.horizontal, hPad)
                            .padding(.bottom, 16)
                        }

                        // ── Role quick-action widget ──────────────────
                        roleWidget
                            .padding(.horizontal, hPad)
                            .padding(.bottom, 16)

                        // ── Pilot currency card ───────────────────────
                        if isPilot {
                            PilotCurrencyCard()
                                .padding(.horizontal, hPad)
                                .padding(.bottom, 16)
                        }

                        // ── Module tiles ──────────────────────────────
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            if showAviation {
                                ModuleTile(
                                    icon: "airplane",
                                    title: config.moduleAviation.uppercased(),
                                    subtitle: vm.aviationSummary,
                                    accentColor: .mdzBlue,
                                    badges: vm.aviationBadges,
                                    wide: isWide
                                ) { tabSelect.selected = 1 }
                            }
                            if showLoft {
                                ModuleTile(
                                    icon: "backpack.fill",
                                    title: config.moduleLoft.uppercased(),
                                    subtitle: vm.loftSummary,
                                    accentColor: .mdzGreen,
                                    badges: vm.loftBadges,
                                    wide: isWide
                                ) { tabSelect.selected = 2 }
                            }
                            if showGroundSchool {
                                ModuleTile(
                                    icon: "graduationcap.fill",
                                    title: config.moduleGroundSchool.uppercased(),
                                    subtitle: vm.groundSchoolSummary,
                                    accentColor: .mdzAmber,
                                    badges: vm.groundSchoolBadges,
                                    wide: isWide
                                ) { tabSelect.selected = 3 }
                            }
                            if showManifest {
                                ModuleTile(
                                    icon: "list.clipboard.fill",
                                    title: config.moduleManifest.uppercased(),
                                    subtitle: vm.manifestSummary,
                                    accentColor: .mdzRed,
                                    badges: vm.manifestBadges,
                                    wide: isWide
                                ) { /* manifest TBD */ }
                            }
                        }
                        .padding(.horizontal, hPad)

                        // ── Airworthy aircraft (pilot) ────────────────
                        if isPilot && !vm.airworthyAircraft.isEmpty {
                            aircraftSection
                                .padding(.horizontal, hPad)
                                .padding(.top, 24)
                        }

                        // ── Alerts ────────────────────────────────────
                        if !vm.alerts.isEmpty {
                            alertsSection
                                .padding(.horizontal, hPad)
                                .padding(.top, 24)
                        }

                        Spacer(minLength: 40)
                    }
                    // On iPad cap the max width so content doesn't over-stretch
                    .frame(maxWidth: isWide ? 1100 : .infinity)
                    .frame(maxWidth: .infinity) // centre it
                }
                .refreshable { await vm.loadDashboard(user: auth.currentUser) }
            }
            .navigationBarHidden(true)
            .task { await vm.loadDashboard(user: auth.currentUser) }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateString)
                .font(.system(size: isWide ? 12 : 11, weight: .semibold))
                .foregroundColor(.mdzMuted)
                .tracking(2)
                .textCase(.uppercase)

            Text(config.dzName.uppercased())
                .font(.system(size: isWide ? 36 : 28, weight: .black, design: .rounded))
                .foregroundColor(.mdzText)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(greeting)
                    .font(.system(size: isWide ? 15 : 13, weight: .medium))
                    .foregroundColor(.mdzMuted)
                Text("·").foregroundColor(.mdzBorder)
                Text(auth.currentUser?.roleDisplayLabel ?? "")
                    .font(.system(size: isWide ? 15 : 13, weight: .semibold))
                    .foregroundColor(.mdzBlue)
            }
        }
    }

    // MARK: - Role widget
    @ViewBuilder
    private var roleWidget: some View {
        if isAdmin {
            EmptyView()
        } else if isPilot {
            PilotQuickWidget(data: vm.pilotData) {
                tabSelect.selected = 1
            }
        } else if isInstructor {
            InstructorQuickWidget(data: vm.instructorData)
        } else if isStudent {
            StudentProgressWidget(data: vm.studentData) {
                tabSelect.selected = 3
            }
        }
    }

    // MARK: - Aircraft section
    private var aircraftSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AIRWORTHY AIRCRAFT")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(2)

            // 2 columns on iPad, 1 on iPhone
            let acCols = isWide
                ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                : [GridItem(.flexible())]

            LazyVGrid(columns: acCols, spacing: 10) {
                ForEach(vm.airworthyAircraft) { ac in
                    Button { tabSelect.selected = 1 } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.mdzBlue.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "airplane")
                                    .foregroundColor(.mdzBlue)
                                    .font(.system(size: 17))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ac.tailNumber)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.mdzText)
                                Text(ac.model)
                                    .font(.system(size: 11))
                                    .foregroundColor(.mdzMuted)
                            }
                            Spacer()
                            Text(ac.status.capitalized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ac.statusColor)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(ac.statusColor.opacity(0.15))
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right")
                                .foregroundColor(.mdzMuted)
                                .font(.system(size: 11))
                        }
                        .padding(12)
                        .background(Color.mdzCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Alerts section
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY AT A GLANCE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(2)

            let alertCols = isWide
                ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                : [GridItem(.flexible())]

            LazyVGrid(columns: alertCols, spacing: 8) {
                ForEach(vm.alerts) { alert in AlertRow(alert: alert) }
            }
        }
    }

    // MARK: - Role helpers
    private var allRoles: [String] {
        ((auth.currentUser?.roles ?? []) + [auth.currentUser?.role ?? ""]).map { $0.lowercased() }
    }
    private var isAdmin:      Bool { allRoles.contains(where: { ["admin","master","godmode","ops"].contains($0) }) }
    private var isPilot:      Bool { allRoles.contains("pilot") }
    private var isInstructor: Bool { allRoles.contains(where: { ["instructor","lms_instructor"].contains($0) }) }
    private var isStudent:    Bool { allRoles.contains(where: { ["student","lms_student"].contains($0) }) }

    private var showMetar:        Bool { isAdmin || isPilot }
    private var showAviation:     Bool { auth.currentUser?.canAccessAviation    == true }
    private var showLoft:         Bool { auth.currentUser?.canAccessLoft        == true }
    private var showGroundSchool: Bool { auth.currentUser?.canAccessGroundSchool == true }
    private var showManifest:     Bool { isAdmin }

    // MARK: - Helpers
    private var greeting: String {
        let h    = Calendar.current.component(.hour, from: Date())
        let name = auth.currentUser?.firstName ?? auth.currentUser?.username ?? "Jumper"
        switch h {
        case 5..<12:  return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        default:      return "Good evening, \(name)"
        }
    }
    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE · MMM d · h:mm a"
        return f.string(from: Date())
    }
}

// MARK: - METAR Widget (wide mode side-by-side)
struct MetarWidget: View {
    let metar:     MetarData?
    let isLoading: Bool
    var wide:      Bool = false
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.mdzBlue)
                    Text("PAAQ PALMER — WEATHER")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.mdzBlue)
                        .tracking(1.5)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(.mdzMuted)
                }
            }

            if isLoading || metar == nil {
                HStack {
                    ProgressView().tint(.mdzBlue).scaleEffect(0.8)
                    Text("Fetching METAR…").font(.system(size: 12)).foregroundColor(.mdzMuted)
                }
            } else if let m = metar {
                if wide {
                    // iPad: all stats in one horizontal row
                    HStack(alignment: .center, spacing: 24) {
                        // Flight category
                        VStack(spacing: 4) {
                            Text(m.flightCategory)
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(m.flightCategoryColor)
                            Text("CATEGORY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.mdzMuted)
                                .tracking(1)
                        }
                        .frame(width: 90)
                        .padding(12)
                        .background(m.flightCategoryColor.opacity(0.12))
                        .cornerRadius(10)

                        Divider().background(Color.mdzBorder).frame(height: 48)

                        MetarStat(label: "TEMP",
                                  value: m.tempF.map { String(format: "%.0f°F", $0) } ?? "--")
                        MetarStat(label: "WIND", value: m.windSummary)
                        MetarStat(label: "VIS",
                                  value: m.visibilitySM.map { $0 >= 10 ? "10+ SM" : String(format: "%.1f SM", $0) } ?? "--")
                        MetarStat(label: "SKY",  value: m.skyCondition)
                        MetarStat(label: "ALT",  value: m.altimInHg.map { String(format: "%.2f\"", $0) } ?? "--")

                        Spacer()

                        if !m.rawText.isEmpty {
                            Text(m.rawText)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.mdzMuted)
                                .lineLimit(2)
                                .frame(maxWidth: 260, alignment: .trailing)
                        }
                    }
                } else {
                    // iPhone: stacked
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 4) {
                            Text(m.flightCategory)
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(m.flightCategoryColor)
                            Text("CATEGORY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.mdzMuted)
                                .tracking(1)
                        }
                        .frame(width: 72)
                        .padding(10)
                        .background(m.flightCategoryColor.opacity(0.12))
                        .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 20) {
                                MetarStat(label: "TEMP",
                                          value: m.tempF.map { String(format: "%.0f°F", $0) } ?? "--")
                                MetarStat(label: "WIND", value: m.windSummary)
                            }
                            HStack(spacing: 20) {
                                MetarStat(label: "VIS",
                                          value: m.visibilitySM.map { $0 >= 10 ? "10+ SM" : String(format: "%.1f SM", $0) } ?? "--")
                                MetarStat(label: "SKY",  value: m.skyCondition)
                            }
                            MetarStat(label: "ALTIMETER",
                                      value: m.altimInHg.map { String(format: "%.2f inHg", $0) } ?? "--")
                        }
                    }
                    if !m.rawText.isEmpty {
                        Text(m.rawText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.mdzMuted)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(wide ? 20 : 14)
        .background(Color.mdzCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

struct MetarStat: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.mdzMuted).tracking(0.8)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.mdzText)
        }
    }
}

// MARK: - Pilot Quick Widget
struct PilotQuickWidget: View {
    let data:      PilotDashData?
    let onTapMore: () -> Void
    @State private var pulse = false
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 11, weight: .black)).foregroundColor(.mdzBlue)
                    Text("TODAY'S FLIGHTS")
                        .font(.system(size: 11, weight: .black)).foregroundColor(.mdzBlue).tracking(1.5)
                }
                Spacer()
                Button(action: onTapMore) {
                    HStack(spacing: 4) {
                        Text("Aviation").font(.system(size: 11, weight: .semibold)).foregroundColor(.mdzBlue)
                        Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.mdzBlue)
                    }
                }
            }

            if let d = data, d.hasOpenFlight, let tail = d.openTailNumber {
                Button(action: onTapMore) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.mdzGreen)
                            .frame(width: 10, height: 10)
                            .scaleEffect(pulse ? 1.35 : 1.0)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                        Text("FLIGHT ACTIVE — \(tail)")
                            .font(.system(size: isWide ? 15 : 13, weight: .black))
                            .foregroundColor(.mdzGreen)
                        Spacer()
                        Text("TAP TO MANAGE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.mdzGreen)
                            .tracking(1)
                    }
                    .padding(12)
                    .background(Color.mdzGreen.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzGreen.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .onAppear { pulse = true }
            }

            if let d = data, d.flightCount > 0 {
                HStack(spacing: 0) {
                    PilotStatCell(label: "FLIGHTS", value: "\(d.flightCount)").frame(maxWidth: .infinity)
                    Divider().background(Color.mdzBorder)
                    PilotStatCell(label: "LOADS",   value: "\(d.totalLoads)").frame(maxWidth: .infinity)
                    Divider().background(Color.mdzBorder)
                    PilotStatCell(label: "PAX",     value: "\(d.totalPax)").frame(maxWidth: .infinity)
                    Divider().background(Color.mdzBorder)
                    PilotStatCell(label: "HOBBS Δ", value: String(format: "%.1f", d.hobbsDelta)).frame(maxWidth: .infinity)
                }
                .frame(height: isWide ? 72 : 56)
            } else {
                Button(action: onTapMore) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start First Flight of the Day")
                            .font(.system(size: isWide ? 16 : 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: isWide ? 52 : 44)
                    .background(Color.mdzRed)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(isWide ? 20 : 14)
        .background(Color.mdzCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Student Progress Widget
struct StudentProgressWidget: View {
    let data:       StudentDashData?
    let onContinue: () -> Void
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 11, weight: .black)).foregroundColor(.mdzAmber)
                Text("MY PROGRESS")
                    .font(.system(size: 11, weight: .black)).foregroundColor(.mdzAmber).tracking(1.5)
            }
            if let d = data {
                HStack {
                    Text(d.courseTitle)
                        .font(.system(size: isWide ? 16 : 14, weight: .bold))
                        .foregroundColor(.mdzText)
                    Spacer()
                    Text("Level \(d.currentLevel)")
                        .font(.system(size: isWide ? 14 : 12, weight: .semibold)).foregroundColor(.mdzBlue)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.mdzBlue.opacity(0.12)).clipShape(Capsule())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.mdzBorder).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(Color.mdzAmber)
                            .frame(width: geo.size.width * CGFloat(d.progressPct / 100), height: 8)
                            .animation(.easeOut(duration: 0.8), value: d.progressPct)
                    }
                }.frame(height: 8)
                HStack {
                    Text("\(d.completedLessons) / \(d.totalLessons) lessons")
                        .font(.system(size: isWide ? 13 : 11)).foregroundColor(.mdzMuted)
                    Spacer()
                    Text("\(Int(d.progressPct))%")
                        .font(.system(size: isWide ? 13 : 11, weight: .bold)).foregroundColor(.mdzAmber)
                }
                Button(action: onContinue) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text(d.nextModuleTitle.map { "Continue: \($0)" } ?? "Go to Ground School")
                            .font(.system(size: isWide ? 15 : 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: isWide ? 50 : 40)
                    .background(Color.mdzAmber).cornerRadius(10)
                }
                .buttonStyle(.plain)
            } else {
                Text("Loading progress…").font(.system(size: 13)).foregroundColor(.mdzMuted)
            }
        }
        .padding(isWide ? 20 : 14)
        .background(Color.mdzCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Instructor Quick Widget
struct InstructorQuickWidget: View {
    let data: InstructorDashData?
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11, weight: .black)).foregroundColor(.mdzGreen)
                Text("INSTRUCTOR OVERVIEW")
                    .font(.system(size: 11, weight: .black)).foregroundColor(.mdzGreen).tracking(1.5)
            }
            if let d = data {
                HStack(spacing: 0) {
                    PilotStatCell(label: "STUDENTS",  value: "\(d.activeStudents)").frame(maxWidth: .infinity)
                    Divider().background(Color.mdzBorder)
                    PilotStatCell(label: "SIGN-OFFS", value: "\(d.pendingSignoffs)").frame(maxWidth: .infinity)
                }
                .frame(height: isWide ? 72 : 56)
            } else {
                Text("Loading…").font(.system(size: 13)).foregroundColor(.mdzMuted)
            }
        }
        .padding(isWide ? 20 : 14)
        .background(Color.mdzCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Module Tile
struct ModuleTile: View {
    let icon:        String
    let title:       String
    let subtitle:    String
    let accentColor: Color
    let badges:      [DashBadge]
    var wide:        Bool = false
    let onTap:       () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: wide ? 14 : 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: wide ? 28 : 22, weight: .semibold))
                        .foregroundColor(accentColor)
                    Spacer()
                    Circle().fill(accentColor).frame(width: 6, height: 6)
                }
                Text(title)
                    .font(.system(size: wide ? 15 : 13, weight: .black))
                    .foregroundColor(.mdzText)
                    .tracking(0.5).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: wide ? 13 : 11, weight: .medium))
                    .foregroundColor(.mdzMuted).lineLimit(2)
                if !badges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(badges) { b in
                            Text(b.label)
                                .font(.system(size: wide ? 11 : 10, weight: .bold))
                                .foregroundColor(b.color)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(b.color.opacity(0.15)).clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(wide ? 20 : 14)
            .frame(maxWidth: .infinity, minHeight: wide ? 160 : 130, alignment: .topLeading)
            .background(Color.mdzCard).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))
            .overlay(VStack { Rectangle().fill(accentColor).frame(height: 3).cornerRadius(14); Spacer() })
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

// MARK: - Shared sub-views
// PilotStatCell lives in Foundation.swift so Aviation and Home can both use it

struct AlertRow: View {
    let alert: DashAlert
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(alert.color).frame(width: 8, height: 8)
            Text(alert.message)
                .font(.system(size: 13, weight: .medium)).foregroundColor(.mdzText)
            Spacer()
            Text(alert.category)
                .font(.system(size: 10, weight: .semibold)).foregroundColor(alert.color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(alert.color.opacity(0.15)).clipShape(Capsule())
        }
        .padding(12).background(Color.mdzCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}
