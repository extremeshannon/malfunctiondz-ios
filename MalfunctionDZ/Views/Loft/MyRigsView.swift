// File: ASC/Views/Loft/MyRigsView.swift
// My Rigs — list of rig owner's rigs; tap a rig to edit.
import SwiftUI
import MalfunctionDZCore

struct MyRigsView: View {
    @StateObject private var vm = MyRigsViewModel()
    /// Shared with `CreateRigSheet` (same API as Logbook → Add Jump → + rig).
    @StateObject private var logbookVm = LogbookViewModel()
    @State private var showAddRig = false
    @State private var rigToEdit: JumperRig?
    @State private var rigPendingDelete: JumperRig?
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                headerSection
                if vm.isLoading && vm.rigs.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.green)).scaleEffect(1.4)
                    Spacer()
                } else if vm.rigs.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        EmptyStateView(
                            icon: "briefcase.fill",
                            title: "No Rigs",
                            subtitle: "Add your harness and reserve here, or when logging a jump in Logbook."
                        )
                        Button {
                            showAddRig = true
                        } label: {
                            Text("Add rig")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(colors.green)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(vm.rigs) { rig in
                            Button {
                                rigToEdit = rig
                            } label: {
                                MyRigRow(rig: rig)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(colors.background)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    rigPendingDelete = rig
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showAddRig) {
            CreateRigSheet(vm: logbookVm) {
                showAddRig = false
                Task { await vm.load() }
            }
        }
        .sheet(item: $rigToEdit) { rig in
            CreateRigSheet(vm: logbookVm, editingRig: rig) {
                rigToEdit = nil
                Task { await vm.load() }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil || logbookVm.error != nil },
            set: {
                if !$0 {
                    vm.error = nil
                    logbookVm.error = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                vm.error = nil
                logbookVm.error = nil
            }
        } message: { Text(vm.error ?? logbookVm.error ?? "") }
        .confirmationDialog(
            "Delete this rig?",
            isPresented: Binding(
                get: { rigPendingDelete != nil },
                set: { if !$0 { rigPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let r = rigPendingDelete {
                    Task {
                        let ok = await logbookVm.deleteRig(rigId: r.id)
                        rigPendingDelete = nil
                        if ok { await vm.load() }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                rigPendingDelete = nil
            }
        } message: {
            Text("This removes the rig from your list. Past jumps stay in your log.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.green)
                Text("MY RIGS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.green)
                    .tracking(2)
                Spacer()
                Text("\(vm.rigs.count) RIG\(vm.rigs.count == 1 ? "" : "S")")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                Button {
                    showAddRig = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(colors.green)
                        .accessibilityLabel("Add rig")
                }
                .buttonStyle(.plain)
            }
            Text(myRigsDateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.navyMid)
    }

    private var myRigsDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - MyRigRow (full summary; "—" when missing)
struct MyRigRow: View {
    let rig: JumperRig
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text(rig.rigLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colors.text)

                sectionBlock("Harness", rows: [
                    ("Mfr", dash(rig.harness?.mfr)),
                    ("Model", dash(rig.harness?.model)),
                    ("SN", dash(rig.harness?.sn)),
                    ("DOM", dash(rig.harness?.dom)),
                ])
                if rigHasMain(rig) {
                    sectionBlock("Main", rows: mainRows())
                }
                sectionBlock("Reserve", rows: [
                    ("Mfr", dash(rig.reserve?.mfr)),
                    ("Model", dash(rig.reserve?.model)),
                    ("Size", sizeStr(rig.reserve?.sizeSqft)),
                    ("SN", dash(rig.reserve?.sn)),
                    ("DOM", dash(rig.reserve?.dom)),
                ])
                sectionBlock("AAD", rows: [
                    ("Mfr", dash(rig.aad?.mfr)),
                    ("Model", dash(rig.aad?.model)),
                    ("SN", dash(rig.aad?.sn)),
                    ("DOM", dash(rig.aad?.dom)),
                ])
                if let n = rig.notes, !n.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Notes: \(n)")
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colors.muted)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func rigHasMain(_ rig: JumperRig) -> Bool {
        guard let m = rig.main else { return false }
        if !(m.mfr ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if !(m.model ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if let sz = m.sizeSqft, sz > 0 { return true }
        if !(m.sn ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if let d = m.dom, !d.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return false
    }

    private func mainRows() -> [(String, String)] {
        guard let m = rig.main else {
            return []
        }
        return [
            ("Mfr", dash(m.mfr)),
            ("Model", dash(m.model)),
            ("Size", sizeStr(m.sizeSqft)),
            ("SN", dash(m.sn)),
            ("DOM", dash(m.dom)),
        ]
    }

    private func sectionBlock(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.5)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.0)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(colors.muted)
                            .frame(width: 44, alignment: .leading)
                        Text(row.1)
                            .font(.system(size: 13))
                            .foregroundColor(colors.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
        }
    }

    private func dash(_ s: String?) -> String {
        let t = (s ?? "").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "—" : t
    }

    private func sizeStr(_ sq: Int?) -> String {
        guard let s = sq, s > 0 else { return "—" }
        return "\(s) sq ft"
    }
}
