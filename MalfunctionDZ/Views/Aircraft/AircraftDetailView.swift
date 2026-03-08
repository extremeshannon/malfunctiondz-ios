// File: ASC/Views/Aircraft/AircraftDetailView.swift
// Change from previous version: added PAX tab (index 3), logbook filter, detail view, thumbnails
import SwiftUI

struct AircraftDetailView: View {
    let aircraft: Aircraft
    var isReadOnly: Bool = false
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @StateObject private var vm = AircraftDetailViewModel()
    @State private var selectedTab = 0
    @State private var logbookFilter = "all"
    @State private var selectedLogbookEntry: LogbookEntry?
    @State private var enlargedImageURL: URL?
    @State private var showEditAircraft = false

    private let logbookFiltersSingle: [(String, String)] = [("all", "All"), ("airframe", "Aircraft"), ("engine", "Engine"), ("prop", "Prop")]
    private var logbookFiltersMulti: [(String, String)] { [("all", "All"), ("airframe", "Aircraft"), ("engine_left", "Left Engine"), ("engine_right", "Right Engine"), ("prop", "Prop")] }
    private var logbookFilters: [(String, String)] { (aircraft.isMultiEngine == true) ? logbookFiltersMulti : logbookFiltersSingle }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Pic 1 style: blue header
                aircraftHeaderBlock
                Group {
                    switch selectedTab {
                    case 0: squawksTab
                    case 1: logbookTab
                    case 2: adsTab
                    case 3: stcTab
                    case 4: PaxView(aircraft: aircraft, isReadOnly: isReadOnly)
                    default: squawksTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colors.background)
                .overlay(alignment: .top) {
                    if let err = vm.error {
                        VStack(spacing: 0) {
                            HStack {
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundColor(colors.text)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Button { vm.error = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(colors.muted)
                                }
                            }
                            .padding(12)
                            .background(colors.amber.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(colors.amber.opacity(0.5), lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(aircraft.tailNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEditAircraft = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .task { await vm.loadDetail(aircraftId: aircraft.id) }
        .onChange(of: aircraft.isMultiEngine) { _, _ in
            if aircraft.isMultiEngine == true && (logbookFilter == "engine" || logbookFilter == "airframe") {
                logbookFilter = "all"
                Task { await vm.loadLogbook(aircraftId: aircraft.id, bookType: "all") }
            }
        }
        .sheet(item: $selectedLogbookEntry) { entry in
            AircraftLogbookEntryDetailSheet(
                aircraft: aircraft,
                entry: entry,
                vm: vm,
                enlargedImageURL: $enlargedImageURL,
                onDismiss: { selectedLogbookEntry = nil }
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { enlargedImageURL != nil },
            set: { if !$0 { enlargedImageURL = nil } }
        )) {
            if let url = enlargedImageURL {
                EnlargeableImageSheet(imageURL: url, onDismiss: { enlargedImageURL = nil })
            }
        }
        .sheet(isPresented: $showEditAircraft) {
            EditAircraftSheet(aircraft: aircraft, onDismiss: { showEditAircraft = false })
        }
    }

    private var aircraftHeaderBlock: some View {
        VStack(spacing: 0) {
            // Header: left-justified, font colors like reference
            VStack(alignment: .leading, spacing: 10) {
                Text(aircraft.model.uppercased() + " · TURBINE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text(aircraft.tailNumber)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 10) {
                    Text(aircraft.status == "airworthy" || aircraft.status == "active" ? "AIRWORTHY" : aircraft.status.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(aircraft.status == "airworthy" || aircraft.status == "active" ? colors.green : colors.amber)
                        .cornerRadius(8)
                    if let mic = aircraft.lastMic ?? aircraft.lastOilChange ?? aircraft.annualDue, !mic.isEmpty {
                        Text("Last mx: \(mic)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                // TTSN, SMOH, PROP, SLOTS — left-aligned, label grey / value white (SMOH orange)
                HStack(alignment: .top, spacing: 24) {
                    metricBlock(label: "TTSN", value: formatHours(aircraft.ttsn), valueColor: .white)
                    metricBlock(label: "SMOH", value: formatHours(aircraft.smoh), valueColor: colors.amber)
                    metricBlock(label: "PROP", value: formatHours(aircraft.propTime), valueColor: .white)
                    metricBlock(label: "SLOTS", value: aircraft.slots.map { "\($0)" } ?? "—", valueColor: .white)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(colors.navyMid)
            Picker("", selection: $selectedTab) {
                Text("Squawks").tag(0)
                Text("Logbooks").tag(1)
                Text("ADs").tag(2)
                Text("STC/337").tag(3)
                Text("Pax").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(colors.navyMid.opacity(0.95))
        }
    }

    private func formatHours(_ s: String?) -> String {
        guard let s = s, !s.isEmpty, s != "—" else { return "—" }
        if s.contains("hr") || s.contains("hrs") { return s }
        return s + " hrs"
    }

    private func metricBlock(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(valueColor)
        }
    }

    private var squawksTab: some View {
        Group {
            if vm.isLoading {
                LoadingOverlay(message: "Loading squawks…")
            } else if vm.squawks.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "No Squawks", subtitle: "Aircraft is squawk-free.")
            } else {
                List(vm.squawks) { squawk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(squawk.description)
                                .font(.subheadline)
                                .foregroundColor(colors.text)
                            Spacer()
                            StatusPill(label: squawk.status.uppercased(), color: squawk.statusColor)
                        }
                        if let by = squawk.reportedBy, let at = squawk.reportedAt {
                            Text("Reported \(at) · \(by)")
                                .font(.caption)
                                .foregroundColor(colors.muted)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(colors.card)
                    .listRowSeparatorTint(colors.border)
                }
                .listStyle(.plain)
                .refreshable { await vm.loadDetail(aircraftId: aircraft.id) }
            }
        }
    }

    private var logbookTab: some View {
        Group {
            VStack(spacing: 0) {
                // Filter: All | Aircraft | Engine | Prop
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(logbookFilters, id: \.0) { key, label in
                            Button {
                                logbookFilter = key
                                Task { await vm.loadLogbook(aircraftId: aircraft.id, bookType: key) }
                            } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(logbookFilter == key ? colors.background : colors.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(logbookFilter == key ? colors.primary : colors.card)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(colors.navyMid)

                if vm.logbook.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "book", title: "No Entries", subtitle: "No logbook entries found.")
                    Spacer()
                } else {
                    List(vm.logbook) { entry in
                        Button {
                            selectedLogbookEntry = entry
                            Task { await vm.loadLogbookEntryDetail(aircraftId: aircraft.id, entryId: entry.id) }
                        } label: {
                            AircraftLogbookEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(colors.card)
                        .listRowSeparatorTint(colors.border)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await vm.loadLogbook(aircraftId: aircraft.id, bookType: logbookFilter)
                    }
                }
            }
        }
    }

    private var stcTab: some View {
        EmptyStateView(
            icon: "doc.badge.clock",
            title: "STC / 337",
            subtitle: "Supplemental Type Certificates and Form 337s for this aircraft. Data will appear here when available."
        )
    }

    private var adsTab: some View {
        Group {
            if vm.ads.isEmpty {
                EmptyStateView(icon: "doc.text", title: "No ADs", subtitle: "No airworthiness directives found.")
            } else {
                List(vm.ads) { ad in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ad.adNumber).font(.caption.monospaced()).foregroundColor(colors.primary)
                            Spacer()
                            StatusPill(
                                label: ad.status.uppercased(),
                                color: ad.status == "complied" ? colors.green : colors.amber
                            )
                        }
                        Text(ad.description).font(.subheadline).foregroundColor(colors.text)
                        if let due = ad.dueDate {
                            Text("Due: \(due)").font(.caption).foregroundColor(colors.amber)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(colors.card)
                    .listRowSeparatorTint(colors.border)
                }
                .listStyle(.plain)
                .refreshable { await vm.loadDetail(aircraftId: aircraft.id) }
            }
        }
    }
}

// MARK: - Logbook Entry Row (list row with thumbnail)
struct AircraftLogbookEntryRow: View {
    let entry: LogbookEntry
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let url = entry.thumbnailURL() {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").foregroundColor(colors.muted)
                    default: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: 56, height: 40)
                .clipped()
                .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(colors.border.opacity(0.5))
                    .frame(width: 56, height: 40)
                    .overlay(Image(systemName: "doc").foregroundColor(colors.muted).font(.system(size: 18)))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.date).font(.caption).foregroundColor(colors.muted)
                    Spacer()
                    Text(entry.bookTypeLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(colors.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colors.primary.opacity(0.2))
                        .cornerRadius(4)
                }
                if let t = entry.tachTime {
                    Text(String(format: "Tach %.1f", t)).font(.caption2).foregroundColor(colors.primary)
                }
                Text(entry.description)
                    .font(.subheadline)
                    .foregroundColor(colors.text)
                    .lineLimit(2)
                if let by = entry.performedBy {
                    Text(by).font(.caption).foregroundColor(colors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Logbook Entry Detail Sheet (full entry + image gallery)
struct AircraftLogbookEntryDetailSheet: View {
    let aircraft: Aircraft
    let entry: LogbookEntry
    @ObservedObject var vm: AircraftDetailViewModel
    @Binding var enlargedImageURL: URL?
    let onDismiss: () -> Void
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                if vm.logbookDetailLoading && vm.logbookDetail == nil {
                    VStack(spacing: 16) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.primary)).scaleEffect(1.2)
                        Text("Loading entry…").font(.subheadline).foregroundColor(colors.muted)
                    }
                } else if let detail = vm.logbookDetail {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Entry card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(detail.bookTypeLabel)
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(colors.primary)
                                        .tracking(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(colors.primary.opacity(0.2))
                                        .cornerRadius(6)
                                    Spacer()
                                }
                                InfoRow(label: "Date", value: detail.date)
                                if let t = detail.tachTime {
                                    InfoRow(label: "Tach", value: String(format: "%.1f", t))
                                }
                                if let h = detail.hobbsTime {
                                    InfoRow(label: "Hobbs", value: String(format: "%.1f", h))
                                }
                                if let by = detail.performedBy, !by.isEmpty {
                                    InfoRow(label: "Performed By", value: by)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DESCRIPTION")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(colors.muted)
                                        .tracking(1)
                                    Text(detail.description)
                                        .font(.system(size: 15))
                                        .foregroundColor(colors.text)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colors.card)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))

                            // Images
                            if !detail.images.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("ATTACHMENTS")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(colors.muted)
                                        .tracking(1)
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10),
                                    ], spacing: 10) {
                                        ForEach(Array(detail.imageURLs().enumerated()), id: \.offset) { _, url in
                                            Button {
                                                enlargedImageURL = url
                                            } label: {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let img): img.resizable().scaledToFill()
                                                    case .failure: Image(systemName: "photo").foregroundColor(colors.muted)
                                                    default: ProgressView()
                                                    }
                                                }
                                                .frame(minWidth: 0, maxWidth: .infinity)
                                                .aspectRatio(4/3, contentMode: .fill)
                                                .clipped()
                                                .cornerRadius(10)
                                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 40)
                    }
                } else {
                    // Fallback: show basic info from list entry
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Date", value: entry.date)
                            if let t = entry.tachTime {
                                InfoRow(label: "Tach", value: String(format: "%.1f", t))
                            }
                            InfoRow(label: "Description", value: entry.description)
                            if let by = entry.performedBy {
                                InfoRow(label: "Performed By", value: by)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Logbook Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundColor(colors.amber)
                }
            }
        }
    }
}

// MARK: - Edit Aircraft (multi-engine and future fields)
struct EditAircraftSheet: View {
    let aircraft: Aircraft
    let onDismiss: () -> Void
    @Environment(\.mdzColors) private var colors
    @State private var isMultiEngine: Bool

    init(aircraft: Aircraft, onDismiss: @escaping () -> Void) {
        self.aircraft = aircraft
        self.onDismiss = onDismiss
        _isMultiEngine = State(initialValue: aircraft.isMultiEngine ?? false)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("When the update-aircraft API is ready, this form will save tail number, times, and multi-engine. Multi-engine aircraft use Left Engine and Right Engine logbook categories.")
                        .font(.subheadline)
                        .foregroundColor(colors.muted)
                        .padding(.horizontal)
                    Toggle(isOn: $isMultiEngine) {
                        Text("Multi-engine")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .tint(colors.accent)
                    .padding(.horizontal, 24)
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Edit Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // TODO: call API to update aircraft multi_engine
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.amber)
                }
            }
        }
    }
}
