// File: ASC/Views/Loft/DzRigDetailView.swift
// DZ Rig detail — Pack form (date, count), pack history, Inspect for rigger.
import SwiftUI

struct DzRigDetailView: View {
    let rigId: Int
    @ObservedObject var vm: DzRigsViewModel
    @State private var packDate = Date()
    @State private var packJobCount = 1
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
                        if vm.detailCanMarkPacked && (rig.outOfService != true) {
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
            if let rig = vm.detailRig, let last = vm.detailRecords.first, let pd = isoDate(from: last.packDate) {
                packDate = pd
            } else {
                packDate = Date()
            }
        }
        .onDisappear {
            vm.clearDetail()
        }
    }

    private func rigHeaderSection(rig: LoftRig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rig.label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.mdzText)
                Spacer()
                packJobsBadge(rig: rig)
            }
            if let mfr = rig.harness.mfr { detailRow("Harness", mfr) }
            if let sn = rig.reserve.sn { detailRow("Reserve SN", sn) }
            if let dom = rig.reserve.dom { detailRow("Reserve DOM", dom) }
            if let sn = rig.aad.sn { detailRow("AAD SN", sn) }
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
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
                Stepper("\(packJobCount)", value: $packJobCount, in: 1...25)
                    .labelsHidden()
                Text("\(packJobCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.mdzGreen)
                    .frame(minWidth: 28, alignment: .trailing)
            }
            Button {
                Task {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    await vm.markPacked(rigId: rigId, packDate: df.string(from: packDate), packJobCount: packJobCount)
                    await vm.loadDetail(rigId: rigId)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Pack history")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.mdzMuted)
            ForEach(vm.detailRecords) { rec in
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
                        .foregroundColor(.mdzGreen)
                    if rec.isLocked == true {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.mdzMuted)
                    }
                }
                .padding(12)
                .background(Color.mdzNavyMid.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private func isoDate(from s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
