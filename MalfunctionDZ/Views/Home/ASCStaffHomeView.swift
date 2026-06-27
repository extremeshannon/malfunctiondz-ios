// ASC Staff — Today · Operations (mockup-aligned layout for ASC Staff target).
import SwiftUI
import MalfunctionDZCore

struct ASCStaffHomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var tabSelect: TabSelection
    @ObservedObject var vm: HomeViewModel
    @Binding var showDzStatusModal: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ASC.Space.xxl) {
                ascLargeTitle
                if let alert = criticalAlert {
                    staffAlertBanner(alert)
                }
                quickActionsSection
                activeLoadsSection
                signoffsSection
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.top, ASC.Space.md)
            .padding(.bottom, ASC.Space.xxxl)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Title

    private var ascLargeTitle: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("TODAY")
                .font(ASC.Typography.display(34))
                .foregroundStyle(ASC.Text.primary)
            Text(opsSubtitle)
                .font(ASC.Typography.bodyMedium(14))
                .foregroundStyle(ASC.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var opsSubtitle: String {
        var parts: [String] = []
        if let dz = vm.dzStatus {
            let open = dz.status.lowercased() == "open"
            parts.append(open ? "DZ Green" : "DZ Closed")
        }
        if let active = vm.staffManifestLoads.first(where: { !$0.slots.isEmpty }) {
            parts.append("Load \(active.id) boarding")
        }
        let jumpers = vm.staffManifestLoads.reduce(0) { $0 + $1.filled }
        if jumpers > 0 {
            parts.append("\(jumpers) jumper\(jumpers == 1 ? "" : "s") manifested")
        }
        if parts.isEmpty { return "Operations overview" }
        return parts.joined(separator: " · ")
    }

    // MARK: - Critical alert

    private var criticalAlert: DashAlert? {
        vm.alerts.first { $0.semanticKey == "danger" }
            ?? vm.alerts.first { $0.category == "Loft" }
    }

    private func staffAlertBanner(_ alert: DashAlert) -> some View {
        HStack(alignment: .top, spacing: ASC.Space.md) {
            Text("!")
                .font(ASC.Typography.display(18))
                .foregroundStyle(ASC.Palette.cutaway)
                .frame(width: 28, height: 28)
                .background(ASC.Palette.cutaway.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.category.uppercased())
                    .font(ASC.Typography.sectionLabel(12))
                    .foregroundStyle(ASC.Text.primary)
                Text(alert.message)
                    .font(ASC.Typography.caption(12))
                    .foregroundStyle(ASC.Text.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ASC.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ASC.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                .strokeBorder(ASC.Palette.cutaway.opacity(0.45), lineWidth: 0.5)
        )
    }

    // MARK: - Quick actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: ASC.Space.md) {
            Text("QUICK ACTIONS")
                .font(ASC.Typography.sectionLabel(12))
                .tracking(2)
                .foregroundStyle(ASC.Text.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ASC.Space.sm) {
                quickActionTile(icon: "plus", label: "New Load") {
                    tabSelect.selected = 5
                }
                quickActionTile(icon: "pause.fill", label: "Hold DZ") {
                    showDzStatusModal = true
                }
                quickActionTile(icon: "checkmark", label: "Sign-Off") {
                    tabSelect.selected = 3
                    tabSelect.openInstructorReviews = true
                }
                quickActionTile(icon: "flag.fill", label: "Incident") {
                    tabSelect.selected = 5
                }
            }
        }
    }

    private func quickActionTile(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: ASC.Space.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ASC.Palette.daylight)
                Text(label.uppercased())
                    .font(ASC.Typography.eyebrow(10))
                    .tracking(1.2)
                    .foregroundStyle(ASC.Text.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ASC.Space.lg)
            .background(ASC.Surface.card)
            .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ASC.Radius.lg, style: .continuous)
                    .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active loads

    private var activeLoadsSection: some View {
        VStack(alignment: .leading, spacing: ASC.Space.md) {
            HStack {
                Text("ACTIVE LOADS")
                    .font(ASC.Typography.sectionLabel(12))
                    .tracking(2)
                    .foregroundStyle(ASC.Text.muted)
                Spacer()
                Button { tabSelect.selected = 5 } label: {
                    Text("Calendar →")
                        .font(ASC.Typography.eyebrow(11))
                        .foregroundStyle(ASC.Text.link)
                }
            }

            if vm.staffManifestLoads.isEmpty {
                Text("No loads scheduled for today.")
                    .font(ASC.Typography.body(14))
                    .foregroundStyle(ASC.Text.muted)
                    .ascCard()
            } else {
                ForEach(Array(vm.staffManifestLoads.prefix(4))) { load in
                    staffLoadCard(load)
                }
            }
        }
    }

    private func staffLoadCard(_ load: StaffManifestLoad) -> some View {
        VStack(alignment: .leading, spacing: ASC.Space.md) {
            HStack(alignment: .center) {
                HStack(spacing: ASC.Space.sm) {
                    Text("LOAD")
                        .font(ASC.Typography.display(18))
                        .foregroundStyle(ASC.Text.primary)
                    Text("\(load.id)")
                        .font(ASC.Typography.display(18))
                        .foregroundStyle(ASC.Palette.hiVis)
                    loadStatusPill(load)
                }
                Spacer()
                if !load.time.isEmpty {
                    Text(load.time)
                        .font(ASC.Typography.numeric(16))
                        .foregroundStyle(ASC.Palette.daylight)
                }
            }

            if load.slots.isEmpty {
                Text("No jumpers assigned")
                    .font(ASC.Typography.caption(11))
                    .foregroundStyle(ASC.Text.muted)
            } else {
                StaffSlotFlowLayout(spacing: 6) {
                    ForEach(load.slots.prefix(3)) { slot in
                        slotChip(slot.chipLabel)
                    }
                    if load.slots.count > 3 {
                        slotChip("+\(load.slots.count - 3) more")
                    }
                }
            }

            if !load.aircraft.isEmpty {
                Text(load.aircraft.uppercased())
                    .font(ASC.Typography.eyebrow(10))
                    .tracking(1.4)
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

    private func loadStatusPill(_ load: StaffManifestLoad) -> some View {
        let style = loadStatusStyle(load)
        return HStack(spacing: 5) {
            Circle().fill(style.color).frame(width: 5, height: 5)
            Text(style.label)
                .font(ASC.Typography.eyebrow(9))
                .tracking(1.2)
                .foregroundStyle(style.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(style.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func loadStatusStyle(_ load: StaffManifestLoad) -> (label: String, color: Color) {
        let filled = load.filled
        if filled >= 4 { return ("Boarding", ASC.Palette.hiVis) }
        if filled >= 1 { return ("Filling", ASC.Palette.daylight) }
        return ("Open", ASC.Text.muted)
    }

    private func slotChip(_ text: String) -> some View {
        Text(text)
            .font(ASC.Typography.eyebrow(10))
            .foregroundStyle(ASC.Text.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(ASC.Surface.deep)
            .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.sm, style: .continuous))
    }

    // MARK: - Sign-offs

    @ViewBuilder
    private var signoffsSection: some View {
        if auth.currentUser?.isInstructorRole == true {
            VStack(alignment: .leading, spacing: ASC.Space.md) {
                HStack {
                    Text("SIGN-OFFS PENDING")
                        .font(ASC.Typography.sectionLabel(12))
                        .tracking(2)
                        .foregroundStyle(ASC.Text.muted)
                    Spacer()
                    Text("\(vm.staffSignoffItems.count)")
                        .font(ASC.Typography.sectionLabel(12))
                        .foregroundStyle(ASC.Palette.hiVis)
                }

                if vm.staffSignoffItems.isEmpty {
                    Text("No pending sign-offs.")
                        .font(ASC.Typography.body(14))
                        .foregroundStyle(ASC.Text.muted)
                        .ascCard()
                } else {
                    ForEach(vm.staffSignoffItems.prefix(3)) { item in
                        signoffRow(item)
                    }
                }
            }
        }
    }

    private func signoffRow(_ item: InstructorSignoffItem) -> some View {
        HStack(alignment: .center, spacing: ASC.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.studentName)
                    .font(ASC.Typography.bodyMedium(13))
                    .foregroundStyle(ASC.Text.primary)
                Text("\(item.courseTitle) · \(item.displayTitle)")
                    .font(ASC.Typography.caption(11))
                    .foregroundStyle(ASC.Text.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button {
                tabSelect.selected = 3
                tabSelect.openInstructorReviews = true
            } label: {
                Text("REVIEW")
                    .font(ASC.Typography.eyebrow(10))
                    .tracking(1.2)
                    .foregroundStyle(ASC.Palette.hiVis)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: ASC.Radius.sm, style: .continuous)
                            .strokeBorder(ASC.Palette.hiVis, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(ASC.Space.lg)
        .background(ASC.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
        )
    }
}

// Simple wrapping chip row for jumper names.
private struct StaffSlotFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
