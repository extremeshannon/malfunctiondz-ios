// File: ASC/Views/Loft/MyRigsView.swift
// My Rigs — read-only list of rig owner's rigs. View-only; no editing.
import SwiftUI

struct MyRigsView: View {
    @StateObject private var vm = MyRigsViewModel()
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
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
                    EmptyStateView(icon: "briefcase.fill", title: "No Rigs", subtitle: "Add rigs in your Logbook to see them here.")
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(vm.rigs) { rig in
                                MyRigRow(rig: rig)
                            }
                        }
                        .padding(16)
                    }
                }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.mdzGreen)
                Text("MY RIGS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.mdzGreen)
                    .tracking(2)
                Spacer()
                Text("\(vm.rigs.count) RIG\(vm.rigs.count == 1 ? "" : "S")")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzMuted)
                    .tracking(1)
            }
            Text(myRigsDateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.mdzMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.mdzNavyMid)
    }

    private var myRigsDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - MyRigRow (read-only detail, no navigation to edit)
struct MyRigRow: View {
    let rig: JumperRig

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rig.rigLabel)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.mdzText)
            HStack(spacing: 20) {
                if let mfr = rig.harness?.mfr, !mfr.isEmpty {
                    labelVal("Harness", mfr)
                }
                if let mfr = rig.reserve?.mfr, !mfr.isEmpty {
                    labelVal("Reserve", mfr)
                }
                if let dom = rig.reserveDomDisplay, !dom.isEmpty {
                    labelVal("Reserve DOM", dom)
                }
                if let dom = rig.aadDomDisplay, !dom.isEmpty {
                    labelVal("AAD DOM", dom)
                }
            }
            if (rig.reserveDomDisplay ?? "").isEmpty && (rig.aadDomDisplay ?? "").isEmpty &&
               (rig.harness?.mfr ?? "").isEmpty && (rig.reserve?.mfr ?? "").isEmpty {
                Text("Add equipment details in Logbook")
                    .font(.system(size: 12))
                    .foregroundColor(.mdzMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private func labelVal(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mdzText)
        }
    }
}
