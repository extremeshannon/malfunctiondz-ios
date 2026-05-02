// File: ASC/Views/Home/HomeView.swift
// iPad: Multi-column grid, wider METAR layout, NavigationStack instead of NavigationView.
import SwiftUI
import MalfunctionDZCore

// MARK: - Tab Selection (shared singleton for programmatic navigation)
class TabSelection: ObservableObject {
    @Published var selected: Int = 0
    static let shared = TabSelection()
}

struct HomeView: View {
    @EnvironmentObject private var auth:      AuthManager
    @EnvironmentObject private var config:    AppConfig
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.appShell) private var appShell
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @StateObject private var vm = HomeViewModel()
    @State private var dzStatusJustUpdated = false
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var showDzStatusModal = false
    @State private var showDzAnnouncementModal = false
    @AppStorage("mdz_dismissed_announcement") private var dismissedAnnouncementKey = ""

    private var isMemberShell: Bool { appShell == .member }

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
                colors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ──────────────────────────────────
                        headerSection
                            .padding(.horizontal, hPad)
                            .padding(.top, isWide ? 16 : 12)
                            .padding(.bottom, 12)

                        // ── Dismissible announcement banner (when there is an announcement; no big card) ─
                        if showDzStatus, let dz = vm.dzStatus, let ann = dz.announcement, !ann.isEmpty, dismissedAnnouncementKey != ann {
                            announcementBanner(text: ann) {
                                dismissedAnnouncementKey = ann
                            }
                            .padding(.horizontal, hPad)
                            .padding(.bottom, 12)
                        }

                        // ── (Removed: big DZ status card and "Send announcement" button; pill in header is tappable for Admin) ─

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

                        if auth.currentUser?.canCheckInUsers == true && !isMemberShell {
                            StaffCheckInCard()
                                .padding(.horizontal, hPad)
                                .padding(.bottom, 16)
                        }

                        // ── Manifest-only: 25 Jump Check + Aviation status (staff app only) ──
                        if isManifestOnly && !isMemberShell {
                            manifestHomeSection
                                .padding(.horizontal, hPad)
                                .padding(.bottom, 16)
                        }

                        // ── Students awaiting check-offs (instructors) ──
                        if isInstructor, let pending = vm.instructorData?.pendingSignoffs, pending > 0 {
                            studentsAwaitingCard(pending: pending)
                                .padding(.horizontal, hPad)
                                .padding(.bottom, 16)
                        }

                        // ── Pilot currency card ───────────────────────
                        if isPilot {
                            PilotCurrencyCard()
                                .padding(.horizontal, hPad)
                                .padding(.bottom, 16)
                        }

                        // ── My rigs (reserve / AAD expiry) ─────────────
                        if !vm.myRigs.isEmpty {
                            RigExpiryCard(rigs: vm.myRigs) {
                                if auth.currentUser?.canAccessMyRigs == true
                                    || (isMemberShell && auth.currentUser?.canAccessLogbook == true) {
                                    tabSelect.selected = 6
                                } else {
                                    tabSelect.selected = 4
                                }
                            }
                            .padding(.horizontal, hPad)
                            .padding(.bottom, 16)
                        }

                        // ── Logbook config (Start Freefall, Home DZ) for skydivers ──
                        if (showLogbook || showGroundSchool) && !isAdmin {
                            LogbookConfigCard(vm: vm)
                                .padding(.horizontal, hPad)
                                .padding(.bottom, 16)
                        }

                        // ── Module tiles ──────────────────────────────
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            if showAviation && !isMemberShell {
                                ModuleTile(
                                    icon: "airplane",
                                    title: config.moduleAviation.uppercased(),
                                    subtitle: vm.aviationSummary,
                                    accentColor: colors.aviation,
                                    badges: vm.aviationBadges,
                                    wide: isWide
                                ) { tabSelect.selected = 1 }
                            }
                            if showLoft && !isMemberShell {
                                ModuleTile(
                                    icon: "backpack.fill",
                                    title: config.moduleLoft.uppercased(),
                                    subtitle: vm.loftSummary,
                                    accentColor: colors.loft,
                                    badges: vm.loftBadges,
                                    wide: isWide
                                ) { tabSelect.selected = 2 }
                            }
                            if auth.currentUser?.canAccessRigs == true && !isMemberShell {
                                ModuleTile(
                                    icon: "briefcase.fill",
                                    title: "RIGS",
                                    subtitle: "Personal rigs + DZ rigs (read-only)",
                                    accentColor: colors.green,
                                    badges: [],
                                    wide: isWide
                                ) { tabSelect.selected = 6 }
                            } else {
                                if auth.currentUser?.canAccessMyRigs == true
                                    || (isMemberShell && auth.currentUser?.canAccessLogbook == true) {
                                    ModuleTile(
                                        icon: "briefcase.fill",
                                        title: "MY RIGS",
                                        subtitle: "Your rigs — reserve & AAD expiry",
                                        accentColor: colors.green,
                                        badges: [],
                                        wide: isWide
                                    ) { tabSelect.selected = 6 }
                                }
                                if auth.currentUser?.canAccessDzRigs == true && !isMemberShell {
                                    ModuleTile(
                                        icon: "square.stack.3d.up.fill",
                                        title: "DZ RIGS",
                                        subtitle: isAdmin ? vm.loftSummary : "DZ-owned rigs — Packers can mark packed",
                                        accentColor: colors.dz,
                                        badges: isAdmin ? vm.loftBadges : [],
                                        wide: isWide
                                    ) { tabSelect.selected = 7 }
                                }
                            }
                            if showGroundSchool {
                                ModuleTile(
                                    icon: "graduationcap.fill",
                                    title: config.moduleGroundSchool.uppercased(),
                                    subtitle: vm.groundSchoolSummary,
                                    accentColor: colors.groundSchool,
                                    badges: vm.groundSchoolBadges,
                                    wide: isWide
                                ) { tabSelect.selected = 3 }
                            }
                            if showLogbook {
                                ModuleTile(
                                    icon: "book.closed.fill",
                                    title: "LOGBOOK",
                                    subtitle: "Jump entries & sign-offs",
                                    accentColor: colors.amber,
                                    badges: [],
                                    wide: isWide
                                ) { tabSelect.selected = 4 }
                            }
                            if auth.currentUser?.canAccessCalendar == true {
                                ModuleTile(
                                    icon: "calendar",
                                    title: "CALENDAR",
                                    subtitle: isMemberShell ? "Events" : "Events & todos",
                                    accentColor: colors.primary,
                                    badges: [],
                                    wide: isWide
                                ) { tabSelect.selected = 5 }
                                if !isMemberShell {
                                    ModuleTile(
                                        icon: "square.grid.3x3.fill",
                                        title: "SHIFTS",
                                        subtitle: "My schedule & pick shifts",
                                        accentColor: colors.accent,
                                        badges: [],
                                        wide: isWide
                                    ) { tabSelect.selected = 12 }
                                }
                            }
                            if showManifest && !isMemberShell {
                                ModuleTile(
                                    icon: "list.clipboard.fill",
                                    title: config.moduleManifest.uppercased(),
                                    subtitle: vm.manifestSummary,
                                    accentColor: colors.accent,
                                    badges: vm.manifestBadges,
                                    wide: isWide
                                ) { /* manifest TBD */ }
                            }
                            if auth.currentUser?.canManageUsers == true && !isMemberShell {
                                ModuleTile(
                                    icon: "person.2.fill",
                                    title: "USERS",
                                    subtitle: "Manage logins and roles",
                                    accentColor: colors.accent,
                                    badges: [],
                                    wide: isWide
                                ) { tabSelect.selected = 8 }
                            }
                        }
                        .padding(.horizontal, hPad)

                        // ── Airworthy aircraft (pilot) — staff app only ──
                        if isPilot && !vm.airworthyAircraft.isEmpty && !isMemberShell {
                            aircraftSection
                                .padding(.horizontal, hPad)
                                .padding(.top, 24)
                        }

                        // ── Alerts (Today at a Glance) — hidden for admins
                        if !isAdmin && !vm.alerts.isEmpty {
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
                .refreshable {
                    await vm.loadDashboard(user: auth.currentUser)
                    await vm.loadDzStatus()
                }
            }
            .navigationBarHidden(true)
            .task { await vm.loadDashboard(user: auth.currentUser) }
            .task(id: "dz") { await vm.loadDzStatus() }
            .onReceive(NotificationCenter.default.publisher(for: .dzStatusDidUpdateFromPush)) { _ in
                Task { await vm.loadDzStatus() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await vm.loadDzStatus() }
                }
            }
            .onReceive(Timer.publish(every: 120, on: .main, in: .common).autoconnect()) { _ in
                Task {
                    await vm.loadDzStatus()
                    if showMetar { await vm.loadMetar() }
                }
            }
            .overlay(alignment: .top) {
                if dzStatusJustUpdated {
                    DZStatusUpdatedBanner(onDismiss: {
                        dzStatusJustUpdated = false
                    })
                    .padding(.horizontal, hPad)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .animation(.easeOut(duration: 0.3), value: dzStatusJustUpdated)
            .sheet(isPresented: $showDzStatusModal) {
                DZStatusModalView(onSaved: {
                    Task { await vm.loadDzStatus() }
                    dzStatusJustUpdated = true
                })
            }
            .sheet(isPresented: $showDzAnnouncementModal) {
                DZAnnouncementModalView(onSaved: {
                    Task { await vm.loadDzStatus() }
                    dzStatusJustUpdated = true
                })
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateString)
                    .font(.system(size: isWide ? 12 : 11, weight: .semibold))
                    .foregroundColor(colors.muted)
                    .tracking(2)
                    .textCase(.uppercase)

                Text(config.dzName.uppercased())
                    .font(.system(size: isWide ? 36 : 28, weight: .black, design: .rounded))
                    .foregroundColor(colors.text)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(greeting)
                        .font(.system(size: isWide ? 15 : 13, weight: .medium))
                        .foregroundColor(colors.muted)
                    Text("·").foregroundColor(colors.border)
                    Text(auth.currentUser?.roleDisplayLabel ?? "")
                        .font(.system(size: isWide ? 15 : 13, weight: .semibold))
                        .foregroundColor(colors.primary)
                }
            }
            Spacer(minLength: 12)
            if showDzStatus {
                if auth.currentUser?.canUpdateDzStatus == true && !isMemberShell {
                    HStack(spacing: 10) {
                        Button {
                            showDzStatusModal = true
                        } label: {
                            DZStatusPill(status: vm.dzStatus)
                        }
                        .buttonStyle(.plain)
                        Button {
                            showDzAnnouncementModal = true
                        } label: {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 12))
                                .foregroundColor(colors.amber)
                        }
                    }
                } else {
                    DZStatusPill(status: vm.dzStatus)
                }
            }
        }
    }

    @ViewBuilder
    private func announcementBanner(text: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 14))
                .foregroundColor(colors.amber)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(colors.muted)
            }
        }
        .padding(12)
        .background(colors.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
    }

    // MARK: - Manifest home section (DZ Rigs + Aviation status)
    @ViewBuilder
    private var manifestHomeSection: some View {
        VStack(spacing: 14) {
            if let dr = vm.dzRigsSummary {
                ManifestStatusCard(
                    icon: "square.stack.3d.up.fill",
                    title: "DZ RIGS",
                    subtitle: dr.summaryText,
                    accentColor: colors.dz
                )
            }
            ManifestStatusCard(
                icon: "airplane",
                title: config.moduleAviation.uppercased(),
                subtitle: vm.aviationSummary,
                accentColor: colors.aviation,
                badges: vm.aviationBadges
            )
        }
    }

    // MARK: - Role widget
    @ViewBuilder
    private var roleWidget: some View {
        if isAdmin {
            EmptyView()
        } else if isPilot && !isMemberShell {
            PilotQuickWidget(data: vm.pilotData) {
                tabSelect.selected = 1
            }
        } else if isInstructor {
            InstructorQuickWidget(
                data: vm.instructorData,
                onTapGroundSchool: (vm.instructorData?.pendingSignoffs ?? 0) > 0 ? { tabSelect.selected = 3 } : nil
            )
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
                .foregroundColor(colors.muted)
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
                                    .fill(colors.aviation.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "airplane")
                                    .foregroundColor(colors.aviation)
                                    .font(.system(size: 17))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ac.tailNumber)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(colors.text)
                                Text(ac.model)
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.muted)
                            }
                            Spacer()
                            Text(ac.status.capitalized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ac.statusColor)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(ac.statusColor.opacity(0.15))
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right")
                                .foregroundColor(colors.muted)
                                .font(.system(size: 11))
                        }
                        .padding(12)
                        .background(colors.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
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
                .foregroundColor(colors.muted)
                .tracking(2)

            let alertCols = isWide
                ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                : [GridItem(.flexible())]

            LazyVGrid(columns: alertCols, spacing: 8) {
                ForEach(vm.alerts) { alert in AlertRow(alert: alert) }
            }
        }
    }

    // MARK: - Students awaiting check-offs (instructor dashboard)
    private func studentsAwaitingCard(pending: Int) -> some View {
        Button {
            tabSelect.selected = 3
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colors.amber.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "pencil.and.signature")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(colors.amber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("STUDENTS AWAITING CHECK-OFFS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(colors.amber)
                        .tracking(1.2)
                    Text("\(pending) student\(pending == 1 ? "" : "s") awaiting sign-off")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colors.text)
                    Text("Tap to open Ground School")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.muted)
            }
            .padding(16)
            .background(colors.card)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.amber.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Role helpers
    private var allRoles: [String] {
        ((auth.currentUser?.roles ?? []) + [auth.currentUser?.role ?? ""]).map { $0.lowercased() }
    }
    private var isAdmin:      Bool { allRoles.contains(where: { ["admin","master","godmode","ops","ops_admin"].contains($0) }) }
    private var isPilot:      Bool { allRoles.contains("pilot") }
    private var isInstructor: Bool { allRoles.contains(where: { ["instructor","lms_instructor"].contains($0) }) }
    private var isStudent:    Bool { allRoles.contains(where: { ["student","lms_student"].contains($0) }) }
    private var isOps:        Bool { allRoles.contains("ops") }
    private var isManifestOnly: Bool { auth.currentUser?.isManifestOnly == true }

    // Weather + DZ Status for everyone (all authenticated users)
    private var showMetar: Bool { true }
    private var showDzStatus: Bool { true }
    private var showAviation:     Bool { auth.currentUser?.canAccessAviation    == true }
    private var showLoft:         Bool { auth.currentUser?.canAccessLoft        == true }
    private var showGroundSchool: Bool { auth.currentUser?.canAccessGroundSchool == true }
    /// Logbook tile on Home — for skydivers without Ground School access
    private var showLogbook:      Bool { auth.currentUser?.canAccessLogbook == true && !showGroundSchool }
    private var showManifest:     Bool { auth.currentUser?.canSeeManifestTile == true }

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
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(colors.primary)
                    Text("PAAQ PALMER — WEATHER")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(colors.primary)
                        .tracking(1.5)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(colors.muted)
                }
            }

            if isLoading || metar == nil {
                HStack {
                    ProgressView().tint(colors.primary).scaleEffect(0.8)
                    Text("Fetching METAR…").font(.system(size: 12)).foregroundColor(colors.muted)
                }
            } else if let m = metar {
                if wide {
                    // iPad: all stats in one horizontal row
                    HStack(alignment: .center, spacing: 24) {
                        // Flight category
                        VStack(spacing: 4) {
                            Text(m.resolvedFlightCategory)
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(m.flightCategoryColor)
                            Text("CATEGORY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(colors.muted)
                                .tracking(1)
                        }
                        .frame(width: 90)
                        .padding(12)
                        .background(m.flightCategoryColor.opacity(0.12))
                        .cornerRadius(10)

                        Divider().background(colors.border).frame(height: 48)

                        MetarStat(label: "TEMP",
                                  value: m.tempF.map { String(format: "%.0f°F", $0) } ?? "--")
                        MetarStat(label: "WIND", value: m.windSummary)
                        MetarStat(label: "VIS",
                                  value: m.visibilitySM.map { $0 >= 10 ? "10+ SM" : String(format: "%.1f SM", $0) } ?? "--")
                        MetarStat(label: "SKY",  value: m.skyCondition)
                        MetarStat(label: "ALT",  value: m.altimInHgDisplay.map { String(format: "%.2f\"", $0) } ?? "--")

                        Spacer()

                        if !m.rawText.isEmpty {
                            Text(m.rawText)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(colors.muted)
                                .lineLimit(2)
                                .frame(maxWidth: 260, alignment: .trailing)
                        }
                    }
                } else {
                    // iPhone: stacked
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 4) {
                            Text(m.resolvedFlightCategory)
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(m.flightCategoryColor)
                            Text("CATEGORY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(colors.muted)
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
                                      value: m.altimInHgDisplay.map { String(format: "%.2f inHg", $0) } ?? "--")
                        }
                    }
                    if !m.rawText.isEmpty {
                        Text(m.rawText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(colors.muted)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(wide ? 20 : 14)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
    }
}

struct MetarStat: View {
    let label: String; let value: String
    @Environment(\.mdzColors) private var colors
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(colors.muted).tracking(0.8)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(colors.text)
        }
    }
}

// MARK: - Staff check-in (Manifest / Ops Admin / Admin — check others in; no self check-in)
struct StaffCheckInCard: View {
    @Environment(\.mdzColors) private var colors
    @State private var dateStr: String = StaffCheckInCard.todayString()
    @State private var users: [(id: Int, name: String)] = []
    @State private var selectedId: Int = 0
    @State private var loadingList = false
    @State private var submitting = false
    @State private var banner: String?
    @State private var bannerIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.primary)
                Text("CHECK SOMEONE IN")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1.5)
                Spacer()
                if loadingList {
                    ProgressView().scaleEffect(0.85)
                } else {
                    Button {
                        Task { await loadUsers() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Pick a person and date. Jumpers cannot check themselves in from the app.")
                .font(.system(size: 12))
                .foregroundColor(colors.muted)

            VStack(alignment: .leading, spacing: 6) {
                Text("DATE (YYYY-MM-DD)")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(0.8)
                TextField("YYYY-MM-DD", text: $dateStr)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colors.text)
                    .padding(10)
                    .background(colors.card2)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("PERSON")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(0.8)
                Picker("Person", selection: $selectedId) {
                    Text("— Select —").tag(0)
                    ForEach(users, id: \.id) { u in
                        Text(u.name).tag(u.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(colors.card2)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
            }

            if let b = banner {
                Text(b)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(bannerIsError ? colors.danger : colors.green)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((bannerIsError ? colors.danger : colors.green).opacity(0.12))
                    .cornerRadius(8)
            }

            Button {
                Task { await submitCheckIn() }
            } label: {
                HStack {
                    if submitting {
                        ProgressView().tint(.white).scaleEffect(0.9)
                    }
                    Text("Check in")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(colors.primary)
            .disabled(submitting || selectedId <= 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
        .overlay(
            Rectangle()
                .fill(colors.primary)
                .frame(height: 3)
                .cornerRadius(2),
            alignment: .top
        )
        .task { await loadUsers() }
    }

    private func loadUsers() async {
        loadingList = true
        defer { loadingList = false }
        banner = nil
        users = await CheckinAPI.fetchEligibleUsersForCheckIn()
        if !users.contains(where: { $0.id == selectedId }) {
            selectedId = 0
        }
    }

    private func submitCheckIn() async {
        guard selectedId > 0 else {
            banner = "Select a person."
            bannerIsError = true
            return
        }
        let d = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !d.isEmpty else {
            banner = "Enter a date."
            bannerIsError = true
            return
        }
        submitting = true
        defer { submitting = false }
        banner = nil
        if let err = await CheckinAPI.checkInUser(userId: selectedId, dateStr: d) {
            banner = err
            bannerIsError = true
        } else {
            banner = "Checked in for \(d)."
            bannerIsError = false
        }
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: Date())
    }
}

// MARK: - Manifest status card (25 Jump Check, Aviation on home)
struct ManifestStatusCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    var badges: [DashBadge] = []
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1.5)
            }
            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colors.text)
            if !badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(badges) { b in
                        let c = badgeColor(b)
                        Text(b.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(c)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(c.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
        .overlay(
            Rectangle()
                .fill(accentColor)
                .frame(height: 3)
                .cornerRadius(2),
            alignment: .top
        )
    }

    private func badgeColor(_ b: DashBadge) -> Color {
        guard let k = b.semanticKey else { return b.color }
        switch k {
        case "green": return colors.green
        case "danger": return colors.danger
        case "amber": return colors.amber
        case "muted": return colors.muted
        case "primary": return colors.primary
        default: return b.color
        }
    }
}

// MARK: - Pilot Quick Widget
struct PilotQuickWidget: View {
    let data:      PilotDashData?
    let onTapMore: () -> Void
    @State private var pulse = false
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 11, weight: .black)).foregroundColor(colors.primary)
                    Text("TODAY'S FLIGHTS")
                        .font(.system(size: 11, weight: .black)).foregroundColor(colors.primary).tracking(1.5)
                }
                Spacer()
                Button(action: onTapMore) {
                    HStack(spacing: 4) {
                        Text("Aviation").font(.system(size: 11, weight: .semibold)).foregroundColor(colors.primary)
                        Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(colors.primary)
                    }
                }
            }

            if let d = data, d.hasOpenFlight, let tail = d.openTailNumber {
                Button(action: onTapMore) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(colors.green)
                            .frame(width: 10, height: 10)
                            .scaleEffect(pulse ? 1.35 : 1.0)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                        Text("FLIGHT ACTIVE — \(tail)")
                            .font(.system(size: isWide ? 15 : 13, weight: .black))
                            .foregroundColor(colors.green)
                        Spacer()
                        Text("TAP TO MANAGE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(colors.green)
                            .tracking(1)
                    }
                    .padding(12)
                    .background(colors.green.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.green.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .onAppear { pulse = true }
            }

            if let d = data, d.flightCount > 0 {
                HStack(spacing: 0) {
                    PilotStatCell(label: "FLIGHTS", value: "\(d.flightCount)").frame(maxWidth: .infinity)
                    Divider().background(colors.border)
                    PilotStatCell(label: "LOADS",   value: "\(d.totalLoads)").frame(maxWidth: .infinity)
                    Divider().background(colors.border)
                    PilotStatCell(label: "PAX",     value: "\(d.totalPax)").frame(maxWidth: .infinity)
                    Divider().background(colors.border)
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
                    .background(colors.accent)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(isWide ? 20 : 14)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
    }
}

// MARK: - Student Progress Widget
struct StudentProgressWidget: View {
    let data:       StudentDashData?
    let onContinue: () -> Void
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 11, weight: .black)).foregroundColor(colors.amber)
                Text("MY PROGRESS")
                    .font(.system(size: 11, weight: .black)).foregroundColor(colors.amber).tracking(1.5)
            }
            if let d = data {
                HStack {
                    Text(d.courseTitle)
                        .font(.system(size: isWide ? 16 : 14, weight: .bold))
                        .foregroundColor(colors.text)
                    Spacer()
                    Text("Level \(d.currentLevel)")
                        .font(.system(size: isWide ? 14 : 12, weight: .semibold)).foregroundColor(colors.primary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(colors.primary.opacity(0.12)).clipShape(Capsule())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(colors.border).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(colors.amber)
                            .frame(width: geo.size.width * CGFloat(d.progressPct / 100), height: 8)
                            .animation(.easeOut(duration: 0.8), value: d.progressPct)
                    }
                }.frame(height: 8)
                HStack {
                    Text("\(d.completedLessons) / \(d.totalLessons) lessons")
                        .font(.system(size: isWide ? 13 : 11)).foregroundColor(colors.muted)
                    Spacer()
                    Text("\(Int(d.progressPct))%")
                        .font(.system(size: isWide ? 13 : 11, weight: .bold)).foregroundColor(colors.amber)
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
                    .background(colors.amber).cornerRadius(10)
                }
                .buttonStyle(.plain)
            } else {
                Text("Loading progress…").font(.system(size: 13)).foregroundColor(colors.muted)
            }
        }
        .padding(isWide ? 20 : 14)
        .background(colors.card).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
    }
}

// MARK: - Instructor Quick Widget
struct InstructorQuickWidget: View {
    let data: InstructorDashData?
    var onTapGroundSchool: (() -> Void)? = nil
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        Button(action: { onTapGroundSchool?() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .black)).foregroundColor(colors.green)
                    Text("INSTRUCTOR OVERVIEW")
                        .font(.system(size: 11, weight: .black)).foregroundColor(colors.green).tracking(1.5)
                    if (data?.pendingSignoffs ?? 0) > 0 {
                        Spacer()
                        Text("Tap to view")
                            .font(.system(size: 10, weight: .semibold)).foregroundColor(colors.amber)
                    }
                }
                if let d = data {
                    HStack(spacing: 0) {
                        PilotStatCell(label: "STUDENTS",  value: "\(d.activeStudents)").frame(maxWidth: .infinity)
                        Divider().background(colors.border)
                        PilotStatCell(label: "SIGN-OFFS", value: "\(d.pendingSignoffs)").frame(maxWidth: .infinity)
                    }
                    .frame(height: isWide ? 72 : 56)
                } else {
                    Text("Loading…").font(.system(size: 13)).foregroundColor(colors.muted)
                }
            }
            .padding(isWide ? 20 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(onTapGroundSchool == nil)
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
    @Environment(\.mdzColors) private var colors

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
                    .foregroundColor(colors.text)
                    .tracking(0.5).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: wide ? 13 : 11, weight: .medium))
                    .foregroundColor(colors.muted).lineLimit(2)
                if !badges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(badges) { b in
                            let c = badgeColor(b)
                            Text(b.label)
                                .font(.system(size: wide ? 11 : 10, weight: .bold))
                                .foregroundColor(c)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(c.opacity(0.15)).clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(wide ? 20 : 14)
            .frame(maxWidth: .infinity, minHeight: wide ? 160 : 130, alignment: .topLeading)
            .background(colors.card).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
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

    private func badgeColor(_ b: DashBadge) -> Color {
        guard let k = b.semanticKey else { return b.color }
        switch k {
        case "green": return colors.green
        case "danger": return colors.danger
        case "amber": return colors.amber
        case "muted": return colors.muted
        case "primary": return colors.primary
        default: return b.color
        }
    }
}

// MARK: - Shared sub-views
// PilotStatCell lives in Foundation.swift so Aviation and Home can both use it

struct AlertRow: View {
    let alert: DashAlert
    @Environment(\.mdzColors) private var colors
    var body: some View {
        let c = alertColor(alert)
        HStack(spacing: 12) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(alert.message)
                .font(.system(size: 13, weight: .medium)).foregroundColor(colors.text)
            Spacer()
            Text(alert.category)
                .font(.system(size: 10, weight: .semibold)).foregroundColor(c)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(c.opacity(0.15)).clipShape(Capsule())
        }
        .padding(12).background(colors.card).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
    }
    private func alertColor(_ a: DashAlert) -> Color {
        guard let k = a.semanticKey else { return a.color }
        switch k {
        case "green": return colors.green
        case "danger": return colors.danger
        case "amber": return colors.amber
        case "muted": return colors.muted
        case "primary": return colors.primary
        default: return a.color
        }
    }
}

// MARK: - Rig expiry (reserve DOM / AAD DOM)

struct RigExpiryCard: View {
    let rigs: [JumperRig]
    let onTapLogbook: () -> Void
    @Environment(\.mdzColors) private var colors

    var body: some View {
        Button(action: onTapLogbook) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "backpack.fill")
                        .font(.system(size: 18))
                        .foregroundColor(colors.green)
                    Text("MY RIGS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(colors.muted)
                        .tracking(2)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                }
                ForEach(rigs) { rig in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rig.rigLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colors.text)
                        HStack(spacing: 16) {
                            if let dom = rig.reserveDomDisplay, !dom.isEmpty {
                                labelVal("Reserve DOM", dom)
                            }
                            if let dom = rig.aadDomDisplay, !dom.isEmpty {
                                labelVal("AAD DOM", dom)
                            }
                            if (rig.reserveDomDisplay ?? "").isEmpty && (rig.aadDomDisplay ?? "").isEmpty {
                                Text("Add dates in Logbook")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.muted)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.card2)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
                }
            }
            .padding(16)
            .background(colors.card)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
            .overlay(
                Rectangle()
                    .fill(colors.green)
                    .frame(height: 3)
                    .cornerRadius(2),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }

    private func labelVal(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.text)
        }
    }
}

// MARK: - Logbook config (Start Freefall Time, Home Dropzone)

struct LogbookConfigCard: View {
    @ObservedObject var vm: HomeViewModel
    @State private var showFreefallEditor = false
    @State private var freefallEditorValue = ""
    @State private var showHomeDzEditor = false
    @State private var homeDzEditorValue = ""
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundColor(colors.amber)
                Text("LOGBOOK CONFIG")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(2)
            }
            configRow("Default freefall per jump", vm.startFreefallTime.isEmpty ? "Not set" : vm.startFreefallTime) {
                freefallEditorValue = vm.startFreefallTime
                showFreefallEditor = true
            }
            configRow("Home Dropzone", vm.homeDropzone.isEmpty ? "Not set" : vm.homeDropzone) {
                homeDzEditorValue = vm.homeDropzone
                showHomeDzEditor = true
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
        .sheet(isPresented: $showFreefallEditor) {
            ConfigEditorSheet(
                title: "Default freefall per jump",
                hint: "Prefills freefall when you add a jump. Type digits; a colon appears after the minutes (e.g. 130 → 1:30).",
                value: $freefallEditorValue,
                formatFreefallDigits: true,
                onSave: {
                    Task { await vm.setStartFreefallTime(freefallEditorValue); showFreefallEditor = false }
                },
                onCancel: { showFreefallEditor = false }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showHomeDzEditor) {
            ConfigEditorSheet(title: "Home Dropzone", hint: "Your home DZ, prefills when adding a jump", value: $homeDzEditorValue, onSave: {
                Task { await vm.setHomeDropzone(homeDzEditorValue); showHomeDzEditor = false }
            }, onCancel: { showHomeDzEditor = false })
            .presentationDetents([.medium])
        }
    }

    private func configRow(_ label: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(colors.muted)
                        .tracking(0.5)
                    Text(value)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.text)
                }
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(colors.muted)
            }
            .padding(12)
            .background(colors.card2)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(vm.logbookSettingsSaving)
    }
}

// MARK: - DZ Status pill (top-right on dashboard: DZ Open green / DZ Closed red)
struct DZStatusPill: View {
    let status: DZStatus?
    @Environment(\.mdzColors) private var colors

    private var isOpen: Bool {
        guard let s = status?.status else { return false }
        return s.lowercased() == "open"
    }

    private var pillLabel: String {
        guard let s = status?.status else { return "—" }
        switch s.lowercased() {
        case "open": return "DZ OPEN"
        case "closed": return "DZ CLOSED"
        case "announcement": return "DZ CLOSED"
        default: return "DZ CLOSED"
        }
    }

    private var pillColor: Color {
        status == nil ? colors.muted : (isOpen ? colors.green : colors.danger)
    }

    var body: some View {
        Text(pillLabel)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(status == nil ? colors.text : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(pillColor)
            .cornerRadius(8)
    }
}

// MARK: - DZ Status card (open/closed/announcement)
struct DZStatusCard: View {
    let status: DZStatus
    var tappable: Bool = false
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors
    private var isWide: Bool { hSizeClass == .regular }

    private var statusColor: Color {
        switch status.status.lowercased() {
        case "open": return colors.green
        case "closed": return colors.danger
        case "announcement": return colors.amber
        default: return colors.muted
        }
    }

    private var statusLabel: String {
        switch status.status.lowercased() {
        case "open": return "DZ OPEN"
        case "closed": return "DZ CLOSED"
        case "announcement": return "ANNOUNCEMENT"
        default: return status.status.uppercased()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusLabel)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(statusColor)
                    .tracking(1.5)
                if tappable {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colors.muted)
                }
            }
            if let ann = status.announcement, !ann.isEmpty {
                Text(ann)
                    .font(.system(size: isWide ? 15 : 14))
                    .foregroundColor(colors.text)
            }
        }
        .padding(isWide ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
        .overlay(
            Rectangle()
                .fill(statusColor)
                .frame(height: 3)
                .cornerRadius(2),
            alignment: .top
        )
    }
}

// MARK: - DZ Status updated banner (shown briefly after save)
struct DZStatusUpdatedBanner: View {
    let onDismiss: () -> Void
    @State private var appeared = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(colors.green)
                Text("DZ status updated")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(colors.green.opacity(0.15))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.green.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onDismiss()
            }
        }
    }
}

private struct ConfigEditorSheet: View {
    let title: String
    let hint: String
    @Binding var value: String
    var formatFreefallDigits: Bool = false
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(hint)
                        .font(.system(size: 14))
                        .foregroundColor(colors.text)
                    Text("VALUE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(colors.amber)
                        .tracking(1)
                    TextField("", text: $value)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(colors.text)
                        .keyboardType(formatFreefallDigits ? .numberPad : .default)
                        .onChange(of: value) { _, newValue in
                            guard formatFreefallDigits else { return }
                            let formatted = FreefallDurationFormatting.formatWhileTyping(newValue)
                            if formatted != newValue {
                                value = formatted
                            }
                        }
                        .padding(14)
                        .background(colors.card)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                        .foregroundColor(colors.amber)
                }
            }
        }
    }
}
