// ASC Packers — all rig squawks across the gear room.
import SwiftUI
import MalfunctionDZCore

struct PackerSquawksView: View {
    @EnvironmentObject private var tabSelect: TabSelection
    @StateObject private var vm = RigSquawksViewModel()

    var body: some View {
        ZStack {
            ASCScreenBackground()
            VStack(spacing: 0) {
                squawksHeader
                filterRow
                if vm.isLoading && vm.squawks.isEmpty {
                    Spacer()
                    ProgressView().tint(ASC.Palette.hiVis).scaleEffect(1.3)
                    Spacer()
                } else if vm.squawks.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "exclamationmark.triangle.fill",
                        title: "No Squawks",
                        subtitle: vm.filter == .all
                            ? "No squawks recorded across any rig."
                            : "No \(vm.filter.label.lowercased()) squawks."
                    )
                    Spacer()
                } else {
                    squawksList
                }
            }
        }
        .navigationTitle("Squawks")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "Unknown error")
        }
    }

    private var squawksHeader: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("SQUAWKS")
                .font(ASC.Typography.display(28))
                .foregroundStyle(ASC.Text.primary)
            Text(headerSubtitle)
                .font(ASC.Typography.bodyMedium(14))
                .foregroundStyle(ASC.Text.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ASC.Space.lg)
        .padding(.top, ASC.Space.md)
        .padding(.bottom, ASC.Space.sm)
    }

    private var headerSubtitle: String {
        let n = vm.total
        if n == 0 { return "All rigs · no squawks" }
        let openCount = vm.squawks.filter(\.isOpen).count
        if vm.filter == .all, openCount > 0 {
            return "\(n) total · \(openCount) open"
        }
        return "\(n) squawk\(n == 1 ? "" : "s")"
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ASC.Space.sm) {
                ForEach(RigSquawkFilter.allCases) { f in
                    Button {
                        Task { await vm.setFilter(f) }
                    } label: {
                        Text(f.label.uppercased())
                            .font(ASC.Typography.eyebrow(11))
                            .foregroundStyle(vm.filter == f ? ASC.Palette.midnight : ASC.Text.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(vm.filter == f ? ASC.Palette.hiVis : ASC.Surface.card)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(vm.filter == f ? ASC.Palette.hiVis : ASC.Border.hair, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.vertical, ASC.Space.sm)
        }
    }

    private var squawksList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: ASC.Space.md) {
                ForEach(vm.squawks) { squawk in
                    squawkCard(squawk)
                }
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.bottom, ASC.Space.xxxl)
        }
    }

    private func squawkCard(_ squawk: RigSquawk) -> some View {
        Button {
            tabSelect.pendingGearRoomRigId = squawk.rigId
            tabSelect.selected = 0
        } label: {
            VStack(alignment: .leading, spacing: ASC.Space.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: ASC.Space.xs) {
                        Text(squawk.rigLabel.isEmpty ? "Rig #\(squawk.rigId)" : squawk.rigLabel)
                            .font(ASC.Typography.sectionLabel(17))
                            .foregroundStyle(ASC.Text.primary)
                        if !squawk.title.isEmpty {
                            Text(squawk.title)
                                .font(ASC.Typography.bodyMedium(15))
                                .foregroundStyle(ASC.Text.secondary)
                        }
                    }
                    Spacer(minLength: ASC.Space.sm)
                    statusBadge(squawk.statusLabel, status: squawk.status)
                }

                HStack(spacing: ASC.Space.sm) {
                    metaPill(squawk.componentLabel)
                    metaPill(squawk.priorityLabel, accent: priorityAccent(squawk.priority))
                    if !squawk.squawkDate.isEmpty {
                        metaPill(squawk.squawkDate)
                    }
                }

                if !squawk.description.isEmpty {
                    Text(squawk.description)
                        .font(ASC.Typography.body(14))
                        .foregroundStyle(ASC.Text.tertiary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if squawk.status.lowercased() == "closed" {
                    if !squawk.resolution.isEmpty {
                        Text("Resolution: \(squawk.resolution)")
                            .font(ASC.Typography.bodyMedium(13))
                            .foregroundStyle(ASC.Palette.jumpReady)
                    }
                    if !squawk.closedByName.isEmpty, squawk.closedByName != "—" {
                        Text("Closed by \(squawk.closedByName)\(squawk.closedDate.isEmpty ? "" : " · \(squawk.closedDate)")")
                            .font(ASC.Typography.body(12))
                            .foregroundStyle(ASC.Text.tertiary)
                    }
                }

                HStack(spacing: ASC.Space.xs) {
                    Text("View rig")
                        .font(ASC.Typography.eyebrow(11))
                        .foregroundStyle(ASC.role.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ASC.role.accent)
                }
            }
            .padding(ASC.Space.lg)
            .background(ASC.Surface.card)
            .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ASC.Radius.lg, style: .continuous)
                    .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ label: String, status: String) -> some View {
        Text(label)
            .font(ASC.Typography.eyebrow(10))
            .foregroundStyle(statusForeground(status))
            .padding(.horizontal, ASC.Space.sm)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(statusBackground(status))
            )
    }

    private func metaPill(_ text: String, accent: Color = ASC.Text.secondary) -> some View {
        Text(text)
            .font(ASC.Typography.eyebrow(10))
            .foregroundStyle(accent)
            .padding(.horizontal, ASC.Space.sm)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(ASC.Surface.elevated)
            )
    }

    private func statusForeground(_ status: String) -> Color {
        switch status.lowercased() {
        case "open": return ASC.Palette.midnight
        case "deferred": return ASC.Palette.caution
        case "closed": return ASC.Palette.jumpReady
        default: return ASC.Text.primary
        }
    }

    private func statusBackground(_ status: String) -> Color {
        switch status.lowercased() {
        case "open": return ASC.Palette.hiVis.opacity(0.9)
        case "deferred": return ASC.Palette.caution.opacity(0.2)
        case "closed": return ASC.Palette.jumpReady.opacity(0.15)
        default: return ASC.Surface.elevated
        }
    }

    private func priorityAccent(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "critical", "high": return ASC.Palette.cutaway
        case "low": return ASC.Text.tertiary
        default: return ASC.Text.secondary
        }
    }
}
