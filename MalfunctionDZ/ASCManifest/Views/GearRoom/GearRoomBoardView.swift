import SwiftUI

struct GearRoomBoardView: View {
    @EnvironmentObject private var gearStore: GearRoomStore
    @State private var selectedRig: GearRig?

    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 480), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let error = gearStore.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(NightOps.danger)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NightOps.surface.ignoresSafeArea())
        .navigationTitle("Gear Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await gearStore.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(gearStore.isLoading)
            }
        }
        .task {
            if gearStore.rigs.isEmpty {
                await gearStore.refresh()
            }
        }
        .refreshable {
            await gearStore.refresh()
        }
        .sheet(item: $selectedRig) { rig in
            GearRigDetailSheet(rig: rig)
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DZ gear status — read-only")
                .font(.subheadline)
                .foregroundStyle(NightOps.textMuted)
            if let summary = gearStore.summary {
                HStack(spacing: 8) {
                    summaryPill("\(summary.total) rigs")
                    if summary.overdue > 0 {
                        summaryPill("\(summary.overdue) overdue", accent: NightOps.danger)
                    }
                    if summary.dueSoon > 0 {
                        summaryPill("\(summary.dueSoon) reserve due", accent: .orange)
                    }
                    summaryPill("\(summary.current) current", accent: NightOps.success)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(NightOps.navy)
        .overlay(alignment: .top) {
            NightOps.gradientBar.frame(height: 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        if gearStore.isLoading && gearStore.rigs.isEmpty {
            Spacer()
            ProgressView("Loading gear…")
                .tint(NightOps.accent)
            Spacer()
        } else if gearStore.sortedRigs.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "bag")
                    .font(.largeTitle)
                    .foregroundStyle(NightOps.textMuted)
                Text("No DZ rigs")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Add rigs in Gear Room on the web.")
                    .font(.footnote)
                    .foregroundStyle(NightOps.textMuted)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(gearStore.sortedRigs) { rig in
                        Button {
                            selectedRig = rig
                        } label: {
                            GearRigCard(rig: rig)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
    }

    private func summaryPill(_ text: String, accent: Color = .white) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent.opacity(0.18))
            .foregroundStyle(accent)
            .clipShape(Capsule())
    }
}

struct GearRigCard: View {
    let rig: GearRig

    private var uses: Int { rig.usesSinceInspection }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(rig.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                GearStatusPill(category: rig.gearCategory)
            }

            HStack(spacing: 12) {
                dueDateBlock
                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                componentBlock(title: "Container", mfr: rig.harness.mfr, model: rig.harness.model, sn: rig.harness.sn)
                componentBlock(title: "Reserve", mfr: rig.reserve.mfr, model: rig.reserve.model, sn: rig.reserve.sn)
                componentBlock(title: "AAD", mfr: rig.aad.mfr, model: rig.aad.model, sn: rig.aad.sn)
            }

            jumpCheckSection
        }
        .padding(16)
        .nightOpsCard()
        .overlay(alignment: .top) {
            NightOps.gradientBar.frame(height: 3)
        }
    }

    private var dueDateBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Due date")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NightOps.textMuted)
            Text(rig.dueDateDisplay)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(dueDateColor)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dueDateColor: Color {
        if rig.status == "overdue" || (rig.daysLeft ?? 0) < 0 { return NightOps.danger }
        if rig.status == "due_soon" || (rig.daysLeft ?? 999) <= 30 { return .orange }
        return .white
    }

    private func componentBlock(title: String, mfr: String?, model: String?, sn: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(NightOps.accent)
            labeledRow("Mfr", mfr)
            if title != "AAD" {
                labeledRow(title == "Reserve" ? "Size" : "Model", model)
            } else {
                labeledRow("Model", model)
            }
            labeledRow("SN", sn)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func labeledRow(_ label: String, _ value: String?) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption2)
                .foregroundStyle(NightOps.textMuted)
            Text(value?.isEmpty == false ? value! : "—")
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var jumpCheckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("25-Jump Check")
                .font(.caption.weight(.bold))
                .foregroundStyle(NightOps.textMuted)
            HStack {
                Text("\(uses)/25")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(jumpCountColor)
                Spacer()
                if uses < 25 {
                    Text("\(25 - uses) left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(uses >= 20 ? .orange : NightOps.textMuted)
                }
            }
            if uses < 25 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(uses >= 20 ? Color.orange : NightOps.accent)
                            .frame(width: geo.size.width * CGFloat(uses) / 25.0)
                    }
                }
                .frame(height: 6)
            } else {
                Text("Limit reached — inspection required.")
                    .font(.caption)
                    .foregroundStyle(NightOps.danger)
            }
            if let last = rig.lastInspectionAt ?? rig.lastPack, !last.isEmpty {
                Text("Last check: \(displayDate(last))\(rig.packedBy.map { " — \($0)" } ?? "")")
                    .font(.caption2)
                    .foregroundStyle(NightOps.textMuted)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var jumpCountColor: Color {
        if rig.outOfService == true || uses >= 25 { return NightOps.danger }
        if uses >= 20 { return .orange }
        return NightOps.success
    }

    private func displayDate(_ raw: String) -> String {
        raw.count >= 10 ? String(raw.prefix(10)) : raw
    }
}

struct GearStatusPill: View {
    let category: GearDisplayCategory

    var color: Color {
        switch category {
        case .inspection: NightOps.danger
        case .twentyFiveDue: .orange
        case .reserveDue: .blue
        case .airworthy: NightOps.success
        case .unknown: NightOps.textMuted
        }
    }

    var body: some View {
        Text(category.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.22))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct GearRigDetailSheet: View {
    let rig: GearRig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                GearRigCard(rig: rig)
                    .padding()
            }
            .background(NightOps.surface.ignoresSafeArea())
            .navigationTitle(rig.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}
