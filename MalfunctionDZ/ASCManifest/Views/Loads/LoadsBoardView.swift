import SwiftUI

struct LoadsBoardView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @State private var showAddLoad = false
    @State private var selectedLoad: ManifestLoad?
    @State private var addJumperLoad: ManifestLoad?
    @State private var assignPilotLoad: ManifestLoad?
    @State private var page = 0

    private let cardsPerPage = 3

    private var totalPages: Int {
        let n = store.filteredLoads.count
        if n == 0 { return 1 }
        return (n + cardsPerPage - 1) / cardsPerPage
    }

    private var showArrows: Bool {
        store.filteredLoads.count > cardsPerPage
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            filterBar
            if let error = store.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(NightOps.danger)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            pagedCards
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NightOps.surface.ignoresSafeArea())
        .navigationTitle("Load Manager")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddLoad = true
                } label: {
                    Label("New Load", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .sheet(isPresented: $showAddLoad) {
            AddLoadSheet()
        }
        .sheet(item: $selectedLoad) { load in
            LoadDetailView(load: load)
        }
        .sheet(item: $addJumperLoad) { load in
            AddSlotSheet(loadID: load.id) {
                Task { await store.refreshLoadSlots(load.id) }
            }
        }
        .sheet(item: $assignPilotLoad) { load in
            AssignPilotSheet(loadID: load.id) {
                Task { await store.refresh() }
            }
        }
        .sheet(item: $store.pendingStudentAdd) { pending in
            AssignInstructorSheet(pending: pending) {
                Task { await store.refreshLoadSlots(pending.loadID) }
            }
        }
        .onChange(of: store.filteredLoads.count) { _, count in
            let maxPage = max(0, (count - 1) / cardsPerPage)
            if page > maxPage { page = maxPage }
        }
        .refreshable {
            await store.refresh()
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(NightOps.gradientBar)
                .frame(height: 6)
            HStack {
                DatePicker("", selection: $store.selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .environment(\.timeZone, ManifestAppConfig.opsTimeZone)
                    .environment(\.calendar, ManifestAppConfig.opsCalendar)
                    .onChange(of: store.selectedDate) { _, _ in
                        Task { await store.refresh() }
                    }
                Spacer()
                Text("\(store.filteredLoads.count) loads")
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
                if showArrows {
                    Text("Page \(page + 1) of \(totalPages)")
                        .font(.caption)
                        .foregroundStyle(NightOps.textMuted)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            Text("Three loads stay on this side. Use the arrows when there are more than three.")
                .font(.footnote)
                .foregroundStyle(NightOps.textMuted)
                .padding(.horizontal)
                .padding(.bottom, 4)
            if store.dayListUnavailable {
                Text("Staff day API is not on \(session.environment.baseURL.host ?? session.environment.displayName) yet. Deploy GET /api/manifest/day.php, rebuild Live, re-login, then refresh.")
                    .font(.caption)
                    .foregroundStyle(NightOps.accent)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .background(NightOps.navy)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", active: store.statusFilter == nil) {
                    store.statusFilter = nil
                }
                ForEach(ManifestLoadStatus.allCases.filter { $0 != .cancelled }) { status in
                    FilterChip(title: status.label, active: store.statusFilter == status) {
                        store.statusFilter = status
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(NightOps.navyLight.opacity(0.5))
    }

    private var pagedCards: some View {
        HStack(spacing: 8) {
            pageArrow(system: "chevron.left", enabled: showArrows && page > 0) {
                page = max(0, page - 1)
            }

            if store.isLoading && store.loads.isEmpty {
                ProgressView("Loading loads…")
                    .tint(NightOps.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(0..<cardsPerPage, id: \.self) { slot in
                            slotView(slot: slot, height: geo.size.height)
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }

            pageArrow(system: "chevron.right", enabled: showArrows && page < totalPages - 1) {
                page = min(totalPages - 1, page + 1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func slotView(slot: Int, height: CGFloat) -> some View {
        let index = page * cardsPerPage + slot
        if index < store.filteredLoads.count {
            let load = store.filteredLoads[index]
            LoadCardView(
                load: load,
                loadNumber: index + 1,
                onTapHeader: { selectedLoad = load },
                onAdvance: { Task { await store.advanceStatus(load: load) } },
                onAssignPilot: { assignPilotLoad = load },
                onAddJumper: { addJumperLoad = load }
            )
            .frame(maxWidth: .infinity)
            .frame(height: max(height - 24, 280))
        } else {
            Button {
                showAddLoad = true
            } label: {
                VStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                    Text("New Load")
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(NightOps.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .nightOpsCard()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .frame(height: max(height - 24, 280))
            .opacity(index == store.filteredLoads.count ? 1 : 0.35)
        }
    }

    private func pageArrow(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title.weight(.bold))
                .foregroundStyle(enabled ? .white : Color.white.opacity(0.2))
                .frame(width: 44, height: 88)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(showArrows ? 1 : 0)
        .accessibilityHidden(!showArrows)
    }
}

private struct FilterChip: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Color.white : Color.white.opacity(0.12))
                .foregroundStyle(active ? NightOps.navy : .white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
