import SwiftUI

struct AccountDetailView: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @EnvironmentObject private var store: ManifestStore
    @Environment(\.dismiss) private var dismiss

    let target: AccountTarget

    @State private var detail: AccountDetail?
    @State private var permissions: AccountPermissions?
    @State private var gear: [AccountGearItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var showIDScan = false
    @State private var showCharge = false
    @State private var showHistory = false
    @State private var showWaivers = false
    @State private var showStudentHub = false

    private var userID: Int? {
        switch target {
        case .user(let id): id
        case .tandem: detail?.user_id
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isLoading {
                        ProgressView("Loading account…")
                            .tint(NightOps.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let errorMessage, detail == nil {
                        Text(errorMessage)
                            .foregroundStyle(NightOps.danger)
                            .padding()
                    } else if let detail {
                        viewDetailsCard(detail)
                        gearCard
                    }
                }
                .padding(20)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
            .background(NightOps.surface.ignoresSafeArea())
            .navigationTitle("View Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showIDScan) {
                if let uid = userID {
                    IDScanView(userID: uid)
                }
            }
            .sheet(isPresented: $showCharge) {
                if let uid = userID {
                    ChargeJumperSheet(userID: uid) {
                        Task { await reload() }
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                if let uid = userID {
                    AccountHistorySheet(userID: uid)
                }
            }
            .sheet(isPresented: $showWaivers) {
                if let uid = userID {
                    AccountWaiversSheet(userID: uid)
                }
            }
            .sheet(isPresented: $showStudentHub) {
                if let uid = userID {
                    StudentHubSheet(userID: uid)
                }
            }
            .task { await reload() }
        }
    }

    private func viewDetailsCard(_ detail: AccountDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(NightOps.gradientBar)
                .frame(height: 6)
                .padding(.horizontal, -20)
                .padding(.top, -20)

            Text("View Details")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("\(detail.display_name ?? "Account") \(detail.user_id.map(String.init) ?? "")")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                quickLink("Student hub") { showStudentHub = true }
                Text("·").foregroundStyle(NightOps.textMuted)
                if permissions?.can_post_ledger == true, userID != nil {
                    quickLink("+Account") { showCharge = true }
                } else {
                    Text("+Account").foregroundStyle(NightOps.textMuted)
                }
                Text("·").foregroundStyle(NightOps.textMuted)
                quickLink("View Waivers") { showWaivers = true }
                Text("·").foregroundStyle(NightOps.textMuted)
                Text("+ Gear").foregroundStyle(.white.opacity(0.9))
            }
            .font(.subheadline.weight(.bold))

            HStack(spacing: 8) {
                if permissions?.can_check_in == true, let uid = userID {
                    Button("Check In") {
                        Task { await checkIn(userID: uid) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.white.opacity(0.22))
                } else {
                    badge("Check In")
                }
                badge("track")
                badge(detail.can_carry_balance == true ? "Carry balance" : "Pay up front")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Weight: \(detail.weight.map(String.init) ?? "—")")
                Text("phone: \(blank(detail.phone))")
                Text("email: \(blank(detail.email))")
                Text("Waiver: \(detail.waiver_valid == true ? "Signed ✓" : "Not signed")")
            }
            .font(.body)
            .foregroundStyle(Color.white.opacity(0.9))

            Text("FINANCIAL")
                .font(.caption.weight(.bold))
                .foregroundStyle(NightOps.textMuted)
                .padding(.top, 8)

            balanceRow("STARTING BALANCE", detail.starting_balance)
            balanceRow("TODAYS BALANCE", detail.todays_balance)
            balanceRow("TOTAL PAID", detail.total_paid)
            balanceRow("TOTAL PAYOUT", detail.total_payout)
            balanceRow("TOTAL BALANCE", detail.total_balance)

            if let uspa = detail.uspa_number, !uspa.isEmpty {
                Text("USPA \(uspa)\(detail.highest_uspa_license.map { " · \($0)" } ?? "")")
                    .font(.footnote)
                    .foregroundStyle(NightOps.textMuted)
            }

            HStack(spacing: 10) {
                if permissions?.can_check_in == true, userID != nil {
                    Button("Scan license") { showIDScan = true }
                        .buttonStyle(.borderedProminent)
                        .tint(NightOps.accent)
                }
                Button("View History") { showHistory = true }
                    .buttonStyle(.bordered)
                    .tint(.white)
                if permissions?.can_post_ledger == true, userID != nil {
                    Button("CHARGE/PAY JUMPER") { showCharge = true }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
            }
            .padding(.top, 8)

            if let actionMessage {
                Text(actionMessage)
                    .font(.footnote)
                    .foregroundStyle(actionMessage.contains("Checked") ? NightOps.success : NightOps.danger)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(NightOps.danger)
            }

            Button("CANCEL") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NightOps.textMuted)
                .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightOpsCard()
    }

    private var gearCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gear")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            if gear.isEmpty {
                Text("No personal rigs on file. Add a container and main canopy.")
                    .foregroundStyle(NightOps.textMuted)
            } else {
                ForEach(gear) { rig in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rig.rig_label ?? "Rig")
                                .font(.headline)
                                .foregroundStyle(.white)
                            if rig.loft_pack_locked == true {
                                Text("Loft pack")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(rig.summary)
                            .font(.footnote)
                            .foregroundStyle(NightOps.textMuted)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightOpsCard()
    }

    private func quickLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .foregroundStyle(.white)
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }

    private func balanceRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("$\(value ?? "0.00")")
                .fontWeight(.bold)
        }
        .foregroundStyle(.white)
    }

    private func blank(_ value: String?) -> String {
        let t = (value ?? "").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "—" : t
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response: AccountDetailResponse
            switch target {
            case .user(let id):
                response = try await session.apiClient.fetchAccountDetail(userID: id)
            case .tandem(let id):
                response = try await session.apiClient.fetchTandemStudentDetail(studentID: id)
            }
            if response.ok, let account = response.account {
                detail = account
                permissions = response.permissions
                gear = response.gear ?? []
            } else {
                errorMessage = response.error ?? "Could not load account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkIn(userID: Int) async {
        do {
            let response = try await session.apiClient.checkInUser(userID: userID, date: store.selectedDate)
            if response.ok {
                actionMessage = "Checked in successfully."
                await store.refreshCheckIns()
            } else {
                actionMessage = response.error ?? "Check-in failed."
            }
        } catch {
            actionMessage = error.localizedDescription
        }
    }
}

struct ChargeJumperSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.dismiss) private var dismiss
    let userID: Int
    var onSaved: () -> Void

    @State private var amount = "0.00"
    @State private var memo = ""
    @State private var paymentType = "credit"
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let types = [
        ("credit", "Credit"),
        ("cash", "Cash"),
        ("check", "Check"),
        ("card_key_in", "Card key in"),
        ("credit_manual", "Credit Manual"),
        ("cash_payout", "Cash Payout"),
        ("check_payout", "Check Payout"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Charge Jumper") {
                    TextField("Enter Charge Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("memo (optional)", text: $memo)
                    Picker("Payment Type", selection: $paymentType) {
                        ForEach(types, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Charge Jumper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("SUBMIT") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let response = try await session.apiClient.postAccountLedger(
                userID: userID,
                amount: amount,
                memo: memo,
                paymentType: paymentType
            )
            if response.ok {
                onSaved()
                dismiss()
            } else {
                errorMessage = response.error ?? "Could not record charge."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AccountHistorySheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.dismiss) private var dismiss
    let userID: Int
    @State private var items: [AccountHistoryItem] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if items.isEmpty {
                    Text("No history yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.created_date ?? "")
                                Spacer()
                                Text("$\(item.amount_display ?? "0.00")")
                                    .fontWeight(.bold)
                            }
                            Text((item.txn_type ?? "").capitalized)
                                .font(.caption)
                            if let note = item.note, !note.isEmpty {
                                Text(note).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task {
                do {
                    let response = try await session.apiClient.fetchAccountHistory(userID: userID)
                    if response.ok {
                        items = response.items ?? []
                    } else {
                        errorMessage = response.error
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct AccountWaiversSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.dismiss) private var dismiss
    let userID: Int
    @State private var items: [AccountWaiverItem] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if items.isEmpty {
                    Text("No waivers on file.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.waiver_type ?? "Waiver")
                                .font(.headline)
                            Text("\(item.source_label ?? "") · \(item.signed_at ?? "—")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Waivers")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task {
                do {
                    let response = try await session.apiClient.fetchAccountWaivers(userID: userID)
                    if response.ok {
                        items = response.items ?? []
                    } else {
                        errorMessage = response.error
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct StudentHubSheet: View {
    @EnvironmentObject private var session: ManifestSessionStore
    @Environment(\.dismiss) private var dismiss
    let userID: Int
    @State private var label = "Loading…"
    @State private var extra = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Student hub") {
                    Text(label)
                    if !extra.isEmpty {
                        Text(extra).foregroundStyle(.secondary)
                    }
                    Text("Full LMS student hub remains on the web. Next jump is shown here for desk ops.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Student hub")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task {
                do {
                    let data = try await session.apiClient.fetchNextLevel(userID: userID)
                    if data.ok {
                        label = data.label ?? data.module_title ?? "No next jump on file."
                        if data.needs_enrollment == true {
                            extra = "Needs LMS enrollment."
                        } else if let jt = data.jump_type, !jt.isEmpty {
                            extra = "Jump type: \(jt)"
                        }
                    } else {
                        label = data.error ?? "Not an LMS student."
                    }
                } catch {
                    label = error.localizedDescription
                }
            }
        }
    }
}
