// File: ASC/Views/GroundSchool/LogbookView.swift
// Purpose: Skydiver logbook — list of jumps, stats, detail view, signature capture.
import SwiftUI
import PencilKit

struct LogbookView: View {
    /// nil = standalone "My Logbook" (all entries); non-nil = logbook for that course
    let courseId: Int?
    let courseTitle: String
    /// When true, back button is hidden (e.g. when used as tab/sidebar root)
    private var isStandaloneRoot: Bool = false

    @StateObject private var vm = LogbookViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPriorEditor = false
    @State private var priorEditorValue = ""
    @State private var showStartFreefallEditor = false
    @State private var startFreefallEditorValue = ""
    @State private var showHomeDzEditor = false
    @State private var homeDzEditorValue = ""
    @State private var showAddEntry = false

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
            Color.mdzBackground.ignoresSafeArea()

            if vm.isLoading && vm.entries.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber)).scaleEffect(1.2)
                    Text("Loading logbook…").font(.subheadline).foregroundColor(.mdzMuted)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LOGBOOK")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.mdzAmber)
                                .tracking(2)
                            Text(courseTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.mdzText)
                        }

                        // Config + Add (standalone only)
                        if isStandalone {
                            configSection
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
                                    .foregroundColor(.mdzMuted)
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
                                .foregroundColor(.mdzMuted)
                            Text(vm.otherTrainingNotes.isEmpty ? " " : vm.otherTrainingNotes)
                                .font(.system(size: 14))
                                .foregroundColor(.mdzText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.mdzCard)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isStandaloneRoot {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.mdzAmber)
                    }
                }
            }
        }
        .task { await vm.load(courseId: courseId, userId: nil) }
        .sheet(isPresented: $showPriorEditor) { priorJumpEditorSheet }
        .sheet(isPresented: $showStartFreefallEditor) { startFreefallEditorSheet }
        .sheet(isPresented: $showHomeDzEditor) { homeDzEditorSheet }
        .sheet(isPresented: $showAddEntry) {
            addEntrySheet
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONFIG")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(1)
            configCard("Prior Jumps", subtitle: "Jumps you had before using this system", value: "\(vm.priorJumpCount)") {
                priorEditorValue = "\(vm.priorJumpCount)"
                showPriorEditor = true
            }
            configCard("Start Freefall Time", subtitle: "Default freefall when adding a jump (e.g. 45 or 1:30)", value: vm.startFreefallTime.isEmpty ? "Not set" : vm.startFreefallTime) {
                startFreefallEditorValue = vm.startFreefallTime
                showStartFreefallEditor = true
            }
            configCard("Home Dropzone", subtitle: "Your home DZ, prefills when adding a jump", value: vm.homeDropzone.isEmpty ? "Not set" : vm.homeDropzone) {
                homeDzEditorValue = vm.homeDropzone
                showHomeDzEditor = true
            }
        }
    }

    private func configCard(_ label: String, subtitle: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.mdzMuted)
                        .tracking(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.mdzMuted)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mdzAmber)
                    .lineLimit(1)
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.mdzMuted)
            }
            .padding(14)
            .background(Color.mdzCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var addJumpButton: some View {
        Button {
            showAddEntry = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.mdzGreen)
                Text("Add Jump #\(vm.nextJumpNumber)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.mdzText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mdzMuted)
            }
            .padding(14)
            .background(Color.mdzCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzGreen.opacity(0.4), lineWidth: 1))
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
            Divider().frame(height: 36).background(Color.mdzBorder)
            StatCell(label: "FREEFALL", value: latest?.delay ?? "—")
            Divider().frame(height: 36).background(Color.mdzBorder)
            StatCell(label: "LAST JUMP", value: timeSinceLast)
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private var studentNoteCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 16))
                .foregroundColor(.mdzAmber)
            Text("Students need instructor sign-offs for logbook entries. At 25 jumps you'll become a skydiver and can add your own.")
                .font(.system(size: 12))
                .foregroundColor(.mdzMuted)
        }
        .padding(12)
        .background(Color.mdzAmber.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzAmber.opacity(0.3), lineWidth: 1))
    }

    private var priorJumpEditorSheet: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter the number of jumps you had before using this system. New entries will continue from there.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.mdzText)
                    Text("JUMP COUNT")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.mdzAmber)
                        .tracking(1)
                    TextField("0", text: $priorEditorValue)
                        .keyboardType(.numberPad)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.mdzText)
                        .padding(14)
                        .background(Color.mdzCard)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Prior Jumps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPriorEditor = false }
                        .foregroundColor(.mdzAmber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let val = Int(priorEditorValue) ?? 0
                        if val >= 0 {
                            Task {
                                await vm.setPriorJumpCount(val)
                                showPriorEditor = false
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.mdzAmber)
                    .disabled(vm.isSaving || (Int(priorEditorValue) ?? -1) < 0)
                }
            }
        }
    }

    private var startFreefallEditorSheet: some View {
        configEditorSheet(
            title: "Start Freefall Time",
            hint: "Default freefall seconds when adding a jump. Use 45 for 45 sec, or 1:30 for 1 min 30 sec.",
            value: $startFreefallEditorValue,
            onSave: {
                Task {
                    await vm.setStartFreefallTime(startFreefallEditorValue)
                    showStartFreefallEditor = false
                }
            },
            onCancel: { showStartFreefallEditor = false },
            label: "FREEFALL (sec or M:SS)"
        )
    }

    private var homeDzEditorSheet: some View {
        configEditorSheet(
            title: "Home Dropzone",
            hint: "Your home dropzone. This prefills the DZ field when adding a new jump.",
            value: $homeDzEditorValue,
            onSave: {
                Task {
                    await vm.setHomeDropzone(homeDzEditorValue)
                    showHomeDzEditor = false
                }
            },
            onCancel: { showHomeDzEditor = false },
            label: "DROPZONE NAME"
        )
    }

    private func configEditorSheet(
        title: String,
        hint: String,
        value: Binding<String>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        label: String
    ) -> some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(hint)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.mdzText)
                    Text(label)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.mdzAmber)
                        .tracking(1)
                    TextField("", text: value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.mdzText)
                        .padding(14)
                        .background(Color.mdzCard)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.mdzAmber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                        .foregroundColor(.mdzAmber)
                        .disabled(vm.isSaving)
                }
            }
        }
    }

    private var addEntrySheet: some View {
        AddLogbookEntrySheet(
            vm: vm,
            nextJumpNumber: vm.nextJumpNumber,
            lastEntry: vm.entries.last,
            startFreefallTime: vm.startFreefallTime,
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

// MARK: - Stat cell for stats bar
struct StatCell: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.mdzText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact list row (clickable)
struct LogbookEntryRow: View {
    let entry: SkydiverLogbookEntry
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.jumpNumber)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.mdzAmber)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date ?? "—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.mdzText)
                Text([entry.jumpType, entry.dz].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundColor(.mdzMuted)
            }
            Spacer()
            if entry.isSigned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.mdzGreen)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mdzMuted)
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Entry detail (full info + signature)
struct LogbookEntryDetailView: View {
    let entry: SkydiverLogbookEntry
    @ObservedObject var vm: LogbookViewModel
    @State private var showSignaturePad = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
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
                            .foregroundColor(.mdzAmber)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.mdzAmber.opacity(0.12))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzAmber.opacity(0.4), lineWidth: 1))
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
                .foregroundColor(.mdzMuted)
                .tracking(1)
            VStack(alignment: .leading, spacing: 8) {
                if entry.isSigned {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.mdzGreen)
                        Text("Signed and locked")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.mdzText)
                    }
                } else {
                    Text("Phone-to-phone signing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.mdzText)
                    Text("Sign from another device — coming soon")
                        .font(.system(size: 12))
                        .foregroundColor(.mdzMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.mdzCard2)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
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
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Draw your signature below")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.mdzText)
                    SignatureCanvasRepresentable(canvas: $canvasView)
                        .frame(height: 200)
                        .background(Color(red: 12/255, green: 29/255, blue: 53/255))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.mdzBorder, lineWidth: 1))
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
                        .foregroundColor(.mdzAmber)
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
                    .foregroundColor(.mdzAmber)
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
                    .foregroundColor(.mdzMuted)
                Text(entry.comments?.isEmpty == false ? entry.comments! : " ")
                    .font(.system(size: 14))
                    .foregroundColor(.mdzText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 60)
                    .padding(10)
                    .background(Color.mdzCard2)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
            }

            // Result (pass/repeat)
            if entry.result != nil {
                HStack(spacing: 6) {
                    Text("Result")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.mdzMuted)
                    Text(entry.resultDisplay)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(entry.result?.lowercased() == "pass" ? .mdzGreen : .mdzAmber)
                }
            }

            // Signature
            HStack(spacing: 8) {
                Text("Signature")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.mdzMuted)
                if entry.isSigned, let signedBy = entry.signedBy, !signedBy.isEmpty {
                    Text(signedBy)
                        .font(.system(size: 13))
                        .foregroundColor(.mdzText)
                    if let lic = entry.instructorLicenseNumber, !lic.isEmpty {
                        Text("(\(lic))")
                            .font(.system(size: 11))
                            .foregroundColor(.mdzMuted)
                    }
                    if let at = entry.signedAt {
                        Text("· \(at)")
                            .font(.system(size: 11))
                            .foregroundColor(.mdzMuted)
                    }
                } else {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .background(Color.mdzCard2)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.mdzBorder, lineWidth: 1))
                }
            }
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Grid row (4 columns like reference)

struct LogbookGridRow: View {
    let labels: [String]
    let values: [String]

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { item in
                    Text(item.element.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.mdzMuted)
                        .tracking(0.5)
                    if item.offset < 3 { Spacer(minLength: 4) }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { item in
                    Text(item.element.isEmpty ? " " : item.element)
                        .font(.system(size: 13))
                        .foregroundColor(.mdzText)
                    if item.offset < 3 { Spacer(minLength: 4) }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.mdzCard2)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.mdzBorder, lineWidth: 1))
        }
    }
}

// MARK: - Add Logbook Entry Sheet

struct AddLogbookEntrySheet: View {
    @ObservedObject var vm: LogbookViewModel
    let nextJumpNumber: Int
    let lastEntry: SkydiverLogbookEntry?
    let startFreefallTime: String
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

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Jump #\(nextJumpNumber)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.mdzAmber)

                        addEntryField("DZ", text: $dz, hint: "Drop zone name")
                        addEntryField("Altitude", text: $altitude, hint: "Exit altitude (e.g. 13500)")
                        addEntryField("Freefall", text: $delay, hint: "Seconds or M:SS (e.g. 45 or 1:30)")
                        datePickerField
                        addEntryField("Aircraft", text: $aircraft, hint: "e.g. Caravan, Otter")
                        rigPickerField
                        addEntryField("Equipment", text: $equipment, hint: "Rig or canopy (free text if not in list)")
                        addEntryField("Jump Type", text: $jumpType, hint: "e.g. solo, tandem, hop-n-pop")
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.mdzAmber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let dateStr = Self.dateFormatter.string(from: jumpDate)
                        onSave(dz, altitude, delay, dateStr, aircraft, equipment, selectedRigId, jumpType, comments)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.mdzAmber)
                }
            }
        }
    }

    private var rigPickerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RIG")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzAmber)
                .tracking(1)
            Text("Select a saved rig or add one")
                .font(.system(size: 12))
                .foregroundColor(Color.mdzText.opacity(0.9))
            HStack(spacing: 10) {
                Picker("", selection: $selectedRigId) {
                    Text("None").tag(nil as Int?)
                    ForEach(vm.rigs) { rig in
                        Text(rig.rigLabel).tag(rig.id as Int?)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.mdzAmber)
                .colorScheme(.dark)
                Button {
                    showCreateRig = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.mdzAmber)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.mdzCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
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
        if delay.isEmpty, !startFreefallTime.isEmpty { delay = startFreefallTime }
    }

    private var datePickerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzAmber)
                .tracking(1)
            DatePicker("", selection: $jumpDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.mdzAmber)
                .colorScheme(.dark)
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private func addEntryField(_ label: String, text: Binding<String>, hint: String? = nil, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzAmber)
                    .tracking(1)
                if let h = hint, !h.isEmpty {
                    Text(h)
                        .font(.system(size: 12))
                        .foregroundColor(Color.mdzText.opacity(0.9))
                }
            }
            if multiline {
                TextField(label, text: text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.mdzText)
                    .tint(Color.mdzAmber)
            } else {
                TextField(label, text: text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.mdzText)
                    .tint(Color.mdzAmber)
            }
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Create Rig Sheet (matches loft form: harness, reserve dropdowns, AAD dropdowns)

struct CreateRigSheet: View {
    @ObservedObject var vm: LogbookViewModel
    let onComplete: () -> Void

    @State private var rigLabel = ""
    @State private var harnessMfr = ""
    @State private var harnessModel = ""
    @State private var harnessSn = ""
    @State private var harnessDom = ""
    @State private var reserveMfr = ""
    @State private var reserveModel = ""
    @State private var reserveSizeSqft = ""
    @State private var reserveSn = ""
    @State private var reserveDom = ""
    @State private var aadMfr = ""
    @State private var aadModel = ""
    @State private var aadSn = ""
    @State private var aadDom = ""
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss

    private var cat: RigCatalogResponse? { vm.rigCatalog }
    private var reserveMfrs: [String] { cat?.reserveMfrs ?? [] }
    private var reserveModels: [String] { reserveMfr.isEmpty ? [] : (cat?.reserveModelsByMfr?[reserveMfr] ?? []) }
    private var reserveSizes: [Int] {
        guard !reserveMfr.isEmpty, !reserveModel.isEmpty else { return [] }
        return cat?.reserveSizesByMfrModel?[reserveMfr]?[reserveModel] ?? []
    }
    private var aadMfrs: [String] { cat?.aadMfrs ?? [] }
    private var aadModels: [String] { aadMfr.isEmpty ? [] : (cat?.aadModelsByMfr?[aadMfr] ?? []) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Add a rig to select when logging jumps. Same fields as the loft rig form.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.mdzText.opacity(0.9))
                            .padding(.bottom, 4)

                        sectionTitle("Rig")
                        addField("Rig label", text: $rigLabel, hint: "e.g. Sigma-5, My Rig")

                        sectionTitle("Harness & Container")
                        addField("Harness MFR", text: $harnessMfr)
                        addField("Harness Model", text: $harnessModel)
                        addField("Harness SN", text: $harnessSn)
                        addField("Harness DOM", text: $harnessDom, hint: "YYYY-MM-DD")

                        sectionTitle("Reserve Canopy")
                        pickerField("Reserve Manufacturer", selection: $reserveMfr, options: reserveMfrs) { reserveModel = ""; reserveSizeSqft = "" }
                        pickerField("Reserve Model", selection: $reserveModel, options: reserveModels) { reserveSizeSqft = "" }
                        pickerField("Reserve Size (sqft)", selection: $reserveSizeSqft, options: reserveSizes.map { "\($0)" })
                        addField("Reserve SN", text: $reserveSn)
                        addField("Reserve DOM", text: $reserveDom, hint: "YYYY-MM-DD")

                        sectionTitle("AAD")
                        pickerField("AAD Manufacturer", selection: $aadMfr, options: aadMfrs) { aadModel = "" }
                        pickerField("AAD Model", selection: $aadModel, options: aadModels)
                        addField("AAD SN", text: $aadSn)
                        addField("AAD DOM", text: $aadDom, hint: "YYYY-MM-DD")

                        sectionTitle("Notes")
                        addField("Notes", text: $notes, hint: "Optional")
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Rig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete()
                        dismiss()
                    }
                    .foregroundColor(.mdzAmber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let sizeInt = Int(reserveSizeSqft.trimmingCharacters(in: .whitespaces))
                            let ok = await vm.createRig(
                                rigLabel: rigLabel.trimmingCharacters(in: .whitespaces),
                                harnessMfr: harnessMfr.isEmpty ? nil : harnessMfr,
                                harnessModel: harnessModel.isEmpty ? nil : harnessModel,
                                harnessSn: harnessSn.isEmpty ? nil : harnessSn,
                                harnessDom: harnessDom.isEmpty ? nil : harnessDom,
                                reserveMfr: reserveMfr.isEmpty ? nil : reserveMfr,
                                reserveModel: reserveModel.isEmpty ? nil : reserveModel,
                                reserveSizeSqft: (sizeInt != nil && sizeInt! > 0) ? sizeInt : nil,
                                reserveSn: reserveSn.isEmpty ? nil : reserveSn,
                                reserveDom: reserveDom.isEmpty ? nil : reserveDom,
                                aadMfr: aadMfr.isEmpty ? nil : aadMfr,
                                aadModel: aadModel.isEmpty ? nil : aadModel,
                                aadSn: aadSn.isEmpty ? nil : aadSn,
                                aadDom: aadDom.isEmpty ? nil : aadDom,
                                notes: notes.isEmpty ? nil : notes
                            )
                            if ok {
                                onComplete()
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.mdzAmber)
                    .disabled(rigLabel.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSaving)
                }
            }
            .task { await vm.loadRigCatalog() }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 11, weight: .black))
            .foregroundColor(.mdzMuted)
            .tracking(1.2)
            .padding(.top, 8)
    }

    private func addField(_ label: String, text: Binding<String>, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.mdzAmber)
                    .tracking(1)
                if let h = hint, !h.isEmpty {
                    Text(h)
                        .font(.system(size: 12))
                        .foregroundColor(Color.mdzText.opacity(0.9))
                }
            }
            TextField(label, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.mdzText)
                .tint(Color.mdzAmber)
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }

    private func pickerField(_ label: String, selection: Binding<String>, options: [String], onChange: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.mdzAmber)
                .tracking(1)
            Picker(label, selection: selection) {
                Text("— Select —").tag("")
                ForEach(options, id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .tint(.mdzAmber)
            .onChange(of: selection.wrappedValue) { _, _ in onChange?() }
        }
        .padding(14)
        .background(Color.mdzCard)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.mdzBorder, lineWidth: 1))
    }
}

// MARK: - Grid row (4 columns like reference)

struct LogbookFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(0.5)
            Text(value.isEmpty ? " " : value)
                .font(.system(size: 13))
                .foregroundColor(.mdzText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.mdzCard2)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.mdzBorder, lineWidth: 1))
        }
    }
}
