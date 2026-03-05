// File: ASC/Views/Loft/DzRigDetailView.swift
// DZ Rig detail — Pack form (date, count), pack history, Inspect for rigger.
import SwiftUI

struct DzRigDetailView: View {
    let rigId: Int
    @ObservedObject var vm: DzRigsViewModel
    @State private var packDate = Date()
    @State private var packJobCount = 1
    @State private var packNotes = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            if vm.isLoadingDetail && vm.detailRig == nil {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzGreen)).scaleEffect(1.4)
            } else if let rig = vm.detailRig {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        rigHeaderSection(rig: rig)
                        if !rig.isEligibleFor25JumpCheck {
                            expiredReadOnlyBanner(rig: rig)
                        } else if vm.detailCanMarkPacked && (rig.outOfService != true) {
                            packFormSection
                        }
                        if vm.detailCanInspect && (rig.outOfService == true) {
                            inspectSection
                        }
                        if !vm.detailRecords.isEmpty {
                            packHistorySection
                        }
                    }
                    .padding(16)
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

    private func rigHeaderSection(rig: LoftRig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                rigThumbnail(rig: rig)
                VStack(alignment: .leading, spacing: 6) {
                    Text(rig.label)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.mdzText)
                    packJobsBadge(rig: rig)
                }
                Spacer()
            }
            if let mfr = rig.harness.mfr { detailRow("Harness", mfr) }
            if let mod = rig.harness.model, !mod.isEmpty { detailRow("Harness model", mod) }
            if let sn = rig.harness.sn { detailRow("Harness SN", sn) }
            if let mfr = rig.reserve.mfr { detailRow("Reserve", mfr) }
            if let sn = rig.reserve.sn { detailRow("Reserve SN", sn) }
            if let dom = rig.reserve.dom { detailRow("Reserve DOM", dom) }
            if let mfr = rig.aad.mfr { detailRow("AAD", mfr) }
            if let sn = rig.aad.sn { detailRow("AAD SN", sn) }
            if let mfr = rig.manufacturer { detailRow("Manufacturer", mfr) }
            if let mod = rig.model { detailRow("Model", mod) }
            rigImagesSection(rig: rig)
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func rigThumbnail(rig: LoftRig) -> some View {
        let url = rig.imageURL(path: rig.imageContainer)
        Group {
            if let u = url {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: placeholderImage(icon: "square.stack.3d.up.fill")
                    default: placeholderImage(icon: "square.stack.3d.up.fill")
                    }
                }
            } else {
                placeholderImage(icon: "square.stack.3d.up.fill")
            }
        }
        .frame(width: 80, height: 80)
        .clipped()
        .cornerRadius(8)
    }

    private func placeholderImage(icon: String) -> some View {
        ZStack {
            Color.mdzNavyMid
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.mdzMuted)
        }
    }

    @ViewBuilder
    private func rigImagesSection(rig: LoftRig) -> some View {
        let hasAny = (rig.imageContainer != nil && !(rig.imageContainer ?? "").isEmpty)
            || (rig.imageReserve != nil && !(rig.imageReserve ?? "").isEmpty)
            || (rig.imageMain != nil && !(rig.imageMain ?? "").isEmpty)
        if hasAny {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pictures")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.mdzMuted)
                HStack(spacing: 12) {
                    if let p = rig.imageContainer, !p.isEmpty, let url = rig.imageURL(path: p) {
                        rigImageCell(label: "Container", url: url)
                    }
                    if let p = rig.imageReserve, !p.isEmpty, let url = rig.imageURL(path: p) {
                        rigImageCell(label: "Reserve", url: url)
                    }
                    if let p = rig.imageMain, !p.isEmpty, let url = rig.imageURL(path: p) {
                        rigImageCell(label: "Main", url: url)
                    }
                }
            }
        }
    }

    private func rigImageCell(label: String, url: URL) -> some View {
        VStack(spacing: 4) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                case .failure: placeholderImage(icon: "photo")
                default: placeholderImage(icon: "photo")
                }
            }
            .frame(width: 70, height: 70)
            .clipped()
            .cornerRadius(6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.mdzMuted)
        }
    }

    private func packJobsBadge(rig: LoftRig) -> some View {
        let n = rig.packJobsSinceInspection ?? 0
        let outOfService = rig.outOfService == true
        return HStack(spacing: 6) {
            Text("\(min(n, 25))/25 pack jobs")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(outOfService ? .mdzDanger : .mdzGreen)
            if outOfService {
                Text("OUT OF SERVICE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.mdzDanger)
                    .cornerRadius(4)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.mdzMuted)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mdzText)
        }
    }

    private func expiredReadOnlyBanner(rig: LoftRig) -> some View {
        let (title, subtitle): (String, String) = rig.status == "overdue"
            ? ("Rig Expired — Not eligible for 25 Jump Check", "Reserve is overdue. This rig cannot be used for pack jobs until repacked.")
            : ("No Pack Data — Not eligible for 25 Jump Check", "No pack record on file. This rig cannot be used until pack data is entered.")
        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.mdzDanger)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.mdzText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.mdzMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.mdzDanger.opacity(0.12))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzDanger.opacity(0.5), lineWidth: 1))
    }

    private var packFormSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Record Pack Job")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.mdzGreen)
            DatePicker("Pack date", selection: $packDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(.mdzGreen)
            HStack {
                Text("Pack jobs this entry")
                    .font(.system(size: 13))
                    .foregroundColor(.mdzText)
                Spacer()
                Picker("", selection: $packJobCount) {
                    ForEach(1...25, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.mdzGreen)
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
                .background(Color.mdzGreen)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(vm.markingRigId == rigId)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private var inspectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rig needs inspection")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.mdzMuted)
            Button {
                Task {
                    await vm.inspect(rigId: rigId)
                }
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
                .background(Color.mdzAmber)
                .foregroundColor(.black)
                .cornerRadius(10)
            }
            .disabled(vm.markingRigId == rigId)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzAmber.opacity(0.5), lineWidth: 1))
    }

    private var packHistorySection: some View {
        let (currentRecords, expiredRecords) = partitionPackHistory(vm.detailRecords)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Pack history")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.mdzMuted)
            ForEach(currentRecords) { rec in
                packHistoryRow(rec: rec)
            }
            if !expiredRecords.isEmpty {
                HStack {
                    Text("EXPIRED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.mdzDanger)
                        .tracking(1)
                    Spacer()
                }
                .padding(.top, 4)
                ForEach(expiredRecords) { rec in
                    packHistoryRow(rec: rec, isExpired: true)
                }
            }
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private func partitionPackHistory(_ records: [PackRecord]) -> (current: [PackRecord], expired: [PackRecord]) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())
        var current: [PackRecord] = []
        var expired: [PackRecord] = []
        for rec in records {
            let exp = rec.isExpired == true || (rec.dueDate != nil && (rec.dueDate ?? "") < today)
            if exp { expired.append(rec) }
            else { current.append(rec) }
        }
        return (current, expired)
    }

    private func packHistoryRow(rec: PackRecord, isExpired: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.packDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mdzText)
                if let by = rec.packedBy {
                    Text(by)
                        .font(.system(size: 11))
                        .foregroundColor(.mdzMuted)
                }
            }
            Spacer()
            Text("×\(rec.packJobCount ?? 1)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isExpired ? .mdzDanger : .mdzGreen)
            if rec.isLocked == true {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.mdzMuted)
            }
        }
        .padding(12)
        .background(isExpired ? Color.mdzDanger.opacity(0.08) : Color.mdzNavyMid.opacity(0.5))
        .cornerRadius(8)
    }

    private func isoDate(from s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
