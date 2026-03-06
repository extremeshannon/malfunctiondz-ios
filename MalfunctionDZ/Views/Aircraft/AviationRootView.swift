// File: ASC/Views/Aircraft/AviationRootView.swift
// iPad: NavigationSplitView with aircraft list sidebar + detail pane.
//       iPhone: NavigationStack (unchanged behaviour).
import SwiftUI

// MARK: - Root Router
struct AviationRootView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        if auth.currentUser?.aviationViewMode == .adminFull {
            AircraftListView(isReadOnly: false)
        } else if auth.currentUser?.aviationViewMode == .opsReadOnly {
            AircraftListView(isReadOnly: true)
        } else {
            if hSizeClass == .regular {
                PilotAviationSplitView()
            } else {
                PilotAviationView()
            }
        }
    }
}

// MARK: - iPad Pilot Aviation: split view
struct PilotAviationSplitView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var vm = PilotAviationViewModel()
    @State private var selectedFlight: PilotFlight?

    var body: some View {
        NavigationSplitView {
            // ── Sidebar: flight list ──────────────────────────
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    sidebarHeader
                    if vm.isLoading && vm.recentFlights.isEmpty {
                        Spacer()
                        ProgressView().tint(.mdzBlue).scaleEffect(1.2)
                        Spacer()
                    } else {
                        List(selection: $selectedFlight) {
                            // Open flight at top
                            if let open = vm.openFlight {
                                Section("ACTIVE") {
                                    OpenFlightRow(flight: open)
                                        .tag(open)
                                        .listRowBackground(Color.mdzCard)
                                        .listRowSeparatorTint(Color.mdzBorder)
                                }
                            }

                            // Aircraft
                            if !vm.airworthyAircraft.isEmpty {
                                Section("AIRWORTHY AIRCRAFT") {
                                    ForEach(vm.airworthyAircraft) { ac in
                                        PilotAircraftRow(aircraft: ac)
                                            .listRowBackground(Color.mdzCard)
                                            .listRowSeparatorTint(Color.mdzBorder)
                                    }
                                }
                            }

                            // Recent flights
                            if !vm.recentFlights.isEmpty {
                                Section("RECENT FLIGHTS") {
                                    ForEach(vm.recentFlights) { flight in
                                        PilotFlightSidebarRow(flight: flight)
                                            .tag(flight)
                                            .listRowBackground(Color.mdzCard)
                                            .listRowSeparatorTint(Color.mdzBorder)
                                    }
                                }
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .background(Color.mdzBackground)
                        .refreshable { await vm.load(pilotId: auth.currentUser?.id ?? 0) }
                    }
                }
            }
            .navigationTitle("My Flights")
            .navigationBarTitleDisplayMode(.inline)

        } detail: {
            // ── Detail: today summary or pax entry ───────────
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                if let summary = vm.todaySummary, summary.flightCount > 0 {
                    ScrollView {
                        VStack(spacing: 20) {
                            TodayFlightSummaryCard(summary: summary)
                                .padding(.horizontal, 32)
                                .padding(.top, 32)

                            if let aircraft = vm.airworthyAircraft.first {
                                NavigationLink(destination: PaxView(aircraft: aircraft)) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Log New Load")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 320)
                                    .frame(height: 52)
                                    .background(Color.mdzRed)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 32)
                            }
                            Spacer()
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        EmptyStateView(
                            icon: "airplane",
                            title: "No Flights Today",
                            subtitle: "Select an aircraft from the sidebar to start logging."
                        )
                        if let aircraft = vm.airworthyAircraft.first {
                            NavigationLink(destination: PaxView(aircraft: aircraft)) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start New Flight")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: 320)
                                .frame(height: 52)
                                .background(Color.mdzRed)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
        .task {
            if let uid = auth.currentUser?.id {
                await vm.load(pilotId: uid)
            }
        }
        .accentColor(.mdzRed)
    }

    private var sidebarHeader: some View {
        HStack {
            Image(systemName: "airplane")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.mdzBlue)
            Text("PILOT OPERATIONS")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.mdzBlue)
                .tracking(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mdzNavyMid)
    }
}

// MARK: - Sidebar flight row (compact)
struct PilotFlightSidebarRow: View {
    let flight: PilotFlight
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(flight.status == "open" ? Color.mdzGreen : Color.mdzMuted)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(flight.tailNumber)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.mdzText)
                Text(flight.flightDate)
                    .font(.system(size: 11))
                    .foregroundColor(.mdzMuted)
            }
            Spacer()
            Text("\(flight.loadCount) loads")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mdzMuted)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sidebar open flight row
struct OpenFlightRow: View {
    let flight: PilotFlight
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.mdzGreen)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(flight.tailNumber)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.mdzGreen)
                Text("IN PROGRESS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.mdzGreen)
                    .tracking(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - iPhone Pilot Aviation View (unchanged)
struct PilotAviationView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var vm = PilotAviationViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    moduleHeader(icon: "airplane", label: "MY FLIGHTS", subtitle: "Pilot Operations")

                    if vm.isLoading && vm.recentFlights.isEmpty {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzBlue)).scaleEffect(1.4)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                if let open = vm.openFlight {
                                    NavigationLink(destination: pilotPaxDestination) {
                                        OpenFlightCard(flight: open)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                } else if let aircraft = vm.airworthyAircraft.first {
                                    NavigationLink(destination: PaxView(aircraft: aircraft)) {
                                        startFlightButton
                                    }
                                    .padding(.horizontal, 16)
                                } else {
                                    noAircraftWarning.padding(.horizontal, 16)
                                }

                                if !vm.airworthyAircraft.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        sectionLabel("AIRCRAFT")
                                        ForEach(vm.airworthyAircraft) { aircraft in
                                            NavigationLink(destination: PaxView(aircraft: aircraft)) {
                                                PilotAircraftRow(aircraft: aircraft)
                                                    .padding(.horizontal, 16)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                if let today = vm.todaySummary, today.flightCount > 0 {
                                    TodayFlightSummaryCard(summary: today).padding(.horizontal, 16)
                                }

                                if !vm.recentFlights.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        sectionLabel("RECENT FLIGHTS")
                                        ForEach(vm.recentFlights) { flight in
                                            PilotFlightHistoryRow(flight: flight).padding(.horizontal, 16)
                                        }
                                    }
                                }
                                Spacer(minLength: 40)
                            }
                            .padding(.top, 16)
                        }
                        .refreshable { await vm.load(pilotId: auth.currentUser?.id ?? 0) }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                if let uid = auth.currentUser?.id { await vm.load(pilotId: uid) }
            }
        }
    }

    @ViewBuilder
    private var pilotPaxDestination: some View {
        if let aircraft = vm.airworthyAircraft.first(where: {
            $0.tailNumber == vm.openFlight?.tailNumber
        }) ?? vm.airworthyAircraft.first {
            PaxView(aircraft: aircraft)
        } else {
            Text("Aircraft unavailable").foregroundColor(.mdzMuted)
        }
    }

    private var startFlightButton: some View {
        HStack {
            Image(systemName: "play.fill")
            Text("Start New Flight").font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(Color.mdzRed).cornerRadius(12)
    }

    private var noAircraftWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.mdzAmber)
            Text("No airworthy aircraft available")
                .font(.system(size: 14, weight: .medium)).foregroundColor(.mdzMuted)
        }
        .frame(maxWidth: .infinity).padding(16)
        .background(Color.mdzCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.mdzMuted)
            .tracking(2)
            .padding(.horizontal, 16)
    }
}

// MARK: - Open Flight Card
struct OpenFlightCard: View {
    let flight: PilotFlight
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.mdzGreen).frame(width: 8, height: 8)
                    Text("FLIGHT IN PROGRESS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.mdzGreen).tracking(2)
                }
                Spacer()
                Text(flight.tailNumber)
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.mdzText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundColor(.mdzMuted)
            }
            HStack(spacing: 24) {
                PilotStatCell(label: "LOADS", value: "\(flight.loadCount)")
                PilotStatCell(label: "PAX",   value: "\(flight.totalPax)")
                PilotStatCell(label: "DATE",  value: flight.flightDate)
                Spacer()
            }
        }
        .padding(16).background(Color.mdzCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzGreen.opacity(0.4), lineWidth: 1))
        .overlay(VStack { Rectangle().fill(Color.mdzGreen).frame(height: 3).cornerRadius(14); Spacer() })
    }
}

// MARK: - Pilot Aircraft Row
struct PilotAircraftRow: View {
    let aircraft: Aircraft
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.mdzBlue.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "airplane").foregroundColor(.mdzBlue).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(aircraft.tailNumber).font(.system(size: 15, weight: .bold)).foregroundColor(.mdzText)
                Text(aircraft.model).font(.system(size: 12)).foregroundColor(.mdzMuted)
            }
            Spacer()
            StatusPill(label: aircraft.status.capitalized, color: aircraft.statusColor)
            Image(systemName: "chevron.right").foregroundColor(.mdzMuted).font(.system(size: 12))
        }
        .padding(14).background(Color.mdzCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Today Summary Card (scales for iPad)
struct TodayFlightSummaryCard: View {
    let summary: TodaySummary
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S SUMMARY")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzMuted).tracking(2)
            HStack(spacing: 0) {
                PilotStatCell(label: "FLIGHTS", value: "\(summary.flightCount)").frame(maxWidth: .infinity)
                Divider().background(Color.mdzBorder)
                PilotStatCell(label: "LOADS",   value: "\(summary.totalLoads)").frame(maxWidth: .infinity)
                Divider().background(Color.mdzBorder)
                PilotStatCell(label: "PAX",     value: "\(summary.totalPax)").frame(maxWidth: .infinity)
                Divider().background(Color.mdzBorder)
                PilotStatCell(label: "HOBBS Δ", value: String(format: "%.1f", summary.hobbsDelta)).frame(maxWidth: .infinity)
            }
            .frame(height: isWide ? 72 : 56)
        }
        .padding(isWide ? 20 : 16).background(Color.mdzCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Flight History Row
struct PilotFlightHistoryRow: View {
    let flight: PilotFlight
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(flight.status == "open" ? Color.mdzGreen : Color.mdzMuted)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(flight.tailNumber).font(.system(size: 14, weight: .bold)).foregroundColor(.mdzText)
                Text(flight.flightDate).font(.system(size: 11)).foregroundColor(.mdzMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(flight.loadCount) loads · \(flight.totalPax) pax")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.mdzText)
                if flight.hobbsDelta > 0 {
                    Text(String(format: "Hobbs Δ %.1f", flight.hobbsDelta))
                        .font(.system(size: 11)).foregroundColor(.mdzMuted)
                }
            }
        }
        .padding(12).background(Color.mdzCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
            flight.status == "open" ? Color.mdzGreen.opacity(0.3) : Color.mdzBorder, lineWidth: 1
        ))
    }
}

// MARK: - Models
struct PilotFlight: Identifiable, Decodable, Hashable, Equatable {
    let id: Int; let tailNumber: String; let flightDate: String
    let loadCount: Int; let totalPax: Int
    let hobbsStart: StringDouble; let hobbsEnd: StringDouble?; let status: String
    var hobbsDelta: Double {
        guard let e = hobbsEnd?.value, let s = hobbsStart.value else { return 0 }
        return e - s
    }
    enum CodingKeys: String, CodingKey {
        case id, status
        case tailNumber = "tail_number"; case flightDate = "flight_date_only"
        case loadCount = "load_count";   case totalPax   = "total_pax"
        case hobbsStart = "hobbs_start"; case hobbsEnd   = "hobbs_end"
    }
    // Explicit Hashable/Equatable using stable id — avoids StringDouble conformance issue
    static func == (lhs: PilotFlight, rhs: PilotFlight) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TodaySummary { let flightCount, totalLoads, totalPax: Int; let hobbsDelta: Double }

// MARK: - ViewModel (unchanged)
@MainActor
class PilotAviationViewModel: ObservableObject {
    @Published var isLoading         = false
    @Published var airworthyAircraft: [Aircraft] = []
    @Published var openFlight:       PilotFlight?
    @Published var recentFlights:    [PilotFlight] = []
    @Published var todaySummary:     TodaySummary?

    func load(pilotId: Int) async {
        guard pilotId > 0 else { return }
        isLoading = true; defer { isLoading = false }
        await withTaskGroup(of: Void.self) {
            $0.addTask { await self.loadAircraft() }
            $0.addTask { await self.loadRecentFlights(pilotId: pilotId) }
            $0.addTask { await self.loadTodaySummary(pilotId: pilotId) }
        }
    }

    private func loadAircraft() async {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/aircraft/list.php") else { return }
        var req = URLRequest(url: url); req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                await AuthManager.shared.logout()
                return
            }
            struct ListResp: Decodable { let ok: Bool; let aircraft: [Aircraft]? }
            guard let resp = try? JSONDecoder().decode(ListResp.self, from: data), resp.ok, let all = resp.aircraft else { return }
            airworthyAircraft = all.filter { ["airworthy", "active"].contains($0.status.lowercased()) }
        } catch { /* network error */ }
    }

    private func loadRecentFlights(pilotId: Int) async {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/flights/my_flights.php?pilot_user_id=\(pilotId)&limit=10") else { return }
        var req = URLRequest(url: url); req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(MobileResponse<[PilotFlight]>.self, from: data),
              resp.ok, let flights = resp.data else { return }
        recentFlights = flights
        openFlight    = flights.first(where: { $0.status == "open" })
    }

    private func loadTodaySummary(pilotId: Int) async {
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/flights/today.php?pilot_user_id=\(pilotId)") else { return }
        var req = URLRequest(url: url); req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        struct TR: Decodable { let ok: Bool; let data: TD?
            struct TD: Decodable { let flight_count, total_loads, total_pax: Int; let hobbs_delta: StringDouble }
        }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let resp = try? JSONDecoder().decode(TR.self, from: data), resp.ok, let d = resp.data else { return }
        todaySummary = TodaySummary(flightCount: d.flight_count, totalLoads: d.total_loads,
                                     totalPax: d.total_pax, hobbsDelta: d.hobbs_delta.value ?? 0)
    }
}

// MARK: - Shared helper
private func moduleHeader(icon: String, label: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(.mdzBlue)
            Text(label).font(.system(size: 11, weight: .black)).foregroundColor(.mdzBlue).tracking(2)
        }
        Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundColor(.mdzMuted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 20).padding(.vertical, 16)
    .background(Color.mdzNavyMid)
}
