// File: ASC/Views/GroundSchool/LogbookView.swift
// Purpose: Skydiver logbook for a course — printable-style layout matching reference.
//          Shows jump entries (Jump, DZ, Altitude, Delay, Date, Aircraft, Equipment,
//          Total Time, Jump Type, Comments, Signature) and Other training / comments.
import SwiftUI

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

                        // Prior jump count + Add (standalone only)
                        if isStandalone {
                            priorJumpSection
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
                                    ? "Jump sign-offs will appear here. Entries are added when an instructor signs off a jump."
                                    : "Jump sign-offs from this course will appear here. Entries are added when an instructor signs off a jump."
                            )
                            .padding(.vertical, 24)
                        } else {
                            ForEach(vm.entries) { entry in
                                LogbookEntryCard(entry: entry)
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
        .sheet(isPresented: $showPriorEditor) {
            priorJumpEditorSheet
        }
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

    private var priorJumpSection: some View {
        Button {
            priorEditorValue = "\(vm.priorJumpCount)"
            showPriorEditor = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PRIOR JUMPS")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.mdzMuted)
                        .tracking(1)
                    Text("Jumps you had before using this system")
                        .font(.system(size: 12))
                        .foregroundColor(.mdzMuted)
                }
                Spacer()
                Text("\(vm.priorJumpCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.mdzAmber)
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

    private var addEntrySheet: some View {
        AddLogbookEntrySheet(
            nextJumpNumber: vm.nextJumpNumber,
            onSave: { dz, altitude, delay, date, aircraft, equipment, totalTime, jumpType, comments in
                Task {
                    await vm.addEntry(dz: dz, altitude: altitude, delay: delay, date: date, aircraft: aircraft,
                                     equipment: equipment, totalTime: totalTime, jumpType: jumpType, comments: comments)
                    showAddEntry = false
                }
            },
            onCancel: { showAddEntry = false }
        )
    }
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
                           values: [entry.date ?? "", entry.aircraft ?? "", entry.equipment ?? "", entry.totalTime ?? ""])

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
    let nextJumpNumber: Int
    let onSave: (String?, String?, String?, String?, String?, String?, String?, String?, String?) -> Void
    let onCancel: () -> Void

    @State private var dz = ""
    @State private var altitude = ""
    @State private var delay = ""
    @State private var date = ""
    @State private var aircraft = ""
    @State private var equipment = ""
    @State private var totalTime = ""
    @State private var jumpType = ""
    @State private var comments = ""

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Jump #\(nextJumpNumber)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.mdzAmber)

                        addEntryField("DZ", text: $dz)
                        addEntryField("Altitude", text: $altitude)
                        addEntryField("Delay", text: $delay)
                        addEntryField("Date", text: $date, hint: "e.g. 2025-03-02")
                        addEntryField("Aircraft", text: $aircraft)
                        addEntryField("Equipment", text: $equipment)
                        addEntryField("Total Time", text: $totalTime)
                        addEntryField("Jump Type", text: $jumpType, hint: "e.g. solo, tandem")
                        addEntryField("Comments", text: $comments, multiline: true)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Jump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.mdzAmber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(dz, altitude, delay, date, aircraft, equipment, totalTime, jumpType, comments)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.mdzAmber)
                }
            }
        }
    }

    private func addEntryField(_ label: String, text: Binding<String>, hint: String? = nil, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.mdzMuted)
                .tracking(0.5)
            if multiline {
                TextField(hint ?? label, text: text, axis: .vertical)
                    .lineLimit(3...6)
            } else {
                TextField(hint ?? label, text: text)
            }
        }
        .padding(12)
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
