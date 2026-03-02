// File: ASC/Views/Aircraft/AircraftListView.swift
import SwiftUI

struct AircraftListView: View {
    @StateObject private var vm = AircraftViewModel()
    @EnvironmentObject private var config: AppConfig

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── Header ──────────────────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "airplane")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.mdzBlue)
                            Text(config.moduleAviation.uppercased())
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.mdzBlue)
                                .tracking(2)
                        }
                        Text(dateString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.mdzMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.mdzNavyMid)

                    if vm.isLoading && vm.aircraft.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .mdzBlue))
                            .scaleEffect(1.4)
                        Spacer()
                    } else if vm.aircraft.isEmpty {
                        Spacer()
                        EmptyStateView(icon: "airplane",
                                       title: "No Aircraft",
                                       subtitle: "No aircraft found in the fleet.")
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(vm.aircraft) { aircraft in
                                    NavigationLink(destination: AircraftDetailView(aircraft: aircraft)) {
                                        AircraftCard(aircraft: aircraft)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable { await vm.loadAll() }
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await vm.loadAll() }
            .alert("Error", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK", role: .cancel) { vm.error = nil }
            } message: { Text(vm.error ?? "") }
        }
    }
}

// MARK: - Aircraft Card
struct AircraftCard: View {
    let aircraft: Aircraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top row — tail + status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(aircraft.tailNumber)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.mdzText)
                    Text(aircraft.model)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.mdzMuted)
                }
                Spacer()
                StatusPill(label: aircraft.status.uppercased(), color: aircraft.statusColor)
            }

            Divider().background(Color.mdzBorder)

            // Stats row
            HStack(spacing: 0) {
                if let next = aircraft.next100hrDue {
                    StatCol(label: "ENGINE TBO", value: next, color: tboColor)
                }
                if let annual = aircraft.annualDue {
                    Spacer()
                    StatCol(label: "ANNUAL DUE", value: annual, color: .mdzMuted)
                }
                if aircraft.openSquawks > 0 {
                    Spacer()
                    StatCol(label: "SQUAWKS",
                            value: "\(aircraft.openSquawks) open",
                            color: .mdzDanger)
                }
            }

            // Alert badges
            if aircraft.hasAlerts {
                HStack(spacing: 6) {
                    if aircraft.overdue > 0 {
                        AlertBadge(label: "\(aircraft.overdue) OVERDUE", color: .mdzDanger)
                    }
                    if aircraft.dueSoon > 0 {
                        AlertBadge(label: "\(aircraft.dueSoon) DUE SOON", color: .mdzAmber)
                    }
                    if aircraft.openSquawks > 0 {
                        AlertBadge(label: "\(aircraft.openSquawks) SQUAWKS", color: .mdzAmber)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(aircraft.hasAlerts ? Color.mdzRed.opacity(0.4) : Color.mdzBorder,
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
        guard let next = aircraft.next100hrDue else { return .mdzMuted }
        if next.contains("Overdue") { return .mdzDanger }
        return .mdzGreen
    }
}

struct StatCol: View {
    let label: String
    let value: String
    var color: Color = .mdzText

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(1)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
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
