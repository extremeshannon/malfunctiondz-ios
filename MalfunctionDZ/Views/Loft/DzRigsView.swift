// File: ASC/Views/Loft/DzRigsView.swift
// DZ Rigs — DZ-owned rigs. Packers see list, tap rig for detail; pack form in detail; at 25 pack jobs rig is out of service.
import SwiftUI

struct DzRigsView: View {
    @StateObject private var vm = DzRigsViewModel()
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        NavigationStack {
            dzRigsContent
                .navigationDestination(for: Int.self) { rigId in
                    DzRigDetailView(rigId: rigId, vm: vm)
                }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .navigationDestination(for: Int.self) { rigId in
            DzRigDetailView(rigId: rigId, vm: vm)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    private var dzRigsContent: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                headerSection
                if vm.isLoading && vm.rigs.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzGreen)).scaleEffect(1.4)
                    Spacer()
                } else if vm.rigs.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "square.stack.3d.up.fill", title: "No DZ Rigs", subtitle: "No DZ-owned rigs in the loft.")
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if let s = vm.summary {
                                HStack(spacing: 0) {
                                    SummaryStatBox(value: s.overdue, label: "OVERDUE", color: .mdzDanger)
                                    Divider().background(Color.mdzBorder).frame(height: 40)
                                    SummaryStatBox(value: s.dueSoon, label: "DUE SOON", color: .mdzAmber)
                                    Divider().background(Color.mdzBorder).frame(height: 40)
                                    SummaryStatBox(value: s.current, label: "CURRENT", color: .mdzGreen)
                                }
                                .padding(.vertical, 12)
                                .background(Color.mdzCard)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
                            }
                            if !vm.overdueRigs.isEmpty {
                                DzRigsSection(title: "OVERDUE — \(vm.overdueRigs.count) RIGS", color: .mdzDanger,
                                               icon: "exclamationmark.circle.fill", rigs: vm.overdueRigs)
                            }
                            if !vm.dueSoonRigs.isEmpty {
                                DzRigsSection(title: "DUE SOON — \(vm.dueSoonRigs.count) RIGS", color: .mdzAmber,
                                               icon: "clock.fill", rigs: vm.dueSoonRigs)
                            }
                            if !vm.currentRigs.isEmpty {
                                DzRigsSection(title: "CURRENT — \(vm.currentRigs.count) RIGS", color: .mdzGreen,
                                               icon: "checkmark.circle.fill", rigs: vm.currentRigs)
                            }
                            if !vm.unknownRigs.isEmpty {
                                DzRigsSection(title: "NO PACK RECORD — \(vm.unknownRigs.count) RIGS", color: .mdzMuted,
                                               icon: "questionmark.circle.fill", rigs: vm.unknownRigs)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mdzGreen)
                Text("DZ RIGS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.mdzGreen)
                    .tracking(2)
                Spacer()
                if let s = vm.summary {
                    Text("\(s.total) RIGS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.mdzMuted)
                        .tracking(1)
                }
            }
            Text(dzRigsDateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.mdzMuted)
            if vm.canMarkPacked {
                Text("Tap a rig to open detail — add pack jobs, set date")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.mdzAmber)
                NavigationLink {
                    JumpCheckView(vm: vm)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.fall")
                            .font(.system(size: 12, weight: .semibold))
                        Text("25 Jump Check")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.mdzAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.mdzAmber.opacity(0.15))
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.mdzNavyMid)
    }

    private var dzRigsDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - DzRigsSection
struct DzRigsSection: View {
    let title: String
    let color: Color
    let icon: String
    let rigs: [LoftRig]

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
                        Divider().background(Color.mdzBorder)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color.mdzCard)
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

    private var packJobsText: String {
        let n = rig.packJobsSinceInspection ?? 0
        if rig.outOfService == true {
            return "25/25 — Out"
        }
        return "\(n)/25"
    }

    private var packJobsColor: Color {
        rig.outOfService == true ? .mdzDanger : .mdzGreen
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(rig.statusColor)
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
                    .foregroundColor(.mdzText)
                HStack(spacing: 6) {
                    if let mfr = rig.harness.mfr {
                        Text(mfr)
                            .font(.system(size: 11))
                            .foregroundColor(.mdzMuted)
                            .lineLimit(1)
                    }
                    if let sn = rig.reserve.sn {
                        Text("· \(sn)")
                            .font(.system(size: 11))
                            .foregroundColor(.mdzMuted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(packJobsText)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(packJobsColor)
                Text(rig.daysLeftText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.mdzMuted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mdzMuted)
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
            Color.mdzNavyMid
            Image(systemName: "photo")
                .font(.system(size: 16))
                .foregroundColor(.mdzMuted)
        }
    }
}
