// HHIO — pack records ledger (reserve repacks + stats).
import SwiftUI
import MalfunctionDZCore

struct LoftRecordsRootView: View {
    @StateObject private var vm = LoftRecordsViewModel()
    @State private var showAdd = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                statsHeader
                if vm.isLoading && vm.records.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.loft)).scaleEffect(1.4)
                    Spacer()
                } else if vm.records.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Pack Records",
                        subtitle: "Add a reserve repack to start the loft ledger."
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(vm.records) { rec in
                            LoftRecordRowView(record: rec)
                                .listRowBackground(colors.card)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Pack Records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(colors.loft)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                LoftRecordAddView(vm: vm)
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RESERVE REPACK STATS")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            if let s = vm.stats {
                HStack(spacing: 0) {
                    statCell(value: s.reserveTotal ?? 0, label: "TOTAL", color: colors.text)
                    Divider().frame(height: 36).background(colors.border)
                    statCell(value: s.reserveOverdue ?? 0, label: "OVERDUE", color: colors.danger)
                    Divider().frame(height: 36).background(colors.border)
                    statCell(value: s.reserveDueSoon ?? 0, label: "DUE SOON", color: colors.amber)
                }
                .padding(.vertical, 10)
                .background(colors.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
            }
            Text("Reserve repacks and loft stats stay in HHIO. MalfunctionDZ shares DZ pack job dates only.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(colors.muted)
        }
        .padding(16)
        .background(colors.navyMid)
    }

    private func statCell(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LoftRecordRowView: View {
    let record: LoftRecordRow
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.rigLabel ?? "Rig")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                Spacer()
                Text(record.typeLabel.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(record.recordType == "reserve" ? colors.loft : colors.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(colors.loft.opacity(record.recordType == "reserve" ? 0.15 : 0.05))
                    .cornerRadius(4)
            }
            HStack(spacing: 12) {
                Label(record.packDate, systemImage: "calendar")
                if record.recordType == "reserve", let due = record.dueDate, !due.isEmpty {
                    Label("Due \(due)", systemImage: "clock")
                } else if let n = record.packJobCount {
                    Label("×\(n)", systemImage: "number")
                }
            }
            .font(.system(size: 11))
            .foregroundColor(colors.muted)
            if let by = record.byName, !by.isEmpty {
                Text("By \(by)")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
            if let svc = record.servicePerformed, !svc.isEmpty {
                Text(svc)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colors.loft)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LoftRecordAddView: View {
    @ObservedObject var vm: LoftRecordsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors

    @State private var selectedRigId = 0
    @State private var packDate = Date()
    @State private var servicePerformed = "I&R"
    @State private var byName = ""
    @State private var ownerName = ""
    @State private var ownerPhone = ""

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            Form {
                Section("Rig") {
                    Picker("Rig", selection: $selectedRigId) {
                        Text("Select rig").tag(0)
                        ForEach(vm.rigs) { rig in
                            Text(rig.label).tag(rig.id)
                        }
                    }
                }
                Section("Reserve repack") {
                    DatePicker("Pack date", selection: $packDate, displayedComponents: .date)
                    Picker("Service", selection: $servicePerformed) {
                        ForEach(vm.reserveServiceOptions, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    Picker("Rigger", selection: $byName) {
                        Text("Select rigger").tag("")
                        ForEach(vm.riggers, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Text("Due date is pack date + \(vm.reserveRepackDays) days (loft config).")
                        .font(.caption)
                        .foregroundColor(colors.muted)
                }
                Section("Owner (optional)") {
                    TextField("Owner name", text: $ownerName)
                    TextField("Owner phone", text: $ownerPhone)
                        .keyboardType(.phonePad)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Add Reserve Repack")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        let ok = await vm.addReserveRepack(
                            rigId: selectedRigId,
                            packDate: packDate,
                            servicePerformed: servicePerformed,
                            byName: byName,
                            ownerName: ownerName,
                            ownerPhone: ownerPhone
                        )
                        if ok { dismiss() }
                    }
                }
                .disabled(selectedRigId <= 0 || byName.isEmpty || servicePerformed.isEmpty || vm.isSaving)
            }
        }
        .task {
            if vm.rigs.isEmpty { await vm.loadRigsForPicker() }
            if byName.isEmpty, let first = vm.riggers.first { byName = first }
        }
    }
}
