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
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    contactCard
                    rigsSection
                    historySection
                }
                .padding(16)
            }
        }
        .navigationTitle(customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
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
        .task { await vm.loadDetail(customerId: customer.id) }
        .refreshable { await vm.loadDetail(customerId: customer.id) }
        .overlay {
            if vm.detailLoading && vm.detailRigs.isEmpty {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.loft))
            }
        }
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
                    }
                    .padding(12)
                    .background(colors.card)
                    .cornerRadius(10)
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
