// File: ASC/Views/Loft/DzRigDetailView.swift
// DZ Rig detail — Header, component cards, 25-Jump Check block, pack form, inspect, pack history.
import SwiftUI

struct DzRigDetailView: View {
    let rigId: Int
    @ObservedObject var vm: DzRigsViewModel
    @Environment(\.mdzColors) private var colors
    @State private var packDate = Date()
    @State private var packJobCount = 1
    @State private var packNotes = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoadingDetail && vm.detailRig == nil {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.dz)).scaleEffect(1.4)
            } else if let rig = vm.detailRig {
                ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        rigHeaderBlock(rig: rig)
                        componentCardsBlock(rig: rig)
                        jumpCheckBlock(rig: rig, scrollToPackHistory: { proxy.scrollTo("packHistory", anchor: .center) })
                        if !rig.isEligibleFor25JumpCheck {
                            expiredReadOnlyBanner(rig: rig)
                        } else if vm.detailCanMarkPacked && (rig.outOfService != true) {
                            packFormSection
                        }
                        if !vm.detailRecords.isEmpty {
                            packHistorySection
                                .id("packHistory")
                        }
                    }
                    .padding(16)
                }
                }
            } else {
                EmptyStateView(icon: "questionmark.circle", title: "Rig not found", subtitle: "This DZ rig could not be loaded.")
            }
        }
        .navigationTitle(vm.detailRig?.label ?? "Rig")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: rigId) {
            await vm.loadDetail(rigId: rigId)
            packDate = Date()
            packJobCount = 1
        }
        .onDisappear {
            vm.clearDetail()
        }
    }

    // MARK: - Header: title, subtitle, status pill (Pic 1 style)
    private func rigHeaderBlock(rig: LoftRig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rig.label)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(colors.text)
                    let subtitle = rigSubtitle(rig)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(colors.muted)
                    }
                }
                Spacer(minLength: 8)
                if rig.outOfService == true {
                    Text("OUT OF SERVICE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(colors.danger)
                        .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func rigSubtitle(_ rig: LoftRig) -> String {
        let parts: [String] = [
            rig.model ?? rig.manufacturer,
            rig.harness.sn.map { "SN \($0)" }
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    // MARK: - Three horizontal component cards (CONTAINER, RESERVE, AAD)
    private func componentCardsBlock(rig: LoftRig) -> some View {
        HStack(alignment: .top, spacing: 10) {
            componentCard(
                title: "CONTAINER",
                lines: [
                    ("Mfr", rig.harness.mfr),
                    ("SN", rig.harness.sn)
                ]
            )
            componentCard(
                title: "RESERVE",
                lines: [
                    ("Mfr", rig.reserve.mfr),
                    ("Size", rig.reserve.model),
                    ("SN", rig.reserve.sn),
                    ("DOM", rig.reserve.dom)
                ]
            )
            componentCard(
                title: "AAD",
                lines: [
                    ("Mfr", rig.aad.mfr),
                    ("Model", rig.aad.model),
                    ("SN", rig.aad.sn)
                ]
            )
        }
    }

    private func componentCard(title: String, lines: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, pair in
                if let value = pair.1, !value.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.0)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(colors.muted)
                        Text(value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(colors.text)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(colors.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
    }

    // MARK: - 25-Jump Check block (count, progress bar, warn at 20, lock at 25, last check, All Checks / + Inspect)
    private func jumpCheckBlock(rig: LoftRig, scrollToPackHistory: @escaping () -> Void) -> some View {
        let n = min(rig.packJobsSinceInspection ?? 0, 25)
        let remaining = max(0, 25 - n)
        let atLimit = n >= 25

        return VStack(alignment: .leading, spacing: 12) {
            Text("25-JUMP CHECK")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(n) / 25")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(atLimit ? colors.danger : colors.text)
                Spacer()
                Text("REMAINING \(remaining)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(atLimit ? colors.danger : colors.muted)
            }

            // Progress bar 0–25 with markers at 20 (warn) and 25 (lock)
            jumpCheckProgressBar(current: n, atLimit: atLimit)

            if atLimit {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(colors.dz)
                    Text("Limit reached – rig locked until inspection")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colors.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.amber.opacity(0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.dz.opacity(0.4), lineWidth: 1))
            }

            if let last = rig.lastInspectionAt, !last.isEmpty {
                let formatted = formatLastInspection(last)
                HStack(spacing: 4) {
                    Text("Last check:")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                    Text(formatted)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.text)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(colors.green)
                    Text("Passed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.green)
                }
            }

            HStack(spacing: 10) {
                Button {
                    scrollToPackHistory()
                } label: {
                    Text("All Checks")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.card2)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                if vm.detailCanInspect && rig.outOfService == true {
                    Button {
                        Task { await vm.inspect(rigId: rigId) }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.markingRigId == rigId {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.9)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Inspect")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.dz)
                        .cornerRadius(10)
                    }
                    .disabled(vm.markingRigId == rigId)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func jumpCheckProgressBar(current: Int, atLimit: Bool) -> some View {
        let fillColor = atLimit ? colors.danger : colors.dz
        return GeometryReader { geo in
            let w = geo.size.width
            let segment = w / 25
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(colors.border.opacity(0.5))
                    .frame(height: 10)
                // Filled
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
                    .frame(width: max(0, segment * CGFloat(current)), height: 10)
                // Markers at 20 and 25
                let mark20 = segment * 20
                let mark25 = segment * 25
                if mark20 < w {
                    Rectangle()
                        .fill(colors.amber)
                        .frame(width: 2, height: 14)
                        .offset(x: mark20 - 1)
                }
                if mark25 <= w {
                    Rectangle()
                        .fill(colors.danger)
                        .frame(width: 2, height: 14)
                        .offset(x: mark25 - 2)
                }
            }
        }
        .frame(height: 14)
    }

    private func formatLastInspection(_ iso: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let d = formatter.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: d)
        }
        formatter.dateFormat = "yyyy-MM-dd"
        if let d = formatter.date(from: String(iso.prefix(10))) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: d)
        }
        return String(iso.prefix(10))
    }

    private func expiredReadOnlyBanner(rig: LoftRig) -> some View {
        let (title, subtitle): (String, String) = rig.status == "overdue"
            ? ("Rig Expired — Not eligible for 25 Jump Check", "Reserve is overdue. This rig cannot be used for pack jobs until repacked.")
            : ("No Pack Data — Not eligible for 25 Jump Check", "No pack record on file. This rig cannot be used until pack data is entered.")
        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(colors.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(colors.danger.opacity(0.12))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.danger.opacity(0.5), lineWidth: 1))
    }

    private var packFormSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Record Pack Job")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(colors.dz)
            DatePicker("Pack date", selection: $packDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(colors.dz)
            HStack {
                Text("Pack jobs this entry")
                    .font(.system(size: 13))
                    .foregroundColor(colors.text)
                Spacer()
                Picker("", selection: $packJobCount) {
                    ForEach(1...25, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(colors.dz)
            }
            TextField("Notes (optional)", text: $packNotes, axis: .vertical)
                .lineLimit(2...4)
                .mdzInputStyle()
            Button {
                Task {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    await vm.markPacked(rigId: rigId, packDate: df.string(from: packDate), packJobCount: packJobCount, notes: packNotes)
                    await vm.loadDetail(rigId: rigId)
                    packNotes = ""
                }
            } label: {
                HStack {
                    if vm.markingRigId == rigId {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Submit Pack")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(colors.dz)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(vm.markingRigId == rigId)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var inspectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rig needs inspection")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(colors.muted)
            Button {
                Task { await vm.inspect(rigId: rigId) }
            } label: {
                HStack {
                    if vm.markingRigId == rigId {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Inspect & Clear for 25 More")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(colors.dz)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(vm.markingRigId == rigId)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var packHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("25 Jump Check pack jobs")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(colors.muted)
            ForEach(vm.detailRecords) { rec in
                packHistoryRow(rec: rec)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func packHistoryRow(rec: PackRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.packDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.text)
                if let by = rec.packedBy {
                    Text(by)
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
            }
            Spacer()
            Text("×\(rec.packJobCount ?? 1)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(colors.dz)
            if rec.isLocked == true {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(colors.muted)
            }
        }
        .padding(12)
        .background(colors.navyMid.opacity(0.5))
        .cornerRadius(8)
    }
}
