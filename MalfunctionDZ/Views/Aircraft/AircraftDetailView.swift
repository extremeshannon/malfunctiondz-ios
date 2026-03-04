// File: ASC/Views/Aircraft/AircraftDetailView.swift
// Change from previous version: added PAX tab (index 3), logbook filter, detail view, thumbnails
import SwiftUI

struct AircraftDetailView: View {
    let aircraft: Aircraft
    var isReadOnly: Bool = false
    @StateObject private var vm = AircraftDetailViewModel()
    @State private var selectedTab = 0
    @State private var logbookFilter = "all"
    @State private var selectedLogbookEntry: LogbookEntry?
    @State private var enlargedImageURL: URL?

    private let logbookFilters = [("all", "All"), ("airframe", "Aircraft"), ("engine", "Engine"), ("prop", "Prop")]

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(aircraft.tailNumber)
                            .font(.title.bold().monospaced())
                            .foregroundColor(.mdzText)
                        Spacer()
                        StatusPill(label: aircraft.status.uppercased(), color: aircraft.statusColor)
                    }
                    Text(aircraft.model)
                        .font(.subheadline)
                        .foregroundColor(.mdzMuted)
                    if let annual = aircraft.annualDue {
                        InfoRow(label: "Annual Due", value: annual)
                    }
                    if let next100 = aircraft.next100hrDue {
                        InfoRow(label: "100hr Due", value: next100)
                    }
                    if let oil = aircraft.lastOilChange {
                        InfoRow(label: "Last Oil Change", value: oil)
                    }
                }
                .padding()
                .background(Color.mdzCard)

                // Tab picker — now 4 tabs
                Picker("", selection: $selectedTab) {
                    Text("Squawks").tag(0)
                    Text("Logbook").tag(1)
                    Text("ADs").tag(2)
                    Text("PAX").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.mdzNavyMid)

                // Tab content — frame so all tabs (Squawks, Logbook, ADs, PAX) use full width on iPad
                Group {
                    switch selectedTab {
                    case 0: squawksTab
                    case 1: logbookTab
                    case 2: adsTab
                    case 3: PaxView(aircraft: aircraft, isReadOnly: isReadOnly)
                    default: squawksTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.mdzBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(aircraft.tailNumber)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadDetail(aircraftId: aircraft.id) }
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
                                .foregroundColor(.mdzText)
                            Spacer()
                            StatusPill(label: squawk.status.uppercased(), color: squawk.statusColor)
                        }
                        if let by = squawk.reportedBy, let at = squawk.reportedAt {
                            Text("Reported \(at) · \(by)")
                                .font(.caption)
                                .foregroundColor(.mdzMuted)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.mdzCard)
                    .listRowSeparatorTint(Color.mdzBorder)
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
                                    .foregroundColor(logbookFilter == key ? .mdzBackground : .mdzText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(logbookFilter == key ? Color.mdzBlue : Color.mdzCard)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color.mdzNavyMid)

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
                        .listRowBackground(Color.mdzCard)
                        .listRowSeparatorTint(Color.mdzBorder)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await vm.loadLogbook(aircraftId: aircraft.id, bookType: logbookFilter)
                    }
                }
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
                            Text(ad.adNumber).font(.caption.monospaced()).foregroundColor(.mdzBlue)
                            Spacer()
                            StatusPill(
                                label: ad.status.uppercased(),
                                color: ad.status == "complied" ? .mdzGreen : .mdzAmber
                            )
                        }
                        Text(ad.description).font(.subheadline).foregroundColor(.mdzText)
                        if let due = ad.dueDate {
                            Text("Due: \(due)").font(.caption).foregroundColor(.mdzAmber)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.mdzCard)
                    .listRowSeparatorTint(Color.mdzBorder)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let url = entry.thumbnailURL() {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").foregroundColor(.mdzMuted)
                    default: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: 56, height: 40)
                .clipped()
                .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.mdzBorder.opacity(0.5))
                    .frame(width: 56, height: 40)
                    .overlay(Image(systemName: "doc").foregroundColor(.mdzMuted).font(.system(size: 18)))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.date).font(.caption).foregroundColor(.mdzMuted)
                    Spacer()
                    Text(entry.bookTypeLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.mdzBlue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.mdzBlue.opacity(0.2))
                        .cornerRadius(4)
                }
                if let t = entry.tachTime {
                    Text(String(format: "Tach %.1f", t)).font(.caption2).foregroundColor(.mdzBlue)
                }
                Text(entry.description)
                    .font(.subheadline)
                    .foregroundColor(.mdzText)
                    .lineLimit(2)
                if let by = entry.performedBy {
                    Text(by).font(.caption).foregroundColor(.mdzMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mdzMuted)
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                if vm.logbookDetailLoading && vm.logbookDetail == nil {
                    VStack(spacing: 16) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzBlue)).scaleEffect(1.2)
                        Text("Loading entry…").font(.subheadline).foregroundColor(.mdzMuted)
                    }
                } else if let detail = vm.logbookDetail {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Entry card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(detail.bookTypeLabel)
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.mdzBlue)
                                        .tracking(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.mdzBlue.opacity(0.2))
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
                                        .foregroundColor(.mdzMuted)
                                        .tracking(1)
                                    Text(detail.description)
                                        .font(.system(size: 15))
                                        .foregroundColor(.mdzText)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mdzCard)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mdzBorder, lineWidth: 1))

                            // Images
                            if !detail.images.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("ATTACHMENTS")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.mdzMuted)
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
                                                    case .failure: Image(systemName: "photo").foregroundColor(.mdzMuted)
                                                    default: ProgressView()
                                                    }
                                                }
                                                .frame(minWidth: 0, maxWidth: .infinity)
                                                .aspectRatio(4/3, contentMode: .fill)
                                                .clipped()
                                                .cornerRadius(10)
                                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .foregroundColor(.mdzAmber)
                }
            }
        }
    }
}
