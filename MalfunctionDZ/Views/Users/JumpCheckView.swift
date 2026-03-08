// File: ASC/Views/Users/JumpCheckView.swift
// 25 Jump Check — DZ rigs with pack job counts (X/25). At 25 pack jobs rig is out of service.
import SwiftUI

struct JumpCheckView: View {
    @ObservedObject var vm: DzRigsViewModel
    @State private var searchQuery = ""
    @Environment(\.mdzColors) private var colors

    private var filteredRigs: [LoftRig] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let base = q.isEmpty ? vm.rigs : vm.rigs.filter {
            $0.label.lowercased().contains(q)
            || ($0.manufacturer ?? "").lowercased().contains(q)
            || ($0.model ?? "").lowercased().contains(q)
            || ($0.harness.sn ?? "").lowercased().contains(q)
            || ($0.reserve.sn ?? "").lowercased().contains(q)
        }
        return base
    }

    /// In date: current or due_soon — can add pack jobs.
    private var eligibleRigs: [LoftRig] { filteredRigs.filter { $0.status == "current" || $0.status == "due_soon" } }
    /// Overdue or no pack data — read-only at bottom.
    private var ineligibleRigs: [LoftRig] { filteredRigs.filter { $0.status == "overdue" || $0.status == "unknown" } }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.amber)
                        Text("25 JUMP CHECK")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(colors.amber)
                            .tracking(2)
                        Spacer()
                        Text("\(filteredRigs.count) RIGS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(colors.muted)
                            .tracking(1)
                    }
                    Text("DZ rigs — pack jobs X/25. At 25 pack jobs rig is out of service. Expired rigs (reserve overdue) are read-only.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(colors.navyMid)

                TextField("Search rig label, mfr, model, serial", text: $searchQuery)
                    .mdzInputStyle()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colors.navyMid)
                    .autocorrectionDisabled()

                if vm.isLoading && vm.rigs.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.amber)).scaleEffect(1.4)
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
                            // Eligible rigs (can add pack jobs)
                            ForEach(eligibleRigs) { rig in
                                NavigationLink {
                                    DzRigDetailView(rigId: rig.id, vm: vm)
                                } label: {
                                    DzRigRow(rig: rig, showThumbnails: true)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                if rig.id != eligibleRigs.last?.id {
                                    Divider().background(colors.border).padding(.horizontal, 14)
                                }
                            }
                            // Overdue / no pack data — read-only at bottom
                            if !ineligibleRigs.isEmpty {
                                if !eligibleRigs.isEmpty {
                                    Divider().background(colors.border).padding(.horizontal, 14)
                                }
                                HStack {
                                    Text("EXPIRED / NO PACK DATA — READ ONLY")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(colors.muted)
                                        .tracking(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(colors.danger.opacity(0.08))
                                ForEach(ineligibleRigs) { rig in
                                    NavigationLink {
                                        DzRigDetailView(rigId: rig.id, vm: vm)
                                    } label: {
                                        DzRigRow(rig: rig, showThumbnails: true, isExpired: true)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                    if rig.id != ineligibleRigs.last?.id {
                                        Divider().background(colors.border).padding(.horizontal, 14)
                                    }
                                }
                            }
                        }
                        .background(colors.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.amber.opacity(0.3), lineWidth: 1))
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