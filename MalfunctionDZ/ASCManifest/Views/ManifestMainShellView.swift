import SwiftUI

enum ManifestLeftPane: Equatable {
    case menu
    case checkIn
    case jumpers
    case accounts
    case placeholder(title: String)
}

struct ManifestMainShellView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var manifestStore = ManifestStore()
    @State private var leftPane: ManifestLeftPane = .menu
    @State private var selectedAccount: AccountTarget?

    var body: some View {
        HStack(spacing: 0) {
            leftColumn
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(NightOps.navy)

            NavigationStack {
                LoadsBoardView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NightOps.surface)
        }
        .background(NightOps.surface.ignoresSafeArea())
        .environmentObject(manifestStore)
        .sheet(item: $selectedAccount) { target in
            AccountDetailView(target: target)
                .environmentObject(session)
                .environmentObject(manifestStore)
        }
        .task {
            manifestStore.bind(session: session)
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
    private var leftColumn: some View {
        switch leftPane {
        case .menu:
            opsMenu
        case .checkIn:
            CheckInView(onBack: { leftPane = .menu })
        case .jumpers:
            paneStack(title: "Jumpers") {
                JumperSearchView()
            }
        case .accounts:
            paneStack(title: "Accounts") {
                JumperSearchView()
            }
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
                menuRow("Load Manager", icon: "airplane.departure") { leftPane = .menu }
                menuRow("Check-In", icon: "person.crop.circle.badge.checkmark") { leftPane = .checkIn }
                menuRow("Jumpers", icon: "person") { leftPane = .jumpers }
                menuRow("Accounts", icon: "creditcard") { leftPane = .accounts }
                menuRow("Reservations", icon: "calendar") { leftPane = .placeholder(title: "Reservations") }
                menuRow("Store", icon: "cart") { leftPane = .placeholder(title: "Store") }
                menuRow("Reports", icon: "chart.bar") { leftPane = .placeholder(title: "Reports") }
                menuRow("LMS", icon: "book") { leftPane = .placeholder(title: "LMS") }
                menuRow("Logbook", icon: "book.closed") { leftPane = .placeholder(title: "Logbook") }
                menuRow("Gear Room", icon: "bag") { leftPane = .placeholder(title: "Gear Room") }
                menuRow("Help", icon: "questionmark.circle") { leftPane = .placeholder(title: "Help") }
            }

            Section("DZ") {
                menuRow("Staff", icon: "person.3") { leftPane = .placeholder(title: "Staff") }
                menuRow("Pilots", icon: "airplane") { leftPane = .placeholder(title: "Pilots") }
                menuRow("Aircraft", icon: "airplane.circle") { leftPane = .placeholder(title: "Aircraft") }
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

    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .foregroundStyle(.white)
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
