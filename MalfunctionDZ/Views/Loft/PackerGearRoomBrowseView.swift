// ASC Packers — swipeable Gear Room: browse rigs left/right, view records, submit pack jobs.
import SwiftUI
import MalfunctionDZCore

struct PackerGearRoomBrowseView: View {
    @StateObject private var vm = DzRigsViewModel()
    @EnvironmentObject private var tabSelect: TabSelection
    @State private var searchText = ""
    @State private var filter: PackerRigFilter = .all
    @State private var selectedRigId: Int = 0
    @Environment(\.mdzColors) private var colors

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
                        title: searchText.isEmpty ? "No Rigs" : "No Matches",
                        subtitle: searchText.isEmpty
                            ? "No DZ rigs in the gear room."
                            : "Try a different search or filter."
                    )
                    Spacer()
                } else {
                    pagerHint
                    TabView(selection: $selectedRigId) {
                        ForEach(displayRigs) { rig in
                            PackerRigSwipePage(rig: rig, vm: vm)
                                .tag(rig.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .animation(.easeInOut(duration: 0.2), value: selectedRigId)
                }
            }
        }
        .navigationTitle("Gear Room")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: displayRigs.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                selectedRigId = 0
                return
            }
            if ids.contains(selectedRigId) { return }
            selectedRigId = ids[0]
        }
        .onChange(of: filter) { _, _ in
            selectedRigId = displayRigs.first?.id ?? 0
        }
        .onAppear {
            if selectedRigId == 0, let first = displayRigs.first?.id {
                selectedRigId = first
            }
            applyPendingRigSelection()
        }
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

    // MARK: - Header

    private var gearRoomHeader: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("GEAR ROOM")
                .font(ASC.Typography.display(28))
                .foregroundStyle(ASC.Text.primary)
            if let s = vm.summary {
                Text("\(s.total) rigs · swipe to browse")
                    .font(ASC.Typography.bodyMedium(13))
                    .foregroundStyle(ASC.Text.tertiary)
            } else {
                Text("Swipe left or right between rigs")
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

    private var pagerHint: some View {
        HStack {
            Image(systemName: "hand.draw")
                .font(.system(size: 12))
                .foregroundStyle(ASC.Text.muted)
            Text("Swipe between rigs")
                .font(ASC.Typography.caption(11))
                .foregroundStyle(ASC.Text.muted)
            Spacer()
            if selectedRigId != 0,
               let idx = displayRigs.firstIndex(where: { $0.id == selectedRigId }) {
                Text("\(idx + 1) of \(displayRigs.count)")
                    .font(ASC.Typography.numeric(13))
                    .foregroundStyle(ASC.Palette.daylight)
            }
        }
        .padding(.horizontal, ASC.Space.lg)
        .padding(.bottom, 4)
    }

    private var displayRigs: [LoftRig] {
        let base: [LoftRig]
        switch filter {
        case .all:
            base = vm.rigs.sorted(by: packerRigSort)
        case .priority:
            var seen = Set<Int>()
            base = (vm.outOfServiceRigs + vm.approachingLimitRigs + vm.rigs.filter {
                ($0.packJobsSinceInspection ?? 0) >= 15 && $0.outOfService != true
            }).filter { seen.insert($0.id).inserted }
        case .reserveDue:
            base = vm.overdueRigs + vm.dueSoonRigs
        case .ready:
            base = vm.allClearRigs
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { rigMatchesSearch($0, q) }
    }

    private func applyPendingRigSelection() {
        guard let rigId = tabSelect.pendingGearRoomRigId else { return }
        tabSelect.pendingGearRoomRigId = nil
        if vm.rigs.contains(where: { $0.id == rigId }) {
            filter = .all
            searchText = ""
            selectedRigId = rigId
        }
    }

    private func packerRigSort(_ a: LoftRig, _ b: LoftRig) -> Bool {
        let pa = packerSortRank(a)
        let pb = packerSortRank(b)
        if pa != pb { return pa < pb }
        return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
    }

    private func packerSortRank(_ rig: LoftRig) -> Int {
        if rig.outOfService == true { return 0 }
        if (rig.packJobsSinceInspection ?? 0) >= 20 { return 1 }
        if rig.status == "overdue" { return 2 }
        if rig.status == "due_soon" { return 3 }
        return 4
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
    case all, priority, reserveDue, ready

    var label: String {
        switch self {
        case .all:        return "All"
        case .priority:   return "Priority"
        case .reserveDue: return "Reserves"
        case .ready:      return "Ready"
        }
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
