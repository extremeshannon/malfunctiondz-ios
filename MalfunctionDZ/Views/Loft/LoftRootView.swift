// File: ASC/Views/Loft/LoftRootView.swift
// iPad: NavigationSplitView (rig list | rig detail). iPhone: NavigationStack.
import SwiftUI

struct LoftRootView: View {
    @StateObject private var vm = LoftViewModel()
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        Group {
            if hSizeClass == .regular {
                LoftSplitView(vm: vm)
            } else {
                LoftStackView(vm: vm)
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    fileprivate static var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - iPad: Split (rig list | rig detail)
struct LoftSplitView: View {
    @ObservedObject var vm: LoftViewModel
    @State private var selectedRig: LoftRig?

    private var dateString: String { LoftRootView.dateString }

    var body: some View {
        NavigationSplitView {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    loftHeader
                    if vm.isLoading && vm.rigs.isEmpty {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzGreen)).scaleEffect(1.4)
                        Spacer()
                    } else if vm.rigs.isEmpty {
                        Spacer()
                        EmptyStateView(icon: "backpack.fill", title: "No Rigs", subtitle: "No rigs in the loft.")
                        Spacer()
                    } else {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        List(selection: $selectedRig) {
                            ForEach(combinedRigs) { rig in
                                LoftRigRow(rig: rig)
                                    .tag(rig)
                                    .listRowBackground(Color.mdzCard)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .background(Color.mdzBackground)
                    }
                }
            }
            .navigationTitle("Rigs")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .onAppear { if selectedRig == nil, let first = vm.rigs.first { selectedRig = first } }
            .onChange(of: vm.rigs.count) { _, _ in
                if selectedRig == nil, let first = vm.rigs.first { selectedRig = first }
            }
        } detail: {
            if let rig = selectedRig {
                NavigationStack {
                    RigDetailView(rig: rig)
                }
            } else {
                ZStack {
                    Color.mdzBackground.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "backpack.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.mdzMuted.opacity(0.5))
                        Text("Select a rig")
                            .font(.headline)
                            .foregroundColor(.mdzMuted)
                    }
                }
            }
        }
    }

    private var loftHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "backpack.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mdzGreen)
                Text("LOFT")
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
            Text(dateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.mdzMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.mdzNavyMid)
    }

    private var combinedRigs: [LoftRig] {
        vm.overdueRigs + vm.dueSoonRigs + vm.currentRigs + vm.unknownRigs
    }
}

// MARK: - iPhone: Stack (original behavior)
struct LoftStackView: View {
    @ObservedObject var vm: LoftViewModel

    private var dateString: String { LoftRootView.dateString }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "backpack.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.mdzGreen)
                            Text("LOFT")
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
                        Text(dateString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.mdzMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.mdzNavyMid)

                    if vm.isLoading && vm.rigs.isEmpty {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzGreen)).scaleEffect(1.4)
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
                                    LoftSection(title: "OVERDUE — \(vm.overdueRigs.count) RIGS", color: .mdzDanger,
                                                icon: "exclamationmark.circle.fill", rigs: vm.overdueRigs)
                                }
                                if !vm.dueSoonRigs.isEmpty {
                                    LoftSection(title: "DUE SOON — \(vm.dueSoonRigs.count) RIGS", color: .mdzAmber,
                                                icon: "clock.fill", rigs: vm.dueSoonRigs)
                                }
                                if !vm.currentRigs.isEmpty {
                                    LoftSection(title: "CURRENT — \(vm.currentRigs.count) RIGS", color: .mdzGreen,
                                                icon: "checkmark.circle.fill", rigs: vm.currentRigs)
                                }
                                if !vm.unknownRigs.isEmpty {
                                    LoftSection(title: "NO PACK RECORD — \(vm.unknownRigs.count) RIGS", color: .mdzMuted,
                                                icon: "questionmark.circle.fill", rigs: vm.unknownRigs)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}


// MARK: - Summary Stat Box
struct SummaryStatBox: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(value > 0 ? color : .mdzMuted)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loft Section
struct LoftSection: View {
    let title: String
    let color: Color
    let icon: String
    let rigs: [LoftRig]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
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

            // Rig rows
            VStack(spacing: 0) {
                ForEach(rigs) { rig in
                    NavigationLink(destination: RigDetailView(rig: rig)) {
                        LoftRigRow(rig: rig)
                    }
                    .buttonStyle(.plain)
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

// MARK: - Rig Row
struct LoftRigRow: View {
    let rig: LoftRig

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(rig.statusColor)
                .frame(width: 4, height: 44)

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
                Text(rig.statusLabel)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(rig.statusColor)
                Text(rig.daysLeftText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.mdzMuted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mdzBorder)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Rig Detail
struct RigDetailView: View {
    let rig: LoftRig

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Status card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(rig.label)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.mdzText)
                            Spacer()
                            StatusPill(label: rig.statusLabel, color: rig.statusColor)
                        }
                        if let due = rig.dueDate {
                            InfoRow(label: "Reserve Due", value: due)
                        }
                        InfoRow(label: "Days", value: rig.daysLeftText)
                        if let by = rig.packedBy, let cert = rig.packerCert {
                            InfoRow(label: "Last Packed By", value: "\(by) (\(cert))")
                        }
                        if let pack = rig.lastPack {
                            InfoRow(label: "Last Pack Date", value: pack)
                        }
                    }
                    .padding(16)
                    .background(Color.mdzCard)
                    .cornerRadius(12)

                    // Harness
                    ComponentCard(title: "HARNESS & CONTAINER",
                                  mfr: rig.harness.mfr,
                                  model: rig.harness.model,
                                  sn: rig.harness.sn,
                                  dom: nil)

                    // Reserve
                    ComponentCard(title: "RESERVE PARACHUTE",
                                  mfr: rig.reserve.mfr,
                                  model: rig.reserve.model,
                                  sn: rig.reserve.sn,
                                  dom: rig.reserve.dom)

                    // AAD
                    ComponentCard(title: "AAD",
                                  mfr: rig.aad.mfr,
                                  model: rig.aad.model,
                                  sn: rig.aad.sn,
                                  dom: nil)

                    if let notes = rig.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.mdzMuted)
                                .tracking(1)
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.mdzText)
                        }
                        .padding(16)
                        .background(Color.mdzCard)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(rig.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ComponentCard: View {
    let title: String
    let mfr: String?
    let model: String?
    let sn: String?
    let dom: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(1)
            if let m = mfr   { InfoRow(label: "Manufacturer", value: m) }
            if let m = model  { InfoRow(label: "Model",        value: m) }
            if let s = sn     { InfoRow(label: "Serial",       value: s) }
            if let d = dom    { InfoRow(label: "DOM",          value: d) }
            if mfr == nil && model == nil && sn == nil && dom == nil {
                Text("No data on file")
                    .font(.subheadline)
                    .foregroundColor(.mdzMuted)
            }
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}
