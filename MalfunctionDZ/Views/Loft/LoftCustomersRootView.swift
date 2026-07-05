// HHIO — loft customers (loft role users), rigs, and pack history.
import SwiftUI
import MalfunctionDZCore

struct LoftCustomersRootView: View {
    @StateObject private var vm = LoftCustomersViewModel()
    @State private var showAdd = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                searchBar
                if vm.isLoading && vm.customers.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.loft)).scaleEffect(1.4)
                    Spacer()
                } else if vm.customers.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "person.2.fill",
                        title: "No Customers",
                        subtitle: "Add a loft customer to track rigs and pack history."
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(vm.customers) { customer in
                            NavigationLink(value: customer) {
                                LoftCustomerRow(customer: customer)
                            }
                            .listRowBackground(colors.card)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Customers")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: LoftCustomer.self) { customer in
            LoftCustomerDetailView(customer: customer, vm: vm)
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
                LoftCustomerAddView(vm: vm)
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.searchText) { _, _ in
            Task { await vm.load() }
        }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(colors.muted)
            TextField("Search name, email, phone…", text: $vm.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(colors.text)
        }
        .padding(12)
        .background(colors.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct LoftCustomerRow: View {
    let customer: LoftCustomer
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            MDZIconChip("person.fill", color: colors.loft, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.text)
                if let phone = customer.phone, !phone.isEmpty {
                    Text(phone).font(.system(size: 13)).foregroundColor(colors.muted)
                } else if let email = customer.email, !email.isEmpty {
                    Text(email).font(.system(size: 13)).foregroundColor(colors.muted)
                }
            }
            Spacer()
            if let count = customer.rigCount, count > 0 {
                Text("\(count) rig\(count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colors.loft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.loft.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LoftCustomerDetailView: View {
    let customer: LoftCustomer
    @ObservedObject var vm: LoftCustomersViewModel
    @State private var showAddRig = false
    @State private var showAddInvoice = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    contactCard
                    rigsSection
                    historySection
                    invoicesSection
                }
                .padding(16)
            }
        }
        .navigationTitle(customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: LoftCustomerRig.self) { rig in
            LoftCustomerRigDetailView(customer: customer, rig: rig, vm: vm)
        }
        .navigationDestination(for: LoftInvoice.self) { inv in
            LoftCustomerInvoiceDetailView(customer: customer, invoice: inv, vm: vm)
        }
        .toolbar {
            if vm.canEdit {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showAddInvoice = true } label: {
                        Image(systemName: "doc.badge.plus").foregroundColor(colors.loft)
                    }
                    Button { showAddRig = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(colors.loft)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddRig) {
            NavigationStack {
                LoftCustomerAddRigView(customer: customer, vm: vm)
            }
        }
        .sheet(isPresented: $showAddInvoice) {
            NavigationStack {
                LoftCustomerAddInvoiceView(customer: customer, vm: vm)
            }
        }
        .task { await vm.loadDetail(customerId: customer.id) }
        .refreshable { await vm.loadDetail(customerId: customer.id) }
        .overlay {
            if vm.detailLoading && vm.detailRigs.isEmpty {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.loft))
            }
        }
        .alert("Notice", isPresented: Binding(get: { vm.lastMessage != nil }, set: { if !$0 { vm.lastMessage = nil } })) {
            Button("OK", role: .cancel) { vm.lastMessage = nil }
        } message: { Text(vm.lastMessage ?? "") }
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONTACT").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            if let phone = vm.detailCustomer?.phone ?? customer.phone, !phone.isEmpty {
                Label(phone, systemImage: "phone.fill")
            }
            if let email = vm.detailCustomer?.email ?? customer.email, !email.isEmpty {
                Label(email, systemImage: "envelope.fill")
            }
            Text("@\(customer.username)")
                .font(.system(size: 13))
                .foregroundColor(colors.muted)
        }
        .font(.system(size: 14))
        .foregroundColor(colors.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var rigsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RIGS").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            if vm.detailRigs.isEmpty {
                Text("No rigs yet").font(.system(size: 14)).foregroundColor(colors.muted)
            } else {
                ForEach(vm.detailRigs) { rig in
                    NavigationLink(value: rig) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rig.label).font(.system(size: 15, weight: .semibold)).foregroundColor(colors.text)
                                if let mfr = rig.manufacturer, !mfr.isEmpty {
                                    Text([mfr, rig.model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                                        .font(.system(size: 12))
                                        .foregroundColor(colors.muted)
                                }
                            }
                            Spacer()
                            if rig.isActive == false {
                                Text("INACTIVE").font(.system(size: 10, weight: .bold)).foregroundColor(colors.danger)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colors.muted)
                        }
                        .padding(12)
                        .background(colors.card)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PACK HISTORY").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            if vm.detailRecords.isEmpty {
                Text("No pack records yet").font(.system(size: 14)).foregroundColor(colors.muted)
            } else {
                ForEach(vm.detailRecords) { rec in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rec.typeLabel).font(.system(size: 13, weight: .bold)).foregroundColor(colors.loft)
                            Spacer()
                            Text(rec.packDate).font(.system(size: 12)).foregroundColor(colors.muted)
                        }
                        if let label = rec.rigLabel, !label.isEmpty {
                            Text(label).font(.system(size: 13)).foregroundColor(colors.text)
                        }
                        if let by = rec.byName, !by.isEmpty {
                            Text("By \(by)").font(.system(size: 12)).foregroundColor(colors.muted)
                        }
                    }
                    .padding(12)
                    .background(colors.card)
                    .cornerRadius(10)
                }
            }
        }
    }

    private var invoicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVOICES").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            if vm.detailInvoices.isEmpty {
                Text("No invoices yet").font(.system(size: 14)).foregroundColor(colors.muted)
            } else {
                ForEach(vm.detailInvoices) { inv in
                    NavigationLink(value: inv) {
                        LoftCustomerInvoiceRow(invoice: inv)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct LoftCustomerInvoiceRow: View {
    let invoice: LoftInvoice
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(invoice.invoiceNumber).font(.system(size: 13, weight: .bold)).foregroundColor(colors.text)
                    Text(invoice.statusLabel.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(statusColor)
                }
                Text(invoice.amountDisplay).font(.system(size: 15, weight: .semibold)).foregroundColor(colors.loft)
                if let desc = invoice.description, !desc.isEmpty {
                    Text(desc).font(.system(size: 12)).foregroundColor(colors.muted).lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
        }
        .padding(12)
        .background(colors.card)
        .cornerRadius(10)
    }

    private var statusColor: Color {
        switch invoice.status {
        case "paid": return colors.green
        case "draft": return colors.muted
        default: return colors.amber
        }
    }
}

struct LoftCustomerInvoiceDetailView: View {
    let customer: LoftCustomer
    let invoice: LoftInvoice
    @ObservedObject var vm: LoftCustomersViewModel
    @Environment(\.mdzColors) private var colors

    @State private var detail: LoftInvoiceDetailResponse?
    @State private var showAddLine = false
    @State private var sending = false

    private var currentInvoice: LoftInvoice { detail?.invoice ?? invoice }
    private var lines: [LoftInvoiceLine] { detail?.lines ?? [] }
    private var canSend: Bool {
        vm.canEdit && (currentInvoice.sentAt ?? "").isEmpty && currentInvoice.status != "paid"
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard
                    linesSection
                    if let events = detail?.events, !events.isEmpty {
                        eventsSection(events)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(currentInvoice.invoiceNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.canEdit && (currentInvoice.sentAt ?? "").isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddLine = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(colors.loft)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if canSend {
                Button {
                    Task { await sendInvoice() }
                } label: {
                    Text(sending ? "Sending…" : "Send Invoice")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.loft)
                .disabled(sending || lines.isEmpty || currentInvoice.amountCents <= 0)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(colors.background.opacity(0.95))
            } else if vm.canEdit && currentInvoice.status == "open" && !(currentInvoice.sentAt ?? "").isEmpty {
                HStack(spacing: 10) {
                    Button {
                        Task { await vm.sendInvoiceReminder(customerId: customer.id, invoiceId: invoice.id) }
                    } label: {
                        Label("Send reminder", systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(colors.loft)
                    if currentInvoice.status == "open" {
                        Button {
                            Task { await vm.markInvoicePaid(customerId: customer.id, invoiceId: invoice.id) }
                        } label: {
                            Label("Mark paid", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(colors.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(colors.background.opacity(0.95))
            }
        }
        .sheet(isPresented: $showAddLine, onDismiss: { Task { await reload() } }) {
            NavigationStack {
                LoftCustomerAddInvoiceView(customer: customer, vm: vm, existingInvoiceId: invoice.id)
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Notice", isPresented: Binding(get: { vm.lastMessage != nil }, set: { if !$0 { vm.lastMessage = nil } })) {
            Button("OK", role: .cancel) { vm.lastMessage = nil }
        } message: { Text(vm.lastMessage ?? "") }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INVOICE").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            Text(currentInvoice.amountDisplay).font(.system(size: 28, weight: .bold)).foregroundColor(colors.loft)
            Text(currentInvoice.statusLabel).font(.system(size: 13, weight: .semibold)).foregroundColor(colors.text)
            if let due = currentInvoice.dueDate, !due.isEmpty {
                Text("Due \(due)").font(.system(size: 12)).foregroundColor(colors.amber)
            }
            if (currentInvoice.sentAt ?? "").isEmpty {
                Text("Review lines below, then tap Send Invoice when ready.")
                    .font(.system(size: 12)).foregroundColor(colors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LINE ITEMS").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            if lines.isEmpty {
                Text("No items yet — tap + to add pack jobs or services.").font(.system(size: 14)).foregroundColor(colors.muted)
            } else {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(line.lineTypeLabel).font(.system(size: 12, weight: .bold)).foregroundColor(colors.loft)
                            Spacer()
                            Text(line.amountDisplay).font(.system(size: 14, weight: .semibold)).foregroundColor(colors.text)
                        }
                        Text(line.description).font(.system(size: 13)).foregroundColor(colors.text)
                        if let rig = line.rigLabel, !rig.isEmpty {
                            Text(rig).font(.system(size: 11)).foregroundColor(colors.muted)
                        }
                    }
                    .padding(12)
                    .background(colors.card)
                    .cornerRadius(10)
                }
            }
        }
    }

    private func eventsSection(_ events: [LoftInvoiceEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HISTORY").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            ForEach(events) { ev in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ev.eventLabel).font(.system(size: 13, weight: .bold)).foregroundColor(colors.loft)
                        Spacer()
                        Text(ev.createdAt).font(.system(size: 11)).foregroundColor(colors.muted)
                    }
                    if let d = ev.detail, !d.isEmpty {
                        Text(d).font(.system(size: 12)).foregroundColor(colors.text)
                    }
                }
                .padding(12)
                .background(colors.card)
                .cornerRadius(10)
            }
        }
    }

    private func reload() async {
        detail = await vm.loadInvoiceDetail(invoiceId: invoice.id)
    }

    private func sendInvoice() async {
        sending = true
        defer { sending = false }
        if await vm.sendInvoice(customerId: customer.id, invoiceId: invoice.id) {
            await reload()
            await vm.loadDetail(customerId: customer.id)
        }
    }
}

struct LoftCustomerRigDetailView: View {
    let customer: LoftCustomer
    let rig: LoftCustomerRig
    @ObservedObject var vm: LoftCustomersViewModel
    @Environment(\.mdzColors) private var colors

    @State private var rigLabel = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var serialNumber = ""
    @State private var notes = ""
    @State private var canopyMain = ""
    @State private var canopyReserve = ""
    @State private var aad = ""
    @State private var isActive = true
    @State private var saving = false
    @State private var editing = false

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if editing && vm.canEdit {
                        editForm
                    } else {
                        viewCard
                    }
                    packHistorySection
                }
                .padding(16)
            }
        }
        .navigationTitle(rig.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editing ? "Done" : "Edit") {
                        if editing {
                            Task { await save() }
                        } else {
                            loadFields()
                            editing = true
                        }
                    }
                    .disabled(saving)
                }
            }
        }
        .task {
            loadFields()
            await vm.loadRigDetail(customerId: customer.id, rigId: rig.id)
        }
        .refreshable { await vm.loadRigDetail(customerId: customer.id, rigId: rig.id) }
        .onChange(of: vm.rigDetail?.id) { _, _ in
            if !editing { loadFields() }
        }
        .alert("Notice", isPresented: Binding(get: { vm.lastMessage != nil }, set: { if !$0 { vm.lastMessage = nil } })) {
            Button("OK", role: .cancel) { vm.lastMessage = nil }
        } message: { Text(vm.lastMessage ?? "") }
    }

    private var viewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RIG DETAILS").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            detailRow("Label", rigLabel)
            detailRow("Manufacturer", manufacturer)
            detailRow("Model", model)
            detailRow("Serial", serialNumber)
            detailRow("Main", canopyMain)
            detailRow("Reserve", canopyReserve)
            detailRow("AAD", aad)
            if !notes.isEmpty {
                Text(notes).font(.system(size: 13)).foregroundColor(colors.muted)
            }
            Text(isActive ? "Active" : "Inactive")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isActive ? colors.green : colors.danger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EDIT RIG").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            TextField("Rig label", text: $rigLabel)
            TextField("Manufacturer", text: $manufacturer)
            TextField("Model", text: $model)
            TextField("Serial number", text: $serialNumber)
            TextField("Main canopy", text: $canopyMain)
            TextField("Reserve canopy", text: $canopyReserve)
            TextField("AAD", text: $aad)
            TextField("Notes", text: $notes, axis: .vertical)
            Toggle("Active", isOn: $isActive)
        }
        .textFieldStyle(.roundedBorder)
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack {
                    Text(label).font(.system(size: 12)).foregroundColor(colors.muted)
                    Spacer()
                    Text(value).font(.system(size: 14, weight: .medium)).foregroundColor(colors.text)
                }
            }
        }
    }

    private var packHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PACK HISTORY").font(.system(size: 11, weight: .black)).foregroundColor(colors.muted).tracking(1)
            if vm.rigRecords.isEmpty {
                Text("No pack records for this rig").font(.system(size: 14)).foregroundColor(colors.muted)
            } else {
                ForEach(vm.rigRecords) { rec in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rec.typeLabel).font(.system(size: 13, weight: .bold)).foregroundColor(colors.loft)
                            Spacer()
                            Text(rec.packDate).font(.system(size: 12)).foregroundColor(colors.muted)
                        }
                        if let by = rec.byName, !by.isEmpty {
                            Text("By \(by)").font(.system(size: 12)).foregroundColor(colors.muted)
                        }
                    }
                    .padding(12)
                    .background(colors.card)
                    .cornerRadius(10)
                }
            }
        }
    }

    private func loadFields() {
        let r = vm.rigDetail ?? rig
        rigLabel = r.rigLabel ?? ""
        manufacturer = r.manufacturer ?? ""
        model = r.model ?? ""
        serialNumber = r.serialNumber ?? ""
        notes = r.notes ?? ""
        canopyMain = r.canopyMain ?? ""
        canopyReserve = r.canopyReserve ?? ""
        aad = r.aad ?? ""
        isActive = r.isActive ?? true
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let ok = await vm.updateRig(
            customerId: customer.id,
            rigId: rig.id,
            rigLabel: rigLabel,
            manufacturer: manufacturer,
            model: model,
            serialNumber: serialNumber,
            notes: notes,
            isActive: isActive,
            canopyMain: canopyMain,
            canopyReserve: canopyReserve,
            aad: aad
        )
        if ok { editing = false }
    }
}

struct LoftCustomerAddInvoiceView: View {
    let customer: LoftCustomer
    @ObservedObject var vm: LoftCustomersViewModel
    var existingInvoiceId: Int? = nil
    @EnvironmentObject private var hhioSettings: HHIOSettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors

    @State private var lineType = "pack_job"
    @State private var amountText = ""
    @State private var description = ""
    @State private var selectedRecordId = 0
    @State private var selectedRigId = 0
    @State private var serviceRecordType = "reserve"
    @State private var serviceDate = Date()
    @State private var servicePerformed = "I&R"
    @State private var byName = ""
    @State private var saving = false
    @State private var pendingLines: [PendingInvoiceLine] = []

    var body: some View {
        Form {
            if existingInvoiceId == nil && !pendingLines.isEmpty {
                Section("Items on this invoice") {
                    ForEach(pendingLines) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text(item.amountDisplay).font(.system(size: 14, weight: .bold))
                            }
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle).font(.system(size: 12)).foregroundColor(colors.muted)
                            }
                        }
                    }
                    .onDelete { pendingLines.remove(atOffsets: $0) }
                }
            }

            Section("Add line") {
                Picker("Type", selection: $lineType) {
                    Text("Pack job").tag("pack_job")
                    Text("New service").tag("service")
                    Text("Sale").tag("sale")
                }
            }
            Section("Amount") {
                TextField("Amount (e.g. 85.00)", text: $amountText)
                    .keyboardType(.decimalPad)
                if lineType == "pack_job", selectedRecordId > 0, let hint = packJobPriceHint {
                    Text(hint).font(.system(size: 12)).foregroundColor(colors.muted)
                }
            }
            if lineType == "pack_job" {
                Section("Pack record") {
                    if vm.detailRecords.isEmpty {
                        Text("No pack records for this customer").foregroundColor(colors.muted)
                    } else {
                        Picker("Record", selection: $selectedRecordId) {
                            Text("Select record").tag(0)
                            ForEach(vm.detailRecords) { rec in
                                Text("\(rec.typeLabel) — \(rec.rigLabel ?? "Rig") — \(rec.packDate)")
                                    .tag(rec.id)
                            }
                        }
                    }
                }
            } else if lineType == "service" {
                Section("New service") {
                    Picker("Rig", selection: $selectedRigId) {
                        Text("Select rig").tag(0)
                        ForEach(vm.detailRigs) { rig in
                            Text(rig.label).tag(rig.id)
                        }
                    }
                    Picker("Service type", selection: $serviceRecordType) {
                        Text("Reserve repack").tag("reserve")
                        Text("Pack job").tag("pack_job")
                        Text("Inspection").tag("inspection")
                    }
                    DatePicker("Date", selection: $serviceDate, displayedComponents: .date)
                    if serviceRecordType == "reserve" {
                        Picker("Service", selection: $servicePerformed) {
                            Text("I&R").tag("I&R")
                            Text("A&P").tag("A&P")
                        }
                    }
                    TextField("Performed by", text: $byName)
                    TextField("Description (optional)", text: $description)
                }
            } else {
                Section("Sale") {
                    TextField("Item / description", text: $description)
                }
            }

            if existingInvoiceId == nil {
                Section {
                    Button("Add line to invoice") { addPendingLine() }
                        .disabled(!canAddLine)
                }
            }
        }
        .navigationTitle(existingInvoiceId == nil ? "New Invoice" : "Add Line")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(existingInvoiceId == nil ? "Save draft" : "Add") {
                    Task { await save() }
                }
                .disabled(saving || !canSave)
            }
        }
        .task {
            if vm.detailRecords.isEmpty || vm.detailRigs.isEmpty {
                await vm.loadDetail(customerId: customer.id)
            }
            if hhioSettings.loftName == "HHIO Loft" && !hhioSettings.loading {
                await hhioSettings.load()
            }
        }
        .onChange(of: selectedRecordId) { _, newId in
            applySuggestedPrice(forRecordId: newId)
        }
        .onChange(of: lineType) { _, newType in
            if newType == "pack_job" { applySuggestedPrice(forRecordId: selectedRecordId) }
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

    private var canAddLine: Bool {
        switch lineType {
        case "pack_job": return selectedRecordId > 0
        case "service": return selectedRigId > 0
        case "sale": return !description.trimmingCharacters(in: .whitespaces).isEmpty
        default: return false
        }
    }

    private var canSave: Bool {
        if existingInvoiceId != nil {
            return canAddLine
        }
        return !pendingLines.isEmpty || canAddLine
    }

    private var packJobPriceHint: String? {
        guard let rec = vm.detailRecords.first(where: { $0.id == selectedRecordId }),
              rec.recordType == "pack_job" else { return nil }
        let (gearType, isTandem) = gearInfo(for: rec)
        guard let price = hhioSettings.prices.priceText(gearType: gearType, isTandem: isTandem) else {
            return "No preset price for this rig type — edit in Config tab or enter amount manually."
        }
        return "Preset: $\(price)"
    }

    private func gearInfo(for rec: LoftRecordRow) -> (String?, Bool) {
        let rig = rec.rigId.flatMap { rid in vm.detailRigs.first(where: { $0.id == rid }) }
        let gearType = rec.gearType ?? rig?.gearType
        let isTandem = rec.isTandem ?? rig?.isTandem ?? false
        return (gearType, isTandem)
    }

    private func applySuggestedPrice(forRecordId recordId: Int) {
        guard lineType == "pack_job", recordId > 0,
              let rec = vm.detailRecords.first(where: { $0.id == recordId }),
              rec.recordType == "pack_job" else { return }
        let (gearType, isTandem) = gearInfo(for: rec)
        if let price = hhioSettings.prices.priceText(gearType: gearType, isTandem: isTandem) {
            amountText = price
        }
    }

    private func linesToSave() -> [[String: Any]] {
        var lines = pendingLines.map(\.payload)
        if canAddLine, let line = buildLinePayload() {
            lines.append(line)
        }
        return lines
    }

    private func addPendingLine() {
        guard let payload = buildLinePayload() else { return }
        let title: String
        switch lineType {
        case "pack_job":
            let rec = vm.detailRecords.first(where: { $0.id == selectedRecordId })
            title = rec?.typeLabel ?? "Pack job"
        case "sale": title = "Sale"
        default: title = "Service"
        }
        pendingLines.append(PendingInvoiceLine(
            id: UUID(),
            title: title,
            subtitle: description,
            amountCents: amountCents,
            payload: payload
        ))
        amountText = ""
        description = ""
        selectedRecordId = 0
        selectedRigId = 0
    }

    private func buildLinePayload() -> [String: Any]? {
        var line: [String: Any] = [
            "line_type": lineType,
            "amount_cents": amountCents,
            "description": description,
        ]
        if lineType == "pack_job" {
            guard selectedRecordId > 0 else { return nil }
            line["loft_record_id"] = selectedRecordId
            if description.isEmpty, let rec = vm.detailRecords.first(where: { $0.id == selectedRecordId }) {
                line["description"] = "\(rec.typeLabel) — \(rec.rigLabel ?? "Rig") — \(rec.packDate)"
            }
        } else if lineType == "service" {
            guard selectedRigId > 0 else { return nil }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            var rec: [String: Any] = [
                "record_type": serviceRecordType,
                "rig_id": selectedRigId,
                "pack_date": df.string(from: serviceDate),
                "by_name": byName,
            ]
            if serviceRecordType == "reserve" { rec["service_performed"] = servicePerformed }
            line["record"] = rec
            if description.isEmpty { line["description"] = "Loft \(serviceRecordType.replacingOccurrences(of: "_", with: " "))" }
        } else if lineType == "sale" {
            guard !description.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        }
        return line
    }

    private func save() async {
        saving = true
        defer { saving = false }

        if let invoiceId = existingInvoiceId {
            guard let line = buildLinePayload() else { return }
            if await vm.addInvoiceLines(invoiceId: invoiceId, customerId: customer.id, lines: [line]) {
                dismiss()
            }
            return
        }

        let lines = linesToSave()
        guard !lines.isEmpty else { return }
        if await vm.createCustomerInvoice(customerId: customer.id, lines: lines) != nil {
            dismiss()
        }
    }
}

private struct PendingInvoiceLine: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let amountCents: Int
    let payload: [String: Any]

    var amountDisplay: String {
        String(format: "$%.2f", Double(amountCents) / 100.0)
    }
}

struct LoftCustomerAddView: View {
    @ObservedObject var vm: LoftCustomersViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors

    @State private var username = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var saving = false

    var body: some View {
        Form {
            Section("Account") {
                TextField("Username", text: $username).textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
            }
            Section("Contact") {
                TextField("First name", text: $firstName)
                TextField("Last name", text: $lastName)
                TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                TextField("Phone", text: $phone).keyboardType(.phonePad)
            }
        }
        .navigationTitle("Add Customer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || username.isEmpty || password.isEmpty)
            }
        }
        .alert("Error", isPresented: Binding(get: { vm.lastMessage != nil }, set: { if !$0 { vm.lastMessage = nil } })) {
            Button("OK", role: .cancel) { vm.lastMessage = nil }
        } message: { Text(vm.lastMessage ?? "") }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let ok = await vm.addCustomer(
            username: username,
            password: password,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone
        )
        if ok { dismiss() }
    }
}

struct LoftCustomerAddRigView: View {
    let customer: LoftCustomer
    @ObservedObject var vm: LoftCustomersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var rigLabel = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var saving = false

    var body: some View {
        Form {
            Section("Rig") {
                TextField("Rig label / name", text: $rigLabel)
                TextField("Manufacturer", text: $manufacturer)
                TextField("Model", text: $model)
            }
        }
        .navigationTitle("Add Rig")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || rigLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .alert("Error", isPresented: Binding(get: { vm.lastMessage != nil }, set: { if !$0 { vm.lastMessage = nil } })) {
            Button("OK", role: .cancel) { vm.lastMessage = nil }
        } message: { Text(vm.lastMessage ?? "") }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let ok = await vm.addRig(
            customerId: customer.id,
            rigLabel: rigLabel,
            manufacturer: manufacturer,
            model: model
        )
        if ok { dismiss() }
    }
}
