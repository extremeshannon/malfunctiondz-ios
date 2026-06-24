// File: ASC/Views/Aircraft/AircraftDetailView.swift
// Change from previous version: added PAX tab (index 3), logbook filter, detail view, thumbnails
import SwiftUI
import UIKit
import PhotosUI
import MalfunctionDZCore

struct AircraftDetailView: View {
    let aircraft: Aircraft
    var isReadOnly: Bool = false
    @EnvironmentObject private var config: AppConfig
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @StateObject private var vm = AircraftDetailViewModel()
    @State private var selectedTab = 0
    @State private var logbookFilter = "all"
    @State private var selectedLogbookEntry: LogbookEntry?
    @State private var selectedStcEntry: StcEntry?
    @State private var showEditAircraft = false
    @State private var showAddSquawk = false
    @State private var showAddAd = false
    @State private var showAddStc337 = false
    @State private var showAddLogbookEntry = false

    // Logbook filters: single-engine only on detail page. Multi-engine is set only in Add/Edit Aircraft.
    private let logbookFilters: [(String, String)] = [("all", "All"), ("airframe", "Aircraft"), ("engine", "Engine"), ("prop", "Prop")]

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
                            HStack(alignment: .top) {
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundColor(colors.text)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                HStack(spacing: 12) {
                                    Button {
                                        Task { await vm.loadDetail(aircraftId: aircraft.id) }
                                    } label: {
                                        Text("Retry")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(colors.amber)
                                    }
                                    Button { vm.error = nil } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(colors.muted)
                                    }
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
        .navigationTitle(config.dzName)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                addButtonForCurrentTab
            }
        }
        .task { await vm.loadDetail(aircraftId: aircraft.id) }
        .sheet(item: $selectedLogbookEntry) { entry in
            AircraftLogbookEntryDetailSheet(
                aircraft: aircraft,
                entry: entry,
                vm: vm,
                onDismiss: { selectedLogbookEntry = nil }
            )
        }
        .sheet(item: $selectedStcEntry) { entry in
            StcEntryDetailSheet(
                aircraft: aircraft,
                entry: entry,
                vm: vm,
                onDismiss: { selectedStcEntry = nil }
            )
        }
        .sheet(isPresented: $showEditAircraft) {
            EditAircraftSheet(
                aircraft: aircraft,
                onDismiss: { showEditAircraft = false },
                onSaved: { Task { await vm.loadDetail(aircraftId: aircraft.id) } }
            )
        }
        .sheet(isPresented: $showAddSquawk) {
            AddSquawkSheet(aircraft: aircraft, vm: vm, onDismiss: { showAddSquawk = false }, onSaved: { Task { await vm.loadDetail(aircraftId: aircraft.id) } })
        }
        .sheet(isPresented: $showAddAd) {
            AddAdSheet(aircraft: aircraft, vm: vm, onDismiss: { showAddAd = false }, onSaved: { Task { await vm.loadDetail(aircraftId: aircraft.id) } })
        }
        .sheet(isPresented: $showAddStc337) {
            AddStc337Sheet(aircraft: aircraft, vm: vm, onDismiss: { showAddStc337 = false }, onSaved: { Task { await vm.loadDetail(aircraftId: aircraft.id) } })
        }
        .sheet(isPresented: $showAddLogbookEntry) {
            AddAircraftLogbookEntrySheet(aircraft: aircraft, vm: vm, onDismiss: { showAddLogbookEntry = false }, onSaved: { Task { await vm.loadDetail(aircraftId: aircraft.id) } })
        }
    }

    private var aircraftHeaderBlock: some View {
        VStack(spacing: 0) {
            // Header: left-justified, font colors like reference
            VStack(alignment: .leading, spacing: 10) {
                Text(aircraft.model.uppercased() + " · TURBINE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Group {
                    if isReadOnly {
                        Text(aircraft.tailNumber)
                    } else {
                        Button {
                            showEditAircraft = true
                        } label: {
                            Text(aircraft.tailNumber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Tail number \(aircraft.tailNumber)")
                        .accessibilityHint("Opens edit aircraft")
                    }
                }
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
                // TTAF (total airframe), TSMOH (engine), TSPOH (prop), SLOTS (min–max) — left-aligned
                HStack(alignment: .top, spacing: 24) {
                    metricBlock(label: "TTAF", value: formatHours(aircraft.ttsn), valueColor: .white)
                    metricBlock(label: "TSMOH", value: formatHours(aircraft.smoh), valueColor: colors.amber)
                    metricBlock(label: "TSPOH", value: formatHours(aircraft.propTime), valueColor: .white)
                    metricBlock(label: "SLOTS", value: slotsDisplay, valueColor: .white)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
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

    /// Slots display: "min–max" when both set, else single slots value, else "—"
    private var slotsDisplay: String {
        if let minV = aircraft.slotsMin, let maxV = aircraft.slotsMax {
            return "\(minV)–\(maxV)"
        }
        if let s = aircraft.slots { return "\(s)" }
        return "—"
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

    @ViewBuilder
    private var addButtonForCurrentTab: some View {
        if selectedTab != 4 {
            Button {
                switch selectedTab {
                case 0: showAddSquawk = true
                case 1: showAddLogbookEntry = true
                case 2: showAddAd = true
                case 3: showAddStc337 = true
                default: break
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
            }
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
        Group {
            if vm.stcEntries.isEmpty {
                EmptyStateView(
                    icon: "doc.badge.clock",
                    title: "STC / 337",
                    subtitle: "Supplemental Type Certificates and Form 337s for this aircraft. Data will appear here when available."
                )
            } else {
                List(vm.stcEntries) { entry in
                    Button {
                        selectedStcEntry = entry
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.title.isEmpty ? "STC / 337" : entry.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(colors.text)
                                Spacer()
                                Text(entry.recordTypeLabel)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(colors.primary.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            if !entry.description.isEmpty {
                                Text(entry.description)
                                    .font(.caption)
                                    .foregroundColor(colors.muted)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 12) {
                                if let stc = entry.stcNumber, !stc.isEmpty {
                                    Text("STC \(stc)")
                                        .font(.caption2.monospaced())
                                        .foregroundColor(colors.primary)
                                }
                                if let f337 = entry.form337Number, !f337.isEmpty {
                                    Text("337 \(f337)")
                                        .font(.caption2.monospaced())
                                        .foregroundColor(colors.muted)
                                }
                                if !entry.entryDate.isEmpty {
                                    Text(entry.entryDate)
                                        .font(.caption2)
                                        .foregroundColor(colors.muted)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(colors.card)
                    .listRowSeparatorTint(colors.border)
                }
                .listStyle(.plain)
                .refreshable { await vm.loadDetail(aircraftId: aircraft.id) }
            }
        }
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
    let onDismiss: () -> Void
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    /// Shown in a fullScreenCover *inside this sheet* so the image appears on top when tapped (not behind the sheet).
    @State private var localEnlargedImageURL: URL?

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
                                                localEnlargedImageURL = url
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
            .fullScreenCover(isPresented: Binding(
                get: { localEnlargedImageURL != nil },
                set: { if !$0 { localEnlargedImageURL = nil } }
            )) {
                if let url = localEnlargedImageURL {
                    EnlargeableImageSheet(imageURL: url, onDismiss: { localEnlargedImageURL = nil })
                }
            }
        }
    }
}

// MARK: - STC/337 Entry Detail Sheet (full entry + image gallery, tap image to enlarge)
struct StcEntryDetailSheet: View {
    let aircraft: Aircraft
    let entry: StcEntry
    @ObservedObject var vm: AircraftDetailViewModel
    let onDismiss: () -> Void
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var localEnlargedImageURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                if vm.stcEntryDetailLoading && vm.stcEntryDetail == nil {
                    VStack(spacing: 16) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.primary)).scaleEffect(1.2)
                        Text("Loading entry…").font(.subheadline).foregroundColor(colors.muted)
                    }
                } else if let detail = vm.stcEntryDetail {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(detail.recordTypeLabel)
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(colors.primary)
                                        .tracking(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(colors.primary.opacity(0.2))
                                        .cornerRadius(6)
                                    Spacer()
                                }
                                if !detail.title.isEmpty {
                                    InfoRow(label: "Title", value: detail.title)
                                }
                                InfoRow(label: "Date", value: detail.entryDate)
                                if let stc = detail.stcNumber, !stc.isEmpty {
                                    InfoRow(label: "STC number", value: stc)
                                }
                                if let f337 = detail.form337Number, !f337.isEmpty {
                                    InfoRow(label: "Form 337", value: f337)
                                }
                                if let approval = detail.approvalDate, !approval.isEmpty {
                                    InfoRow(label: "Approval date", value: approval)
                                }
                                if let field = detail.fieldApproval, !field.isEmpty {
                                    InfoRow(label: "Field approval", value: field)
                                }
                                if !detail.description.isEmpty {
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
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colors.card)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))

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
                                                localEnlargedImageURL = url
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
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Title", value: entry.title.isEmpty ? "STC / 337" : entry.title)
                            InfoRow(label: "Date", value: entry.entryDate)
                            if !entry.description.isEmpty {
                                InfoRow(label: "Description", value: entry.description)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("STC / 337 Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundColor(colors.amber)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { localEnlargedImageURL != nil },
                set: { if !$0 { localEnlargedImageURL = nil } }
            )) {
                if let url = localEnlargedImageURL {
                    EnlargeableImageSheet(imageURL: url, onDismiss: { localEnlargedImageURL = nil })
                }
            }
            .task {
                await vm.loadStcEntryDetail(aircraftId: aircraft.id, entryId: entry.id)
            }
        }
    }
}

// MARK: - Edit Aircraft (PUT /api/aircraft)
struct EditAircraftSheet: View {
    let aircraft: Aircraft
    let onDismiss: () -> Void
    let onSaved: () -> Void

    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    @State private var loading = true
    @State private var loadError: String?

    @State private var tailNumber = ""
    @State private var make = ""
    @State private var model = ""
    @State private var year = ""
    @State private var serialNumber = ""
    @State private var status = "active"
    @State private var notes = ""
    @State private var currentHobbs = ""
    @State private var currentTach = ""
    @State private var minPaxPerLoad = "1"
    @State private var maxPaxPerLoad = "4"
    @State private var loadTimeMinutes = "30"
    /// Preserved from API (no web field); always round-tripped on save.
    @State private var needsFuel = false
    @State private var isJumpable = true
    @State private var hasFloats = false
    @State private var isMultiEngine = false

    // Single-engine / prop
    @State private var engineMake = ""
    @State private var engineModel = ""
    @State private var engineSerial = ""
    @State private var engineTT = ""
    @State private var engineTSMOH = ""
    @State private var propMake = ""
    @State private var propModel = ""
    @State private var propSerial = ""
    @State private var propTT = ""
    @State private var propTSOH = ""

    // Multi-engine
    @State private var leftEngineMake = ""
    @State private var leftEngineModel = ""
    @State private var leftEngineSerial = ""
    @State private var leftEngineTT = ""
    @State private var leftEngineTSMOH = ""
    @State private var rightEngineMake = ""
    @State private var rightEngineModel = ""
    @State private var rightEngineSerial = ""
    @State private var rightEngineTT = ""
    @State private var rightEngineTSMOH = ""

    @State private var leftPropMake = ""
    @State private var leftPropModel = ""
    @State private var leftPropSerial = ""
    @State private var leftPropTT = ""
    @State private var leftPropTSOH = ""

    @State private var rightPropMake = ""
    @State private var rightPropModel = ""
    @State private var rightPropSerial = ""
    @State private var rightPropTT = ""
    @State private var rightPropTSOH = ""

    @State private var saving = false
    @State private var error: String?

    private let statusOptions = [("active", "Active"), ("inactive", "Inactive"), ("maintenance", "Maintenance")]

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.primary))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(colors.background)
                } else if let err = loadError {
                    VStack(spacing: 16) {
                        Text(err).foregroundColor(colors.danger).multilineTextAlignment(.center).padding()
                        Button("Retry") { Task { await loadDetail() } }.foregroundColor(colors.amber)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.background)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            editFormCard
                        }
                        .padding(20)
                    }
                    .background(colors.background)
                }
            }
            .navigationTitle(editNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss).foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundColor((loading || loadError != nil || saving) ? colors.muted : colors.amber)
                        .disabled(loading || loadError != nil || saving || tailNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task { await loadDetail() }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private var editNavigationTitle: String {
        let t = tailNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Edit Aircraft" : "Edit \(t)"
    }

    private var editFormCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit aircraft details.")
                .font(.subheadline)
                .foregroundColor(colors.muted)

            field("Tail number", $tailNumber, prompt: "N12345")
                .textInputAutocapitalization(.characters)
            HStack(spacing: 12) {
                field("Make", $make, prompt: "Cessna")
                field("Model", $model, prompt: "206")
            }
            HStack(spacing: 12) {
                field("Year", $year, prompt: "", keyboard: .numberPad)
                field("Airframe serial #", $serialNumber, prompt: "Factory S/N")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("STATUS").font(.system(size: 10, weight: .bold)).foregroundColor(colors.muted).tracking(1)
                Picker("", selection: $status) {
                    ForEach(statusOptions, id: \.0) { opt in
                        Text(opt.1).tag(opt.0)
                    }
                }
                .pickerStyle(.segmented)
            }
            HStack(spacing: 12) {
                field("Current Hobbs", $currentHobbs, prompt: "1234.5", keyboard: .decimalPad)
                field("Current Tach", $currentTach, prompt: "1234.5", keyboard: .decimalPad)
            }
            HStack(spacing: 12) {
                field("Min pax/load", $minPaxPerLoad, prompt: "1", keyboard: .numberPad)
                field("Max pax/load", $maxPaxPerLoad, prompt: "4", keyboard: .numberPad)
            }
            field("Load time (min)", $loadTimeMinutes, prompt: "30", keyboard: .numberPad)

            Toggle(isOn: $isMultiEngine) {
                Text("Multi engine").foregroundColor(colors.text)
            }
            .tint(colors.accent)

            editSectionTitle("Inspection checklist")
            Toggle(isOn: $hasFloats) {
                Text("Has floats").foregroundColor(colors.text)
            }
            .tint(colors.accent)
            Text("When on, the C206 inspection checklist includes a Floats section.")
                .font(.caption)
                .foregroundColor(colors.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !isMultiEngine {
                editSectionTitle("Engine (single)")
                HStack(spacing: 12) {
                    field("Engine make", $engineMake, prompt: "Lycoming")
                    field("Engine model", $engineModel, prompt: "IO-540")
                }
                HStack(spacing: 12) {
                    field("Engine serial #", $engineSerial, prompt: "")
                    field("Engine TT", $engineTT, prompt: "1234.5", keyboard: .decimalPad)
                }
                field("Engine TSMOH", $engineTSMOH, prompt: "500.0", keyboard: .decimalPad)

                editSectionTitle("Prop (single)")
                HStack(spacing: 12) {
                    field("Make", $propMake, prompt: "McCauley")
                    field("Model", $propModel, prompt: "e.g. 1A170")
                }
                HStack(spacing: 12) {
                    field("Serial #", $propSerial, prompt: "")
                    field("TTP", $propTT, prompt: "1234.5", keyboard: .decimalPad)
                }
                field("TSOH", $propTSOH, prompt: "500.0", keyboard: .decimalPad)
            } else {
                editSectionTitle("Left engine")
                HStack(spacing: 12) {
                    field("Make", $leftEngineMake, prompt: "Lycoming")
                    field("Model", $leftEngineModel, prompt: "IO-540")
                }
                HStack(spacing: 12) {
                    field("Serial #", $leftEngineSerial, prompt: "")
                    field("TT", $leftEngineTT, prompt: "1234.5", keyboard: .decimalPad)
                }
                field("TSMOH", $leftEngineTSMOH, prompt: "500.0", keyboard: .decimalPad)

                editSectionTitle("Right engine")
                HStack(spacing: 12) {
                    field("Make", $rightEngineMake, prompt: "Lycoming")
                    field("Model", $rightEngineModel, prompt: "IO-540")
                }
                HStack(spacing: 12) {
                    field("Serial #", $rightEngineSerial, prompt: "")
                    field("TT", $rightEngineTT, prompt: "1234.5", keyboard: .decimalPad)
                }
                field("TSMOH", $rightEngineTSMOH, prompt: "500.0", keyboard: .decimalPad)

                editSectionTitle("Left prop")
                HStack(spacing: 12) {
                    field("Make", $leftPropMake, prompt: "McCauley")
                    field("Model", $leftPropModel, prompt: "")
                }
                HStack(spacing: 12) {
                    field("Serial #", $leftPropSerial, prompt: "")
                    field("TTP", $leftPropTT, prompt: "1234.5", keyboard: .decimalPad)
                }
                field("TSOH", $leftPropTSOH, prompt: "500.0", keyboard: .decimalPad)

                editSectionTitle("Right prop")
                HStack(spacing: 12) {
                    field("Make", $rightPropMake, prompt: "McCauley")
                    field("Model", $rightPropModel, prompt: "")
                }
                HStack(spacing: 12) {
                    field("Serial #", $rightPropSerial, prompt: "")
                    field("TTP", $rightPropTT, prompt: "1234.5", keyboard: .decimalPad)
                }
                field("TSOH", $rightPropTSOH, prompt: "500.0", keyboard: .decimalPad)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(4...12)
                    .font(.system(size: 16))
                    .foregroundColor(colors.text)
                    .padding(12)
                    .background(colors.background)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private func editSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(colors.text)
            .padding(.top, 6)
    }

    private func field(_ label: String, _ binding: Binding<String>, prompt: String = "", keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
            TextField(prompt, text: binding)
                .keyboardType(keyboard)
                .font(.system(size: 16))
                .foregroundColor(colors.text)
                .padding(12)
                .background(colors.background)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        }
    }

    private func loadDetail() async {
        loading = true
        loadError = nil
        defer { loading = false }

        guard let token = KeychainHelper.readToken() else {
            loadError = "Not signed in"
            return
        }
        let urls = ["\(kServerURL)/api/aircraft/detail.php?id=\(aircraft.id)", "\(kServerURL)/api/aircraft/detail?id=\(aircraft.id)"]
        guard let url = urls.compactMap({ URL(string: $0) }).first else {
            loadError = "Bad URL"
            return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                AuthManager.shared.logout()
                loadError = "Session expired"
                return
            }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = root["ok"] as? Bool, ok,
                  let ac = root["aircraft"] as? [String: Any] else {
                loadError = "Could not load aircraft"
                return
            }
            tailNumber = stringVal(ac["tail_number"])
            make = stringVal(ac["make"])
            model = stringVal(ac["model"])
            serialNumber = stringVal(ac["serial_number"])
            notes = stringVal(ac["notes"])
            status = (stringVal(ac["status"]).isEmpty ? "active" : stringVal(ac["status"]).lowercased())
            if !["active", "inactive", "maintenance"].contains(status) { status = "active" }
            year = {
                if let y = ac["year"] as? Int { return "\(y)" }
                if let y = ac["year"] as? Double { return "\(Int(y))" }
                return ""
            }()
            minPaxPerLoad = intStr(ac["min_pax_per_load"], fallback: "1")
            maxPaxPerLoad = intStr(ac["max_pax_per_load"], fallback: "4")
            loadTimeMinutes = intStr(ac["load_time_minutes"], fallback: "30")
            needsFuel = boolVal(ac["needs_fuel"])
            isJumpable = ac["is_jumpable"] == nil ? true : boolVal(ac["is_jumpable"])
            hasFloats = boolVal(ac["has_floats"])
            currentHobbs = numStr(ac["current_hobbs"])
            currentTach = numStr(ac["current_tach"])

            engineMake = stringVal(ac["engine_make"])
            engineModel = stringVal(ac["engine_model"])
            engineSerial = stringVal(ac["engine_serial"])
            engineTT = numStr(ac["engine_tt"])
            engineTSMOH = numStr(ac["engine_tsmoh"])
            propMake = stringVal(ac["prop_make"])
            propModel = stringVal(ac["prop_model"])
            propSerial = stringVal(ac["prop_serial"])
            propTT = numStr(ac["prop_tt"])
            propTSOH = numStr(ac["prop_tso"])

            leftEngineMake = stringVal(ac["left_engine_make"])
            leftEngineModel = stringVal(ac["left_engine_model"])
            leftEngineSerial = stringVal(ac["left_engine_serial"])
            leftEngineTT = numStr(ac["left_engine_tt"])
            leftEngineTSMOH = numStr(ac["left_engine_tsmoh"])
            rightEngineMake = stringVal(ac["right_engine_make"])
            rightEngineModel = stringVal(ac["right_engine_model"])
            rightEngineSerial = stringVal(ac["right_engine_serial"])
            rightEngineTT = numStr(ac["right_engine_tt"])
            rightEngineTSMOH = numStr(ac["right_engine_tsmoh"])

            leftPropMake = stringVal(ac["left_prop_make"])
            leftPropModel = stringVal(ac["left_prop_model"])
            leftPropSerial = stringVal(ac["left_prop_serial"])
            leftPropTT = numStr(ac["left_prop_tt"])
            leftPropTSOH = numStr(ac["left_prop_tso"])
            rightPropMake = stringVal(ac["right_prop_make"])
            rightPropModel = stringVal(ac["right_prop_model"])
            rightPropSerial = stringVal(ac["right_prop_serial"])
            rightPropTT = numStr(ac["right_prop_tt"])
            rightPropTSOH = numStr(ac["right_prop_tso"])

            if let b = ac["is_multi_engine"] as? Bool {
                isMultiEngine = b
            } else if let i = ac["is_multi_engine"] as? Int {
                isMultiEngine = i != 0
            } else {
                isMultiEngine = aircraft.isMultiEngine ?? false
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func stringVal(_ v: Any?) -> String {
        guard let v, !(v is NSNull) else { return "" }
        return "\(v)".trimmingCharacters(in: .whitespaces)
    }

    private func numStr(_ v: Any?) -> String {
        guard let v, !(v is NSNull) else { return "" }
        if let d = v as? Double {
            if abs(d.rounded() - d) < 1e-9 { return String(Int(d.rounded())) }
            return String(d)
        }
        if let i = v as? Int { return "\(i)" }
        return "\(v)"
    }

    private func boolVal(_ v: Any?) -> Bool {
        if let b = v as? Bool { return b }
        if let i = v as? Int { return i != 0 }
        return false
    }

    private func intStr(_ v: Any?, fallback: String) -> String {
        guard let v, !(v is NSNull) else { return fallback }
        if let i = v as? Int { return "\(i)" }
        if let d = v as? Double { return "\(Int(d))" }
        let s = "\(v)".trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? fallback : s
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
            "id": aircraft.id,
            "tail_number": tailNumber.trimmingCharacters(in: .whitespaces),
            "make": make.trimmingCharacters(in: .whitespaces),
            "model": model.trimmingCharacters(in: .whitespaces),
            "serial_number": serialNumber.trimmingCharacters(in: .whitespaces),
            "status": status,
            "notes": notes.trimmingCharacters(in: .whitespaces),
            "is_multi_engine": isMultiEngine,
            "has_floats": hasFloats,
            "needs_fuel": needsFuel,
            "is_jumpable": isJumpable,
        ]
        if let y = Int(year.trimmingCharacters(in: .whitespaces)), y > 1900, y < 2100 {
            payload["year"] = y
        }

        let minP = Int(minPaxPerLoad.trimmingCharacters(in: .whitespaces)) ?? 1
        let maxP = Int(maxPaxPerLoad.trimmingCharacters(in: .whitespaces)) ?? 4
        payload["min_pax_per_load"] = min(20, max(1, minP))
        payload["max_pax_per_load"] = min(30, max(1, maxP))
        let loadT = Int(loadTimeMinutes.trimmingCharacters(in: .whitespaces)) ?? 30
        payload["load_time_minutes"] = min(120, max(0, loadT))

        if let v = Double(currentHobbs.trimmingCharacters(in: .whitespaces)) { payload["current_hobbs"] = v }
        if let v = Double(currentTach.trimmingCharacters(in: .whitespaces)) { payload["current_tach"] = v }

        if !isMultiEngine {
            payload["engine_make"] = engineMake.trimmingCharacters(in: .whitespaces)
            payload["engine_model"] = engineModel.trimmingCharacters(in: .whitespaces)
            payload["engine_serial"] = engineSerial.trimmingCharacters(in: .whitespaces)
            if let v = Double(engineTT.trimmingCharacters(in: .whitespaces)) { payload["engine_tt"] = v }
            if let v = Double(engineTSMOH.trimmingCharacters(in: .whitespaces)) { payload["engine_tsmoh"] = v }
            payload["prop_make"] = propMake.trimmingCharacters(in: .whitespaces)
            payload["prop_model"] = propModel.trimmingCharacters(in: .whitespaces)
            payload["prop_serial"] = propSerial.trimmingCharacters(in: .whitespaces)
            if let v = Double(propTT.trimmingCharacters(in: .whitespaces)) { payload["prop_tt"] = v }
            if let v = Double(propTSOH.trimmingCharacters(in: .whitespaces)) { payload["prop_tso"] = v }
        } else {
            payload["left_engine_make"] = leftEngineMake.trimmingCharacters(in: .whitespaces)
            payload["left_engine_model"] = leftEngineModel.trimmingCharacters(in: .whitespaces)
            payload["left_engine_serial"] = leftEngineSerial.trimmingCharacters(in: .whitespaces)
            if let v = Double(leftEngineTT.trimmingCharacters(in: .whitespaces)) { payload["left_engine_tt"] = v }
            if let v = Double(leftEngineTSMOH.trimmingCharacters(in: .whitespaces)) { payload["left_engine_tsmoh"] = v }
            payload["right_engine_make"] = rightEngineMake.trimmingCharacters(in: .whitespaces)
            payload["right_engine_model"] = rightEngineModel.trimmingCharacters(in: .whitespaces)
            payload["right_engine_serial"] = rightEngineSerial.trimmingCharacters(in: .whitespaces)
            if let v = Double(rightEngineTT.trimmingCharacters(in: .whitespaces)) { payload["right_engine_tt"] = v }
            if let v = Double(rightEngineTSMOH.trimmingCharacters(in: .whitespaces)) { payload["right_engine_tsmoh"] = v }

            payload["left_prop_make"] = leftPropMake.trimmingCharacters(in: .whitespaces)
            payload["left_prop_model"] = leftPropModel.trimmingCharacters(in: .whitespaces)
            payload["left_prop_serial"] = leftPropSerial.trimmingCharacters(in: .whitespaces)
            if let v = Double(leftPropTT.trimmingCharacters(in: .whitespaces)) { payload["left_prop_tt"] = v }
            if let v = Double(leftPropTSOH.trimmingCharacters(in: .whitespaces)) { payload["left_prop_tso"] = v }
            payload["right_prop_make"] = rightPropMake.trimmingCharacters(in: .whitespaces)
            payload["right_prop_model"] = rightPropModel.trimmingCharacters(in: .whitespaces)
            payload["right_prop_serial"] = rightPropSerial.trimmingCharacters(in: .whitespaces)
            if let v = Double(rightPropTT.trimmingCharacters(in: .whitespaces)) { payload["right_prop_tt"] = v }
            if let v = Double(rightPropTSOH.trimmingCharacters(in: .whitespaces)) { payload["right_prop_tso"] = v }
        }

        let base = kServerURL.hasSuffix("/") ? String(kServerURL.dropLast()) : kServerURL
        let paths = [
            "/api/aircraft",
            "/api/aircraft/detail.php",
            "/api/aircraft/detail",
            "/api/aircraft/update.php",
            "/api/aircraft/update",
            "/api/aircraft.php",
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            error = "Could not build request"
            return
        }

        do {
            var lastStatus = 0
            var lastBody = ""
            for path in paths {
                guard let url = URL(string: base + path) else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "PUT"
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
                struct R: Decodable { let ok: Bool; let error: String? }
                if let r = try? JSONDecoder().decode(R.self, from: data) {
                    if r.ok {
                        onSaved()
                        onDismiss()
                        return
                    }
                    error = r.error ?? "Save failed"
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
                ? "Aircraft update API not found (HTTP \(lastStatus)). Deploy FastAPI with PUT /api/aircraft/detail.php or route /api/* to uvicorn."
                : (lastBody.isEmpty ? "Could not save aircraft" : lastBody)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Image picker (camera or photo library) for logbook/STC scans
private struct AircraftImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AircraftImagePicker
        init(_ parent: AircraftImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.imageData = img.jpegData(compressionQuality: 0.85)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

// MARK: - Add Squawk
private struct AddSquawkSheet: View {
    let aircraft: Aircraft
    @ObservedObject var vm: AircraftDetailViewModel
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @Environment(\.mdzColors) private var colors
    @State private var title = ""
    @State private var description = ""
    @State private var status = "open"
    @State private var priority = "normal"
    @State private var squawkDate = ""
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Title", text: $title).textInputAutocapitalization(.sentences) }
                Section { TextField("Description (optional)", text: $description, axis: .vertical).lineLimit(3...) }
                Section {
                    Picker("Status", selection: $status) {
                        Text("Open").tag("open"); Text("Deferred").tag("deferred"); Text("Closed").tag("closed")
                    }
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag("low"); Text("Normal").tag("normal"); Text("High").tag("high"); Text("Critical").tag("critical")
                    }
                    TextField("Date (YYYY-MM-DD)", text: $squawkDate).keyboardType(.numbersAndPunctuation)
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundColor(colors.danger).font(.caption) }
                }
            }
            .scrollContentBackground(.hidden).background(colors.background)
            .navigationTitle("Add Squawk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss).foregroundColor(colors.amber) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.fontWeight(.semibold).foregroundColor(colors.amber).disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if squawkDate.isEmpty { squawkDate = Self.todayString() } }
        }
    }
    private static func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
    private func save() async {
        saving = true; errorMessage = nil; defer { saving = false }
        let (_, err) = await vm.postSquawk(aircraftId: aircraft.id, title: title.trimmingCharacters(in: .whitespaces), description: description.trimmingCharacters(in: .whitespaces), status: status, priority: priority, squawkDate: squawkDate.isEmpty ? Self.todayString() : squawkDate)
        if err != nil { errorMessage = err; return }
        onSaved(); onDismiss()
    }
}

// MARK: - Add AD
private struct AddAdSheet: View {
    let aircraft: Aircraft
    @ObservedObject var vm: AircraftDetailViewModel
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @Environment(\.mdzColors) private var colors
    @State private var category = "airframe"
    @State private var adNumber = ""
    @State private var title = ""
    @State private var notes = ""
    @State private var lastCompliedDate = ""
    @State private var nextDueDate = ""
    @State private var statusOverride = "ok"
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        Text("Airframe").tag("airframe"); Text("Engine").tag("engine"); Text("Prop").tag("prop")
                    }
                    TextField("AD Number", text: $adNumber).textInputAutocapitalization(.none)
                    TextField("Title", text: $title).textInputAutocapitalization(.sentences)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...)
                }
                Section {
                    TextField("Last complied (YYYY-MM-DD)", text: $lastCompliedDate).keyboardType(.numbersAndPunctuation)
                    TextField("Next due (YYYY-MM-DD)", text: $nextDueDate).keyboardType(.numbersAndPunctuation)
                    Picker("Status", selection: $statusOverride) {
                        Text("OK").tag("ok"); Text("Due").tag("due"); Text("Overdue").tag("overdue")
                    }
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundColor(colors.danger).font(.caption) }
                }
            }
            .scrollContentBackground(.hidden).background(colors.background)
            .navigationTitle("Add AD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss).foregroundColor(colors.amber) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.fontWeight(.semibold).foregroundColor(colors.amber).disabled(saving)
                }
            }
        }
    }
    private func save() async {
        saving = true; errorMessage = nil; defer { saving = false }
        let (_, err) = await vm.postAd(aircraftId: aircraft.id, category: category, adNumber: adNumber, title: title, notes: notes, lastCompliedDate: lastCompliedDate, nextDueDate: nextDueDate, statusOverride: statusOverride)
        if err != nil { errorMessage = err; return }
        onSaved(); onDismiss()
    }
}

// MARK: - Add Logbook Entry (with camera/photo) — aircraft maintenance logbook
private struct AddAircraftLogbookEntrySheet: View {
    let aircraft: Aircraft
    @ObservedObject var vm: AircraftDetailViewModel
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @Environment(\.mdzColors) private var colors
    @State private var entryDate = ""
    @State private var description = ""
    @State private var bookType = "airframe"
    @State private var tachTime = ""
    @State private var hobbsTime = ""
    @State private var mechanicName = ""
    @State private var mechanicRating = ""
    @State private var imageData: Data?
    @State private var showImageSource = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Date (YYYY-MM-DD)", text: $entryDate).keyboardType(.numbersAndPunctuation)
                    TextField("Description", text: $description, axis: .vertical).lineLimit(3...)
                    Picker("Book type", selection: $bookType) {
                        Text("Aircraft").tag("airframe"); Text("Engine").tag("engine"); Text("Prop").tag("prop")
                    }
                    TextField("Tach time", text: $tachTime).keyboardType(.decimalPad)
                    TextField("Hobbs time", text: $hobbsTime).keyboardType(.decimalPad)
                    TextField("Performed by", text: $mechanicName)
                    TextField("Rating", text: $mechanicRating)
                }
                Section(header: Text("Photo / Scan")) {
                    Button {
                        showImageSource = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill").foregroundColor(colors.primary)
                            Text(imageData == nil ? "Take photo or choose from library" : "Photo attached (tap to change)")
                                .foregroundColor(colors.text)
                        }
                    }
                    .confirmationDialog("Add photo", isPresented: $showImageSource) {
                        Button("Take Photo") { showCamera = true }
                        Button("Choose from Library") { showPhotoLibrary = true }
                        Button("Cancel", role: .cancel) { }
                    }
                    if imageData != nil {
                        Image(uiImage: UIImage(data: imageData!) ?? UIImage())
                            .resizable().scaledToFit().frame(maxHeight: 120).cornerRadius(8)
                    }
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundColor(colors.danger).font(.caption) }
                }
            }
            .scrollContentBackground(.hidden).background(colors.background)
            .navigationTitle("Add Logbook Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss).foregroundColor(colors.amber) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.fontWeight(.semibold).foregroundColor(colors.amber).disabled(saving || description.trimmingCharacters(in: .whitespaces).isEmpty || entryDate.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                AircraftImagePicker(sourceType: .camera, imageData: $imageData)
            }
            .fullScreenCover(isPresented: $showPhotoLibrary) {
                AircraftImagePicker(sourceType: .photoLibrary, imageData: $imageData)
            }
            .onAppear { if entryDate.isEmpty { entryDate = Self.todayString() } }
        }
    }
    private static func todayString() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }
    private func save() async {
        saving = true; errorMessage = nil; defer { saving = false }
        let (_, err) = await vm.postLogbook(aircraftId: aircraft.id, entryDate: entryDate.isEmpty ? Self.todayString() : entryDate, description: description.trimmingCharacters(in: .whitespaces), bookType: bookType, tachTime: tachTime, hobbsTime: hobbsTime, mechanicName: mechanicName, mechanicRating: mechanicRating, imageData: imageData)
        if err != nil { errorMessage = err; return }
        onSaved(); onDismiss()
    }
}

// MARK: - Add STC/337 (with camera/photo)
private struct AddStc337Sheet: View {
    let aircraft: Aircraft
    @ObservedObject var vm: AircraftDetailViewModel
    let onDismiss: () -> Void
    let onSaved: () -> Void
    @Environment(\.mdzColors) private var colors
    @State private var recordType = "stc"
    @State private var title = ""
    @State private var description = ""
    @State private var stcNumber = ""
    @State private var form337Number = ""
    @State private var entryDate = ""
    @State private var approvalDate = ""
    @State private var fieldApproval = ""
    @State private var imageData: Data?
    @State private var showImageSource = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $recordType) {
                        Text("STC").tag("stc"); Text("Form 337").tag("form337")
                    }
                    TextField("Title", text: $title).textInputAutocapitalization(.sentences)
                    TextField("Description", text: $description, axis: .vertical).lineLimit(2...)
                    TextField("STC number", text: $stcNumber).textInputAutocapitalization(.none)
                    TextField("Form 337 number", text: $form337Number).textInputAutocapitalization(.none)
                    TextField("Entry date (YYYY-MM-DD)", text: $entryDate).keyboardType(.numbersAndPunctuation)
                    TextField("Approval date (YYYY-MM-DD)", text: $approvalDate).keyboardType(.numbersAndPunctuation)
                    TextField("Field approval", text: $fieldApproval)
                }
                Section(header: Text("Photo / Scan")) {
                    Button {
                        showImageSource = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill").foregroundColor(colors.primary)
                            Text(imageData == nil ? "Take photo or choose from library" : "Photo attached (tap to change)")
                                .foregroundColor(colors.text)
                        }
                    }
                    .confirmationDialog("Add photo", isPresented: $showImageSource) {
                        Button("Take Photo") { showCamera = true }
                        Button("Choose from Library") { showPhotoLibrary = true }
                        Button("Cancel", role: .cancel) { }
                    }
                    if imageData != nil {
                        Image(uiImage: UIImage(data: imageData!) ?? UIImage())
                            .resizable().scaledToFit().frame(maxHeight: 120).cornerRadius(8)
                    }
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundColor(colors.danger).font(.caption) }
                }
            }
            .scrollContentBackground(.hidden).background(colors.background)
            .navigationTitle("Add STC/337")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss).foregroundColor(colors.amber) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.fontWeight(.semibold).foregroundColor(colors.amber).disabled(saving)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                AircraftImagePicker(sourceType: .camera, imageData: $imageData)
            }
            .fullScreenCover(isPresented: $showPhotoLibrary) {
                AircraftImagePicker(sourceType: .photoLibrary, imageData: $imageData)
            }
            .onAppear { if entryDate.isEmpty { entryDate = Self.todayString() } }
        }
    }
    private static func todayString() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }
    private func save() async {
        saving = true; errorMessage = nil; defer { saving = false }
        let (_, err) = await vm.postStc337(aircraftId: aircraft.id, recordType: recordType, title: title, description: description, stcNumber: stcNumber, form337Number: form337Number, entryDate: entryDate, approvalDate: approvalDate, fieldApproval: fieldApproval, imageData: imageData)
        if err != nil { errorMessage = err; return }
        onSaved(); onDismiss()
    }
}
