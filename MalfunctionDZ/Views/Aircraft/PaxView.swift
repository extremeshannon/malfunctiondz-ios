// File: ASC/Views/Aircraft/PaxView.swift
// Embedded as a tab inside AircraftDetailView
// Shows the full pilot PAX entry flow:
//   1. No flight → Start Flight form
//   2. Open flight → Load table + Add Load + Close Flight
//   3. Closed flight → Summary

import SwiftUI

struct PaxView: View {
    @StateObject private var vm: PaxViewModel
    @EnvironmentObject private var auth: AuthManager

    init(aircraft: Aircraft) {
        // pilotUserId is re-read live inside PaxViewModel via AuthManager
        _vm = StateObject(wrappedValue: PaxViewModel())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                switch vm.phase {
                case .loading:
                    loadingView
                case .noFlight:
                    startFlightView
                case .openFlight:
                    openFlightView
                case .closedFlight:
                    closedFlightView
                case .error(let msg):
                    errorView(msg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.mdzBackground)
        .task { await vm.loadState() }
        .refreshable { await vm.loadState() }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .mdzBlue))
                .scaleEffect(1.3)
            Text("Loading flight state…")
                .font(.subheadline)
                .foregroundColor(.mdzMuted)
            Spacer(minLength: 40)
        }
    }

    // MARK: - Error
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.mdzAmber)
            Text(msg).foregroundColor(.mdzMuted)
            Button("Retry") { Task { await vm.loadState() } }
                .buttonStyle(PaxButtonStyle())
        }
        .padding(32)
    }

    // MARK: - Start Flight
    private var startFlightView: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaxSectionHeader(icon: "airplane.departure", title: "START FLIGHT")

            if let err = vm.errorMessage {
                PaxErrorBanner(message: err)
            }

            // Aircraft picker
            VStack(alignment: .leading, spacing: 6) {
                PaxFieldLabel("Aircraft")
                Picker("Aircraft", selection: $vm.selectedAircraftId) {
                    Text("— Select —").tag(0)
                    ForEach(vm.availableAircraft) { ac in
                        Text(ac.displayName).tag(ac.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(.mdzBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.mdzCard2)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mdzBorder, lineWidth: 1))
                .onChange(of: vm.selectedAircraftId) { id in
                    if let ac = vm.availableAircraft.first(where: { $0.id == id }) {
                        vm.autoFillFromAircraft(ac)
                    }
                }
            }

            // Date
            VStack(alignment: .leading, spacing: 6) {
                PaxFieldLabel("Flight Date")
                TextField("YYYY-MM-DD", text: $vm.flightDate)
                    .mdzInputStyle()
                    .keyboardType(.numbersAndPunctuation)
            }

            // Hobbs + Tach start — side by side
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Hobbs Start")
                    TextField("0.0", text: $vm.hobbsStart)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Tach Start")
                    TextField("0.00", text: $vm.tachStart)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
            }

            Button {
                Task { await vm.startFlight() }
            } label: {
                HStack {
                    if vm.isSaving { ProgressView().tint(.white).scaleEffect(0.8) }
                    Text("Start Flight")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PaxButtonStyle(color: .mdzGreen))
            .disabled(vm.isSaving)
        }
        .paxCard()
    }

    // MARK: - Open Flight
    private var openFlightView: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Flight info bar
            if let f = vm.flight {
                flightInfoBar(f)
            }

            // Loads table
            loadsSection

            // Add load
            addLoadSection

            // Close flight
            closeFlightSection
        }
    }

    private func flightInfoBar(_ f: Flight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PaxSectionHeader(icon: "airplane", title: "ACTIVE FLIGHT")
            HStack(spacing: 16) {
                if let tn = f.tailNumber {
                    PaxPill(label: tn, color: .mdzBlue)
                }
                if let d = f.flightDateOnly {
                    PaxPill(label: d, color: .mdzMuted)
                }
                if let h = f.hobbsStart?.value {
                    PaxPill(label: "H: \(String(format: "%.1f", h))", color: .mdzMuted)
                }
                if let t = f.tachStart?.value {
                    PaxPill(label: "T: \(String(format: "%.2f", t))", color: .mdzMuted)
                }
            }
            .flexWrapped()
        }
        .paxCard()
    }

    // MARK: - Loads Table
    private var loadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PaxSectionHeader(icon: "person.3.fill", title: "LOADS")
                Spacer()
                Text("Total: \(vm.totalPax) pax")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mdzGreen)
            }

            if vm.loads.isEmpty {
                Text("No loads yet — add the first one below.")
                    .font(.subheadline)
                    .foregroundColor(.mdzMuted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 1) {
                    // Header
                    HStack {
                        Text("#").paxTableHeader().frame(width: 28)
                        Text("Pax").paxTableHeader().frame(width: 36)
                        Text("Alt").paxTableHeader().frame(minWidth: 50, alignment: .trailing)
                        Text("Hobbs").paxTableHeader().frame(minWidth: 52, alignment: .trailing)
                        Text("Tach").paxTableHeader().frame(minWidth: 52, alignment: .trailing)
                        Text("Fuel").paxTableHeader().frame(minWidth: 40, alignment: .trailing)
                        Text("Oil").paxTableHeader().frame(minWidth: 36, alignment: .trailing)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.mdzNavyMid)

                    ForEach(vm.loads) { load in
                        LoadRow(load: load) {
                            Task { await vm.deleteLoad(load) }
                        }
                    }
                }
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mdzBorder, lineWidth: 1))
            }
        }
        .paxCard()
    }

    // MARK: - Add Load
    private var addLoadSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaxSectionHeader(icon: "plus.circle.fill", title: "ADD LOAD")

            if let err = vm.errorMessage {
                PaxErrorBanner(message: err)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Pax Count *")
                    TextField("e.g. 14", text: $vm.loadPax)
                        .mdzInputStyle()
                        .keyboardType(.numberPad)
                }
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Altitude (ft)")
                    TextField("e.g. 14000", text: $vm.loadAltitude)
                        .mdzInputStyle()
                        .keyboardType(.numberPad)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Hobbs *")
                    TextField("0.0", text: $vm.loadHobbs)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Tach *")
                    TextField("0.00", text: $vm.loadTach)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Fuel Added (gal)")
                    TextField("optional", text: $vm.loadFuel)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Oil Added (qt)")
                    TextField("optional", text: $vm.loadOil)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                PaxFieldLabel("Notes")
                TextField("optional", text: $vm.loadNotes)
                    .mdzInputStyle()
            }

            Button {
                Task { await vm.addLoad() }
            } label: {
                HStack {
                    if vm.isSaving { ProgressView().tint(.white).scaleEffect(0.8) }
                    Image(systemName: "plus")
                    Text("Add Load")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PaxButtonStyle(color: .mdzBlue))
            .disabled(vm.isSaving)
        }
        .paxCard()
    }

    // MARK: - Close Flight
    private var closeFlightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaxSectionHeader(icon: "xmark.circle.fill", title: "CLOSE FLIGHT")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Hobbs End")
                    TextField("0.0", text: $vm.hobbsEnd)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 6) {
                    PaxFieldLabel("Tach End")
                    TextField("0.00", text: $vm.tachEnd)
                        .mdzInputStyle()
                        .keyboardType(.decimalPad)
                }
            }

            // Live elapsed
            if let hobbs = vm.hobbsElapsed, let tach = vm.tachElapsed {
                HStack(spacing: 16) {
                    HStack(spacing:4){Image(systemName:"clock").font(.caption).foregroundColor(.mdzGreen);Text("Hobbs: \(hobbs)")}
                        .font(.caption)
                        .foregroundColor(.mdzGreen)
                    HStack(spacing:4){Image(systemName:"clock").font(.caption).foregroundColor(.mdzGreen);Text("Tach: \(tach)")}
                        .font(.caption)
                        .foregroundColor(.mdzGreen)
                }
            }

            Button {
                Task { await vm.closeFlight() }
            } label: {
                HStack {
                    if vm.isSaving { ProgressView().tint(.white).scaleEffect(0.8) }
                    Image(systemName: "checkmark.circle")
                    Text("Close Flight")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PaxButtonStyle(color: .mdzDanger))
            .disabled(vm.isSaving)
        }
        .paxCard()
    }

    // MARK: - Closed Summary
    private var closedFlightView: some View {
        VStack(alignment: .leading, spacing: 16) {
            PaxSectionHeader(icon: "checkmark.seal.fill", title: "FLIGHT CLOSED")

            if let f = vm.flight {
                VStack(spacing: 1) {
                    SummaryRow(label: "Aircraft",     value: f.tailNumber ?? "—")
                    SummaryRow(label: "Date",         value: f.flightDateOnly ?? "—")
                    SummaryRow(label: "Total Pax",    value: "\(vm.totalPax)")
                    if let hs = f.hobbsStart?.value, let he = f.hobbsEnd?.value {
                        SummaryRow(label: "Hobbs",
                                   value: "\(String(format:"%.1f",hs)) → \(String(format:"%.1f",he)) (\(String(format:"%.1f",he-hs)) hrs)")
                    }
                    if let ts = f.tachStart?.value, let te = f.tachEnd?.value {
                        SummaryRow(label: "Tach",
                                   value: "\(String(format:"%.2f",ts)) → \(String(format:"%.2f",te)) (\(String(format:"%.2f",te-ts)) hrs)")
                    }
                }
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mdzBorder, lineWidth: 1))
            }

            // Loads recap
            if !vm.loads.isEmpty {
                VStack(spacing: 1) {
                    ForEach(vm.loads) { load in
                        LoadRow(load: load, onDelete: nil)
                    }
                }
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mdzBorder, lineWidth: 1))
            }
        }
        .paxCard()
    }
}

// MARK: - Sub-Views

struct LoadRow: View {
    let load: FlightLoad
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            Text("\(load.loadNumber)").paxTableCell().frame(width: 28)
            Text("\(load.paxCount)").paxTableCell(color: .mdzGreen).frame(width: 36)
            Text(load.altitude.map { "\($0 / 1000)k" } ?? "—").paxTableCell().frame(minWidth: 50, alignment: .trailing)
            Text(load.hobbsTime?.value.map { String(format: "%.1f", $0) } ?? "—").paxTableCell().frame(minWidth: 52, alignment: .trailing)
            Text(load.tachTime?.value.map { String(format: "%.2f", $0) } ?? "—").paxTableCell().frame(minWidth: 52, alignment: .trailing)
            Text(load.fuelAdded?.value.map { String(format: "%.1f", $0) } ?? "—").paxTableCell().frame(minWidth: 40, alignment: .trailing)
            Text(load.oilAdded?.value.map { String(format: "%.2f", $0) } ?? "—").paxTableCell().frame(minWidth: 36, alignment: .trailing)
            Spacer()
            if let del = onDelete {
                Button(action: del) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.mdzDanger.opacity(0.6))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.mdzCard)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mdzMuted)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.mdzText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mdzCard)
    }
}

struct PaxSectionHeader: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.mdzBlue)
            Text(title)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.mdzBlue)
                .tracking(1.5)
        }
    }
}

struct PaxPill: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct PaxErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.mdzDanger)
            Text(message)
                .font(.caption)
                .foregroundColor(.mdzDanger)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mdzDanger.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PaxFieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.mdzMuted)
            .tracking(0.8)
    }
}

struct PaxButtonStyle: ButtonStyle {
    var color: Color = .mdzBlue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(10)
    }
}

// MARK: - View extensions
extension View {
    func paxCard() -> some View {
        self.padding(16)
            .background(Color.mdzCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mdzBorder, lineWidth: 1))
            .padding(.bottom, 12)
    }

    func mdzInputStyle() -> some View {
        self.padding(10)
            .background(Color.mdzNavyMid)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mdzBorder, lineWidth: 1))
            .foregroundColor(.mdzText)
            .font(.system(size: 15))
    }

    func paxTableHeader() -> some View {
        self.font(.system(size: 9, weight: .black))
            .foregroundColor(.mdzMuted)
            .tracking(0.5)
    }

    func paxTableCell(color: Color = .mdzText) -> some View {
        self.font(.system(size: 12, weight: .medium))
            .foregroundColor(color)
    }

    func flexWrapped() -> some View {
        self // SwiftUI doesn't do flex-wrap natively — HStack is close enough for pills
    }
}
