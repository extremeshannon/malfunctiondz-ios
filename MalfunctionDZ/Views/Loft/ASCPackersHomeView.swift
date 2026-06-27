// ASC Packers — Queue · Active (mockup-aligned home for packer shell).
import SwiftUI
import MalfunctionDZCore

struct ASCPackersHomeView: View {
    @EnvironmentObject private var tabSelect: TabSelection
    @StateObject private var vm = DzRigsViewModel()

    var body: some View {
        ZStack {
            ASCScreenBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: ASC.Space.xxl) {
                    ascLargeTitle
                    statRow
                    prioritySection
                    reservesDueSection
                }
                .padding(.horizontal, ASC.Space.lg)
                .padding(.top, ASC.Space.md)
                .padding(.bottom, ASC.Space.xxxl)
            }
            .refreshable { await vm.load() }

            if vm.isLoading && vm.rigs.isEmpty {
                ProgressView().tint(ASC.Palette.hiVis)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Int.self) { rigId in
            DzRigDetailView(rigId: rigId, vm: vm)
        }
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "Unknown error")
        }
    }

    // MARK: - Title

    private var ascLargeTitle: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("QUEUE")
                .font(ASC.Typography.display(34))
                .foregroundStyle(ASC.Text.primary)
            Text(queueSubtitle)
                .font(ASC.Typography.bodyMedium(14))
                .foregroundStyle(ASC.Text.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var queueSubtitle: String {
        let total = vm.summary?.total ?? vm.rigs.count
        let reservesDue = (vm.summary?.overdue ?? vm.overdueRigs.count)
            + (vm.summary?.dueSoon ?? vm.dueSoonRigs.count)
        if total == 0 { return "No DZ rigs in queue" }
        if reservesDue > 0 {
            return "\(total) rigs · \(reservesDue) reserve\(reservesDue == 1 ? "" : "s") due this week"
        }
        return "\(total) rigs in gear room"
    }

    // MARK: - Stats

    private var statRow: some View {
        HStack(spacing: ASC.Space.sm) {
            statTile(
                label: "Today",
                value: "\(vm.summary?.total ?? vm.rigs.count)",
                meta: todayMeta,
                accent: ASC.role.accent
            )
            statTile(
                label: "Priority",
                value: "\(priorityRigs.count)",
                meta: "Same-day pack",
                accent: ASC.Palette.caution
            )
            statTile(
                label: "Done",
                value: "\(vm.summary?.current ?? vm.currentRigs.count)",
                meta: "In service",
                accent: ASC.Palette.jumpReady
            )
        }
    }

    private var todayMeta: String {
        let mains = vm.rigs.filter { $0.outOfService != true }.count
        let reserves = vm.overdueRigs.count + vm.dueSoonRigs.count
        return "\(mains) mains · \(reserves) reserves"
    }

    private func statTile(label: String, value: String, meta: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(ASC.Typography.eyebrow(10))
                .tracking(1.6)
                .foregroundStyle(ASC.Text.muted)
            Text(value)
                .font(ASC.Typography.numeric(26))
                .foregroundStyle(ASC.Text.primary)
            Text(meta)
                .font(ASC.Typography.caption(10))
                .foregroundStyle(ASC.Text.tertiary)
                .lineLimit(2)
        }
        .ascStatTile(accent)
    }

    // MARK: - Priority queue

    private var priorityRigs: [LoftRig] {
        var list = vm.approachingLimitRigs + vm.outOfServiceRigs
        if list.isEmpty {
            list = vm.allClearRigs.filter { ($0.packJobsSinceInspection ?? 0) >= 15 }
        }
        return Array(list.prefix(6))
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: ASC.Space.md) {
            HStack {
                Text("PRIORITY · SAME-DAY")
                    .font(ASC.Typography.sectionLabel(12))
                    .tracking(2)
                    .foregroundStyle(ASC.Text.muted)
                Spacer()
                Button { tabSelect.selected = 0 } label: {
                    Text("Gear Room →")
                        .font(ASC.Typography.eyebrow(11))
                        .foregroundStyle(ASC.Text.link)
                }
            }

            if priorityRigs.isEmpty {
                Text("No priority pack jobs right now.")
                    .font(ASC.Typography.body(14))
                    .foregroundStyle(ASC.Text.muted)
                    .ascCard()
            } else {
                ForEach(Array(priorityRigs.enumerated()), id: \.element.id) { index, rig in
                    NavigationLink(value: rig.id) {
                        packQueueCard(
                            rig: rig,
                            queueNumber: index + 1,
                            priority: true,
                            dueLabel: packDueLabel(for: rig)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Reserves due

    private var reservesDueSection: some View {
        let reserveRigs = Array((vm.overdueRigs + vm.dueSoonRigs).prefix(5))
        return VStack(alignment: .leading, spacing: ASC.Space.md) {
            HStack {
                Text("RESERVES DUE")
                    .font(ASC.Typography.sectionLabel(12))
                    .tracking(2)
                    .foregroundStyle(ASC.Text.muted)
                Spacer()
                Button { tabSelect.selected = 0 } label: {
                    Text("See all →")
                        .font(ASC.Typography.eyebrow(11))
                        .foregroundStyle(ASC.Text.link)
                }
            }

            if reserveRigs.isEmpty {
                Text("No reserve repacks due.")
                    .font(ASC.Typography.body(14))
                    .foregroundStyle(ASC.Text.muted)
                    .ascCard()
            } else {
                ForEach(reserveRigs) { rig in
                    NavigationLink(value: rig.id) {
                        packQueueCard(
                            rig: rig,
                            queueNumber: nil,
                            priority: false,
                            dueLabel: reserveDueLabel(for: rig)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Queue card

    private func packQueueCard(
        rig: LoftRig,
        queueNumber: Int?,
        priority: Bool,
        dueLabel: (text: String, sub: String, color: Color)
    ) -> some View {
        HStack(alignment: .center, spacing: ASC.Space.md) {
            if priority {
                Rectangle()
                    .fill(ASC.Palette.caution)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
            }

            if let n = queueNumber {
                Text(String(format: "%02d", n))
                    .font(ASC.Typography.numeric(18))
                    .foregroundStyle(ASC.Palette.daylight)
                    .frame(width: 32, alignment: .leading)
            } else {
                Text("R")
                    .font(ASC.Typography.numeric(18))
                    .foregroundStyle(dueLabel.color)
                    .frame(width: 32, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(rigDisplayName(rig))
                    .font(ASC.Typography.bodyMedium(13))
                    .foregroundStyle(ASC.Text.primary)
                    .multilineTextAlignment(.leading)
                Text(rigMetaLine(rig))
                    .font(ASC.Typography.caption(11))
                    .foregroundStyle(ASC.Text.muted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(dueLabel.text)
                    .font(ASC.Typography.numeric(16))
                    .foregroundStyle(dueLabel.color)
                Text(dueLabel.sub)
                    .font(ASC.Typography.caption(10))
                    .foregroundStyle(ASC.Text.muted)
            }
        }
        .padding(ASC.Space.lg)
        .background(ASC.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
        )
    }

    private func rigDisplayName(_ rig: LoftRig) -> String {
        let harness = [rig.harness.mfr, rig.harness.model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        let main = [rig.reserve.mfr, rig.reserve.model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        if !harness.isEmpty && !main.isEmpty { return "\(harness) · \(main)" }
        if !harness.isEmpty { return harness }
        return rig.label
    }

    private func rigMetaLine(_ rig: LoftRig) -> String {
        var parts: [String] = []
        if !rig.label.isEmpty { parts.append(rig.label) }
        let jobs = rig.packJobsSinceInspection ?? 0
        if jobs > 0 { parts.append("\(jobs)/25 packs") }
        if rig.outOfService == true { parts.append("Out of service") }
        return parts.joined(separator: " · ")
    }

    private func packDueLabel(for rig: LoftRig) -> (text: String, sub: String, color: Color) {
        if rig.outOfService == true {
            return ("25", "packs", ASC.Palette.caution)
        }
        let jobs = rig.packJobsSinceInspection ?? 0
        return ("\(jobs)", "packs", ASC.Palette.daylight)
    }

    private func reserveDueLabel(for rig: LoftRig) -> (text: String, sub: String, color: Color) {
        if rig.status == "overdue" || (rig.daysLeft ?? 0) < 0 {
            let days = abs(rig.daysLeft ?? 0)
            return ("\(days)d", "overdue", ASC.Palette.cutaway)
        }
        if let d = rig.daysLeft {
            return ("\(d)d", "left", ASC.Palette.caution)
        }
        return ("—", "due", ASC.Text.muted)
    }
}
