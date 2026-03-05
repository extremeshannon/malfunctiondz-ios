// File: ASC/Views/Users/JumpCheckView.swift
// 25 Jump Check — DZ rigs with pack job counts (X/25). At 25 pack jobs rig is out of service.
import SwiftUI

struct JumpCheckView: View {
    @ObservedObject var vm: DzRigsViewModel
    @State private var searchQuery = ""

    private var filteredRigs: [LoftRig] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return vm.rigs }
        return vm.rigs.filter {
            $0.label.lowercased().contains(q)
            || ($0.manufacturer ?? "").lowercased().contains(q)
            || ($0.model ?? "").lowercased().contains(q)
            || ($0.harness.sn ?? "").lowercased().contains(q)
            || ($0.reserve.sn ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.mdzAmber)
                        Text("25 JUMP CHECK")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.mdzAmber)
                            .tracking(2)
                        Spacer()
                        Text("\(filteredRigs.count) RIGS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.mdzMuted)
                            .tracking(1)
                    }
                    Text("DZ rigs — pack jobs X/25. At 25 pack jobs rig is out of service until inspected.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.mdzMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.mdzNavyMid)

                TextField("Search rig label, mfr, model, serial", text: $searchQuery)
                    .mdzInputStyle()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.mdzNavyMid)
                    .autocorrectionDisabled()

                if vm.isLoading && vm.rigs.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber)).scaleEffect(1.4)
                    Spacer()
                } else if filteredRigs.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: searchQuery.isEmpty ? "No DZ Rigs" : "No matches",
                        subtitle: searchQuery.isEmpty ? "No DZ-owned rigs in the loft." : "Try a different search."
                    )
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(filteredRigs) { rig in
                                NavigationLink(value: rig.id) {
                                    DzRigRow(rig: rig, showThumbnails: true)
                                }
                                .buttonStyle(.plain)
                                if rig.id != filteredRigs.last?.id {
                                    Divider().background(Color.mdzBorder).padding(.horizontal, 14)
                                }
                            }
                        }
                        .background(Color.mdzCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzAmber.opacity(0.3), lineWidth: 1))
                        .padding(16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("25 Jump Check")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.load() }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}