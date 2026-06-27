// ASC Pilot — Loads · Today (mockup-aligned layout for pilot shell).
import SwiftUI
import MalfunctionDZCore

struct ASCPilotHomeView: View {
    @EnvironmentObject private var tabSelect: TabSelection
    @ObservedObject var vm: HomeViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ASC.Space.xxl) {
                ascLargeTitle
                weatherBanner
                activeSection
                loadsList
            }
            .padding(.horizontal, ASC.Space.lg)
            .padding(.top, ASC.Space.md)
            .padding(.bottom, ASC.Space.xxxl)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Title

    private var ascLargeTitle: some View {
        VStack(alignment: .leading, spacing: ASC.Space.sm) {
            Text("LOADS")
                .font(ASC.Typography.display(34))
                .foregroundStyle(ASC.Text.primary)
            Text(subtitleLine)
                .font(ASC.Typography.bodyMedium(14))
                .foregroundStyle(ASC.Palette.beacon)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitleLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let day = f.string(from: Date())
        let loads = vm.pilotLoads.count
        let total = max(vm.pilotData?.totalLoads ?? 0, loads)
        if total > 0 {
            return "\(day) · \(loads) of \(total) complete"
        }
        if let p = vm.pilotData, p.totalPax > 0 {
            return "\(day) · \(p.totalPax) pax today"
        }
        return "\(day) · No loads yet"
    }

    // MARK: - Weather

    private var weatherBanner: some View {
        Group {
            if let m = vm.metar {
                HStack(spacing: ASC.Space.lg) {
                    weatherCol(
                        label: "Surface",
                        value: m.windDir.map { "\($0)" } ?? "—",
                        unit: "°",
                        detail: surfaceWindDetail(m),
                        detailColor: ASC.Palette.beacon
                    )
                    weatherCol(
                        label: "@ 10k",
                        value: "—",
                        unit: nil,
                        detail: "Winds aloft",
                        detailColor: ASC.Text.muted
                    )
                    weatherCol(
                        label: "Ceiling",
                        value: ceilingLabel(m),
                        unit: nil,
                        detail: visibilityDetail(m),
                        detailColor: m.resolvedFlightCategory == "VFR" ? ASC.Palette.jumpReady : ASC.Text.tertiary
                    )
                }
                .padding(ASC.Space.lg)
                .background(ASC.Surface.card)
                .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                        .strokeBorder(ASC.Border.hair, lineWidth: 0.5)
                )
            } else if vm.metarLoading {
                HStack(spacing: ASC.Space.sm) {
                    ProgressView().tint(ASC.Palette.beacon)
                    Text("Fetching weather…")
                        .font(ASC.Typography.caption(12))
                        .foregroundStyle(ASC.Text.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .ascCard()
            }
        }
    }

    private func weatherCol(label: String, value: String, unit: String?, detail: String, detailColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(ASC.Typography.eyebrow(10))
                .tracking(1.8)
                .foregroundStyle(ASC.Text.muted)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(ASC.Typography.numeric(22))
                    .foregroundStyle(ASC.Text.primary)
                if let unit {
                    Text(unit)
                        .font(ASC.Typography.caption(13))
                        .foregroundStyle(ASC.Text.tertiary)
                }
            }
            Text(detail)
                .font(ASC.Typography.caption(11))
                .foregroundStyle(detailColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func surfaceWindDetail(_ m: MetarData) -> String {
        guard let spd = m.windSpeedKts, spd > 0 else { return "Calm" }
        if let gust = m.windGustKts { return "\(spd) kt G\(gust)" }
        return "\(spd) kt"
    }

    private func ceilingLabel(_ m: MetarData) -> String {
        switch m.resolvedFlightCategory {
        case "VFR": return "CLR"
        case "MVFR": return "MVFR"
        case "IFR": return "IFR"
        case "LIFR": return "LIFR"
        default: return m.skyCondition.uppercased()
        }
    }

    private func visibilityDetail(_ m: MetarData) -> String {
        if let vis = m.visibilitySM {
            return vis >= 10 ? "10+ mi vis" : String(format: "%.1f mi vis", vis)
        }
        return m.skyCondition
    }

    // MARK: - Active section header

    private var activeSection: some View {
        HStack {
            Text("ACTIVE")
                .font(ASC.Typography.sectionLabel(12))
                .tracking(2)
                .foregroundStyle(ASC.Text.muted)
            Spacer()
            Text(activeTail)
                .font(ASC.Typography.sectionLabel(12))
                .tracking(1)
                .foregroundStyle(ASC.Palette.daylight)
        }
    }

    private var activeTail: String {
        vm.pilotData?.openTailNumber
            ?? vm.pilotOpenFlight?.tailNumber
            ?? vm.airworthyAircraft.first?.tailNumber
            ?? "—"
    }

    // MARK: - Loads

    @ViewBuilder
    private var loadsList: some View {
        if vm.pilotLoads.isEmpty {
            emptyLoadsCard
        } else {
            VStack(spacing: ASC.Space.md) {
                ForEach(Array(vm.pilotLoads.enumerated()), id: \.element.id) { index, load in
                    pilotLoadCard(load, isNextUp: index == 0 && vm.pilotOpenFlight?.isOpen == true)
                }
            }
        }
    }

    private var emptyLoadsCard: some View {
        VStack(alignment: .leading, spacing: ASC.Space.lg) {
            Text("No loads on today's flight yet.")
                .font(ASC.Typography.body(14))
                .foregroundStyle(ASC.Text.tertiary)
            ASCPrimaryButton(title: "Start First Flight →") {
                tabSelect.selected = 1
            }
        }
        .ascCard()
    }

    private func pilotLoadCard(_ load: FlightLoad, isNextUp: Bool) -> some View {
        VStack(alignment: .leading, spacing: ASC.Space.md) {
            if isNextUp {
                HStack {
                    Spacer()
                    nextUpPill
                }
            }

            HStack(alignment: .firstTextBaseline) {
                loadNumberLabel(load.loadNumber)
                Spacer()
                Text(loadTimePlaceholder(load))
                    .font(ASC.Typography.numeric(16))
                    .foregroundStyle(ASC.Palette.daylight)
            }
            .padding(.top, isNextUp ? ASC.Space.sm : 0)

            loadMetaGrid(load, highlightStatus: !isNextUp)

            if isNextUp {
                ASCPrimaryButton(title: primaryCTATitle) {
                    tabSelect.selected = 1
                }
                .padding(.top, ASC.Space.sm)
            }
        }
        .padding(ASC.Space.lg)
        .background(ASC.Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASC.Radius.card, style: .continuous)
                .strokeBorder(isNextUp ? ASC.Palette.hiVis : ASC.Border.hair, lineWidth: isNextUp ? 1 : 0.5)
        )
    }

    private var nextUpPill: some View {
        HStack(spacing: 5) {
            Circle().fill(ASC.Palette.hiVis).frame(width: 5, height: 5)
            Text("NEXT UP")
                .font(ASC.Typography.eyebrow(9))
                .tracking(1.4)
                .foregroundStyle(ASC.Palette.hiVis)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(ASC.Palette.hiVis.opacity(0.15))
        .clipShape(Capsule())
    }

    private func loadNumberLabel(_ n: Int) -> some View {
        HStack(spacing: 6) {
            Text("LOAD")
                .font(ASC.Typography.display(18))
                .foregroundStyle(ASC.Text.primary)
            Text("\(n)")
                .font(ASC.Typography.display(18))
                .foregroundStyle(ASC.Palette.hiVis)
        }
    }

    private func loadTimePlaceholder(_ load: FlightLoad) -> String {
        // Flight loads API has no scheduled time — show load sequence hint.
        "L\(load.loadNumber)"
    }

    private func loadMetaGrid(_ load: FlightLoad, highlightStatus: Bool) -> some View {
        VStack(spacing: 6) {
            metaRow(key: "Pax", value: "\(load.paxCount)")
            if let alt = load.altitude, alt > 0 {
                metaRow(key: "Exit alt", value: "\(alt.formatted())' AGL")
            }
            if highlightStatus {
                metaRow(
                    key: "Status",
                    value: statusLabel(for: load),
                    valueColor: ASC.Palette.daylight
                )
            }
        }
    }

    private func metaRow(key: String, value: String, valueColor: Color = ASC.Text.primary) -> some View {
        HStack {
            Text(key)
                .font(ASC.Typography.caption(12))
                .foregroundStyle(ASC.Text.muted)
            Spacer()
            Text(value)
                .font(ASC.Typography.bodyMedium(13))
                .foregroundStyle(valueColor)
        }
    }

    private func statusLabel(for load: FlightLoad) -> String {
        if vm.pilotOpenFlight?.isOpen == true { return "On active flight" }
        return "Complete"
    }

    private var primaryCTATitle: String {
        vm.pilotOpenFlight?.isOpen == true ? "Manage Flight →" : "Open Aviation →"
    }
}
