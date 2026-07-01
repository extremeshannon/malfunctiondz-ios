// ASC Packers — Gear Room: vertical icon grid; tap a rig to swipe left/right in detail.
import SwiftUI
import MalfunctionDZCore

private struct RigNavTarget: Identifiable, Hashable {
    let id: Int
}

struct PackerGearRoomBrowseView: View {
    @StateObject private var vm = DzRigsViewModel()
    @EnvironmentObject private var tabSelect: TabSelection
    @State private var searchText = ""
    @State private var filter: PackerRigFilter = .airworthy
    @State private var openRig: RigNavTarget?

    private let iconGridColumns = [
        GridItem(.flexible(), spacing: ASC.Space.md),
        GridItem(.flexible(), spacing: ASC.Space.md),
    ]

    var body: some View {
        ZStack {
            ASCScreenBackground()
            VStack(spacing: 0) {
                gearRoomHeader
                filterRow
                if vm.isLoading && vm.rigs.isEmpty {
                    Spacer()
                    ProgressView().tint(ASC.Palette.hiVis).scaleEffect(1.3)
                    Spacer()
                } else if displayRigs.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "square.stack.3d.up.fill",
                        title: searchText.isEmpty ? emptyTitle : "No Matches",
                        subtitle: searchText.isEmpty
                            ? emptySubtitle
                            : "Try a different search or filter."
                    )
                    Spacer()
                } else {
                    rigIconGrid
                }
            }
        }
        .navigationTitle("Gear Room")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openRig) { target in
            PackerGearRoomRigPagerView(
                rigs: displayRigs,
                initialRigId: target.id,
                vm: vm
            )
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onAppear { applyPendingRigSelection() }
        .onChange(of: tabSelect.pendingGearRoomRigId) { _, _ in
            applyPendingRigSelection()
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "Unknown error")
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .airworthy:    return "No Airworthy Rigs"
        case .need25Jump:   return "No 25-Jump Rigs"
        case .notInService: return "No Out-of-Service Rigs"
        }
    }

    private var emptySubtitle: String {
        switch filter {
        case .airworthy:
            return "No DZ rigs are pack-ready right now."
        case .need25Jump:
            return "No DZ rigs are at the 25-jump inspection limit."
        case .notInService:
            return "No other DZ rigs are out of service."
        }
    }

    // MARK: - Icon grid (scroll up / down)

    private var rigIconGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: iconGridColumns, spacing: ASC.Space.md) {
                ForEach(displayRigs) { rig in
                    Button {
                        openRig = RigNavTarget(id: rig.id)
                    } label: {
                        PackerGearRoomIconCard(rig: rig)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.bottom, ASC.Space.xxxl)
        }
    }

    // MARK: - Header

    private var gearRoomHeader: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("GEAR ROOM")
                .font(ASC.Typography.display(28))
                .foregroundStyle(ASC.Text.primary)
            if vm.summary != nil {
                Text("\(displayRigs.count) of \(dzRigCount) DZ rigs · tap to open · swipe in detail")
                    .font(ASC.Typography.bodyMedium(13))
                    .foregroundStyle(ASC.Text.tertiary)
            } else {
                Text("DZ rigs only · tap a rig · swipe left or right inside")
                    .font(ASC.Typography.bodyMedium(13))
                    .foregroundStyle(ASC.Text.tertiary)
            }
            HStack(spacing: ASC.Space.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ASC.Text.muted)
                TextField("Search label, SN, mfr…", text: $searchText)
                    .font(ASC.Typography.body(15))
                    .foregroundStyle(ASC.Text.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ASC.Text.muted)
                    }
                }
            }
            .padding(.horizontal, ASC.Space.md)
            .padding(.vertical, 10)
            .background(ASC.Surface.card)
            .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                    .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ASC.Space.lg)
        .padding(.top, ASC.Space.md)
        .padding(.bottom, ASC.Space.sm)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ASC.Space.sm) {
                ForEach(PackerRigFilter.allCases, id: \.self) { f in
                    Button { filter = f } label: {
                        Text(f.label)
                            .font(ASC.Typography.eyebrow(11))
                            .foregroundStyle(filter == f ? ASC.Palette.midnight : ASC.Text.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(filter == f ? ASC.Palette.hiVis : ASC.Surface.card)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    filter == f ? ASC.Palette.hiVis : ASC.Border.hair,
                                    lineWidth: 0.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.vertical, ASC.Space.sm)
        }
    }

    private func applyPendingRigSelection() {
        guard let rigId = tabSelect.pendingGearRoomRigId else { return }
        tabSelect.pendingGearRoomRigId = nil
        guard let rig = vm.rigs.first(where: { $0.id == rigId && $0.isDzRig }) else { return }
        searchText = ""
        filter = PackerGearRoomFilters.filter(for: rig)
        openRig = RigNavTarget(id: rigId)
    }

    private var dzRigs: [LoftRig] {
        vm.rigs.filter { $0.isDzRig }
    }

    private var dzRigCount: Int {
        dzRigs.count
    }

    private var displayRigs: [LoftRig] {
        let base: [LoftRig]
        switch filter {
        case .airworthy:
            base = dzRigs.filter { PackerGearRoomFilters.isAirworthy($0) }
        case .need25Jump:
            base = dzRigs.filter { PackerGearRoomFilters.needs25Jump($0) }
        case .notInService:
            base = dzRigs.filter { PackerGearRoomFilters.isNotInService($0) }
        }
        let sorted = base.sorted(by: PackerGearRoomFilters.sortRigs)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return sorted }
        return sorted.filter { rigMatchesSearch($0, q) }
    }

    private func rigMatchesSearch(_ rig: LoftRig, _ q: String) -> Bool {
        let hay = [
            rig.label,
            rig.manufacturer,
            rig.model,
            rig.harness.mfr, rig.harness.model, rig.harness.sn,
            rig.reserve.mfr, rig.reserve.model, rig.reserve.sn,
            rig.aad.mfr, rig.aad.model, rig.aad.sn,
            rig.packedBy,
            rig.packerCert
        ].compactMap { $0?.lowercased() }.joined(separator: " ")
        return hay.contains(q)
    }
}

// MARK: - Filter

private enum PackerRigFilter: CaseIterable {
    case airworthy, need25Jump, notInService

    var label: String {
        switch self {
        case .airworthy:     return "Airworthy"
        case .need25Jump:    return "25 Jump"
        case .notInService:  return "Out of Service"
        }
    }
}

private enum PackerGearRoomFilters {
    /// ASC Sigma tandem rigs (label or reserve/harness model).
    static func isSigmaTandem(_ rig: LoftRig) -> Bool {
        let label = rig.label.lowercased()
        if label.contains("sigma") || label.contains("tandem") { return true }
        let reserve = (rig.reserve.model ?? rig.reserve.mfr ?? "").lowercased()
        let harness = (rig.harness.model ?? rig.harness.mfr ?? "").lowercased()
        return reserve.contains("sigma") || harness.contains("sigma")
    }

    static func sortRigs(_ a: LoftRig, _ b: LoftRig) -> Bool {
        let sigmaA = isSigmaTandem(a) ? 0 : 1
        let sigmaB = isSigmaTandem(b) ? 0 : 1
        if sigmaA != sigmaB { return sigmaA < sigmaB }
        return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
    }

    /// Pack-ready DZ rig: reserve current/due soon, under 25 pack jobs (includes 20–24 warning range).
    static func isAirworthy(_ rig: LoftRig) -> Bool {
        guard rig.isDzRig, rig.outOfService != true else { return false }
        guard rig.status == "current" || rig.status == "due_soon" else { return false }
        return (rig.packJobsSinceInspection ?? 0) < 25
    }

    /// At the 25-jump limit — locked until inspection.
    static func needs25Jump(_ rig: LoftRig) -> Bool {
        guard rig.isDzRig else { return false }
        if rig.outOfService == true { return true }
        return (rig.packJobsSinceInspection ?? 0) >= 25
    }

    /// Other active DZ rigs not pack-ready and not in the 25-jump queue (overdue, no pack record, etc.).
    static func isNotInService(_ rig: LoftRig) -> Bool {
        guard rig.isDzRig else { return false }
        if isAirworthy(rig) || needs25Jump(rig) { return false }
        return true
    }

    static func filter(for rig: LoftRig) -> PackerRigFilter {
        if needs25Jump(rig) { return .need25Jump }
        if isAirworthy(rig) { return .airworthy }
        return .notInService
    }
}

// MARK: - Icon card (grid cell)

private struct PackerGearRoomIconCard: View {
    let rig: LoftRig

    private var packJobsText: String {
        let n = rig.packJobsSinceInspection ?? 0
        if rig.outOfService == true { return "25/25" }
        return "\(n)/25"
    }

    private var statusColor: Color {
        if rig.outOfService == true { return ASC.Palette.cutaway }
        switch rig.status {
        case "overdue": return ASC.Palette.cutaway
        case "due_soon": return ASC.Palette.caution
        case "current": return ASC.Palette.jumpReady
        default: return ASC.Text.muted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            ZStack(alignment: .topTrailing) {
                rigThumbnail
                    .frame(maxWidth: .infinity)
                    .frame(height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.md, style: .continuous))
                Text(packJobsText)
                    .font(ASC.Typography.eyebrow(9))
                    .foregroundStyle(ASC.Palette.midnight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(ASC.Palette.hiVis)
                    .clipShape(Capsule())
                    .padding(8)
            }
            Text(rig.label)
                .font(ASC.Typography.sectionLabel(14))
                .foregroundStyle(ASC.Text.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            HStack(spacing: ASC.Space.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(rig.daysLeftText)
                    .font(ASC.Typography.caption(11))
                    .foregroundStyle(ASC.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(ASC.Space.md)
        .background(ASC.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                .strokeBorder(statusColor.opacity(0.45), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var rigThumbnail: some View {
        if let path = rig.imageContainer ?? rig.imageMain ?? rig.imageReserve,
           !path.isEmpty,
           let url = rig.imageURL(path: path) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    thumbPlaceholder
                }
            }
        } else {
            thumbPlaceholder
        }
    }

    private var thumbPlaceholder: some View {
        ZStack {
            ASC.Surface.deep
            Image(systemName: "backpack.fill")
                .font(.system(size: 36))
                .foregroundStyle(ASC.Palette.daylight.opacity(0.85))
        }
    }
}

// MARK: - Horizontal rig pager (after tap)

private struct PackerGearRoomRigPagerView: View {
    let rigs: [LoftRig]
    @ObservedObject var vm: DzRigsViewModel
    @State private var selectedRigId: Int

    init(rigs: [LoftRig], initialRigId: Int, vm: DzRigsViewModel) {
        self.rigs = rigs
        self.vm = vm
        _selectedRigId = State(initialValue: initialRigId)
    }

    var body: some View {
        VStack(spacing: 0) {
            pagerHint
            TabView(selection: $selectedRigId) {
                ForEach(rigs) { rig in
                    PackerRigSwipePage(rig: rig, vm: vm)
                        .tag(rig.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .animation(.easeInOut(duration: 0.2), value: selectedRigId)
        }
        .background(ASCScreenBackground())
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: rigs.map(\.id)) { _, ids in
            guard !ids.isEmpty else { return }
            if !ids.contains(selectedRigId) {
                selectedRigId = ids[0]
            }
        }
    }

    private var pagerHint: some View {
        HStack {
            Image(systemName: "hand.draw")
                .font(.system(size: 12))
                .foregroundStyle(ASC.Text.muted)
            Text("Swipe between rigs")
                .font(ASC.Typography.caption(11))
                .foregroundStyle(ASC.Text.muted)
            Spacer()
            if let idx = rigs.firstIndex(where: { $0.id == selectedRigId }) {
                Text("\(idx + 1) of \(rigs.count)")
                    .font(ASC.Typography.numeric(13))
                    .foregroundStyle(ASC.Palette.daylight)
            }
        }
        .padding(.horizontal, ASC.Space.lg)
        .padding(.vertical, ASC.Space.sm)
    }
}

// MARK: - Swipe page (one rig)

private struct PackerRigSwipePage: View {
    let rig: LoftRig
    @ObservedObject var vm: DzRigsViewModel

    @State private var packDate = Date()
    @State private var packJobCount = 1
    @State private var packNotes = ""
    @Environment(\.mdzColors) private var colors

    private var liveRig: LoftRig {
        vm.rigs.first(where: { $0.id == rig.id }) ?? rig
    }

    private var detailLoaded: Bool {
        vm.detailRig?.id == rig.id
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ASC.Space.lg) {
                rigHeroCard
                packProgressCard
                if detailLoaded && !vm.detailRecords.isEmpty {
                    packHistoryCard
                } else if vm.isLoadingDetail && vm.detailRig?.id != rig.id {
                    ProgressView().tint(ASC.Palette.hiVis).frame(maxWidth: .infinity)
                }
                if canSubmitPack {
                    packJobCard
                } else if liveRig.outOfService == true {
                    lockedBanner
                } else if !liveRig.isEligibleFor25JumpCheck {
                    ineligibleBanner
                }
                NavigationLink {
                    DzRigDetailView(rigId: rig.id, vm: vm)
                } label: {
                    HStack {
                        Text("Full rig detail")
                            .font(ASC.Typography.bodyMedium(14))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(ASC.Text.link)
                    .padding(ASC.Space.lg)
                    .ascCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.bottom, ASC.Space.xxxl)
        }
        .task(id: rig.id) {
            packDate = Date()
            packJobCount = 1
            packNotes = ""
            await vm.loadDetail(rigId: rig.id)
        }
    }

    private var canSubmitPack: Bool {
        (vm.detailCanMarkPacked || vm.canMarkPacked)
            && liveRig.outOfService != true
            && liveRig.isEligibleFor25JumpCheck
    }

    // MARK: Cards

    private var rigHeroCard: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(liveRig.label)
                        .font(ASC.Typography.display(22))
                        .foregroundStyle(ASC.Text.primary)
                    Text(rigMetaLine)
                        .font(ASC.Typography.caption(12))
                        .foregroundStyle(ASC.Text.muted)
                }
                Spacer(minLength: 8)
                statusPill
            }
            HStack(spacing: ASC.Space.md) {
                miniStat("Harness", value: liveRig.harness.mfr ?? "—")
                miniStat("Reserve", value: liveRig.reserve.mfr ?? "—")
                miniStat("AAD", value: liveRig.aad.mfr ?? "—")
            }
        }
        .ascCard()
    }

    private var rigMetaLine: String {
        var parts: [String] = []
        if let sn = liveRig.harness.sn, !sn.isEmpty { parts.append("SN \(sn)") }
        parts.append(liveRig.daysLeftText)
        if let by = liveRig.packedBy, !by.isEmpty { parts.append("Last: \(by)") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var statusPill: some View {
        if liveRig.outOfService == true {
            ascPill("LOCKED", color: ASC.Palette.cutaway)
        } else if liveRig.status == "overdue" {
            ascPill("OVERDUE", color: ASC.Palette.cutaway)
        } else if liveRig.status == "due_soon" {
            ascPill("DUE SOON", color: ASC.Palette.caution)
        } else {
            ascPill("IN SERVICE", color: ASC.Palette.jumpReady)
        }
    }

    private func ascPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(ASC.Typography.eyebrow(9))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func miniStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(ASC.Typography.eyebrow(9))
                .foregroundStyle(ASC.Text.muted)
            Text(value)
                .font(ASC.Typography.bodyMedium(12))
                .foregroundStyle(ASC.Text.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var packProgressCard: some View {
        let n = min(liveRig.packJobsSinceInspection ?? 0, 25)
        let atLimit = n >= 25
        return VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("25-JUMP CHECK")
                .font(ASC.Typography.sectionLabel(12))
                .foregroundStyle(ASC.Text.muted)
            HStack(alignment: .firstTextBaseline) {
                Text("\(n)")
                    .font(ASC.Typography.numeric(32))
                    .foregroundStyle(atLimit ? ASC.Palette.cutaway : ASC.Text.primary)
                Text("/ 25 packs")
                    .font(ASC.Typography.body(14))
                    .foregroundStyle(ASC.Text.tertiary)
                Spacer()
                Text("\(max(0, 25 - n)) left")
                    .font(ASC.Typography.caption(12))
                    .foregroundStyle(atLimit ? ASC.Palette.cutaway : ASC.Text.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ASC.Border.hair)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(atLimit ? ASC.Palette.cutaway : ASC.Palette.hiVis)
                        .frame(width: geo.size.width * CGFloat(n) / 25.0, height: 8)
                }
            }
            .frame(height: 8)
        }
        .ascCard()
    }

    private var packHistoryCard: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("PACK RECORDS")
                .font(ASC.Typography.sectionLabel(12))
                .foregroundStyle(ASC.Text.muted)
            let recent = Array(vm.detailRecords.prefix(8))
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, rec in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.packDate)
                            .font(ASC.Typography.bodyMedium(13))
                            .foregroundStyle(ASC.Text.primary)
                        if let by = rec.packedBy {
                            Text(by)
                                .font(ASC.Typography.caption(11))
                                .foregroundStyle(ASC.Text.muted)
                        }
                    }
                    Spacer()
                    Text("×\(rec.packJobCount ?? 1)")
                        .font(ASC.Typography.numeric(14))
                        .foregroundStyle(ASC.Palette.daylight)
                }
                .padding(.vertical, 8)
                if index < recent.count - 1 {
                    Divider().background(ASC.Border.hair)
                }
            }
        }
        .ascCard()
    }

    private var packJobCard: some View {
        VStack(alignment: .leading, spacing: ASC.Space.md) {
            Text("SUBMIT PACK JOB")
                .font(ASC.Typography.sectionLabel(12))
                .foregroundStyle(ASC.Palette.hiVis)
            DatePicker("Pack date", selection: $packDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(ASC.Palette.hiVis)
                .foregroundStyle(ASC.Text.primary)
            HStack {
                Text("Jobs this entry")
                    .font(ASC.Typography.body(14))
                    .foregroundStyle(ASC.Text.secondary)
                Spacer()
                Picker("", selection: $packJobCount) {
                    ForEach(1...25, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .tint(ASC.Palette.hiVis)
            }
            TextField("Notes (optional)", text: $packNotes, axis: .vertical)
                .lineLimit(2...3)
                .font(ASC.Typography.body(14))
                .foregroundStyle(ASC.Text.primary)
                .padding(12)
                .background(ASC.Surface.deep)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button {
                Task {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    await vm.markPacked(
                        rigId: rig.id,
                        packDate: df.string(from: packDate),
                        packJobCount: packJobCount,
                        notes: packNotes
                    )
                    await vm.loadDetail(rigId: rig.id)
                    packNotes = ""
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.markingRigId == rig.id {
                        ProgressView().tint(ASC.Palette.midnight)
                    } else {
                        Text("Submit Pack")
                            .font(ASC.Typography.sectionLabel(14))
                    }
                }
                .foregroundStyle(ASC.Palette.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ASC.Palette.hiVis)
                .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.md, style: .continuous))
            }
            .disabled(vm.markingRigId == rig.id)
            .buttonStyle(.plain)
        }
        .ascCard()
    }

    private var lockedBanner: some View {
        banner(
            title: "Out of service — inspection required",
            subtitle: "Use 25 Jump Check to inspect and clear this rig.",
            color: ASC.Palette.cutaway
        )
    }

    private var ineligibleBanner: some View {
        banner(
            title: "Not eligible for pack jobs",
            subtitle: liveRig.status == "overdue"
                ? "Reserve is overdue — repack required first."
                : "No pack record on file for this rig.",
            color: ASC.Palette.caution
        )
    }

    private func banner(title: String, subtitle: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ASC.Typography.bodyMedium(14))
                    .foregroundStyle(ASC.Text.primary)
                Text(subtitle)
                    .font(ASC.Typography.caption(12))
                    .foregroundStyle(ASC.Text.muted)
            }
        }
        .padding(ASC.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                .strokeBorder(color.opacity(0.45), lineWidth: 1)
        )
    }
}
