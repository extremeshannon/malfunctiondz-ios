// Jump sign-off — student logbook submit + instructor Pass/Retake review.
import SwiftUI
import MalfunctionDZCore

// MARK: - Review checklist (ASP jump / ground — matches web review_checklist JSON)

struct ReviewChecklistItem: Codable, Identifiable, Hashable {
    let label: String
    let inputName: String
    let required: Bool?
    let prefix: String?
    let fieldId: String?
    let incrementalBox: Bool?
    let checkboxBox: String?
    let alreadyComplete: Bool?
    let locked: Bool?
    let signedByInitials: String?

    var id: String { inputName }

    enum CodingKeys: String, CodingKey {
        case label, required, prefix, locked
        case inputName = "input_name"
        case fieldId = "field_id"
        case incrementalBox = "incremental_box"
        case checkboxBox = "checkbox_box"
        case alreadyComplete = "already_complete"
        case signedByInitials = "signed_by_initials"
    }

    var isRequired: Bool { required ?? true }
    var isInteractive: Bool { !(alreadyComplete ?? false) && !(locked ?? false) }
}

struct ReviewChecklistSection: Codable, Identifiable, Hashable {
    let key: String?
    let title: String?
    let requiredItems: [ReviewChecklistItem]?
    let openItems: [ReviewChecklistItem]?
    let maneuverItems: [ReviewChecklistItem]?
    let carryover: Bool?
    let incrementalTable: Bool?

    var id: String { key ?? title ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case key, title, carryover
        case requiredItems = "required_items"
        case openItems = "open_items"
        case maneuverItems = "maneuver_items"
        case incrementalTable = "incremental_table"
    }
}

struct ReviewChecklistPayload: Codable, Hashable {
    let title: String?
    let description: String?
    let orderedSections: [ReviewChecklistSection]?
    let incrementalManeuverMode: Bool?

    enum CodingKeys: String, CodingKey {
        case title, description
        case orderedSections = "ordered_sections"
        case incrementalManeuverMode = "incremental_maneuver_mode"
    }

    var allRequiredInputNames: [String] {
        guard let sections = orderedSections else { return [] }
        return sections.flatMap { section in
            let pools = [section.requiredItems, section.maneuverItems].compactMap { $0 }
            return pools.flatMap { items in
                items.filter { $0.isRequired && $0.isInteractive }.map(\.inputName)
            }
        }
    }
}

@MainActor
final class ReviewChecklistState: ObservableObject {
    @Published var checked: Set<String> = []
    @Published var instructorAck = false

    let checklist: ReviewChecklistPayload?
    let ackStatement: String

    init(checklist: ReviewChecklistPayload?, ackStatement: String = "") {
        self.checklist = checklist
        self.ackStatement = ackStatement
    }

    var hasChecklist: Bool {
        guard let sections = checklist?.orderedSections else { return false }
        return sections.contains { !($0.requiredItems ?? []).isEmpty || !($0.openItems ?? []).isEmpty }
    }

    var allRequiredChecked: Bool {
        guard let names = checklist?.allRequiredInputNames, !names.isEmpty else { return true }
        return names.allSatisfy { checked.contains($0) }
    }

    var ackRequired: Bool { !ackStatement.isEmpty }

    var passReady: Bool { allRequiredChecked && (!ackRequired || instructorAck) }

    func reviewChecksPayload() -> [String: String] {
        var out: [String: String] = [:]
        for name in checked { out[name] = "1" }
        return out
    }
}

struct ReviewChecklistView: View {
    @ObservedObject var state: ReviewChecklistState
    @Environment(\.mdzColors) private var colors

    var body: some View {
        if let checklist = state.checklist {
            VStack(alignment: .leading, spacing: 14) {
                if let title = checklist.title, !title.isEmpty {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(colors.muted)
                        .tracking(1)
                }
                if let desc = checklist.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                }
                if state.hasChecklist {
                    Text("All required items must be checked before Pass.")
                        .font(.system(size: 11))
                        .foregroundColor(colors.amber)
                }
                ForEach(checklist.orderedSections ?? []) { section in
                    sectionBlock(section)
                }
                if state.ackRequired { ackBlock }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func sectionBlock(_ section: ReviewChecklistSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(colors.text)
            }
            if section.incrementalTable == true || !(section.maneuverItems ?? []).isEmpty {
                incrementalTable(section.maneuverItems ?? section.requiredItems ?? [])
            } else {
                if let required = section.requiredItems, !required.isEmpty {
                    Text("Required")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(colors.muted)
                        .tracking(0.8)
                    ForEach(required) { item in checklistRow(item, required: true) }
                }
            }
            if let open = section.openItems, !open.isEmpty {
                Text("Not required")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(0.8)
                    .padding(.top, 4)
                Text("Check only what the student completed on this jump.")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
                ForEach(open) { item in checklistRow(item, required: false) }
            }
        }
    }

    private func incrementalTable(_ items: [ReviewChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                if item.alreadyComplete == true {
                    HStack(spacing: 10) {
                        Text(item.checkboxBox ?? "✓")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(colors.green)
                            .frame(width: 28, height: 28)
                            .background(colors.green.opacity(0.15))
                            .cornerRadius(6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.system(size: 14))
                                .foregroundColor(colors.muted)
                            if let initl = item.signedByInitials, !initl.isEmpty {
                                Text("Signed \(initl)")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.green)
                            }
                        }
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(colors.green)
                    }
                    .padding(.vertical, 4)
                } else {
                    checklistRow(item, required: item.isRequired)
                }
            }
        }
    }

    private func checklistRow(_ item: ReviewChecklistItem, required: Bool) -> some View {
        let done = state.checked.contains(item.inputName)
        let disabled = !item.isInteractive
        return Button {
            guard item.isInteractive else { return }
            toggle(item.inputName)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if let box = item.checkboxBox, item.incrementalBox == true {
                    Text(box)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(done ? colors.green : (disabled ? colors.muted.opacity(0.5) : colors.text))
                        .frame(width: 28, height: 28)
                        .background((done ? colors.green : colors.card2).opacity(done ? 0.2 : 1))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(done ? colors.green : colors.border))
                } else {
                    Image(systemName: done ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundColor(done ? colors.green : (disabled ? colors.muted.opacity(0.4) : colors.muted))
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let prefix = item.prefix, !prefix.isEmpty {
                        Text(prefix)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(colors.amber)
                    }
                    Text(item.label)
                        .font(.system(size: 14, weight: required ? .semibold : .regular))
                        .foregroundColor(disabled ? colors.muted : colors.text)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .opacity(disabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var ackBlock: some View {
        Button { state.instructorAck.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state.instructorAck ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(state.instructorAck ? colors.green : colors.muted)
                Text(state.ackStatement)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.text)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card2)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(state.instructorAck ? colors.green.opacity(0.5) : colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ name: String) {
        if state.checked.contains(name) { state.checked.remove(name) }
        else { state.checked.insert(name) }
    }
}

// MARK: - Helpers

func isJumpSignoffLessonTitle(_ title: String) -> Bool {
    let t = title.lowercased()
    return (t.contains("sign off") || t.contains("signoff")) && !t.contains("review")
}

func isReviewGateLessonTitle(_ title: String) -> Bool {
    let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if isJumpSignoffLessonTitle(title) { return false }
    return t.contains("review") || t.contains("sign off") || t.contains("signoff")
}

// MARK: - Models

struct JumpSignoffChoice: Codable, Identifiable, Hashable {
    let value: String
    let label: String
    var id: String { value }
}

struct JumpSignoffChoices: Codable {
    let aircraft: [JumpSignoffChoice]
    let locations: [JumpSignoffChoice]
    let equipment: [JumpSignoffChoice]
    let jumpTypes: [JumpSignoffChoice]

    enum CodingKeys: String, CodingKey {
        case aircraft, locations, equipment
        case jumpTypes = "jump_types"
    }
}

struct JumpSignoffState: Codable {
    let id: Int
    let status: String
    let studentNote: String?
    let instructorNotes: String?
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case studentNote = "student_note"
        case instructorNotes = "instructor_notes"
        case submittedAt = "submitted_at"
    }
}

struct JumpLogEntryPayload: Codable {
    let id: Int?
    let jumpNumber: Int?
    let jumpDate: String?
    let jumpType: String?
    let altitudeFt: Int?
    let aircraftLabel: String?
    let dropzoneName: String?
    let equipment: String?
    let freefallSeconds: Int?
    let freefallDisplay: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, notes, equipment
        case jumpNumber = "jump_number"
        case jumpDate = "jump_date"
        case jumpType = "jump_type"
        case altitudeFt = "altitude_ft"
        case aircraftLabel = "aircraft_label"
        case dropzoneName = "dropzone_name"
        case freefallSeconds = "freefall_seconds"
        case freefallDisplay = "freefall_display"
    }
}

struct JumpSignoffFormPayload: Codable {
    let jumpNumber: Int?
    let jumpDate: String?
    let jumpType: String?
    let altitudeFt: Int?
    let aircraftLabel: String?
    let dropzoneName: String?
    let equipment: String?
    let freefallSeconds: Int?
    let notes: String?
    let studentNote: String?

    enum CodingKeys: String, CodingKey {
        case notes, equipment
        case jumpNumber = "jump_number"
        case jumpDate = "jump_date"
        case jumpType = "jump_type"
        case altitudeFt = "altitude_ft"
        case aircraftLabel = "aircraft_label"
        case dropzoneName = "dropzone_name"
        case freefallSeconds = "freefall_seconds"
        case studentNote = "student_note"
    }
}

struct JumpSignoffLoadResponse: Codable {
    let ok: Bool
    let signoff: JumpSignoffState?
    let entry: JumpLogEntryPayload?
    let form: JumpSignoffFormPayload?
    let choices: JumpSignoffChoices?
    let aspJumpTypeLabel: String?
    let totalFreefallDisplay: String?
    let canSubmit: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, signoff, entry, form, choices, error
        case aspJumpTypeLabel = "asp_jump_type_label"
        case totalFreefallDisplay = "total_freefall_display"
        case canSubmit = "can_submit"
    }
}

struct JumpSignoffSubmitBody: Codable {
    let lessonId: Int
    let moduleId: Int
    let jumpDate: String
    let jumpType: String
    let aircraftLabel: String
    let dropzoneName: String
    let altitudeFt: Int?
    let jumpNumber: Int?
    let freefallSeconds: Int?
    let equipment: String
    let notes: String
    let studentNote: String

    enum CodingKeys: String, CodingKey {
        case notes, equipment
        case lessonId = "lesson_id"
        case moduleId = "module_id"
        case jumpDate = "jump_date"
        case jumpType = "jump_type"
        case aircraftLabel = "aircraft_label"
        case dropzoneName = "dropzone_name"
        case altitudeFt = "altitude_ft"
        case jumpNumber = "jump_number"
        case freefallSeconds = "freefall_seconds"
        case studentNote = "student_note"
    }
}

struct InstructorJumpSignoffDetail: Codable {
    let id: Int
    let studentId: Int
    let studentName: String
    let courseTitle: String
    let moduleTitle: String
    let lessonTitle: String
    let status: String
    let studentNote: String?
    let instructorNotes: String?
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case studentId = "student_id"
        case studentName = "student_name"
        case courseTitle = "course_title"
        case moduleTitle = "module_title"
        case lessonTitle = "lesson_title"
        case studentNote = "student_note"
        case instructorNotes = "instructor_notes"
        case submittedAt = "submitted_at"
    }
}

struct InstructorJumpReviewResponse: Codable {
    let ok: Bool
    let signoff: InstructorJumpSignoffDetail?
    let entry: JumpLogEntryPayload?
    let aspJumpTypeLabel: String?
    let canResolve: Bool?
    let instructorProfileReady: Bool?
    let reviewChecklist: ReviewChecklistPayload?
    let instructorJumpSignoffStatement: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, signoff, entry, error
        case aspJumpTypeLabel = "asp_jump_type_label"
        case canResolve = "can_resolve"
        case instructorProfileReady = "instructor_profile_ready"
        case reviewChecklist = "review_checklist"
        case instructorJumpSignoffStatement = "instructor_jump_signoff_statement"
    }
}

// MARK: - Student ViewModel

@MainActor
final class JumpSignoffViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var status = "draft"
    @Published var canSubmit = false
    @Published var choices: JumpSignoffChoices?
    @Published var aspJumpTypeLabel = ""
    @Published var totalFreefallDisplay = ""
    @Published var instructorNotes = ""
    @Published var error: String?

    @Published var jumpNumber = ""
    @Published var jumpDate = ""
    @Published var jumpType = "aff"
    @Published var aircraft = ""
    @Published var location = ""
    @Published var equipment = ""
    @Published var altitude = ""
    @Published var freefallSeconds = ""
    @Published var notes = ""
    @Published var studentNote = ""

    let lessonId: Int
    let moduleId: Int

    init(lessonId: Int, moduleId: Int) {
        self.lessonId = lessonId
        self.moduleId = moduleId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/jump-signoff.php?lesson_id=\(lessonId)&module_id=\(moduleId)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(JumpSignoffLoadResponse.self, from: data)
            guard resp.ok, let form = resp.form else {
                error = resp.error ?? "Could not load jump sign-off"
                return
            }
            status = resp.signoff?.status ?? "draft"
            canSubmit = resp.canSubmit ?? false
            choices = resp.choices
            aspJumpTypeLabel = resp.aspJumpTypeLabel ?? ""
            totalFreefallDisplay = resp.totalFreefallDisplay ?? ""
            instructorNotes = resp.signoff?.instructorNotes ?? ""
            applyForm(form)
        } catch {
            self.error = "Could not load jump sign-off."
        }
    }

    private func applyForm(_ form: JumpSignoffFormPayload) {
        jumpNumber = form.jumpNumber.map { "\($0)" } ?? ""
        jumpDate = form.jumpDate ?? ""
        jumpType = form.jumpType ?? "aff"
        aircraft = form.aircraftLabel ?? ""
        location = form.dropzoneName ?? ""
        equipment = form.equipment ?? ""
        altitude = form.altitudeFt.map { "\($0)" } ?? ""
        freefallSeconds = form.freefallSeconds.map { "\($0)" } ?? ""
        notes = form.notes ?? ""
        studentNote = form.studentNote ?? ""
    }

    func submit() async -> Bool {
        guard canSubmit else { return false }
        if equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "Select equipment."
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/jump-signoff.php") else { return false }

        let body = JumpSignoffSubmitBody(
            lessonId: lessonId,
            moduleId: moduleId,
            jumpDate: jumpDate,
            jumpType: jumpType,
            aircraftLabel: aircraft,
            dropzoneName: location,
            altitudeFt: Int(altitude),
            jumpNumber: Int(jumpNumber),
            freefallSeconds: Int(freefallSeconds),
            equipment: equipment,
            notes: notes,
            studentNote: studentNote
        )
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct R: Codable { let ok: Bool; let error: String? }
            let resp = try JSONDecoder().decode(R.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not submit jump"
                return false
            }
            await load()
            return true
        } catch {
            self.error = "Could not submit jump."
            return false
        }
    }
}

// MARK: - Shared jump logbook form layout

struct JumpSignoffFormLayout: View {
    @Binding var jumpNumber: String
    @Binding var jumpDate: String
    @Binding var location: String
    @Binding var aircraft: String
    @Binding var equipment: String
    @Binding var altitude: String
    @Binding var freefallSeconds: String
    @Binding var notes: String

    let choices: JumpSignoffChoices?
    let aspJumpTypeLabel: String
    let totalFreefallDisplay: String
    var jumpNumberDisabled: Bool = true

    @Environment(\.mdzColors) private var colors
    @Environment(\.horizontalSizeClass) private var hSize

    private var wide: Bool { hSize == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if wide {
                row(jumpNumberField, dateField)
                row(placePicker, aircraftPicker)
                row(equipmentPicker, altitudeField)
                row(freefallField, jumpTypeField)
            } else {
                row(jumpNumberField, dateField)
                placePicker
                aircraftPicker
                equipmentPicker
                row(altitudeField, freefallField)
                jumpTypeField
            }

            if !totalFreefallDisplay.isEmpty {
                Text("Total freefall logged: \(totalFreefallDisplay)")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }

            descriptionField
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var jumpNumberField: some View {
        formField("Jump #", text: $jumpNumber, disabled: jumpNumberDisabled)
    }

    private var dateField: some View {
        formField("Date", text: $jumpDate)
    }

    private var altitudeField: some View {
        formField("Altitude (ft)", text: $altitude, keyboard: .numberPad)
    }

    private var freefallField: some View {
        formField("Freefall (sec)", text: $freefallSeconds, keyboard: .numberPad)
    }

    private var placePicker: some View {
        formPicker("Place", selection: $location, choices: choices?.locations ?? [])
    }

    private var aircraftPicker: some View {
        formPicker("Aircraft", selection: $aircraft, choices: choices?.aircraft ?? [])
    }

    private var equipmentPicker: some View {
        formPicker("Equipment", selection: $equipment, choices: choices?.equipment ?? [])
    }

    @ViewBuilder
    private var jumpTypeField: some View {
        if aspJumpTypeLabel.isEmpty {
            Color.clear.frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Jump type")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colors.muted)
                Text(aspJumpTypeLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(colors.card2)
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Jump description")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(colors.muted)
            TextEditor(text: $notes)
                .frame(minHeight: wide ? 88 : 72)
                .padding(8)
                .background(colors.card2)
                .cornerRadius(8)
                .foregroundColor(colors.text)
        }
    }

    private func row<Left: View, Right: View>(_ left: Left, _ right: Right) -> some View {
        HStack(alignment: .top, spacing: 12) {
            left.frame(maxWidth: .infinity)
            right.frame(maxWidth: .infinity)
        }
    }

    private func formField(
        _ label: String,
        text: Binding<String>,
        disabled: Bool = false,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(colors.muted)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .disabled(disabled)
                .padding(10)
                .background(colors.card2)
                .cornerRadius(8)
                .foregroundColor(colors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formPicker(_ label: String, selection: Binding<String>, choices: [JumpSignoffChoice]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(colors.muted)
            Menu {
                Button("Select…") { selection.wrappedValue = "" }
                ForEach(choices) { c in
                    Button(c.label) { selection.wrappedValue = c.value }
                }
            } label: {
                HStack {
                    Text(pickerLabel(selection.wrappedValue, choices: choices))
                        .foregroundColor(selection.wrappedValue.isEmpty ? colors.muted : colors.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(colors.muted)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.card2)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pickerLabel(_ value: String, choices: [JumpSignoffChoice]) -> String {
        if value.isEmpty { return "Select…" }
        return choices.first(where: { $0.value == value })?.label ?? value
    }
}

// MARK: - Student UI

struct JumpSignoffLessonSection: View {
    let lessonId: Int
    let moduleId: Int
    @StateObject private var vm: JumpSignoffViewModel
    @Environment(\.mdzColors) private var colors

    init(lessonId: Int, moduleId: Int) {
        self.lessonId = lessonId
        self.moduleId = moduleId
        _vm = StateObject(wrappedValue: JumpSignoffViewModel(lessonId: lessonId, moduleId: moduleId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("JUMP LOGBOOK")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.amber)
                .tracking(1.2)

            statusBanner

            if vm.status == "passed" {
                JumpLogEntryReadonlyCard(entry: nil, vm: vm)
            } else if vm.status == "pending_review" {
                Text("Jump log submitted — waiting for instructor review (Pass or Retake).")
                    .font(.system(size: 13))
                    .foregroundColor(colors.amber)
                JumpLogEntryReadonlyCard(entry: nil, vm: vm)
            } else if vm.canSubmit {
                JumpSignoffFormLayout(
                    jumpNumber: $vm.jumpNumber,
                    jumpDate: $vm.jumpDate,
                    location: $vm.location,
                    aircraft: $vm.aircraft,
                    equipment: $vm.equipment,
                    altitude: $vm.altitude,
                    freefallSeconds: $vm.freefallSeconds,
                    notes: $vm.notes,
                    choices: vm.choices,
                    aspJumpTypeLabel: vm.aspJumpTypeLabel,
                    totalFreefallDisplay: vm.totalFreefallDisplay
                )

                Button {
                    Task { _ = await vm.submit() }
                } label: {
                    Text(vm.isSubmitting ? "Submitting…" : "Submit for Instructor Review")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.primary)
                        .cornerRadius(12)
                }
                .disabled(vm.isSubmitting)
            }

            if vm.status == "retake", !vm.instructorNotes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(colors.danger)
                    Text("Instructor: \(vm.instructorNotes)")
                        .font(.system(size: 12))
                        .foregroundColor(colors.danger)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.danger.opacity(0.08))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch vm.status {
        case "passed":
            statusPill("Jump signed off — Pass", icon: "checkmark.seal.fill", tint: colors.green)
        case "pending_review":
            statusPill("Awaiting instructor review", icon: "clock.fill", tint: colors.amber)
        case "retake":
            statusPill("Retake — update and resubmit", icon: "arrow.counterclockwise", tint: colors.danger)
        default:
            Text("Fill in your jump details below. Your instructor will review and mark Pass or Retake.")
                .font(.system(size: 13))
                .foregroundColor(colors.muted)
        }
    }

    private func statusPill(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1))
        .cornerRadius(8)
    }
}

struct JumpLogEntryReadonlyCard: View {
    let entry: JumpLogEntryPayload?
    @ObservedObject var vm: JumpSignoffViewModel
    @Environment(\.mdzColors) private var colors
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        let rows = readonlyRows

        if hSize == .regular {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                    row(item.0, item.1)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                    row(item.0, item.1)
                }
            }
        }
    }

    private var readonlyRows: [(String, String)] {
        var out: [(String, String)] = [
            ("Jump #", vm.jumpNumber),
            ("Date", vm.jumpDate),
            ("Place", vm.location),
            ("Aircraft", vm.aircraft),
            ("Equipment", vm.equipment),
        ]
        if !vm.altitude.isEmpty { out.append(("Altitude", vm.altitude + " ft")) }
        if !vm.freefallSeconds.isEmpty { out.append(("Freefall", vm.freefallSeconds + " sec")) }
        if !vm.aspJumpTypeLabel.isEmpty { out.append(("Type", vm.aspJumpTypeLabel)) }
        if !vm.notes.isEmpty { out.append(("Notes", vm.notes)) }
        return out
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundColor(colors.muted).frame(width: 88, alignment: .leading)
            Text(v).foregroundColor(colors.text)
        }
        .font(.system(size: 13))
    }
}

// MARK: - Instructor review

@MainActor
final class InstructorJumpReviewViewModel: ObservableObject {
    @Published var detail: InstructorJumpReviewResponse?
    @Published var instructorNotes = ""
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var checklistState = ReviewChecklistState(checklist: nil)

    let signoffId: Int
    init(signoffId: Int) { self.signoffId = signoffId }

    var canPass: Bool {
        guard detail?.instructorProfileReady != false else { return false }
        let notesOk = !instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return notesOk && checklistState.passReady
    }

    var canRetake: Bool {
        guard detail?.instructorProfileReady != false else { return false }
        return !instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/jump-signoffs/\(signoffId).php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(InstructorJumpReviewResponse.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Review not found"
                return
            }
            detail = resp
            checklistState = ReviewChecklistState(
                checklist: resp.reviewChecklist,
                ackStatement: resp.instructorJumpSignoffStatement ?? ""
            )
        } catch {
            self.error = "Could not load jump review."
        }
    }

    func resolve(result: String) async -> Bool {
        let notes = instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.isEmpty {
            error = "Instructor notes are required."
            return false
        }
        if result == "pass" {
            if detail?.instructorProfileReady == false {
                error = "Complete jump sign-offs: USPA license and signature in My Profile, plus instructor initials."
                return false
            }
            if !checklistState.passReady {
                error = "Check every required item and confirm the instructor statement before Pass."
                return false
            }
        } else if detail?.instructorProfileReady == false {
            error = "Complete jump sign-offs: USPA license and signature in My Profile, plus instructor initials."
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/jump-signoffs/\(signoffId)/resolve.php") else { return false }
        struct Body: Codable {
            let result: String
            let notes: String
            let instructorJumpSignoffAck: Bool?
            let reviewChecks: [String: String]?

            enum CodingKeys: String, CodingKey {
                case result, notes
                case instructorJumpSignoffAck = "instructor_jump_signoff_ack"
                case reviewChecks = "review_checks"
            }
        }
        let body = Body(
            result: result,
            notes: notes,
            instructorJumpSignoffAck: result == "pass" && checklistState.instructorAck ? true : nil,
            reviewChecks: checklistState.reviewChecksPayload().isEmpty ? nil : checklistState.reviewChecksPayload()
        )
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct R: Codable { let ok: Bool; let error: String? }
            let resp = try JSONDecoder().decode(R.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not save decision"
                return false
            }
            return true
        } catch {
            self.error = "Could not save decision."
            return false
        }
    }
}

struct InstructorJumpReviewDetailView: View {
    let signoffId: Int
    @StateObject private var vm: InstructorJumpReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    init(signoffId: Int) {
        self.signoffId = signoffId
        _vm = StateObject(wrappedValue: InstructorJumpReviewViewModel(signoffId: signoffId))
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && vm.detail == nil {
                ProgressView().tint(colors.amber)
            } else if let s = vm.detail?.signoff {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("JUMP SIGN-OFF")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.primary)
                                .tracking(1.2)
                            Text(s.studentName)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(colors.text)
                            Text(s.lessonTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(colors.amber)
                            Text("\(s.moduleTitle) · \(s.courseTitle)")
                                .font(.system(size: 12))
                                .foregroundColor(colors.muted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colors.card)
                        .cornerRadius(12)

                        if let entry = vm.detail?.entry {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LOGBOOK ENTRY")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.muted)
                                .tracking(1)
                            logRow("Jump #", entry.jumpNumber.map { "\($0)" } ?? "—")
                            logRow("Date", entry.jumpDate ?? "—")
                            logRow("Place", entry.dropzoneName ?? "—")
                            logRow("Aircraft", entry.aircraftLabel ?? "—")
                            logRow("Equipment", entry.equipment ?? "—")
                            if let alt = entry.altitudeFt { logRow("Altitude", "\(alt) ft") }
                            if let ff = entry.freefallDisplay ?? entry.freefallSeconds.map({ "\($0)s" }) {
                                logRow("Freefall", ff)
                            }
                            logRow("Type", vm.detail?.aspJumpTypeLabel ?? entry.jumpType ?? "—")
                            if let n = entry.notes, !n.isEmpty {
                                logRow("Notes", n)
                            }
                        }
                        .padding(16)
                        .background(colors.card)
                        .cornerRadius(12)
                        } else {
                            Text("No logbook entry linked.")
                                .font(.system(size: 13))
                                .foregroundColor(colors.muted)
                                .padding(16)
                                .background(colors.card)
                                .cornerRadius(12)
                        }

                        if vm.detail?.reviewChecklist != nil {
                            ReviewChecklistView(state: vm.checklistState)
                        }

                        if vm.detail?.instructorProfileReady == false {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Complete jump sign-offs: USPA license and signature in My Profile, plus instructor initials.")
                                    .font(.system(size: 12))
                                    .foregroundColor(colors.amber)
                                NavigationLink(destination: InstructorProfileView()) {
                                    Text("Open instructor profile")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colors.primary)
                                }
                            }
                            .padding(12)
                            .background(colors.card)
                            .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("INSTRUCTOR NOTES")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.muted)
                                .tracking(1)
                            TextEditor(text: $vm.instructorNotes)
                                .frame(minHeight: 88)
                                .padding(8)
                                .background(colors.card2)
                                .cornerRadius(8)
                                .foregroundColor(colors.text)
                        }
                        .padding(16)
                        .background(colors.card)
                        .cornerRadius(12)

                        if vm.detail?.canResolve == true {
                            HStack(spacing: 10) {
                                Button {
                                    Task { if await vm.resolve(result: "pass") { dismiss() } }
                                } label: {
                                    Text(vm.isSubmitting ? "Saving…" : "Pass")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(colors.green.opacity(vm.canPass && !vm.isSubmitting ? 1 : 0.35))
                                        .cornerRadius(10)
                                }
                                .disabled(vm.isSubmitting || !vm.canPass)

                                Button {
                                    Task { if await vm.resolve(result: "retake") { dismiss() } }
                                } label: {
                                    Text("Retake")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(colors.danger.opacity(vm.canRetake ? 1 : 0.55))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(colors.card)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.danger.opacity(0.4)))
                                }
                                .disabled(vm.isSubmitting || !vm.canRetake)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Jump Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
    }

    private func logRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundColor(colors.muted).frame(width: 88, alignment: .leading)
            Text(v).foregroundColor(colors.text)
        }
        .font(.system(size: 13))
    }
}

// MARK: - Instructor student jump sign-off (log + Pass/Retake)

struct InstructorManageJumpSignoffResponse: Codable {
    let ok: Bool
    let studentId: Int?
    let studentName: String?
    let lessonTitle: String?
    let signoff: JumpSignoffState?
    let form: JumpSignoffFormPayload?
    let choices: JumpSignoffChoices?
    let aspJumpTypeLabel: String?
    let totalFreefallDisplay: String?
    let canFinalize: Bool?
    let priorRetakeNote: String?
    let instructorProfileReady: Bool?
    let reviewChecklist: ReviewChecklistPayload?
    let instructorJumpSignoffStatement: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, signoff, form, choices, error
        case studentId = "student_id"
        case studentName = "student_name"
        case lessonTitle = "lesson_title"
        case aspJumpTypeLabel = "asp_jump_type_label"
        case totalFreefallDisplay = "total_freefall_display"
        case canFinalize = "can_finalize"
        case priorRetakeNote = "prior_retake_note"
        case instructorProfileReady = "instructor_profile_ready"
        case reviewChecklist = "review_checklist"
        case instructorJumpSignoffStatement = "instructor_jump_signoff_statement"
    }
}

@MainActor
final class InstructorStudentJumpSignoffViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var status = "draft"
    @Published var canFinalize = false
    @Published var instructorProfileReady = false
    @Published var priorRetakeNote = ""
    @Published var choices: JumpSignoffChoices?
    @Published var aspJumpTypeLabel = ""
    @Published var totalFreefallDisplay = ""
    @Published var instructorNotes = ""
    @Published var lessonTitle = ""
    @Published var signoffId = 0
    @Published var error: String?

    @Published var jumpNumber = ""
    @Published var jumpDate = ""
    @Published var jumpType = "aff"
    @Published var aircraft = ""
    @Published var location = ""
    @Published var equipment = ""
    @Published var altitude = ""
    @Published var freefallSeconds = ""
    @Published var notes = ""
    @Published var studentNote = ""
    @Published var checklistState = ReviewChecklistState(checklist: nil)

    let studentId: Int
    let lessonId: Int
    let moduleId: Int

    init(studentId: Int, lessonId: Int, moduleId: Int) {
        self.studentId = studentId
        self.lessonId = lessonId
        self.moduleId = moduleId
    }

    var isEditable: Bool { canFinalize && status != "passed" }

    var logbookValid: Bool {
        !equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !jumpDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canPass: Bool {
        instructorProfileReady
            && logbookValid
            && !instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && checklistState.passReady
    }

    var canRetake: Bool {
        instructorProfileReady
            && logbookValid
            && !instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/jump-signoff.php?student_id=\(studentId)&lesson_id=\(lessonId)&module_id=\(moduleId)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode >= 400,
               let errResp = try? JSONDecoder().decode(InstructorManageJumpSignoffResponse.self, from: data),
               let msg = errResp.error {
                error = msg
                return
            }
            let decoded = try JSONDecoder().decode(InstructorManageJumpSignoffResponse.self, from: data)
            guard decoded.ok, let form = decoded.form else {
                error = decoded.error ?? "Could not load jump sign-off"
                return
            }
            status = decoded.signoff?.status ?? "draft"
            signoffId = decoded.signoff?.id ?? 0
            canFinalize = decoded.canFinalize ?? false
            instructorProfileReady = decoded.instructorProfileReady ?? false
            priorRetakeNote = decoded.priorRetakeNote ?? ""
            choices = decoded.choices
            aspJumpTypeLabel = decoded.aspJumpTypeLabel ?? ""
            totalFreefallDisplay = decoded.totalFreefallDisplay ?? ""
            lessonTitle = decoded.lessonTitle ?? ""
            if status == "pending_review" {
                instructorNotes = decoded.signoff?.instructorNotes ?? ""
            } else if status != "retake" {
                instructorNotes = decoded.signoff?.instructorNotes ?? ""
            } else {
                instructorNotes = ""
            }
            checklistState = ReviewChecklistState(
                checklist: decoded.reviewChecklist,
                ackStatement: decoded.instructorJumpSignoffStatement ?? ""
            )
            applyForm(form)
        } catch {
            self.error = "Could not load jump sign-off."
        }
    }

    private func applyForm(_ form: JumpSignoffFormPayload) {
        jumpNumber = form.jumpNumber.map { "\($0)" } ?? ""
        jumpDate = form.jumpDate ?? ""
        jumpType = form.jumpType ?? "aff"
        aircraft = form.aircraftLabel ?? ""
        location = form.dropzoneName ?? ""
        equipment = form.equipment ?? ""
        altitude = form.altitudeFt.map { "\($0)" } ?? ""
        freefallSeconds = form.freefallSeconds.map { "\($0)" } ?? ""
        notes = form.notes ?? ""
        studentNote = form.studentNote ?? ""
    }

    func finalize(result: String) async -> Bool {
        let instNotes = instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if instNotes.isEmpty {
            error = "Instructor notes are required."
            return false
        }
        if !logbookValid {
            error = "Complete logbook fields (equipment, date, etc.)."
            return false
        }
        if result == "pass" {
            if !instructorProfileReady {
                error = "Complete jump sign-offs: USPA license and signature in My Profile, plus instructor initials."
                return false
            }
            if !checklistState.passReady {
                error = "Check every required item and confirm the instructor statement before Pass."
                return false
            }
        } else if !instructorProfileReady {
            error = "Complete jump sign-offs: USPA license and signature in My Profile, plus instructor initials."
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/jump-signoff/finalize.php") else { return false }

        struct Body: Codable {
            let studentId: Int
            let lessonId: Int
            let moduleId: Int
            let result: String
            let instructorNotes: String
            let jumpDate: String
            let jumpType: String
            let aircraftLabel: String
            let dropzoneName: String
            let altitudeFt: Int?
            let jumpNumber: Int?
            let freefallSeconds: Int?
            let equipment: String
            let notes: String
            let studentNote: String
            let instructorJumpSignoffAck: Bool?
            let reviewChecks: [String: String]?

            enum CodingKeys: String, CodingKey {
                case result, notes, equipment
                case studentId = "student_id"
                case lessonId = "lesson_id"
                case moduleId = "module_id"
                case instructorNotes = "instructor_notes"
                case jumpDate = "jump_date"
                case jumpType = "jump_type"
                case aircraftLabel = "aircraft_label"
                case dropzoneName = "dropzone_name"
                case altitudeFt = "altitude_ft"
                case jumpNumber = "jump_number"
                case freefallSeconds = "freefall_seconds"
                case studentNote = "student_note"
                case instructorJumpSignoffAck = "instructor_jump_signoff_ack"
                case reviewChecks = "review_checks"
            }
        }

        let body = Body(
            studentId: studentId,
            lessonId: lessonId,
            moduleId: moduleId,
            result: result,
            instructorNotes: instNotes,
            jumpDate: jumpDate,
            jumpType: jumpType,
            aircraftLabel: aircraft,
            dropzoneName: location,
            altitudeFt: Int(altitude),
            jumpNumber: Int(jumpNumber),
            freefallSeconds: Int(freefallSeconds),
            equipment: equipment,
            notes: notes,
            studentNote: studentNote,
            instructorJumpSignoffAck: result == "pass" && checklistState.instructorAck ? true : nil,
            reviewChecks: checklistState.reviewChecksPayload().isEmpty ? nil : checklistState.reviewChecksPayload()
        )
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct R: Codable { let ok: Bool; let error: String?; let status: String? }
            let resp = try JSONDecoder().decode(R.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not save sign-off"
                return false
            }
            status = resp.status ?? (result == "pass" ? "passed" : "retake")
            canFinalize = status != "passed"
            if status == "retake" {
                priorRetakeNote = instNotes
                instructorNotes = ""
                await load()
            }
            return true
        } catch {
            self.error = "Could not save sign-off."
            return false
        }
    }
}

struct InstructorStudentJumpSignoffView: View {
    let studentId: Int
    let studentName: String
    let lessonId: Int
    let moduleId: Int
    let courseTitle: String
    let lessonLabel: String

    @StateObject private var vm: InstructorStudentJumpSignoffViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    init(studentId: Int, studentName: String, lessonId: Int, moduleId: Int, courseTitle: String, lessonLabel: String) {
        self.studentId = studentId
        self.studentName = studentName
        self.lessonId = lessonId
        self.moduleId = moduleId
        self.courseTitle = courseTitle
        self.lessonLabel = lessonLabel
        _vm = StateObject(wrappedValue: InstructorStudentJumpSignoffViewModel(
            studentId: studentId, lessonId: lessonId, moduleId: moduleId
        ))
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && vm.lessonTitle.isEmpty {
                ProgressView().tint(colors.amber)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerCard

                        if !vm.instructorProfileReady && vm.isEditable {
                            profileWarning
                        }

                        if !vm.priorRetakeNote.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(colors.danger)
                                Text("Prior retake: \(vm.priorRetakeNote)")
                                    .font(.system(size: 12))
                                    .foregroundColor(colors.danger)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colors.card)
                            .cornerRadius(10)
                        }

                        if vm.status == "passed" {
                            passedSummary
                        } else if vm.isEditable {
                            editableCard
                            passRetakeButtons
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Jump Sign-Off")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
    }

    private var passedSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Jump signed off — Pass", systemImage: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colors.green)
            instReadonlyRow("Jump #", vm.jumpNumber)
            instReadonlyRow("Date", vm.jumpDate)
            instReadonlyRow("Equipment", vm.equipment)
            if !vm.aspJumpTypeLabel.isEmpty { instReadonlyRow("Type", vm.aspJumpTypeLabel) }
            if !vm.instructorNotes.isEmpty { instReadonlyRow("Instructor", vm.instructorNotes) }
        }
        .font(.system(size: 13))
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var editableCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusPill

            Text("Review the jump log, update any fields, add instructor notes, then Pass or Retake.")
                .font(.system(size: 12))
                .foregroundColor(colors.muted)

            InstructorJumpFormFields(vm: vm)

            if vm.checklistState.hasChecklist || vm.checklistState.ackRequired {
                ReviewChecklistView(state: vm.checklistState)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("INSTRUCTOR NOTES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                TextEditor(text: $vm.instructorNotes)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(colors.card2)
                    .cornerRadius(8)
                    .foregroundColor(colors.text)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    @ViewBuilder
    private var statusPill: some View {
        let (label, tint): (String, Color) = {
            switch vm.status {
            case "pending_review": return ("Awaiting your decision", colors.amber)
            case "retake": return ("Retake — log next attempt", colors.danger)
            default: return ("Ready to log jump", colors.primary)
            }
        }()
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .cornerRadius(6)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("JUMP SIGN-OFF")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.primary)
                .tracking(1.2)
            Text(studentName)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(colors.text)
            Text(lessonLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.amber)
            Text(courseTitle)
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var profileWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Complete jump sign-offs: USPA license and signature in My Profile, plus instructor initials.")
                .font(.system(size: 12))
                .foregroundColor(colors.amber)
            NavigationLink(destination: InstructorProfileView()) {
                Text("Open instructor profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.primary)
            }
        }
        .padding(12)
        .background(colors.card)
        .cornerRadius(10)
    }

    private var passRetakeButtons: some View {
        VStack(spacing: 8) {
            if !vm.instructorProfileReady {
                Text("Pass and Retake require a USPA license and signature in My Profile, plus instructor initials.")
                    .font(.system(size: 11))
                    .foregroundColor(colors.amber)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                Button {
                    Task { if await vm.finalize(result: "pass") { dismiss() } }
                } label: {
                    Text(vm.isSubmitting ? "Saving…" : "Pass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(colors.green.opacity(vm.canPass && !vm.isSubmitting ? 1 : 0.35))
                        .cornerRadius(12)
                }
                .disabled(vm.isSubmitting || !vm.canPass)

                Button {
                    Task { _ = await vm.finalize(result: "retake") }
                } label: {
                    Text("Retake")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(colors.danger.opacity(vm.canRetake ? 1 : 0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(colors.card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.danger.opacity(vm.canRetake ? 0.45 : 0.2), lineWidth: 1.5))
                }
                .disabled(vm.isSubmitting || !vm.canRetake)
            }
        }
    }

    private func instReadonlyRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundColor(colors.muted).frame(width: 88, alignment: .leading)
            Text(v).foregroundColor(colors.text)
        }
    }
}

struct InstructorJumpFormFields: View {
    @ObservedObject var vm: InstructorStudentJumpSignoffViewModel

    var body: some View {
        JumpSignoffFormLayout(
            jumpNumber: $vm.jumpNumber,
            jumpDate: $vm.jumpDate,
            location: $vm.location,
            aircraft: $vm.aircraft,
            equipment: $vm.equipment,
            altitude: $vm.altitude,
            freefallSeconds: $vm.freefallSeconds,
            notes: $vm.notes,
            choices: vm.choices,
            aspJumpTypeLabel: vm.aspJumpTypeLabel,
            totalFreefallDisplay: vm.totalFreefallDisplay
        )
    }
}
