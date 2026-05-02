// File: ASC/Views/Loft/DzRigsView.swift
// Gear Room — DZ-owned rigs with status cards: Out of Service, Approaching Limit, Repack Due Soon, All Clear.
import SwiftUI
import MalfunctionDZCore

struct DzRigsView: View {
    @StateObject private var vm = DzRigsViewModel()

    /// Belt-and-suspenders: API often returns bare `"Not Found"` before humanization in VM ships.
    private static func alertBody(_ raw: String?) -> String {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if t.caseInsensitiveCompare("not found") == .orderedSame {
            return "DZ rigs API not found. In Profile, set API Base URL to your MalfunctionDZ server. The backend must expose GET /api/loft/dz_rigs."
        }
        return t.isEmpty ? "Unknown error." : t
    }
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors

    var body: some View {
        NavigationStack {
            gearRoomContent
                .navigationDestination(for: Int.self) { rigId in
                    DzRigDetailView(rigId: rigId, vm: vm)
                }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(Self.alertBody(vm.error))
        }
    }

    private var gearRoomContent: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                gearRoomHeader
                if vm.isLoading && vm.rigs.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.loft)).scaleEffect(1.4)
                    Spacer()
                } else if vm.rigs.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "square.stack.3d.up.fill", title: "No Rigs", subtitle: "No DZ rigs in the gear room.")
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if !vm.outOfServiceRigs.isEmpty {
                                GearRoomCard(
                                    title: "OUT OF SERVICE",
                                    icon: "xmark.circle.fill",
                                    color: colors.danger,
                                    pillLabel: "LOCKED",
                                    rigs: vm.outOfServiceRigs,
                                    style: .outOfService
                                )
                            }
                            if !vm.approachingLimitRigs.isEmpty {
                                GearRoomCard(
                                    title: "APPROACHING LIMIT",
                                    icon: "exclamationmark.triangle.fill",
                                    color: colors.amber,
                                    pillLabel: "WARN",
                                    rigs: vm.approachingLimitRigs,
                                    style: .approachingLimit
                                )
                            }
                            if !vm.repackDueSoonRigs.isEmpty {
                                GearRoomCard(
                                    title: "REPACK DUE SOON",
                                    icon: "info.circle.fill",
                                    color: colors.aviation,
                                    pillLabel: "\(vm.repackDueSoonRigs.count) RIGS",
                                    rigs: vm.repackDueSoonRigs,
                                    style: .repackDueSoon
                                )
                            }
                            if !vm.allClearRigs.isEmpty {
                                GearRoomCard(
                                    title: "ALL CLEAR",
                                    icon: "checkmark.circle.fill",
                                    color: colors.green,
                                    pillLabel: "\(vm.allClearRigs.count) RIGS",
                                    rigs: vm.allClearRigs,
                                    style: .allClear
                                )
                            }
                            if !vm.unknownRigs.isEmpty {
                                GearRoomCard(
                                    title: "NO PACK RECORD",
                                    icon: "questionmark.circle.fill",
                                    color: colors.muted,
                                    pillLabel: "\(vm.unknownRigs.count) RIGS",
                                    rigs: vm.unknownRigs,
                                    style: .allClear
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    private var gearRoomHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("MODULE · RIGS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(colors.muted)
                    .tracking(1.5)
                Spacer()
            }
            Text("Gear Check")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(colors.text)
            if let s = vm.summary {
                let critical = (s.overdue + vm.outOfServiceRigs.count)
                Text("\(s.total) rigs" + (critical > 0 ? " · \(critical) critical" : ""))
                    .font(.system(size: 13))
                    .foregroundColor(colors.muted)
            }
            if vm.canMarkPacked {
                HStack(spacing: 8) {
                    Text("Tap a rig to add pack jobs")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.muted)
                    NavigationLink {
                        JumpCheckView(vm: vm)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.fall")
                                .font(.system(size: 11, weight: .semibold))
                            Text("25 Jump Check")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(colors.dz)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(colors.dz.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.card)
    }

    private var dzRigsDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - Gear Room card (Pic 2 style)
enum GearRoomCardStyle {
    case outOfService   // single rig, big count, "Limit reached", LOCKED
    case approachingLimit // list of rigs with count + "X jumps remaining", WARN
    case repackDueSoon  // "Tandem #1 · #6 · #11", "180-day repack within 30 days", 3 RIGS
    case allClear       // list or count
}

struct GearRoomCard: View {
    let title: String
    let icon: String
    let color: Color
    let pillLabel: String
    let rigs: [LoftRig]
    let style: GearRoomCardStyle
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(color)
                    .tracking(0.5)
                Spacer()
                Text(pillLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color)
                    .cornerRadius(6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            switch style {
            case .outOfService:
                if let rig = rigs.first {
                    outOfServiceContent(rig: rig)
                }
            case .approachingLimit:
                ForEach(rigs) { rig in
                    approachingLimitRow(rig: rig)
                }
            case .repackDueSoon:
                repackDueSoonContent
            case .allClear:
                ForEach(rigs) { rig in
                    NavigationLink(value: rig.id) {
                        GearRoomRow(rig: rig, subtitle: rig.daysLeftText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 14)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    private var cardBackground: Color {
        switch style {
        case .outOfService: return color.opacity(0.12)
        case .approachingLimit: return color.opacity(0.08)
        case .repackDueSoon: return color.opacity(0.08)
        case .allClear: return colors.card
        }
    }

    private func outOfServiceContent(rig: LoftRig) -> some View {
        NavigationLink(value: rig.id) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rig.label)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(colors.text)
                        Text([rig.harness.mfr, rig.harness.sn].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                    }
                    Spacer()
                    Text("25")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(colors.danger)
                }
                Text("Limit reached")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colors.danger)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func approachingLimitRow(rig: LoftRig) -> some View {
        let n = rig.packJobsSinceInspection ?? 0
        let remaining = 25 - n
        return NavigationLink(value: rig.id) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rig.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colors.text)
                    Text("\(rig.harness.mfr ?? "") · \(remaining) jumps remaining")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
                Spacer()
                Text("\(n)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colors.amber)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var repackDueSoonContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if rigs.count == 1, let rig = rigs.first {
                NavigationLink(value: rig.id) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rig.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colors.text)
                        Text("180-day repack within 30 days")
                            .font(.system(size: 11))
                            .foregroundColor(colors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                if rigs.count <= 5 {
                    Text(rigs.map { $0.label }.joined(separator: " · "))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.text)
                }
                Text("180-day repack within 30 days")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
                ForEach(rigs) { rig in
                    NavigationLink(value: rig.id) {
                        HStack {
                            Text(rig.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundColor(colors.muted)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct GearRoomRow: View {
    let rig: LoftRig
    var subtitle: String?
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rig.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                if let s = subtitle, !s.isEmpty {
                    Text(s)
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - DzRigsSection
struct DzRigsSection: View {
    let title: String
    let color: Color
    let icon: String
    let rigs: [LoftRig]
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(color)
                    .tracking(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            VStack(spacing: 0) {
                ForEach(rigs) { rig in
                    NavigationLink(value: rig.id) {
                        DzRigRow(rig: rig)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    if rig.id != rigs.last?.id {
                        Divider().background(colors.border)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(colors.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - DzRigRow
struct DzRigRow: View {
    let rig: LoftRig
    var showThumbnails: Bool = false
    var isExpired: Bool = false
    @Environment(\.mdzColors) private var colors

    private var packJobsText: String {
        let n = rig.packJobsSinceInspection ?? 0
        if rig.outOfService == true {
            return "25/25 — Out"
        }
        return "\(n)/25"
    }

    private var packJobsColor: Color {
        rig.outOfService == true ? colors.danger : colors.green
    }

    private var statusBarColor: Color {
        isExpired ? colors.danger : rig.statusColor
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusBarColor)
                .frame(width: 4, height: showThumbnails ? 56 : 44)

            if showThumbnails {
                HStack(spacing: 6) {
                    rigThumbnail(path: rig.imageContainer, size: 44)
                    rigThumbnail(path: rig.imageMain, size: 44)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(rig.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                HStack(spacing: 6) {
                    if let mfr = rig.harness.mfr {
                        Text(mfr)
                            .font(.system(size: 11))
                            .foregroundColor(colors.muted)
                            .lineLimit(1)
                    }
                    if let sn = rig.reserve.sn {
                        Text("· \(sn)")
                            .font(.system(size: 11))
                            .foregroundColor(colors.muted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if isExpired {
                    Text("Not eligible")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(colors.danger)
                }
                Text(packJobsText)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(packJobsColor)
                Text(rig.daysLeftText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colors.muted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func rigThumbnail(path: String?, size: CGFloat) -> some View {
        Group {
            if let p = path, !p.isEmpty, let url = rig.imageURL(path: p) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: thumbPlaceholder
                    default: thumbPlaceholder
                    }
                }
            } else {
                thumbPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .cornerRadius(6)
    }

    private var thumbPlaceholder: some View {
        ZStack {
            colors.navyMid
            Image(systemName: "photo")
                .font(.system(size: 16))
                .foregroundColor(colors.muted)
        }
    }
}
