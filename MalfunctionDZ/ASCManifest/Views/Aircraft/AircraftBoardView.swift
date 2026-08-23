import SwiftUI

struct AircraftBoardView: View {
    @EnvironmentObject private var store: ManifestStore

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let error = store.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(NightOps.danger)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NightOps.surface.ignoresSafeArea())
        .navigationTitle("Aircraft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task {
                        await store.loadAircraft()
                        await store.refresh(silent: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .refreshable {
            await store.loadAircraft()
            await store.refresh()
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(NightOps.gradientBar)
                .frame(height: 6)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jump planes")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(store.jumpPlanes.count) active · \(store.selectedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(NightOps.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NightOps.navyLight)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.jumpPlanes.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "airplane.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(NightOps.textMuted)
                Text("No jump planes")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Mark an aircraft as Jump plane in Aircraft admin, then refresh.")
                    .font(.footnote)
                    .foregroundStyle(NightOps.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.jumpPlanes) { plane in
                        AircraftCardView(
                            aircraft: plane,
                            summary: store.daySummary(forAircraftID: plane.id),
                            loads: store.loads(forAircraftID: plane.id)
                        )
                    }
                }
                .padding(16)
            }
        }
    }
}

struct AircraftCardView: View {
    let aircraft: ManifestAircraft
    let summary: ManifestAircraftDaySummary
    let loads: [ManifestLoad]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(NightOps.gradientBar)
                .frame(height: 6)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text((aircraft.tail_number ?? "—").uppercased())
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.white)
                        if !aircraft.typeLabel.isEmpty {
                            Text(aircraft.typeLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NightOps.textMuted)
                        }
                    }
                    Spacer()
                    AircraftStatusPill(status: aircraft.statusLabel)
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "Capacity", value: aircraft.paxCapacityLabel)
                    infoRow(label: "Today", value: summary.occupancyLabel)
                    if let altitude = aircraft.altitudeLabel {
                        infoRow(label: "Altitude", value: altitude)
                    }
                    if let pilots = aircraft.pilotsRequiredLabel {
                        infoRow(label: "Crew", value: pilots)
                    }
                }

                if !loads.isEmpty {
                    Divider().overlay(Color.white.opacity(0.12))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Loads")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NightOps.textMuted)
                        ForEach(Array(loads.enumerated()), id: \.element.id) { index, load in
                            HStack {
                                Text("Load \(index + 1)")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Text(load.statusKey.label)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(NightOps.accent)
                                Text(load.slotCountLabel)
                                    .font(.caption)
                                    .foregroundStyle(NightOps.textMuted)
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(14)
        }
        .nightOpsCard()
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(NightOps.textMuted)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }
}

struct AircraftStatusPill: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "active", "airworthy": NightOps.success
        case "maintenance", "mx", "mx check": NightOps.accent
        case "inactive", "grounded": NightOps.danger
        default: .gray
        }
    }

    var body: some View {
        Text(status.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.25))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
