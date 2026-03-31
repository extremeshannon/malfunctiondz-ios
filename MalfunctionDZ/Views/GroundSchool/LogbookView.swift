// File: ASC/Views/GroundSchool/LogbookView.swift
// Purpose: Skydiver logbook — list of jumps, stats, detail view, signature capture.
import SwiftUI
import PencilKit
import MalfunctionDZCore

struct LogbookView: View {
    /// nil = standalone "My Logbook" (all entries); non-nil = logbook for that course
    let courseId: Int?
    let courseTitle: String
    /// When true, back button is hidden (e.g. when used as tab/sidebar root)
    private var isStandaloneRoot: Bool = false

    @StateObject private var vm = LogbookViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var showAddEntry = false
    @State private var showConfigSheet = false

    /// Standalone logbook — all entries, no LMS course (for skydivers without LMS access)
    static func standalone() -> LogbookView {
        LogbookView(courseId: nil, courseTitle: "My Logbook", isStandaloneRoot: true)
    }

    init(courseId: Int?, courseTitle: String, isStandaloneRoot: Bool = false) {
        self.courseId = courseId
        self.courseTitle = courseTitle
        self.isStandaloneRoot = isStandaloneRoot
    }

    private var isStandalone: Bool { courseId == nil }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            if vm.isLoading && vm.entries.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.amber)).scaleEffect(1.2)
                    Text("Loading logbook…").font(.subheadline).foregroundColor(colors.muted)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LOGBOOK")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.amber)
                                .tracking(2)
                            Text(courseTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(colors.text)
                        }

                        // Config + Add (standalone only) — config moved to gear sheet
                        if isStandalone {
                            if vm.isSkydiver {
                                addJumpButton
                            } else if vm.isStudent {
                                studentNoteCard
                            }
                        }

                        if vm.entries.isEmpty {
                            EmptyStateView(
                                icon: "book.closed",
                                title: "No logbook entries yet",
                                subtitle: courseId == nil
                                    ? "Tap Add Jump to log a jump, or entries appear when an instructor signs off."
                                    : "Jump sign-offs from this course will appear here. Entries are added when an instructor signs off a jump."
                            )
                            .padding(.vertical, 24)
                        } else {
                            // Stats bar (standalone only)
                            if isStandalone {
                                logbookStatsBar
                            }
                            // List of jumps (clickable)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("JUMPS")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(colors.muted)
                                    .tracking(1)
                                ForEach(vm.entries.reversed()) { entry in
                                    NavigationLink(destination: LogbookEntryDetailView(entry: entry, vm: vm)) {
                                        LogbookEntryRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Other training / comments (from reference)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Other training / comments")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(colors.muted)
                            Text(vm.otherTrainingNotes.isEmpty ? " " : vm.otherTrainingNotes)
                                .font(.system(size: 14))
                                .foregroundColor(colors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(colors.card)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(20)
                }
                .refreshable { await vm.load(courseId: courseId) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isStandalone && isStandaloneRoot {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showConfigSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(colors.muted)
                    }
                }
            }
            if !isStandaloneRoot {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.amber)
                    }
                }
            }
        }
        .task { await vm.load(courseId: courseId, userId: nil) }
        .sheet(isPresented: $showAddEntry) {
            addEntrySheet
        }
        .sheet(isPresented: $showConfigSheet) {
            LogbookConfigSheet(vm: vm) {
                showConfigSheet = false
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    private var addJumpButton: some View {
        Button {
            showAddEntry = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(colors.green)
                Text("Add Jump #\(vm.nextJumpNumber)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colors.muted)
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.green.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(vm.isSaving)
    }

    private var logbookStatsBar: some View {
        let latest = vm.entries.last
        let timeSinceLast = latest.flatMap { entry -> String? in
            guard let dateStr = entry.date else { return nil }
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            guard let d = f.date(from: dateStr) else { return nil }
            let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
            if days == 0 { return "Today" }
            if days == 1 { return "1 day ago" }
            if days < 7 { return "\(days) days ago" }
            if days < 30 { return "\(days / 7) wk ago" }
            return "\(days / 30) mo ago"
        } ?? "—"
        return HStack(spacing: 0) {
            StatCell(label: "JUMPS", value: "\(vm.totalJumps)")
            Divider().frame(height: 36).background(colors.border)
            StatCell(
                label: "FREEFALL",
                value: FreefallDurationFormatting.formatCumulativeSeconds(vm.totalFreefallSeconds)
            )
            Divider().frame(height: 36).background(colors.border)
            StatCell(label: "LAST JUMP", value: timeSinceLast)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    private var studentNoteCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 16))
                .foregroundColor(colors.amber)
            Text("Students need instructor sign-offs for logbook entries. At 25 jumps you'll become a skydiver and can add your own.")
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
        }
        .padding(12)
        .background(colors.amber.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.amber.opacity(0.3), lineWidth: 1))
    }

    private var addEntrySheet: some View {
        AddLogbookEntrySheet(
            vm: vm,
            nextJumpNumber: vm.nextJumpNumber,
            lastEntry: vm.entries.last,
            startFreefallTime: vm.startFreefallTime,
            defaultJumpType: vm.defaultJumpType,
            homeDropzone: vm.homeDropzone,
            onSave: { dz, altitude, delay, date, aircraft, equipment, rigId, jumpType, comments in
                Task {
                    await vm.addEntry(dz: dz, altitude: altitude, delay: delay, date: date, aircraft: aircraft,
                                     equipment: equipment, rigId: rigId, jumpType: jumpType, comments: comments)
                    showAddEntry = false
                }
            },
            onCancel: { showAddEntry = false }
        )
    }
}

// MARK: - Logbook Config (inline edit, single Save)
struct LogbookConfigSheet: View {
    @ObservedObject var vm: LogbookViewModel
    let onDismiss: () -> Void

    @State private var draftPriorJumps = ""
    @State private var draftPriorFreefallSec = ""
    @State private var draftDefaultFreefall = ""
    @State private var draftJumpType = ""
    @State private var draftHomeDz = ""

    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Edit settings on this screen, then tap Save.")
                            .font(.system(size: 13))
                            .foregroundColor(colors.muted)

                        configField(
                            title: "Prior jumps",
                            subtitle: "Jumps you had before using this system"
                        ) {
                            TextField("0", text: $draftPriorJumps)
                                .keyboardType(.numberPad)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(colors.text)
                        }

                        configField(
                            title: "Start freefall time",
                            subtitle: "Total freefall before this app (whole seconds). Adds to your cumulative total."
                        ) {
                            TextField("0", text: $draftPriorFreefallSec)
                                .keyboardType(.numberPad)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(colors.text)
                        }

                        configField(
                            title: "Default freefall per jump",
                            subtitle: "Prefills when adding a jump. Type digits; : appears after minutes (e.g. 130 → 1:30)."
                        ) {
                            TextField("e.g. 45 or 1:30", text: $draftDefaultFreefall)
                                .keyboardType(.numberPad)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(colors.text)
                                .onChange(of: draftDefaultFreefall) { _, newValue in
                                    let formatted = FreefallDurationFormatting.formatWhileTyping(newValue)
                                    if formatted != newValue {
                                        draftDefaultFreefall = formatted
                                    }
                                }
                        }

                        configField(
                            title: "Default jump type",
                            subtitle: "Prefills new jumps; you can still change each jump."
                        ) {
                            Picker("", selection: $draftJumpType) {
                                Text("None").tag("")
                                if !draftJumpType.isEmpty,
                                   LogbookJumpTypeOptions.all.first(where: { $0.value == draftJumpType }) == nil {
                                    Text(draftJumpType).tag(draftJumpType)
                                }
                                ForEach(0..<LogbookJumpTypeOptions.all.count, id: \.self) { i in
                                    let opt = LogbookJumpTypeOptions.all[i]
                                    Text(opt.label).tag(opt.value)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(colors.amber)
                        }

                        configField(
                            title: "Home dropzone",
                            subtitle: "Prefills DZ when adding a jump."
                        ) {
                            TextField("Drop zone name", text: $draftHomeDz)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(colors.text)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Logbook Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let pj = Int(draftPriorJumps.filter { $0.isNumber }) ?? 0
                            let pff = Int(draftPriorFreefallSec.filter { $0.isNumber }) ?? 0
                            let ok = await vm.saveLogbookSettings(
                                priorJumpCount: max(0, pj),
                                priorFreefallSeconds: max(0, pff),
                                startFreefallTime: draftDefaultFreefall,
                                defaultJumpType: draftJumpType,
                                homeDropzone: draftHomeDz
                            )
                            if ok { onDismiss() }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.amber)
                    .disabled(vm.isSaving)
                }
            }
            .onAppear {
                draftPriorJumps = "\(vm.priorJumpCount)"
                draftPriorFreefallSec = "\(vm.priorFreefallSeconds)"
                draftDefaultFreefall = vm.startFreefallTime
                draftJumpType = vm.defaultJumpType
                draftHomeDz = vm.homeDropzone
            }
        }
    }

    private func configField<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
        }
    }
}

// MARK: - Stat cell for stats bar
struct StatCell: View {
    let label: String
    let value: String
    @Environment(\.mdzColors) private var colors
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(colors.text)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact list row (clickable)
struct LogbookEntryRow: View {
    let entry: SkydiverLogbookEntry
    @Environment(\.mdzColors) private var colors
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.jumpNumber)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(colors.amber)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date ?? "—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.text)
                Text([entry.jumpType, entry.dz].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            Spacer()
            if entry.isSigned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(colors.green)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
    }
}

// MARK: - Entry detail (full info + signature)
struct LogbookEntryDetailView: View {
    let entry: SkydiverLogbookEntry
    @ObservedObject var vm: LogbookViewModel
    @State private var showSignaturePad = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    LogbookEntryCard(entry: entry)
                    if !entry.isLocked && !entry.isSigned {
                        Button {
                            showSignaturePad = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 18))
                                Text("Sign to lock this record")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(colors.amber)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(colors.amber.opacity(0.12))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.amber.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    signatureBlock
                }
                .padding(20)
            }
        }
        .navigationTitle("Jump #\(entry.jumpNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignaturePad) {
            SignaturePadSheet(entryId: entry.id, vm: vm, onComplete: {
                showSignaturePad = false
                dismiss()
            })
        }
    }

    /// Signature block — for phone-to-phone signing (placeholder for future)
    private var signatureBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIGNATURE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            VStack(alignment: .leading, spacing: 8) {
                if entry.isSigned {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(colors.green)
                        Text("Signed and locked")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colors.text)
                    }
                } else {
                    Text("Phone-to-phone signing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.text)
                    Text("Sign from another device — coming soon")
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(colors.card2)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
        }
    }
}

// MARK: - Signature pad (stylus/finger)
struct SignaturePadSheet: View {
    let entryId: Int
    @ObservedObject var vm: LogbookViewModel
    let onComplete: () -> Void
    @State private var canvasView = PKCanvasView()
    @State private var errorMsg: String?
    @Environment(\.mdzColors) private var colors
    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Draw your signature below")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(colors.text)
                    SignatureCanvasRepresentable(canvas: $canvasView)
                        .frame(height: 200)
                        .background(Color(red: 12/255, green: 29/255, blue: 53/255))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                    if let err = errorMsg {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Sign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete() }
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            let rect = canvasView.drawing.bounds
                            guard !rect.isEmpty else {
                                errorMsg = "Please draw your signature first"
                                return
                            }
                            let img = canvasView.drawing.image(from: rect, scale: 2)
                            guard let png = img.pngData() else {
                                errorMsg = "Could not capture signature"
                                return
                            }
                            let base64 = png.base64EncodedString()
                            await vm.signEntry(entryId: entryId, signatureBase64: base64)
                            if vm.error == nil {
                                onComplete()
                            } else {
                                errorMsg = vm.error
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.amber)
                    .disabled(vm.isSaving)
                }
            }
        }
    }
}

// MARK: - Signature canvas (PencilKit — finger/stylus)
struct SignatureCanvasRepresentable: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.tool = PKInkingTool(.pen, color: .label, width: 2)
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = UIColor(red: 12/255, green: 29/255, blue: 53/255, alpha: 1)
        canvas.isOpaque = false
        return canvas
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

// MARK: - Single entry card (printable-style layout)

struct LogbookEntryCard: View {
    let entry: SkydiverLogbookEntry
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Jump, DZ, Altitude, Delay
            LogbookGridRow(labels: ["Jump", "DZ", "Altitude", "Delay"],
                           values: [String(entry.jumpNumber), entry.dz ?? "", entry.altitude ?? "", entry.delay ?? ""])

            // Row 2: Date, Aircraft, Equipment, Total Time
            LogbookGridRow(labels: ["Date", "Aircraft", "Equipment", "Total Time"],
                           values: [entry.date ?? "", entry.aircraft ?? "", entry.equipmentDisplay ?? "", entry.totalTime ?? ""])

            // Jump Type
            LogbookFieldRow(label: "Jump Type", value: entry.jumpType ?? "")

            // Comments (large box)
            VStack(alignment: .leading, spacing: 6) {
                Text("Comments")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(colors.muted)
                Text(entry.comments?.isEmpty == false ? entry.comments! : " ")
                    .font(.system(size: 14))
                    .foregroundColor(colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 60)
                    .padding(10)
                    .background(colors.card2)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
            }

            // Result (pass/repeat)
            if entry.result != nil {
                HStack(spacing: 6) {
                    Text("Result")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(colors.muted)
                    Text(entry.resultDisplay)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(entry.result?.lowercased() == "pass" ? colors.green : colors.amber)
                }
            }

            // Signature
            HStack(spacing: 8) {
                Text("Signature")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(colors.muted)
                if entry.isSigned, let signedBy = entry.signedBy, !signedBy.isEmpty {
                    Text(signedBy)
                        .font(.system(size: 13))
                        .foregroundColor(colors.text)
                    if let lic = entry.instructorLicenseNumber, !lic.isEmpty {
                        Text("(\(lic))")
                            .font(.system(size: 11))
                            .foregroundColor(colors.muted)
                    }
                    if let at = entry.signedAt {
                        Text("· \(at)")
                            .font(.system(size: 11))
                            .foregroundColor(colors.muted)
                    }
                } else {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .background(colors.card2)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(colors.border, lineWidth: 1))
                }
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }
}

// MARK: - Grid row (4 columns like reference)

struct LogbookGridRow: View {
    let labels: [String]
    let values: [String]
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { item in
                    Text(item.element.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(colors.muted)
                        .tracking(0.5)
                    if item.offset < 3 { Spacer(minLength: 4) }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { item in
                    Text(item.element.isEmpty ? " " : item.element)
                        .font(.system(size: 13))
                        .foregroundColor(colors.text)
                    if item.offset < 3 { Spacer(minLength: 4) }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(colors.card2)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(colors.border, lineWidth: 1))
        }
    }
}

// MARK: - Add Logbook Entry Sheet

struct AddLogbookEntrySheet: View {
    @ObservedObject var vm: LogbookViewModel
    let nextJumpNumber: Int
    let lastEntry: SkydiverLogbookEntry?
    let startFreefallTime: String
    let defaultJumpType: String
    let homeDropzone: String
    let onSave: (String?, String?, String?, String?, String?, String?, Int?, String?, String?) -> Void
    let onCancel: () -> Void

    @State private var dz = ""
    @State private var altitude = ""
    @State private var delay = ""
    @State private var jumpDate = Date()
    @State private var aircraft = ""
    @State private var equipment = ""
    @State private var selectedRigId: Int? = nil
    @State private var jumpType = ""
    @State private var comments = ""
    @State private var showCreateRig = false
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Jump #\(nextJumpNumber)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colors.amber)

                        addEntryField("DZ", text: $dz, hint: "Drop zone name")
                        addEntryField("Altitude", text: $altitude, hint: "Exit altitude (e.g. 13500)")
                        addFreefallField()
                        datePickerField
                        addEntryField("Aircraft", text: $aircraft, hint: "e.g. Caravan, Otter")
                        rigPickerField
                        addEntryField("Equipment", text: $equipment, hint: "Rig or canopy (free text if not in list)")
                        addEntryField("Jump Type", text: $jumpType, hint: "Prefills from your default; change freely for this jump")
                        addEntryField("Comments", text: $comments, hint: "Optional remarks", multiline: true)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Jump")
            .onAppear {
                prefillFromLastEntry()
                Task { await vm.loadRigs() }
            }
            .sheet(isPresented: $showCreateRig) {
                CreateRigSheet(vm: vm) {
                    showCreateRig = false
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let dateStr = Self.dateFormatter.string(from: jumpDate)
                        onSave(dz, altitude, delay, dateStr, aircraft, equipment, selectedRigId, jumpType, comments)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.amber)
                }
            }
        }
    }

    private var rigPickerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RIG")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.amber)
                .tracking(1)
            Text("Select a saved rig or add one")
                .font(.system(size: 12))
                .foregroundColor(colors.text.opacity(0.9))
            HStack(spacing: 10) {
                Picker("", selection: $selectedRigId) {
                    Text("None").tag(nil as Int?)
                    ForEach(vm.rigs) { rig in
                        Text(rig.rigLabel).tag(rig.id as Int?)
                    }
                }
                .pickerStyle(.menu)
                .tint(colors.amber)
                .colorScheme(.dark)
                Button {
                    showCreateRig = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(colors.amber)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        }
    }

    private func prefillFromLastEntry() {
        if let e = lastEntry {
            if let v = e.dz, !v.isEmpty { dz = v }
            if let v = e.altitude, !v.isEmpty { altitude = v }
            if let v = e.aircraft, !v.isEmpty { aircraft = v }
            if let v = e.equipment, !v.isEmpty { equipment = v }
            if let rid = e.rigId, rid > 0 { selectedRigId = rid }
        }
        if dz.isEmpty, !homeDropzone.isEmpty { dz = homeDropzone }
        if delay.isEmpty, !startFreefallTime.isEmpty {
            delay = FreefallDurationFormatting.formatWhileTyping(startFreefallTime)
        }
        if jumpType.isEmpty {
            if let j = lastEntry?.jumpType, !j.isEmpty {
                jumpType = j
            } else if !defaultJumpType.isEmpty {
                jumpType = defaultJumpType
            }
        }
    }

    private var datePickerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.amber)
                .tracking(1)
            DatePicker("", selection: $jumpDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(colors.amber)
                .colorScheme(.dark)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
    }

    private func addFreefallField() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FREEFALL")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1)
                Text("This jump’s freefall time (added to your cumulative total). Type digits; : appears after minutes.")
                    .font(.system(size: 12))
                    .foregroundColor(colors.text.opacity(0.9))
            }
            TextField("Freefall", text: $delay)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colors.text)
                .tint(colors.amber)
                .onChange(of: delay) { _, newValue in
                    let formatted = FreefallDurationFormatting.formatWhileTyping(newValue)
                    if formatted != newValue {
                        delay = formatted
                    }
                }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
    }

    private func addEntryField(_ label: String, text: Binding<String>, hint: String? = nil, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1)
                if let h = hint, !h.isEmpty {
                    Text(h)
                        .font(.system(size: 12))
                        .foregroundColor(colors.text.opacity(0.9))
                }
            }
            if multiline {
                TextField(label, text: text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colors.text)
                    .tint(colors.amber)
            } else {
                TextField(label, text: text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colors.text)
                    .tint(colors.amber)
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
    }
}

// MARK: - Create Rig Sheet (matches loft form: harness, reserve dropdowns, AAD dropdowns)

struct CreateRigSheet: View {
    @ObservedObject var vm: LogbookViewModel
    let onComplete: () -> Void
    /// When set, the form updates this rig instead of creating a new one.
    var editingRig: JumperRig? = nil

    @State private var rigLabel = ""
    @State private var harnessMfr = ""
    @State private var harnessModel = ""
    @State private var harnessSn = ""
    @State private var harnessDomDate = Date()
    @State private var reserveMfr = ""
    @State private var reserveModel = ""
    @State private var reserveSizeSqft = ""
    @State private var reserveSn = ""
    @State private var reserveDomDate = Date()
    @State private var includeMainParachute = false
    @State private var mainMfr = ""
    @State private var mainModel = ""
    @State private var mainSizeSqft = ""
    @State private var mainSn = ""
    @State private var mainDomDate = Date()
    @State private var aadMfr = ""
    @State private var aadModel = ""
    @State private var aadSn = ""
    @State private var aadDomDate = Date()
    @State private var notes = ""
    /// Set after catalog loads so Save always sends the correct id for updates.
    @State private var rigIdForSave: Int?
    /// While true, manufacturer pickers must not clear dependent fields (populate from server).
    @State private var isApplyingRigSnapshot = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private var cat: RigCatalogResponse? { vm.rigCatalog }
    private var harnessMfrs: [String] { cat?.harnessMfrs ?? [] }
    private var harnessModels: [String] {
        var base = harnessMfr.isEmpty ? [] : (cat?.harnessModelsByMfr?[harnessMfr] ?? [])
        if !harnessModel.isEmpty, !base.contains(harnessModel) { base.append(harnessModel) }
        return base
    }
    private var reserveMfrs: [String] { cat?.reserveMfrs ?? [] }
    private var reserveModels: [String] {
        var base = reserveMfr.isEmpty ? [] : (cat?.reserveModelsByMfr?[reserveMfr] ?? [])
        if !reserveModel.isEmpty, !base.contains(reserveModel) { base.append(reserveModel) }
        return base
    }
    private var reserveSizes: [Int] {
        guard !reserveMfr.isEmpty, !reserveModel.isEmpty else { return [] }
        var base = cat?.reserveSizesByMfrModel?[reserveMfr]?[reserveModel] ?? []
        if let sz = Int(reserveSizeSqft.trimmingCharacters(in: .whitespaces)), sz > 0, !base.contains(sz) {
            base.append(sz)
        }
        return base
    }
    private var mainMfrs: [String] { cat?.mainMfrs ?? [] }
    private var mainModels: [String] {
        var base = mainMfr.isEmpty ? [] : (cat?.mainModelsByMfr?[mainMfr] ?? [])
        if !mainModel.isEmpty, !base.contains(mainModel) { base.append(mainModel) }
        return base
    }
    private var mainSizes: [Int] {
        guard !mainMfr.isEmpty, !mainModel.isEmpty else { return [] }
        var base = cat?.mainSizesByMfrModel?[mainMfr]?[mainModel] ?? []
        if let sz = Int(mainSizeSqft.trimmingCharacters(in: .whitespaces)), sz > 0, !base.contains(sz) {
            base.append(sz)
        }
        return base
    }
    private var aadMfrs: [String] { cat?.aadMfrs ?? [] }
    private var aadModels: [String] {
        var base = aadMfr.isEmpty ? [] : (cat?.aadModelsByMfr?[aadMfr] ?? [])
        if !aadModel.isEmpty, !base.contains(aadModel) { base.append(aadModel) }
        return base
    }

    /// Required fields: harness, reserve, AAD; main optional block; main SN optional when main is on.
    private var formIsValid: Bool {
        let labelOk = !rigLabel.trimmingCharacters(in: .whitespaces).isEmpty
        let harnessOk = !harnessMfr.isEmpty && !harnessModel.isEmpty && !harnessSn.isEmpty
        let reserveOk = !reserveMfr.isEmpty && !reserveModel.isEmpty && !reserveSizeSqft.isEmpty && !reserveSn.isEmpty
        let aadOk = !aadMfr.isEmpty && !aadModel.isEmpty && !aadSn.isEmpty
        let mainOk: Bool
        if includeMainParachute {
            let sz = Int(mainSizeSqft.trimmingCharacters(in: .whitespaces)) ?? 0
            mainOk = !mainMfr.isEmpty && !mainModel.isEmpty && sz > 0
        } else {
            mainOk = true
        }
        return labelOk && harnessOk && reserveOk && aadOk && mainOk
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(editingRig == nil
                             ? "Add a rig to select when logging jumps. All fields below are required except main canopy SN when main is included."
                             : "Editing this rig. Catalog loads first so manufacturer/model pickers show saved values. Tap Save to update.")
                            .font(.system(size: 13))
                            .foregroundColor(colors.text.opacity(0.9))
                            .padding(.bottom, 4)

                        sectionTitle("Rig")
                        addField("Rig label", text: $rigLabel, hint: "Required")

                        sectionTitle("Harness & Container")
                        pickerField("Harness Manufacturer", selection: $harnessMfr, options: harnessMfrs) { harnessModel = "" }
                        pickerField(
                            "Harness Model",
                            selection: $harnessModel,
                            options: harnessModels,
                            dependencyHint: harnessMfr.isEmpty ? "Select harness manufacturer first." : nil
                        )
                        addField("Harness SN", text: $harnessSn, hint: "Required")
                        domDateRow(
                            label: "Harness DOM",
                            hint: "Date of manufacture (required)",
                            date: $harnessDomDate
                        )

                        sectionTitle("Reserve parachute")
                        Text("Reserve canopy — catalog from the server.")
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                        pickerField("Reserve manufacturer", selection: $reserveMfr, options: reserveMfrs) { reserveModel = ""; reserveSizeSqft = "" }
                        pickerField(
                            "Reserve model",
                            selection: $reserveModel,
                            options: reserveModels,
                            dependencyHint: reserveMfr.isEmpty ? "Select reserve manufacturer first." : nil
                        ) { reserveSizeSqft = "" }
                        pickerField(
                            "Reserve size (sq ft)",
                            selection: $reserveSizeSqft,
                            options: reserveSizes.map { "\($0)" },
                            dependencyHint: {
                                if reserveMfr.isEmpty { return "Select reserve manufacturer first." }
                                if reserveModel.isEmpty { return "Select reserve model first." }
                                return nil
                            }()
                        )
                        addField("Reserve SN", text: $reserveSn, hint: "Required")
                        domDateRow(
                            label: "Reserve DOM",
                            hint: "Date of manufacture (required)",
                            date: $reserveDomDate
                        )

                        Toggle(isOn: $includeMainParachute) {
                            Text("Include main parachute")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(colors.text)
                        }
                        .tint(colors.amber)
                        .padding(.vertical, 4)

                        if includeMainParachute {
                            sectionTitle("Main parachute")
                            Text("Sport / main canopy catalog (separate from reserve).")
                                .font(.system(size: 12))
                                .foregroundColor(colors.muted)
                            pickerField("Main manufacturer", selection: $mainMfr, options: mainMfrs) { mainModel = ""; mainSizeSqft = "" }
                            pickerField(
                                "Main model",
                                selection: $mainModel,
                                options: mainModels,
                                dependencyHint: mainMfr.isEmpty ? "Select main manufacturer first." : nil
                            ) { mainSizeSqft = "" }
                            pickerField(
                                "Main size (sq ft)",
                                selection: $mainSizeSqft,
                                options: mainSizes.map { "\($0)" },
                                dependencyHint: {
                                    if mainMfr.isEmpty { return "Select main manufacturer first." }
                                    if mainModel.isEmpty { return "Select main model first." }
                                    return nil
                                }()
                            )
                            addField("Main SN", text: $mainSn, hint: "Optional")
                            domDateRow(
                                label: "Main DOM",
                                hint: "Date of manufacture (required when main is included)",
                                date: $mainDomDate
                            )
                        }

                        sectionTitle("AAD")
                        pickerField("AAD Manufacturer", selection: $aadMfr, options: aadMfrs) { aadModel = "" }
                        pickerField(
                            "AAD Model",
                            selection: $aadModel,
                            options: aadModels,
                            dependencyHint: aadMfr.isEmpty ? "Select AAD manufacturer first." : nil
                        )
                        addField("AAD SN", text: $aadSn, hint: "Required")
                        domDateRow(
                            label: "AAD DOM",
                            hint: "Date of manufacture (required)",
                            date: $aadDomDate
                        )

                        sectionTitle("Notes")
                        addField("Notes", text: $notes, hint: "Optional")

                        if editingRig != nil {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Text("Delete this rig")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(editingRig == nil ? "Add Rig" : "Edit Rig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete()
                        dismiss()
                    }
                    .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let reserveSizeInt = Int(reserveSizeSqft.trimmingCharacters(in: .whitespaces))
                            let mainSizeInt = Int(mainSizeSqft.trimmingCharacters(in: .whitespaces))
                            let ok = await vm.createRig(
                                rigId: rigIdForSave ?? editingRig?.id,
                                rigLabel: rigLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                                harnessMfr: harnessMfr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : harnessMfr.trimmingCharacters(in: .whitespacesAndNewlines),
                                harnessModel: harnessModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : harnessModel.trimmingCharacters(in: .whitespacesAndNewlines),
                                harnessSn: harnessSn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : harnessSn.trimmingCharacters(in: .whitespacesAndNewlines),
                                harnessDom: domISOString(from: harnessDomDate),
                                mainMfr: includeMainParachute && !mainMfr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? mainMfr.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                                mainModel: includeMainParachute && !mainModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? mainModel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                                mainSizeSqft: includeMainParachute && mainSizeInt != nil && mainSizeInt! > 0 ? mainSizeInt : nil,
                                mainSn: includeMainParachute && !mainSn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? mainSn.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                                mainDom: includeMainParachute ? domISOString(from: mainDomDate) : nil,
                                reserveMfr: reserveMfr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reserveMfr.trimmingCharacters(in: .whitespacesAndNewlines),
                                reserveModel: reserveModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reserveModel.trimmingCharacters(in: .whitespacesAndNewlines),
                                reserveSizeSqft: (reserveSizeInt != nil && reserveSizeInt! > 0) ? reserveSizeInt : nil,
                                reserveSn: reserveSn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reserveSn.trimmingCharacters(in: .whitespacesAndNewlines),
                                reserveDom: domISOString(from: reserveDomDate),
                                aadMfr: aadMfr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : aadMfr.trimmingCharacters(in: .whitespacesAndNewlines),
                                aadModel: aadModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : aadModel.trimmingCharacters(in: .whitespacesAndNewlines),
                                aadSn: aadSn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : aadSn.trimmingCharacters(in: .whitespacesAndNewlines),
                                aadDom: domISOString(from: aadDomDate),
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            if ok {
                                onComplete()
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.amber)
                    .disabled(!formIsValid || vm.isSaving)
                }
            }
            .task {
                await vm.loadRigCatalog()
                populateFromEditingRig()
            }
            .confirmationDialog(
                "Delete this rig?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        let id = rigIdForSave ?? editingRig?.id ?? 0
                        let ok = await vm.deleteRig(rigId: id)
                        if ok {
                            onComplete()
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the rig from your list. Past jumps stay in your log.")
            }
        }
    }

    private func resetFormForNewRig() {
        rigIdForSave = nil
        rigLabel = ""
        harnessMfr = ""
        harnessModel = ""
        harnessSn = ""
        harnessDomDate = Date()
        reserveMfr = ""
        reserveModel = ""
        reserveSizeSqft = ""
        reserveSn = ""
        reserveDomDate = Date()
        includeMainParachute = false
        mainMfr = ""
        mainModel = ""
        mainSizeSqft = ""
        mainSn = ""
        mainDomDate = Date()
        aadMfr = ""
        aadModel = ""
        aadSn = ""
        aadDomDate = Date()
        notes = ""
    }

    private func populateFromEditingRig() {
        guard let r = editingRig else {
            resetFormForNewRig()
            return
        }
        isApplyingRigSnapshot = true
        rigIdForSave = r.id
        rigLabel = r.rigLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        harnessMfr = trim(r.harness?.mfr)
        harnessModel = trim(r.harness?.model)
        harnessSn = trim(r.harness?.sn)
        if let d = dateFromISO(r.harness?.dom) { harnessDomDate = d }
        reserveMfr = trim(r.reserve?.mfr)
        reserveModel = trim(r.reserve?.model)
        if let sz = r.reserve?.sizeSqft, sz > 0 {
            reserveSizeSqft = "\(sz)"
        } else {
            reserveSizeSqft = ""
        }
        reserveSn = trim(r.reserve?.sn)
        if let d = dateFromISO(r.reserve?.dom) { reserveDomDate = d }
        if let m = r.main, (!(m.mfr ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            || !(m.model ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            || (m.sizeSqft != nil && m.sizeSqft! > 0)
            || !(m.sn ?? "").trimmingCharacters(in: .whitespaces).isEmpty) {
            includeMainParachute = true
            mainMfr = trim(m.mfr)
            mainModel = trim(m.model)
            if let sz = m.sizeSqft, sz > 0 { mainSizeSqft = "\(sz)" } else { mainSizeSqft = "" }
            mainSn = trim(m.sn)
            if let d = dateFromISO(m.dom) { mainDomDate = d }
        } else {
            includeMainParachute = false
        }
        aadMfr = trim(r.aad?.mfr)
        aadModel = trim(r.aad?.model)
        aadSn = trim(r.aad?.sn)
        if let d = dateFromISO(r.aad?.dom) { aadDomDate = d }
        notes = trim(r.notes)
        DispatchQueue.main.async {
            isApplyingRigSnapshot = false
        }
    }

    private func trim(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func dateFromISO(_ iso: String?) -> Date? {
        guard let iso = iso, iso.count >= 10,
              let d = Self.domOutputFormatter.date(from: String(iso.prefix(10))) else { return nil }
        return d
    }

    private static let domOutputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func domISOString(from date: Date) -> String {
        Self.domOutputFormatter.string(from: date)
    }

    private func domDateRow(label: String, hint: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1)
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundColor(colors.text.opacity(0.9))
            }
            DatePicker(label, selection: date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(colors.amber)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 11, weight: .black))
            .foregroundColor(colors.muted)
            .tracking(1.2)
            .padding(.top, 8)
    }

    private func addField(_ label: String, text: Binding<String>, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1)
                if let h = hint, !h.isEmpty {
                    Text(h)
                        .font(.system(size: 12))
                        .foregroundColor(colors.text.opacity(0.9))
                }
            }
            TextField(label, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colors.text)
                .tint(colors.amber)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
    }

    /// Inline `Menu` (dropdown) + loading / retry / dependency hints so the sheet is not empty by mistake.
    private func pickerField(
        _ label: String,
        selection: Binding<String>,
        options: [String],
        dependencyHint: String? = nil,
        onChange: (() -> Void)? = nil
    ) -> some View {
        RigCatalogPickerRow(
            label: label,
            selection: selection,
            options: options,
            dependencyHint: dependencyHint,
            isApplyingSnapshot: isApplyingRigSnapshot,
            onChange: onChange,
            vm: vm
        )
    }

    private struct RigCatalogPickerRow: View {
        let label: String
        @Binding var selection: String
        let options: [String]
        var dependencyHint: String?
        var isApplyingSnapshot: Bool
        var onChange: (() -> Void)?
        @ObservedObject var vm: LogbookViewModel
        @Environment(\.mdzColors) private var colors

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1)
                pickerContent
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        }

        @ViewBuilder
        private var pickerContent: some View {
            if vm.rigCatalogLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading catalog…")
                        .font(.system(size: 14))
                        .foregroundColor(colors.text.opacity(0.9))
                }
                .accessibilityElement(children: .combine)
            } else if let err = vm.rigCatalogError, vm.rigCatalog == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.95))
                    Button("Retry") {
                        Task { await vm.loadRigCatalog() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.amber)
                }
            } else if let hint = dependencyHint, options.isEmpty {
                Text(hint)
                    .font(.system(size: 14))
                    .foregroundColor(colors.muted)
            } else if options.isEmpty {
                Text("No loft catalog data for this field. Ask an admin to configure canopy/harness catalogs.")
                    .font(.system(size: 13))
                    .foregroundColor(colors.muted)
            } else {
                Menu {
                    Button("— Select —") { applySelection("") }
                    ForEach(options, id: \.self) { opt in
                        Button(opt) { applySelection(opt) }
                    }
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Text(selection.isEmpty ? "— Select —" : selection)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(colors.text)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .tint(colors.amber)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text(selection.isEmpty ? "Nothing selected" : selection))
            }
        }

        private func applySelection(_ value: String) {
            selection = value
            if !isApplyingSnapshot {
                onChange?()
            }
        }
    }
}

// MARK: - Grid row (4 columns like reference)

struct LogbookFieldRow: View {
    let label: String
    let value: String
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.5)
            Text(value.isEmpty ? " " : value)
                .font(.system(size: 13))
                .foregroundColor(colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(colors.card2)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(colors.border, lineWidth: 1))
        }
    }
}
