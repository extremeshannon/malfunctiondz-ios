import SwiftUI

enum ManifestLeftPane: Equatable {
    case menu
    case checkIn
    case jumpers
    case accounts
    case reports
    case placeholder(title: String)
}

enum ManifestRightPane: Equatable {
    case loadManager
    case pilots
    case aircraft
    case gearRoom
    case reports
}

struct ManifestMainShellView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var manifestStore = ManifestStore()
    @StateObject private var reportsStore = ReportsStore()
    @StateObject private var gearRoomStore = GearRoomStore()
    @State private var leftPane: ManifestLeftPane = .checkIn
    @State private var rightPane: ManifestRightPane = .loadManager
    @State private var selectedAccount: AccountTarget?

    var body: some View {
        HStack(spacing: 0) {
            leftColumn
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(NightOps.navy)

            NavigationStack {
                rightContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NightOps.surface)
        }
        .background(NightOps.surface.ignoresSafeArea())
        .environmentObject(manifestStore)
        .environmentObject(reportsStore)
        .environmentObject(gearRoomStore)
        .sheet(item: $selectedAccount) { target in
            AccountDetailView(target: target)
                .environmentObject(session)
                .environmentObject(manifestStore)
        }
        .task {
            manifestStore.bind(session: session)
            reportsStore.bind(session: session)
            gearRoomStore.bind(session: session)
            await session.refreshProfile()
            await manifestStore.loadAircraft()
            await manifestStore.refresh()
            manifestStore.startLivePolling()
        }
        .onChange(of: session.environment) { _, _ in
            manifestStore.resetBoard()
            manifestStore.stopLivePolling()
            Task {
                await manifestStore.loadAircraft()
                await manifestStore.refresh()
                if session.isAuthenticated {
                    manifestStore.startLivePolling()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await manifestStore.refresh(silent: true) }
            }
        }
        .onDisappear {
            manifestStore.stopLivePolling()
        }
    }

    @ViewBuilder
    private var rightContent: some View {
        switch rightPane {
        case .loadManager:
            LoadsBoardView()
        case .pilots:
            PilotsBoardView()
        case .aircraft:
            AircraftBoardView()
        case .gearRoom:
            GearRoomBoardView()
        case .reports:
            ReportWebView()
        }
    }

    @ViewBuilder
    private var leftColumn: some View {
        switch leftPane {
        case .menu:
            opsMenu
        case .checkIn:
            CheckInView(onOpenMenu: { leftPane = .menu })
        case .jumpers:
            paneStack(title: "Jumpers") {
                JumperSearchView()
            }
        case .accounts:
            paneStack(title: "Accounts") {
                JumperSearchView()
            }
        case .reports:
            ReportsListView(onOpenMenu: { leftPane = .menu })
        case .placeholder(let title):
            paneStack(title: title) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(title) stays on this left pane. The three load cards stay on the right.")
                        .foregroundStyle(.white)
                    Text("Full \(title) is still on the web Load Manager.")
                        .font(.footnote)
                        .foregroundStyle(NightOps.textMuted)
                    Spacer()
                }
                .padding()
            }
        }
    }

    private var opsMenu: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ASC Manifest")
                        .font(.headline)
                    Text(session.currentUser?.displayName ?? "Staff")
                        .font(.caption)
                        .foregroundStyle(NightOps.textMuted)
                    Text(session.environment.displayName)
                        .font(.caption2)
                        .foregroundStyle(NightOps.accent)
                    Text(session.environment.baseURL.host ?? session.environment.baseURL.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(NightOps.textMuted)
                }
                .padding(.vertical, 4)
                SidebarSearchBoxes { person in
                    selectedAccount = person.accountTarget
                }
            }

            Section("Ops") {
                menuRow("Load Manager", icon: "airplane.departure", active: rightPane == .loadManager) {
                    leftPane = .menu
                    rightPane = .loadManager
                }
                menuRow("Check-In", icon: "person.crop.circle.badge.checkmark") { leftPane = .checkIn }
                menuRow("Jumpers", icon: "person") { leftPane = .jumpers }
                menuRow("Accounts", icon: "creditcard") { leftPane = .accounts }
                menuRow("Reservations", icon: "calendar") { leftPane = .placeholder(title: "Reservations") }
                menuRow("Store", icon: "cart") { leftPane = .placeholder(title: "Store") }
                menuRow("Reports", icon: "chart.bar", active: rightPane == .reports) {
                    leftPane = .reports
                    rightPane = .reports
                    Task { await reportsStore.refresh() }
                }
                menuRow("LMS", icon: "book") { leftPane = .placeholder(title: "LMS") }
                menuRow("Logbook", icon: "book.closed") { leftPane = .placeholder(title: "Logbook") }
                menuRow("Gear Room", icon: "bag", active: rightPane == .gearRoom) {
                    leftPane = .menu
                    rightPane = .gearRoom
                    Task { await gearRoomStore.refresh() }
                }
                menuRow("Help", icon: "questionmark.circle") { leftPane = .placeholder(title: "Help") }
            }

            Section("DZ") {
                menuRow("Staff", icon: "person.3") { leftPane = .placeholder(title: "Staff") }
                menuRow("Pilots", icon: "airplane", active: rightPane == .pilots) {
                    rightPane = .pilots
                    leftPane = .menu
                    Task { await manifestStore.loadPilots() }
                }
                menuRow("Aircraft", icon: "airplane.circle", active: rightPane == .aircraft) {
                    leftPane = .menu
                    rightPane = .aircraft
                    Task { await manifestStore.loadAircraft() }
                }
            }

            Section {
                Button(role: .destructive) {
                    session.signOut()
                } label: {
                    Label(session.isEmbedded ? "Exit Manifest" : "Sign Out",
                          systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(NightOps.navy)
    }

    private func menuRow(_ title: String, icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(active ? .body.weight(.semibold) : .body)
        }
        .foregroundStyle(active ? NightOps.accent : .white)
    }

    private func paneStack<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            ManifestLeftPaneHeader(title: title) { leftPane = .menu }
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(NightOps.navy)
    }
}

struct ManifestLeftPaneHeader: View {
    let title: String
    var onBack: () -> Void
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onBack) {
                Label("Back to Menu", systemImage: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(NightOps.accent)

            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if let onRefresh {
                    Button("Refresh", action: onRefresh)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(NightOps.navyLight)
        }
    }
}
