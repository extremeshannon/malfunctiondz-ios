// File: ASC/Views/Aircraft/AircraftListView.swift
// iPad: NavigationSplitView (list | detail). iPhone: NavigationStack.
import SwiftUI
import MalfunctionDZCore

struct AircraftListView: View {
    @StateObject private var vm = AircraftViewModel()
    @EnvironmentObject private var config: AppConfig
    @Environment(\.horizontalSizeClass) private var hSizeClass
    var isReadOnly: Bool = false

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        Group {
            if hSizeClass == .regular {
                AircraftListSplitView(vm: vm, dateString: dateString, isReadOnly: isReadOnly)
            } else {
                AircraftListStackView(vm: vm, dateString: dateString, isReadOnly: isReadOnly)
            }
        }
        .task { await vm.loadAll() }
        .refreshable { await vm.loadAll() }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}

// MARK: - iPad: Split (aircraft list | detail)
struct AircraftListSplitView: View {
    @ObservedObject var vm: AircraftViewModel
    let dateString: String
    var isReadOnly: Bool = false
    @EnvironmentObject private var config: AppConfig
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var selectedAircraft: Aircraft?
    @State private var showAddAircraft = false

    private var displayedAircraft: [Aircraft] { vm.aircraft }

    var body: some View {
        NavigationSplitView {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    if vm.isLoading && vm.aircraft.isEmpty {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.primary)).scaleEffect(1.4)
                        Spacer()
                    } else if displayedAircraft.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "airplane",
                            title: "No Aircraft",
                            subtitle: "No aircraft found in the fleet."
                        )
                        Spacer()
                    } else {
                        List(selection: $selectedAircraft) {
                            Section(header: sectionHeader) {
                                ForEach(displayedAircraft) { aircraft in
                                    AircraftListRow(aircraft: aircraft)
                                        .tag(aircraft)
                                        .listRowBackground(colors.card)
                                }
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .background(colors.background)
                    }
                }
            }
            .navigationTitle(config.dzName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !isReadOnly {
                        Button {
                            showAddAircraft = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .onAppear { if selectedAircraft == nil, let first = vm.aircraft.first { selectedAircraft = first } }
            .onChange(of: vm.aircraft.count) { _, _ in
                if selectedAircraft == nil, let first = vm.aircraft.first { selectedAircraft = first }
            }
            .sheet(isPresented: $showAddAircraft) {
                AddAircraftSheet(
                    onDismiss: { showAddAircraft = false },
                    onCreated: {
                        showAddAircraft = false
                        Task { await vm.loadAll() }
                    }
                )
            }
        } detail: {
            if let aircraft = selectedAircraft {
                AircraftDetailView(aircraft: aircraft, isReadOnly: isReadOnly)
            } else {
                ZStack {
                    colors.background.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "airplane")
                            .font(.system(size: 48))
                            .foregroundColor(colors.muted.opacity(0.5))
                        Text("Select an aircraft")
                            .font(.headline)
                            .foregroundColor(colors.muted)
                    }
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Image(systemName: "airplane")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.aviation)
            Text(config.moduleAviation.uppercased())
                .font(.system(size: 11, weight: .black))
                .foregroundColor(colors.aviation)
                .tracking(2)
            Text("·")
                .foregroundColor(colors.muted)
            Text(dateString)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(colors.muted)
        }
        .padding(.vertical, 6)
    }

    // Used on iPhone (AircraftListStackView); iPad split uses nav bar + section header for even headers
    private var aircraftHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(config.dzName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(colors.text)
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.aviation)
                Text(config.moduleAviation.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.aviation)
                    .tracking(2)
            }
            Text(dateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.navyMid)
    }
}

struct AircraftListRow: View {
    let aircraft: Aircraft
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.tailNumber)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(colors.text)
                Text(aircraft.model)
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            Spacer()
            StatusPill(label: aircraft.status.uppercased(), color: aircraft.statusColor)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - iPhone: Stack (original behavior)
struct AircraftListStackView: View {
    @ObservedObject var vm: AircraftViewModel
    let dateString: String
    var isReadOnly: Bool = false
    @EnvironmentObject private var config: AppConfig
    @Environment(\.mdzColors) private var colors
    @State private var showAddAircraft = false

    private var displayedAircraft: [Aircraft] { vm.aircraft }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(config.dzName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(colors.text)
                                HStack {
                                    Image(systemName: "airplane")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(colors.aviation)
                                    Text(config.moduleAviation.uppercased())
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(colors.aviation)
                                        .tracking(2)
                                }
                                Text(dateString)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(colors.muted)
                            }
                            Spacer()
                            if !isReadOnly {
                                Button {
                                    showAddAircraft = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(colors.aviation)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colors.navyMid)

                    if vm.isLoading && vm.aircraft.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: colors.primary))
                            .scaleEffect(1.4)
                        Spacer()
                    } else if displayedAircraft.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "airplane",
                            title: "No Aircraft",
                            subtitle: "No aircraft found in the fleet."
                        )
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(displayedAircraft) { aircraft in
                                    NavigationLink(destination: AircraftDetailView(aircraft: aircraft, isReadOnly: isReadOnly)) {
                                        AircraftCard(aircraft: aircraft)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddAircraft) {
                AddAircraftSheet(
                    onDismiss: { showAddAircraft = false },
                    onCreated: {
                        showAddAircraft = false
                        Task { await vm.loadAll() }
                    }
                )
            }
        }
    }
}

// MARK: - Aircraft Card
struct AircraftCard: View {
    let aircraft: Aircraft
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top row — tail + status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(aircraft.tailNumber)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(colors.text)
                    Text(aircraft.model)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colors.muted)
                }
                Spacer()
                StatusPill(label: aircraft.status.uppercased(), color: aircraft.statusColor)
            }

            Divider().background(colors.border)

            // Stats row
            HStack(spacing: 0) {
                if let next = aircraft.next100hrDue {
                    StatCol(label: "ENGINE TBO", value: next, color: tboColor)
                }
                if let annual = aircraft.annualDue {
                    Spacer()
                    StatCol(label: "ANNUAL DUE", value: annual, color: colors.muted)
                }
                if aircraft.openSquawks > 0 {
                    Spacer()
                    StatCol(label: "SQUAWKS",
                            value: "\(aircraft.openSquawks) open",
                            color: colors.danger)
                }
            }

            // Alert badges (squawks already in stats row above — no duplicate)
            if aircraft.overdue > 0 || aircraft.dueSoon > 0 {
                HStack(spacing: 6) {
                    if aircraft.overdue > 0 {
                        AlertBadge(label: "\(aircraft.overdue) OVERDUE", color: colors.danger)
                    }
                    if aircraft.dueSoon > 0 {
                        AlertBadge(label: "\(aircraft.dueSoon) DUE SOON", color: colors.amber)
                    }
                }
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(aircraft.hasAlerts ? colors.accent.opacity(0.4) : colors.border,
                              lineWidth: 1)
        )
        .overlay(
            VStack {
                Rectangle()
                    .fill(aircraft.statusColor)
                    .frame(height: 3)
                    .cornerRadius(14)
                Spacer()
            }
        )
    }

    private var tboColor: Color {
        guard let next = aircraft.next100hrDue else { return colors.muted }
        if next.contains("Overdue") { return colors.danger }
        return colors.green
    }
}

struct StatCol: View {
    let label: String
    let value: String
    var color: Color?
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color ?? colors.text)
        }
    }
}

struct AlertBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .black))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Add Aircraft (POST /api/aircraft)
struct AddAircraftSheet: View {
    let onDismiss: () -> Void
    let onCreated: () -> Void

    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    @State private var tailNumber = ""
    @State private var make = ""
    @State private var model = ""
    @State private var year = ""
    @State private var serialNumber = ""
    @State private var engineTT = ""
    @State private var engineTSMOH = ""
    @State private var propTT = ""
    @State private var propTSOH = ""
    @State private var currentHobbs = ""
    @State private var currentTach = ""
    @State private var isMultiEngine = false
    @State private var status = "active"
    @State private var saving = false
    @State private var error: String?

    private let statusOptions = [("active", "Active"), ("inactive", "Inactive"), ("maintenance", "Maintenance")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionFields
                    Toggle(isOn: $isMultiEngine) {
                        Text("Multi-engine")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(colors.text)
                    }
                    .tint(colors.accent)
                    Text("Multi-engine aircraft use Left Engine and Right Engine logbooks.")
                        .font(.caption)
                        .foregroundColor(colors.muted)
                }
                .padding(20)
            }
            .background(colors.background)
            .navigationTitle("Add Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss).foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundColor(canSubmit ? colors.amber : colors.muted)
                        .disabled(!canSubmit || saving)
                }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private var canSubmit: Bool {
        !tailNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var sectionFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Tail number", $tailNumber)
                .textInputAutocapitalization(.characters)
            HStack(spacing: 12) {
                field("Make", $make)
                field("Model", $model)
            }
            HStack(spacing: 12) {
                field("Year", $year)
                    .keyboardType(.numberPad)
                field("Serial", $serialNumber)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("STATUS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                Picker("", selection: $status) {
                    ForEach(statusOptions, id: \.0) { opt in
                        Text(opt.1).tag(opt.0)
                    }
                }
                .pickerStyle(.segmented)
            }
            Text("Times (optional)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
                .padding(.top, 4)
            field("Engine TT (TTSN)", $engineTT).keyboardType(.decimalPad)
            field("Engine TSMOH", $engineTSMOH).keyboardType(.decimalPad)
            field("Prop TT", $propTT).keyboardType(.decimalPad)
            field("Prop TSPOH / TSO", $propTSOH).keyboardType(.decimalPad)
            field("Current Hobbs", $currentHobbs).keyboardType(.decimalPad)
            field("Current Tach", $currentTach).keyboardType(.decimalPad)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func field(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
            TextField("", text: binding)
                .font(.system(size: 16))
                .foregroundColor(colors.text)
                .padding(12)
                .background(colors.background)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        }
    }

    private func save() async {
        error = nil
        saving = true
        defer { saving = false }

        guard let token = KeychainHelper.readToken() else {
            error = "Not signed in"
            return
        }

        var payload: [String: Any] = [
            "tail_number": tailNumber.trimmingCharacters(in: .whitespaces),
            "make": make.trimmingCharacters(in: .whitespaces),
            "model": model.trimmingCharacters(in: .whitespaces),
            "serial_number": serialNumber.trimmingCharacters(in: .whitespaces),
            "status": status,
            "is_multi_engine": isMultiEngine,
            "is_jumpable": true,
        ]
        if let y = Int(year.trimmingCharacters(in: .whitespaces)), y > 1900, y < 2100 {
            payload["year"] = y
        }
        if let v = Double(engineTT.trimmingCharacters(in: .whitespaces)) { payload["engine_tt"] = v }
        if let v = Double(engineTSMOH.trimmingCharacters(in: .whitespaces)) { payload["engine_tsmoh"] = v }
        if let v = Double(propTT.trimmingCharacters(in: .whitespaces)) { payload["prop_tt"] = v }
        if let v = Double(propTSOH.trimmingCharacters(in: .whitespaces)) { payload["prop_tso"] = v }
        if let v = Double(currentHobbs.trimmingCharacters(in: .whitespaces)) { payload["current_hobbs"] = v }
        if let v = Double(currentTach.trimmingCharacters(in: .whitespaces)) { payload["current_tach"] = v }

        let base = kServerURL.hasSuffix("/") ? String(kServerURL.dropLast()) : kServerURL
        // Try extensionless first (often routed to FastAPI), then list.php (same file as working fleet GET).
        let paths = [
            "/api/aircraft",
            "/api/aircraft/list.php",
            "/api/aircraft/list",
            "/api/aircraft/create.php",
            "/api/aircraft/create",
            "/api/aircraft.php",
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            error = "Could not build request"
            return
        }

        struct R: Decodable { let ok: Bool; let error: String? }

        do {
            var lastStatus = 0
            var lastBody = ""
            for path in paths {
                guard let url = URL(string: base + path) else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.httpBody = bodyData
                let (data, response) = try await URLSession.shared.data(for: req)
                lastBody = String(data: data, encoding: .utf8) ?? ""
                guard let http = response as? HTTPURLResponse else { continue }
                lastStatus = http.statusCode
                if http.statusCode == 401 {
                    AuthManager.shared.logout()
                    error = "Session expired"
                    return
                }
                if http.statusCode == 405 || http.statusCode == 404 {
                    continue
                }
                if let r = try? JSONDecoder().decode(R.self, from: data) {
                    if r.ok {
                        onCreated()
                        return
                    }
                    error = r.error ?? "Could not create aircraft"
                    return
                }
                if http.statusCode == 403 || http.statusCode == 422 || http.statusCode == 409 {
                    error = lastBody.isEmpty ? "Request failed (HTTP \(http.statusCode))" : lastBody
                    return
                }
                error = lastBody.isEmpty ? "Unexpected response (HTTP \(http.statusCode))" : lastBody
                return
            }
            error = (lastStatus == 404 || lastStatus == 405)
                ? "Aircraft create API not found (HTTP \(lastStatus)). Deploy FastAPI with POST /api/aircraft/list.php or route /api/* to uvicorn."
                : (lastBody.isEmpty ? "Could not reach aircraft API" : lastBody)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
