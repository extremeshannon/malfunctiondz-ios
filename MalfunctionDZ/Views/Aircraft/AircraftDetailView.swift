// File: ASC/Views/Aircraft/AircraftDetailView.swift
// Change from previous version: added PAX tab (index 3), logbook filter, detail view, thumbnails
import SwiftUI
import PhotosUI

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
        let (id, err) = await vm.postSquawk(aircraftId: aircraft.id, title: title.trimmingCharacters(in: .whitespaces), description: description.trimmingCharacters(in: .whitespaces), status: status, priority: priority, squawkDate: squawkDate.isEmpty ? Self.todayString() : squawkDate)
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
