// File: ASC/Views/Aircraft/AircraftListView.swift
// iPad: NavigationSplitView (list | detail). iPhone: NavigationStack.
import SwiftUI

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
                    aircraftHeader
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
                            ForEach(displayedAircraft) { aircraft in
                                AircraftListRow(aircraft: aircraft)
                                    .tag(aircraft)
                                    .listRowBackground(colors.card)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .background(colors.background)
                    }
                }
            }
            .navigationTitle(config.moduleAviation)
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
                AddAircraftPlaceholderSheet(onDismiss: { showAddAircraft = false })
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
                AddAircraftPlaceholderSheet(onDismiss: { showAddAircraft = false })
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

// MARK: - Add Aircraft (placeholder until API exists)
struct AddAircraftPlaceholderSheet: View {
    let onDismiss: () -> Void
    @Environment(\.mdzColors) private var colors
    @State private var isMultiEngine = false

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 56))
                        .foregroundColor(colors.muted)
                    Text("Add Aircraft")
                        .font(.headline)
                    Toggle(isOn: $isMultiEngine) {
                        Text("Multi-engine")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .tint(colors.accent)
                    .padding(.horizontal, 24)
                    Text("When the add-aircraft API is ready, this form will include tail number, model, TTSN, SMOH, prop time, and multi-engine. Multi-engine aircraft use Left Engine and Right Engine logbooks.")
                        .font(.subheadline)
                        .foregroundColor(colors.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Add Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}
