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
                        subtitle: "Add a reserve repack, pack job, or inspection to start the loft ledger."
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(vm.records) { rec in
                            NavigationLink(value: rec) {
                                LoftRecordRowView(record: rec)
                            }
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
        .navigationDestination(for: LoftRecordRow.self) { rec in
            LoftRecordDetailView(record: rec, vm: vm)
        }
        .toolbar {
            if vm.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(colors.loft)
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
            Text("LOFT STATS")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            if let s = vm.stats {
                HStack(spacing: 0) {
                    statCell(value: s.reserveTotal ?? 0, label: "RESERVE", color: colors.loft)
                    Divider().frame(height: 36).background(colors.border)
                    statCell(value: s.packJobTotal ?? 0, label: "PACK", color: colors.text)
                    Divider().frame(height: 36).background(colors.border)
                    statCell(value: s.reserveOverdue ?? 0, label: "OVERDUE", color: colors.danger)
                }
                .padding(.vertical, 10)
                .background(colors.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
            }
            Text("Tap a record for invoices, payment status, and reminder history.")
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

struct LoftRecordDetailView: View {
    let record: LoftRecordRow
    @ObservedObject var vm: LoftRecordsViewModel
    @State private var showCreateInvoice = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    recordCard
                    invoicesSection
                    if !vm.detailEvents.isEmpty {
                        historySection
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(record.rigLabel ?? "Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateInvoice = true } label: {
                        Image(systemName: "doc.badge.plus").foregroundColor(colors.loft)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateInvoice) {
            NavigationStack {
                LoftInvoiceCreateView(recordId: record.id, vm: vm)
            }
        }
        .task { await vm.loadRecordDetail(recordId: record.id) }
        .refreshable { await vm.loadRecordDetail(recordId: record.id) }
        .overlay {
            if vm.detailLoading && vm.detailInvoices.isEmpty {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.loft))
            }
        }
        .alert("Notice", isPresented: Binding(get: { vm.lastMessage != nil }, set: { if !$0 { vm.lastMessage = nil } })) {
            Button("OK", role: .cancel) { vm.lastMessage = nil }
        } message: { Text(vm.lastMessage ?? "") }
    }

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECORD").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            Text(record.typeLabel).font(.system(size: 16, weight: .bold)).foregroundColor(colors.loft)
            Label(record.packDate, systemImage: "calendar")
            if record.recordType == "reserve", let due = record.dueDate, !due.isEmpty {
                Label("Due \(due)", systemImage: "clock")
            }
            if let by = record.byName, !by.isEmpty {
                Label("By \(by)", systemImage: "person.fill")
            }
            if let owner = record.ownerName, !owner.isEmpty {
                Label(owner, systemImage: "person.crop.circle")
            }
        }
        .font(.system(size: 14))
        .foregroundColor(colors.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var invoicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVOICES").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            if vm.detailInvoices.isEmpty {
                Text("No invoices yet").font(.system(size: 14)).foregroundColor(colors.muted)
            } else {
                ForEach(vm.detailInvoices) { inv in
                    LoftInvoiceCard(invoice: inv, recordId: record.id, vm: vm)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVOICE HISTORY").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            ForEach(vm.detailEvents) { ev in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ev.eventLabel).font(.system(size: 13, weight: .bold)).foregroundColor(colors.loft)
                        Spacer()
                        Text(ev.createdAt).font(.system(size: 11)).foregroundColor(colors.muted)
                    }
                    if let d = ev.detail, !d.isEmpty {
                        Text(d).font(.system(size: 12)).foregroundColor(colors.text)
                    }
                    if let by = ev.byName, !by.isEmpty {
                        Text("By \(by)").font(.system(size: 11)).foregroundColor(colors.muted)
                    }
                }
                .padding(12)
                .background(colors.card)
                .cornerRadius(10)
            }
        }
    }
}

struct LoftInvoiceCard: View {
    let invoice: LoftInvoice
    let recordId: Int
    @ObservedObject var vm: LoftRecordsViewModel
    @Environment(\.mdzColors) private var colors

    private var statusColor: Color {
        switch invoice.status {
        case "paid": return colors.green
        case "void": return colors.muted
        default: return colors.amber
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(invoice.invoiceNumber)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                Spacer()
                Text(invoice.statusLabel.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(4)
            }
            Text(invoice.amountDisplay)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colors.loft)
            if let desc = invoice.description, !desc.isEmpty {
                Text(desc).font(.system(size: 13)).foregroundColor(colors.muted)
            }
            if let due = invoice.dueDate, !due.isEmpty, invoice.status == "open" {
                Text("Due \(due)").font(.system(size: 12)).foregroundColor(colors.amber)
            }
            if invoice.status == "open", vm.canEdit {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            let ok = await vm.markInvoicePaid(invoiceId: invoice.id, recordId: recordId)
                            if ok { await vm.loadInvoiceHistory(invoiceId: invoice.id) }
                        }
                    } label: {
                        Label("Mark paid", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.green)

                    Button {
                        Task {
                            let ok = await vm.sendInvoiceReminder(invoiceId: invoice.id, recordId: recordId)
                            if ok { await vm.loadInvoiceHistory(invoiceId: invoice.id) }
                        }
                    } label: {
                        Label("Email", systemImage: "envelope.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(colors.loft)
                }
            }
            if let email = invoice.customerEmail, !email.isEmpty {
                Text(email).font(.system(size: 11)).foregroundColor(colors.muted)
            }
        }
        .padding(12)
        .background(colors.card)
        .cornerRadius(10)
        .onTapGesture {
            Task { await vm.loadInvoiceHistory(invoiceId: invoice.id) }
        }
    }
}

struct LoftInvoiceCreateView: View {
    let recordId: Int?
    @ObservedObject var vm: LoftRecordsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var description = ""
    @State private var sendEmail = true
    @State private var saving = false

    var body: some View {
        Form {
            Section("Amount") {
                TextField("Amount (e.g. 85.00)", text: $amountText)
                    .keyboardType(.decimalPad)
            }
            Section("Details") {
                TextField("Description (optional)", text: $description)
                Toggle("Email customer", isOn: $sendEmail)
            }
        }
        .navigationTitle("Create Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || amountCents <= 0)
            }
        }
        .alert("Error", isPresented: Binding(get: { vm.lastMessage != nil }, set: { if !$0 { vm.lastMessage = nil } })) {
            Button("OK", role: .cancel) { vm.lastMessage = nil }
        } message: { Text(vm.lastMessage ?? "") }
    }

    private var amountCents: Int {
        let cleaned = amountText.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard let val = Double(cleaned) else { return 0 }
        return Int((val * 100).rounded())
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let ok = await vm.createInvoice(
            recordId: recordId,
            amountCents: amountCents,
            description: description,
            sendEmail: sendEmail
        )
        if ok { dismiss() }
    }
}

struct LoftRecordAddView: View {
    @ObservedObject var vm: LoftRecordsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors

    @State private var recordType = "reserve"
    @State private var selectedRigId = 0
    @State private var packDate = Date()
    @State private var servicePerformed = "I&R"
    @State private var byName = ""
    @State private var ownerName = ""
    @State private var ownerPhone = ""
    @State private var packJobCount = 1
    @State private var createInvoice = false
    @State private var invoiceAmount = ""

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            Form {
                Section("Type") {
                    Picker("Record type", selection: $recordType) {
                        Text("Reserve repack").tag("reserve")
                        Text("Pack job").tag("pack_job")
                        Text("Inspection").tag("inspection")
                    }
                }
                Section("Rig") {
                    Picker("Rig", selection: $selectedRigId) {
                        Text("Select rig").tag(0)
                        ForEach(vm.rigs) { rig in
                            Text(rig.label).tag(rig.id)
                        }
                    }
                }
                Section("Details") {
                    DatePicker("Date", selection: $packDate, displayedComponents: .date)
                    if recordType == "reserve" {
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
                        Text("Due date is pack date + \(vm.reserveRepackDays) days.")
                            .font(.caption)
                            .foregroundColor(colors.muted)
                    } else if recordType == "pack_job" {
                        Stepper("Pack count: \(packJobCount)", value: $packJobCount, in: 1...25)
                        TextField("Packed by", text: $byName)
                    } else {
                        Picker("Result", selection: $servicePerformed) {
                            Text("PASS").tag("PASS")
                            Text("FAIL").tag("FAIL")
                        }
                        TextField("Inspector", text: $byName)
                    }
                }
                Section("Owner (optional)") {
                    TextField("Owner name", text: $ownerName)
                    TextField("Owner phone", text: $ownerPhone)
                        .keyboardType(.phonePad)
                }
                Section("Invoice (optional)") {
                    Toggle("Create invoice", isOn: $createInvoice)
                    if createInvoice {
                        TextField("Amount (e.g. 85.00)", text: $invoiceAmount)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Add Pack Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!canSave || vm.isSaving)
            }
        }
        .task {
            if vm.rigs.isEmpty { await vm.loadRigsForPicker() }
            if byName.isEmpty, let first = vm.riggers.first { byName = first }
        }
    }

    private var canSave: Bool {
        guard selectedRigId > 0 else { return false }
        if recordType == "reserve" {
            return !byName.isEmpty && !servicePerformed.isEmpty
        }
        return true
    }

    private var invoiceCents: Int {
        let cleaned = invoiceAmount.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard let val = Double(cleaned) else { return 0 }
        return Int((val * 100).rounded())
    }

    private func save() async {
        let ok = await vm.addRecord(
            recordType: recordType,
            rigId: selectedRigId,
            packDate: packDate,
            servicePerformed: servicePerformed,
            byName: byName,
            ownerName: ownerName,
            ownerPhone: ownerPhone,
            packJobCount: packJobCount,
            createInvoice: createInvoice,
            amountCents: invoiceCents,
            sendInvoiceEmail: createInvoice
        )
        if ok { dismiss() }
    }
}
