// File: ASC/Views/GroundSchool/LogbookView.swift
// Purpose: Skydiver logbook — list of jumps, stats, detail view, signature capture.
import SwiftUI
import MalfunctionDZCore
import CoreImage

struct LogbookView: View {
    /// nil = standalone "My Logbook" (all entries); non-nil = logbook for that course
    let courseId: Int?
    let courseTitle: String
    /// When true, back button is hidden (e.g. when used as tab/sidebar root)
    private var isStandaloneRoot: Bool = false

    @StateObject private var vm = LogbookViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appShell) private var appShell
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme
    @State private var showAddEntry = false
    @State private var showConfigSheet = false
    @State private var showSigningFlow = false
    @State private var signingFlowInitialMode: LogbookWitnessFlowView.Mode = .request
    @State private var signingFlowEntry: SkydiverLogbookEntry?

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
                            if canAddLogbookJumps {
                                addJumpButton
                            } else if showTrainingStudentBanner {
                                studentNoteCard
                            }
                        }

                        if hasUnsignedJumps {
                            signJumpButton
                        }
                        if canSignOthersLogbook {
                            signOthersLogbookButton
                        }

                        if vm.entries.isEmpty {
                            EmptyStateView(
                                icon: "book.closed",
                                title: vm.error != nil ? "Could not load logbook" : "No logbook entries yet",
                                subtitle: vm.error
                                    ?? (courseId == nil
                                        ? "Tap Add Jump to log a jump, or entries appear when an instructor signs off."
                                        : "Jump sign-offs from this course will appear here. Entries are added when an instructor signs off a jump.")
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
                                    LogbookEntryRow(
                                        entry: entry,
                                        vm: vm,
                                        onSignJump: entry.needsWitnessSignature && !entry.isWitnessSigned
                                            ? { openSignJump(for: entry) }
                                            : nil
                                    )
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
                    Button("Gear") {
                        showConfigSheet = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.amber)
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
        .sheet(isPresented: $showSigningFlow, onDismiss: { signingFlowEntry = nil }) {
            LogbookWitnessFlowView(
                entry: signingFlowEntry,
                unsignedEntries: signingFlowEntry == nil
                    ? vm.entries.filter { $0.needsWitnessSignature }
                    : [],
                initialMode: signingFlowInitialMode,
                vm: vm
            ) {
                showSigningFlow = false
                signingFlowEntry = nil
                Task { await vm.load(courseId: courseId) }
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

    private var hasUnsignedJumps: Bool {
        vm.entries.contains { $0.needsWitnessSignature }
    }

    /// Skydivers, pilots, and instructors can counter-sign another jumper's logbook entry.
    private var canSignOthersLogbook: Bool {
        guard let user = AuthManager.shared.currentUser else { return false }
        return user.isSkydiverRole || user.isPilotRole || user.isInstructorRole
    }

    private func openSignJump(for entry: SkydiverLogbookEntry) {
        signingFlowEntry = entry
        signingFlowInitialMode = .request
        showSigningFlow = true
    }

    private var signJumpButton: some View {
        Button {
            signingFlowEntry = nil
            signingFlowInitialMode = .request
            showSigningFlow = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "signature")
                    .font(.system(size: 18))
                    .foregroundColor(colors.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign jump")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colors.text)
                    Text("Get another jumper to sign your unsigned entries")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colors.muted)
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.amber.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var signOthersLogbookButton: some View {
        Button {
            signingFlowInitialMode = .witness
            showSigningFlow = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundColor(colors.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign logbook")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colors.text)
                    Text("Sign someone else's nearby jump")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
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
    }

    /// Full logbook access — skydivers, instructors, pilots (not training-only students).
    private var canAddLogbookJumps: Bool {
        if vm.isSkydiver { return true }
        guard let user = AuthManager.shared.currentUser else { return false }
        return user.isInstructorRole || user.isSkydiverRole || user.isPilotRole
    }

    /// 25-jump / sign-off notice is for training students only.
    private var showTrainingStudentBanner: Bool {
        guard vm.isStudent else { return false }
        guard let user = AuthManager.shared.currentUser else { return true }
        if user.isInstructorRole || user.isSkydiverRole || user.isPilotRole { return false }
        return user.isStudentRole
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
                await vm.addEntry(dz: dz, altitude: altitude, delay: delay, date: date, aircraft: aircraft,
                                  equipment: equipment, rigId: rigId, jumpType: jumpType, comments: comments)
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
    @State private var draftDefaultAircraft = ""

    @Environment(\.appShell) private var appShell
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private var sheetTitle: String { appShell.isMemberShell ? "Gear" : "Logbook Config" }

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
                            subtitle: "Default DZ when adding a jump."
                        ) {
                            LogbookEditablePicker(
                                label: "Dropzone",
                                hint: nil,
                                value: $draftHomeDz,
                                options: vm.dropzoneOptions
                            )
                        }

                        configField(
                            title: "Default aircraft",
                            subtitle: "Prefills aircraft when adding a jump."
                        ) {
                            LogbookEditablePicker(
                                label: "Aircraft",
                                hint: nil,
                                value: $draftDefaultAircraft,
                                options: vm.aircraftOptions
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(sheetTitle)
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
                                homeDropzone: draftHomeDz,
                                defaultAircraft: draftDefaultAircraft
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
                draftDefaultAircraft = vm.defaultAircraft
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
    @ObservedObject var vm: LogbookViewModel
    var onSignJump: (() -> Void)? = nil
    @Environment(\.mdzColors) private var colors

    private var needsSign: Bool {
        entry.needsWitnessSignature && !entry.isWitnessSigned
    }

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink(destination: LogbookEntryDetailView(entry: entry, vm: vm)) {
                rowContent
            }
            .buttonStyle(.plain)

            if needsSign, let onSignJump {
                Button(action: onSignJump) {
                    Text("Sign jump")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(colors.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(colors.amber.opacity(0.15))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.amber.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rowContent: some View {
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
            if needsSign {
                Text("NEEDS SIG")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(colors.amber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(colors.amber.opacity(0.15))
                    .cornerRadius(4)
            } else if entry.isSigned {
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
    @State private var showWitnessFlow = false
    @State private var showEditSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    LogbookEntryCard(entry: entry)
                    if entry.isEditable {
                        Button {
                            showEditSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 18))
                                Text("Edit jump")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(colors.text)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(colors.card2)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    if entry.needsWitnessSignature {
                        Button {
                            showWitnessFlow = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "signature")
                                    .font(.system(size: 18))
                                Text("Sign jump")
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
        .sheet(isPresented: $showEditSheet) {
            AddLogbookEntrySheet(
                vm: vm,
                nextJumpNumber: entry.jumpNumber,
                lastEntry: nil,
                editingEntry: entry,
                startFreefallTime: vm.startFreefallTime,
                defaultJumpType: vm.defaultJumpType,
                homeDropzone: vm.homeDropzone,
                onSave: { dz, altitude, delay, date, aircraft, equipment, rigId, jumpType, comments in
                    let ok = await vm.updateEntry(
                        entryId: entry.id,
                        dz: dz, altitude: altitude, delay: delay, date: date,
                        aircraft: aircraft, equipment: equipment, rigId: rigId,
                        jumpType: jumpType, comments: comments
                    )
                    if ok {
                        showEditSheet = false
                        dismiss()
                    }
                    return ok
                },
                onCancel: { showEditSheet = false }
            )
        }
        .sheet(isPresented: $showWitnessFlow) {
            LogbookWitnessFlowView(
                entry: entry,
                unsignedEntries: [],
                initialMode: .request,
                vm: vm
            ) {
                showWitnessFlow = false
                Task { await vm.load(courseId: nil, userId: nil) }
            }
        }
    }

    private var signatureBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIGNATURES")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            VStack(alignment: .leading, spacing: 12) {
                if entry.isInstructorSigned {
                    instructorSignatureSection
                }
                if entry.isWitnessSigned {
                    witnessSignatureSection
                } else if entry.needsWitnessSignature {
                    Text("Another skydiver or pilot must sign this jump (hold phones together or show a QR code).")
                        .font(.system(size: 13))
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

    private var studentSignatureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(colors.green)
                Text("Signed by you")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.text)
            }
            if let name = entry.studentSignedBy, !name.isEmpty {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundColor(colors.text)
            }
            if let at = entry.studentSignedAt, !at.isEmpty {
                Text(formatSignedDate(at))
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            if let urlStr = entry.studentSignatureUrl,
               let url = MDZSignatureURL.absolute(urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().frame(maxHeight: 72)
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }

    private var instructorSignatureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INSTRUCTOR")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.8)
            if let name = entry.signedBy, !name.isEmpty {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colors.text)
            }
            if let lic = entry.instructorLicenseNumber, !lic.isEmpty {
                Text(lic)
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            if let at = entry.signedAt, !at.isEmpty {
                Text(formatSignedDate(at))
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
        }
    }

    private var witnessSignatureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SIGNED BY")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(0.8)
            if let name = entry.witnessSignedBy, !name.isEmpty {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colors.text)
            }
            if let lic = entry.witnessLicenseNumber, !lic.isEmpty {
                Text("License \(lic)")
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            if let at = entry.witnessSignedAt, !at.isEmpty {
                Text(formatSignedDate(at))
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            if let urlStr = entry.witnessSignatureUrl, !urlStr.isEmpty {
                MDZRemoteSignatureImage(path: urlStr, cacheBuster: 0)
                    .frame(maxHeight: 72)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.3), lineWidth: 1))
            }
        }
    }

    private func formatSignedDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 10 { return String(trimmed.prefix(10)) }
        return trimmed
    }
}

// MARK: - Sign logbook flow (Multipeer + QR)
struct LogbookWitnessFlowView: View {
    enum Mode: String, CaseIterable { case request = "Sign jump"; case witness = "Sign logbook" }

    let entry: SkydiverLogbookEntry?
    let unsignedEntries: [SkydiverLogbookEntry]
    let initialMode: Mode
    @ObservedObject var vm: LogbookViewModel
    let onComplete: () -> Void

    @StateObject private var session: MDZSigningSession
    @State private var mode: Mode
    @State private var selectedEntryForRequest: SkydiverLogbookEntry?
    @State private var qrPayload = ""
    @State private var challengeNonce = ""
    @State private var witnessNotes = ""
    @State private var isSigning = false
    @State private var statusMessage = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors

    init(
        entry: SkydiverLogbookEntry?,
        unsignedEntries: [SkydiverLogbookEntry] = [],
        initialMode: Mode = .request,
        vm: LogbookViewModel,
        onComplete: @escaping () -> Void
    ) {
        self.entry = entry
        self.unsignedEntries = unsignedEntries
        self.initialMode = initialMode
        self.vm = vm
        self.onComplete = onComplete
        let user = AuthManager.shared.currentUser
        let uid = user?.id ?? 0
        let name = [user?.firstName, user?.lastName].compactMap { $0 }.joined(separator: " ")
        let display = name.isEmpty ? (user?.username ?? "MalfunctionDZ") : name
        _session = StateObject(wrappedValue: MDZSigningSession(userId: uid, displayName: display))
        _mode = State(initialValue: initialMode)
        _selectedEntryForRequest = State(initialValue: unsignedEntries.count == 1 ? unsignedEntries.first : nil)
    }

    private var activeRequestEntry: SkydiverLogbookEntry? {
        if let entry, entry.needsWitnessSignature { return entry }
        return selectedEntryForRequest
    }

    private var showsModePicker: Bool { true }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if showsModePicker {
                            Picker("Mode", selection: $mode) {
                                ForEach(Mode.allCases, id: \.self) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(mode == .request
                                 ? "You are waiting for someone to sign your jump."
                                 : "You are signing another jumper's entry.")
                                .font(.system(size: 12))
                                .foregroundColor(colors.muted)
                        }

                        if let entry {
                            Text(entrySummary(entry))
                                .font(.system(size: 14))
                                .foregroundColor(colors.muted)
                        }

                        switch mode {
                        case .request:
                            requestWitnessSection
                        case .witness:
                            witnessNearbySection
                        }

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 13))
                                .foregroundColor(colors.amber)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(mode == .witness ? "Sign logbook" : "Sign jump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        session.reset()
                        dismiss()
                        onComplete()
                    }
                }
            }
            .onChange(of: session.state) { _, newState in
                switch newState {
                case .completed:
                    statusMessage = "Signature recorded."
                    isSigning = false
                case .failed(let msg):
                    statusMessage = msg
                    isSigning = false
                default:
                    break
                }
            }
            .onChange(of: mode) { _, _ in
                session.reset()
                qrPayload = ""
                statusMessage = ""
                witnessNotes = ""
                isSigning = false
            }
            .task(id: mode) {
                if mode == .witness {
                    await vm.reloadSignerProfile()
                }
            }
        }
    }

  @ViewBuilder
    private var requestWitnessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 1 — You (jumper waiting for a signature)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)

            if unsignedEntries.count > 1, entry == nil {
                Text("Pick a jump:")
                    .font(.system(size: 13))
                    .foregroundColor(colors.text)
                ForEach(unsignedEntries) { jump in
                    Button {
                        selectedEntryForRequest = jump
                        session.reset()
                        qrPayload = ""
                    } label: {
                        HStack {
                            Text(entrySummary(jump))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(colors.text)
                            Spacer()
                            if selectedEntryForRequest?.id == jump.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(colors.amber)
                            }
                        }
                        .padding(12)
                        .background(colors.card2)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let active = activeRequestEntry {
                if unsignedEntries.count <= 1 || entry != nil {
                    Text(entrySummary(active))
                        .font(.system(size: 14))
                        .foregroundColor(colors.text)
                }

                Button("Start nearby signing") {
                    Task { await startAdvertising(for: active) }
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.amber)

                if !qrPayload.isEmpty {
                    LogbookWitnessQRCodeView(payload: qrPayload)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    Text("Or scan this QR with any phone camera — signer logs in and taps Confirm.")
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                }

                switch session.state {
                case .advertising, .awaitingWitness:
                    Text("Broadcasting — keep this screen open. The other person uses Sign logbook → Look for nearby logbooks.")
                        .font(.system(size: 13))
                        .foregroundColor(colors.muted)
                case .completed:
                    Text("Signed!")
                        .foregroundColor(colors.green)
                default:
                    EmptyView()
                }
            } else if entry == nil, !unsignedEntries.isEmpty {
                Text("Select a jump above, then tap Start nearby signing.")
                    .font(.system(size: 13))
                    .foregroundColor(colors.muted)
            } else {
                Text("No jumps waiting for a signature.")
                    .foregroundColor(colors.muted)
            }
        }
    }

    @ViewBuilder
    private var witnessNearbySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 2 — You (signing someone else's jump)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
            Text("The other jumper must tap Sign jump at the top of Logbook (or on the jump row), then Start nearby signing. Keep that screen open before you search below.")
                .font(.system(size: 13))
                .foregroundColor(colors.muted)

            if vm.hasSavedSignature == false {
                Text("Set up your signature in Profile before you can sign logbook entries.")
                    .foregroundColor(colors.amber)
            }

            Button("Look for nearby logbooks") {
                session.startBrowsing()
            }
            .buttonStyle(.borderedProminent)
            .tint(colors.green)

            if case .browsing = session.state, session.discoveredPeers.isEmpty {
                Text("Searching… If nothing appears, confirm the other phone is broadcasting (Step 1).")
                    .font(.system(size: 13))
                    .foregroundColor(colors.muted)
            }

            if case .connecting = session.state {
                HStack(spacing: 10) {
                    ProgressView().tint(colors.amber)
                    Text("Connecting…")
                        .font(.system(size: 14))
                        .foregroundColor(colors.text)
                }
                .padding(.vertical, 4)
            }

            if case .failed = session.state, mode == .witness {
                Button("Try again") {
                    statusMessage = ""
                    session.startBrowsing()
                }
                .buttonStyle(.bordered)
                .tint(colors.amber)
            }

            ForEach(session.discoveredPeers) { row in
                Button {
                    session.connect(to: row.peer)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 18))
                            .foregroundColor(colors.green)
                        Text("Connect to \(row.peer.displayName)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(colors.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colors.muted)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.card2)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.green.opacity(0.45), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if case .awaitingConfirmation(let request) = session.state {
                witnessConfirmationPanel(request: request)
            }
        }
    }

    @ViewBuilder
    private func witnessConfirmationPanel(request: LogbookSignRequest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Confirm signature")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(colors.text)

            Text(request.summary)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.amber)

            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR SIGNATURE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                if !vm.signerDisplayName.isEmpty {
                    Text(vm.signerDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colors.text)
                }
                if !vm.signerLicenseDisplay.isEmpty {
                    Text("License \(vm.signerLicenseDisplay)")
                        .font(.system(size: 13))
                        .foregroundColor(colors.muted)
                }
                if let url = MDZSignatureURL.absolute(vm.savedSignatureUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().frame(maxHeight: 72)
                        case .failure:
                            Text("Could not load saved signature")
                                .font(.system(size: 12))
                                .foregroundColor(colors.amber)
                        default:
                            ProgressView().tint(colors.amber)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(colors.card)
                    .cornerRadius(8)
                } else {
                    Text("Add your signature in Profile first.")
                        .font(.system(size: 13))
                        .foregroundColor(colors.amber)
                }
            }
            .padding(14)
            .background(colors.card2)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTES (OPTIONAL)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1)
                TextField("Witness notes for this jump", text: $witnessNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(colors.card)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
                    .foregroundColor(colors.text)
            }

            Button {
                guard vm.hasSavedSignature, !isSigning else { return }
                isSigning = true
                session.confirmAndSign(request, witnessNotes: witnessNotes)
            } label: {
                HStack {
                    if isSigning { ProgressView().tint(.white) }
                    Text(isSigning ? "Signing…" : "Sign jump")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(colors.green)
            .disabled(!vm.hasSavedSignature || isSigning)

            Button("Decline", role: .cancel) {
                witnessNotes = ""
                isSigning = false
                session.decline()
            }
            .foregroundColor(colors.muted)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.green.opacity(0.35), lineWidth: 1))
    }

    private func entrySummary(_ entry: SkydiverLogbookEntry) -> String {
        var parts = ["Jump #\(entry.jumpNumber)"]
        if let dz = entry.dz, !dz.isEmpty { parts.append("@ \(dz)") }
        if let alt = entry.altitude, !alt.isEmpty { parts.append("\(alt) ft") }
        return parts.joined(separator: " ")
    }

    private func startAdvertising(for entry: SkydiverLogbookEntry) async {
        let summary = entrySummary(entry)
        guard let challenge = await vm.createSigningChallenge(entryId: entry.id, summary: summary) else {
            statusMessage = vm.error ?? "Could not start signing session"
            return
        }
        qrPayload = challenge.qrPayload
        challengeNonce = challenge.nonce
        let request = LogbookSignRequest(entryId: entry.id, nonce: challenge.nonce, summary: summary)
        session.startAdvertising(for: request)
    }
}

struct LogbookWitnessQRCodeView: View {
    let payload: String
    @Environment(\.mdzColors) private var colors

    var body: some View {
        Group {
            if let img = Self.makeQRImage(from: payload) {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 40))
                        .foregroundColor(colors.muted)
                    Text("Could not render QR code")
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                }
                .frame(width: 220, height: 220)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
    }

    private static func makeQRImage(from string: String) -> UIImage? {
        guard !string.isEmpty,
              let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Signature pad (stylus/finger)
struct SignaturePadSheet: View {
    let entryId: Int
    @ObservedObject var vm: LogbookViewModel
    let onComplete: () -> Void
    @State private var strokes: [MDZSignatureStroke] = []
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
                    MDZFingerSignaturePad(
                        strokes: $strokes,
                        inkColor: .white,
                        lineWidth: 3,
                        paperColor: Color(red: 12 / 255, green: 29 / 255, blue: 53 / 255)
                    )
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
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
            .onAppear { strokes = [] }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete() }
                        .foregroundColor(colors.amber)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            guard let img = signatureImageFromStrokes(strokes, ink: .white, lineWidth: 3),
                                  let png = img.pngData() else {
                                errorMsg = "Please draw your signature first"
                                return
                            }
                            let base64 = png.base64EncodedString()
                            if await vm.signEntry(entryId: entryId, signatureBase64: base64) {
                                onComplete()
                            } else {
                                errorMsg = vm.error ?? "Could not sign entry"
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

            // Signature (witness counter-sign or instructor sign-off)
            VStack(alignment: .leading, spacing: 6) {
                Text("Signature")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(colors.muted)
                logbookSignatureBox
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
    }

    @ViewBuilder
    private var logbookSignatureBox: some View {
        if entry.isWitnessSigned {
            VStack(alignment: .leading, spacing: 8) {
                if let name = entry.witnessSignedBy, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.text)
                }
                if let lic = entry.witnessLicenseNumber, !lic.isEmpty {
                    Text("License \(lic)")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
                if let urlStr = entry.witnessSignatureUrl, !urlStr.isEmpty {
                    MDZRemoteSignatureImage(path: urlStr, cacheBuster: 0)
                        .frame(maxHeight: 72)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.3), lineWidth: 1))
                }
                if let at = entry.witnessSignedAt, !at.isEmpty {
                    Text(LogbookEntryCard.formatSignedDate(at))
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(colors.card2)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        } else if entry.isInstructorSigned, let signedBy = entry.signedBy, !signedBy.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(signedBy)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.text)
                if let lic = entry.instructorLicenseNumber, !lic.isEmpty {
                    Text("License \(lic)")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
                if let at = entry.signedAt, !at.isEmpty {
                    Text(LogbookEntryCard.formatSignedDate(at))
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(colors.card2)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        } else {
            Text(" ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 56)
                .padding(10)
                .background(colors.card2)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        }
    }

    private static func formatSignedDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 10 { return String(trimmed.prefix(10)) }
        return trimmed
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
    var editingEntry: SkydiverLogbookEntry? = nil
    let startFreefallTime: String
    let defaultJumpType: String
    let homeDropzone: String
    let onSave: (String?, String?, String?, String?, String?, String?, Int?, String?, String?) async -> Bool
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
    @State private var showSaveError = false
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
                        Text("Jump #\(editingEntry?.jumpNumber ?? nextJumpNumber)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colors.amber)

                        LogbookEditablePicker(
                            label: "DZ",
                            hint: "Drop zone name",
                            value: $dz,
                            options: vm.dropzoneOptions,
                            onAddOption: { vm.rememberPickerOption(dropzone: $0) }
                        )
                        addEntryField("Altitude", text: $altitude, hint: "Exit altitude (e.g. 13500)")
                        addFreefallField()
                        datePickerField
                        LogbookEditablePicker(
                            label: "Aircraft",
                            hint: "e.g. Caravan, Twin Otter",
                            value: $aircraft,
                            options: vm.aircraftOptions,
                            onAddOption: { vm.rememberPickerOption(aircraft: $0) }
                        )
                        rigPickerField
                        addEntryField("Equipment", text: $equipment, hint: "Rig or canopy (free text if not in list)")
                        addEntryField("Jump Type", text: $jumpType, hint: "Prefills from your default; change freely for this jump")
                        addEntryField("Comments", text: $comments, hint: "Optional remarks", multiline: true)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(editingEntry == nil ? "Add Jump" : "Edit Jump")
            .onAppear {
                if let e = editingEntry {
                    prefillFromEntry(e)
                } else {
                    prefillFromLastEntry()
                }
                Task { await vm.loadRigs() }
            }
            .sheet(isPresented: $showCreateRig) {
                CreateRigSheet(vm: vm, onComplete: {
                    showCreateRig = false
                })
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
                        Task {
                            let dateStr = Self.dateFormatter.string(from: jumpDate)
                            let ok = await onSave(dz, altitude, delay, dateStr, aircraft, equipment, selectedRigId, jumpType, comments)
                            if ok {
                                onCancel()
                            } else {
                                showSaveError = true
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.amber)
                    .disabled(vm.isSaving)
                }
            }
            .alert(editingEntry == nil ? "Could not add jump" : "Could not save changes", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.error ?? (editingEntry == nil ? "Failed to add entry" : "Failed to update entry"))
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
            if let v = e.altitude, !v.isEmpty { altitude = v }
            if let v = e.equipment, !v.isEmpty { equipment = v }
            if let rid = e.rigId, rid > 0 { selectedRigId = rid }
        }
        if dz.isEmpty {
            if !vm.lastDropzoneName.isEmpty { dz = vm.lastDropzoneName }
            else if !homeDropzone.isEmpty { dz = homeDropzone }
            else if let v = lastEntry?.dz, !v.isEmpty { dz = v }
        }
        if aircraft.isEmpty {
            if !vm.lastAircraftLabel.isEmpty { aircraft = vm.lastAircraftLabel }
            else if !vm.defaultAircraft.isEmpty { aircraft = vm.defaultAircraft }
            else if let v = lastEntry?.aircraft, !v.isEmpty { aircraft = v }
        }
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

    private func prefillFromEntry(_ e: SkydiverLogbookEntry) {
        dz = e.dz ?? ""
        altitude = e.altitude ?? ""
        delay = e.delay ?? ""
        aircraft = e.aircraft ?? ""
        equipment = e.equipment ?? ""
        if let rid = e.rigId, rid > 0 { selectedRigId = rid }
        jumpType = e.jumpType ?? ""
        comments = e.comments ?? ""
        if let ds = e.date, !ds.isEmpty {
            let f = Self.dateFormatter
            if let d = f.date(from: String(ds.prefix(10))) {
                jumpDate = d
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

// MARK: - Editable picker (preset list + add custom)

struct LogbookEditablePicker: View {
    let label: String
    let hint: String?
    @Binding var value: String
    var options: [String]
    var onAddOption: ((String) -> Void)? = nil

    @State private var showAddAlert = false
    @State private var newOptionText = ""
    @Environment(\.mdzColors) private var colors

    private var displayOptions: [String] {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return options }
        if options.contains(where: { $0.caseInsensitiveCompare(v) == .orderedSame }) {
            return options
        }
        return [v] + options
    }

    var body: some View {
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
            Menu {
                ForEach(displayOptions, id: \.self) { opt in
                    Button(opt) { value = opt }
                }
                Divider()
                Button("Add new…") {
                    newOptionText = value
                    showAddAlert = true
                }
            } label: {
                HStack {
                    Text(value.isEmpty ? "Select…" : value)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(value.isEmpty ? colors.muted : colors.text)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colors.amber)
                }
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border, lineWidth: 1))
        .alert("Add \(label)", isPresented: $showAddAlert) {
            TextField(label, text: $newOptionText)
            Button("Add") {
                let trimmed = newOptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                value = trimmed
                onAddOption?(trimmed)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved for future jumps on this device and synced when you add a jump.")
        }
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
    @State private var invalidFields: Set<RigFormField> = []
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
    private enum RigFormField: Hashable {
        case rigLabel
        case harnessMfr, harnessModel, harnessSn
        case reserveMfr, reserveModel, reserveSize, reserveSn
        case mainMfr, mainModel, mainSize
        case aadMfr, aadModel, aadSn
    }

    private func orderedMissingFields() -> [RigFormField] {
        var missing: [RigFormField] = []
        if rigLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(.rigLabel) }
        if harnessMfr.isEmpty { missing.append(.harnessMfr) }
        if harnessModel.isEmpty { missing.append(.harnessModel) }
        if harnessSn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(.harnessSn) }
        if reserveMfr.isEmpty { missing.append(.reserveMfr) }
        if reserveModel.isEmpty { missing.append(.reserveModel) }
        let reserveSz = Int(reserveSizeSqft.trimmingCharacters(in: .whitespaces)) ?? 0
        if reserveSizeSqft.trimmingCharacters(in: .whitespaces).isEmpty || reserveSz <= 0 { missing.append(.reserveSize) }
        if reserveSn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(.reserveSn) }
        if includeMainParachute {
            if mainMfr.isEmpty { missing.append(.mainMfr) }
            if mainModel.isEmpty { missing.append(.mainModel) }
            let mainSz = Int(mainSizeSqft.trimmingCharacters(in: .whitespaces)) ?? 0
            if mainSizeSqft.trimmingCharacters(in: .whitespaces).isEmpty || mainSz <= 0 { missing.append(.mainSize) }
        }
        if aadMfr.isEmpty { missing.append(.aadMfr) }
        if aadModel.isEmpty { missing.append(.aadModel) }
        if aadSn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(.aadSn) }
        return missing
    }

    private func fieldIsInvalid(_ field: RigFormField) -> Bool { invalidFields.contains(field) }

    private func clearInvalid(_ field: RigFormField) {
        if invalidFields.contains(field) { invalidFields.remove(field) }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    colors.background.ignoresSafeArea()
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            if !invalidFields.isEmpty {
                                validationBanner
                            }

                            Text(editingRig == nil
                                 ? "Add a rig to select when logging jumps. All fields below are required except main canopy SN when main is included."
                                 : "Editing this rig. Catalog loads first so manufacturer/model pickers show saved values. Tap Save to update.")
                                .font(.system(size: 13))
                                .foregroundColor(colors.text.opacity(0.9))
                                .padding(.bottom, 4)

                            sectionTitle("Rig")
                            addField("Rig label", text: $rigLabel, field: .rigLabel, hint: "Required")

                            sectionTitle("Harness & Container")
                            pickerField("Harness Manufacturer", selection: $harnessMfr, field: .harnessMfr, options: harnessMfrs) {
                                harnessModel = ""
                                clearInvalid(.harnessMfr)
                            }
                            pickerField(
                                "Harness Model",
                                selection: $harnessModel,
                                field: .harnessModel,
                                options: harnessModels,
                                dependencyHint: harnessMfr.isEmpty ? "Select harness manufacturer first." : nil
                            ) {
                                clearInvalid(.harnessModel)
                            }
                            addField("Harness SN", text: $harnessSn, field: .harnessSn, hint: "Required")
                            domDateRow(
                                label: "Harness DOM",
                                hint: "Date of manufacture (required)",
                                date: $harnessDomDate
                            )

                            sectionTitle("Reserve parachute")
                            Text("Reserve canopy — catalog from the server.")
                                .font(.system(size: 12))
                                .foregroundColor(colors.muted)
                            pickerField("Reserve manufacturer", selection: $reserveMfr, field: .reserveMfr, options: reserveMfrs) {
                                reserveModel = ""
                                reserveSizeSqft = ""
                                clearInvalid(.reserveMfr)
                            }
                            pickerField(
                                "Reserve model",
                                selection: $reserveModel,
                                field: .reserveModel,
                                options: reserveModels,
                                dependencyHint: reserveMfr.isEmpty ? "Select reserve manufacturer first." : nil
                            ) {
                                reserveSizeSqft = ""
                                clearInvalid(.reserveModel)
                            }
                            pickerField(
                                "Reserve size (sq ft)",
                                selection: $reserveSizeSqft,
                                field: .reserveSize,
                                options: reserveSizes.map { "\($0)" },
                                dependencyHint: {
                                    if reserveMfr.isEmpty { return "Select reserve manufacturer first." }
                                    if reserveModel.isEmpty { return "Select reserve model first." }
                                    return nil
                                }()
                            ) {
                                clearInvalid(.reserveSize)
                            }
                            addField("Reserve SN", text: $reserveSn, field: .reserveSn, hint: "Required")
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
                            .onChange(of: includeMainParachute) { _, on in
                                if !on {
                                    invalidFields.remove(.mainMfr)
                                    invalidFields.remove(.mainModel)
                                    invalidFields.remove(.mainSize)
                                }
                            }

                            if includeMainParachute {
                                sectionTitle("Main parachute")
                                Text("Sport / main canopy catalog (separate from reserve).")
                                    .font(.system(size: 12))
                                    .foregroundColor(colors.muted)
                                pickerField("Main manufacturer", selection: $mainMfr, field: .mainMfr, options: mainMfrs) {
                                    mainModel = ""
                                    mainSizeSqft = ""
                                    clearInvalid(.mainMfr)
                                }
                                pickerField(
                                    "Main model",
                                    selection: $mainModel,
                                    field: .mainModel,
                                    options: mainModels,
                                    dependencyHint: mainMfr.isEmpty ? "Select main manufacturer first." : nil
                                ) {
                                    mainSizeSqft = ""
                                    clearInvalid(.mainModel)
                                }
                                pickerField(
                                    "Main size (sq ft)",
                                    selection: $mainSizeSqft,
                                    field: .mainSize,
                                    options: mainSizes.map { "\($0)" },
                                    dependencyHint: {
                                        if mainMfr.isEmpty { return "Select main manufacturer first." }
                                        if mainModel.isEmpty { return "Select main model first." }
                                        return nil
                                    }()
                                ) {
                                    clearInvalid(.mainSize)
                                }
                                addField("Main SN", text: $mainSn, field: nil, hint: "Optional")
                                domDateRow(
                                    label: "Main DOM",
                                    hint: "Date of manufacture (required when main is included)",
                                    date: $mainDomDate
                                )
                            }

                            sectionTitle("AAD")
                            pickerField("AAD Manufacturer", selection: $aadMfr, field: .aadMfr, options: aadMfrs) {
                                aadModel = ""
                                clearInvalid(.aadMfr)
                            }
                            pickerField(
                                "AAD Model",
                                selection: $aadModel,
                                field: .aadModel,
                                options: aadModels,
                                dependencyHint: aadMfr.isEmpty ? "Select AAD manufacturer first." : nil
                            ) {
                                clearInvalid(.aadModel)
                            }
                            addField("AAD SN", text: $aadSn, field: .aadSn, hint: "Required")
                            domDateRow(
                                label: "AAD DOM",
                                hint: "Date of manufacture (required)",
                                date: $aadDomDate
                            )

                            sectionTitle("Notes")
                            addField("Notes", text: $notes, field: nil, hint: "Optional")

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
                            let missing = orderedMissingFields()
                            if !missing.isEmpty {
                                invalidFields = Set(missing)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo(missing[0], anchor: .center)
                                }
                                return
                            }
                            invalidFields = []
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
                        .disabled(vm.isSaving)
                    }
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

    private var validationBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(colors.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Missing required fields")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.danger)
                Text("Complete the highlighted fields below to save.")
                    .font(.system(size: 12))
                    .foregroundColor(colors.text.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(colors.danger.opacity(0.12))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.danger.opacity(0.55), lineWidth: 1))
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

    private func addField(_ label: String, text: Binding<String>, field: RigFormField?, hint: String? = nil) -> some View {
        let invalid = field.map { fieldIsInvalid($0) } ?? false
        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(invalid ? colors.danger : colors.amber)
                    .tracking(1)
                if invalid {
                    Text("Required")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colors.danger)
                } else if let h = hint, !h.isEmpty {
                    Text(h)
                        .font(.system(size: 12))
                        .foregroundColor(colors.text.opacity(0.9))
                }
            }
            TextField(label, text: text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colors.text)
                .tint(invalid ? colors.danger : colors.amber)
                .onChange(of: text.wrappedValue) { _, _ in
                    if let field { clearInvalid(field) }
                }
        }
        .padding(14)
        .background(invalid ? colors.danger.opacity(0.08) : colors.card)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(invalid ? colors.danger : colors.border, lineWidth: invalid ? 1.5 : 1)
        )
        .modifier(RigFormScrollAnchor(field: field))
    }

    /// Inline `Menu` (dropdown) + loading / retry / dependency hints so the sheet is not empty by mistake.
    private func pickerField(
        _ label: String,
        selection: Binding<String>,
        field: RigFormField,
        options: [String],
        dependencyHint: String? = nil,
        onChange: (() -> Void)? = nil
    ) -> some View {
        RigCatalogPickerRow(
            label: label,
            selection: selection,
            field: field,
            isInvalid: fieldIsInvalid(field),
            options: options,
            dependencyHint: dependencyHint,
            isApplyingSnapshot: isApplyingRigSnapshot,
            onChange: onChange,
            vm: vm
        )
        .modifier(RigFormScrollAnchor(field: field))
    }

    private struct RigFormScrollAnchor: ViewModifier {
        let field: RigFormField?

        func body(content: Content) -> some View {
            if let field {
                content.id(field)
            } else {
                content
            }
        }
    }

    private struct RigCatalogPickerRow: View {
        let label: String
        @Binding var selection: String
        let field: RigFormField
        let isInvalid: Bool
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
                    .foregroundColor(isInvalid ? colors.danger : colors.amber)
                    .tracking(1)
                if isInvalid {
                    Text("Required")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colors.danger)
                }
                pickerContent
            }
            .padding(14)
            .background(isInvalid ? colors.danger.opacity(0.08) : colors.card)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isInvalid ? colors.danger : colors.border, lineWidth: isInvalid ? 1.5 : 1)
            )
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
