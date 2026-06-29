// Instructor sign-off queue — review student progress and approve/deny.
import SwiftUI
import MalfunctionDZCore

// MARK: - Models

struct InstructorSignoffListResponse: Codable {
    let ok: Bool
    let items: [InstructorSignoffItem]?
    let pendingCount: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, items, error
        case pendingCount = "pending_count"
    }
}

struct InstructorSignoffItem: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String?
    let studentId: Int
    let studentName: String
    let courseId: Int
    let courseTitle: String
    let moduleId: Int?
    let moduleTitle: String?
    let lessonTitle: String?
    let studentNote: String?
    let requestedAt: String?
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, kind
        case studentId = "student_id"
        case studentName = "student_name"
        case courseId = "course_id"
        case courseTitle = "course_title"
        case moduleId = "module_id"
        case moduleTitle = "module_title"
        case lessonTitle = "lesson_title"
        case studentNote = "student_note"
        case requestedAt = "requested_at"
        case submittedAt = "submitted_at"
    }

    var isJumpSignoff: Bool { (kind ?? "ground_signoff") == "jump_signoff" }

    var displayTitle: String {
        if isJumpSignoff {
            return lessonTitle ?? "Jump sign-off"
        }
        return moduleTitle ?? "Module review"
    }

    var submittedLabel: String {
        let raw = submittedAt ?? requestedAt ?? ""
        return raw.count >= 16 ? String(raw.prefix(16)) : raw
    }
}

struct InstructorSignoffDetailResponse: Codable {
    let ok: Bool
    let request: InstructorSignoffRequest?
    let studentProgressPct: Double?
    let moduleReview: InstructorModuleReview?
    let instructorProfileReady: Bool?
    let reviewChecklist: ReviewChecklistPayload?
    let instructorReadinessStatement: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, request, error
        case studentProgressPct = "student_progress_pct"
        case moduleReview = "module_review"
        case instructorProfileReady = "instructor_profile_ready"
        case reviewChecklist = "review_checklist"
        case instructorReadinessStatement = "instructor_readiness_statement"
    }
}

struct InstructorModuleReview: Codable {
    let moduleId: Int
    let moduleComplete: Bool
    let moduleProgressPct: Double
    let lessonsComplete: Int
    let lessonsTotal: Int
    let quizzesPassed: Bool
    let lessons: [InstructorStudentLesson]
    let quizAttempts: [InstructorQuizAttempt]
    let quizzes: [InstructorModuleQuiz]

    enum CodingKeys: String, CodingKey {
        case lessons, quizzes
        case moduleId = "module_id"
        case moduleComplete = "module_complete"
        case moduleProgressPct = "module_progress_pct"
        case lessonsComplete = "lessons_complete"
        case lessonsTotal = "lessons_total"
        case quizzesPassed = "quizzes_passed"
        case quizAttempts = "quiz_attempts"
    }
}

struct InstructorModuleQuiz: Codable, Identifiable {
    let quizId: Int
    let quizTitle: String
    let lessonTitle: String
    let lessonId: Int
    let passed: Bool
    let bestScorePct: Double?
    let attemptCount: Int

    var id: Int { quizId }

    enum CodingKeys: String, CodingKey {
        case passed
        case quizId = "quiz_id"
        case quizTitle = "quiz_title"
        case lessonTitle = "lesson_title"
        case lessonId = "lesson_id"
        case bestScorePct = "best_score_pct"
        case attemptCount = "attempt_count"
    }
}

struct InstructorSignoffRequest: Codable {
    let id: Int
    let studentId: Int
    let studentName: String
    let courseId: Int
    let courseTitle: String
    let moduleId: Int
    let moduleTitle: String
    let studentNote: String?
    let requestedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case studentName = "student_name"
        case courseId = "course_id"
        case courseTitle = "course_title"
        case moduleId = "module_id"
        case moduleTitle = "module_title"
        case studentNote = "student_note"
        case requestedAt = "requested_at"
    }
}

struct InstructorStudentLesson: Codable, Identifiable {
    let lessonId: Int
    let title: String
    let lessonType: String
    let required: Bool
    let completed: Bool
    let completedAt: String?

    var id: Int { lessonId }

    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case title, required, completed
        case lessonType = "lesson_type"
        case completedAt = "completed_at"
    }
}

struct InstructorQuizAttempt: Codable, Identifiable {
    let id: Int
    let quizTitle: String
    let attemptNumber: Int
    let scorePct: Double
    let passed: Bool
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, passed
        case quizTitle = "quiz_title"
        case attemptNumber = "attempt_number"
        case scorePct = "score_pct"
        case submittedAt = "submitted_at"
    }
}

struct SignoffResolveBody: Codable {
    let status: String
    let notes: String
    let instructorReadyAck: Bool?
    let reviewChecks: [String: String]?

    enum CodingKeys: String, CodingKey {
        case status, notes
        case instructorReadyAck = "instructor_ready_ack"
        case reviewChecks = "review_checks"
    }
}

// MARK: - ViewModel

@MainActor
final class InstructorReviewViewModel: ObservableObject {
    @Published var items: [InstructorSignoffItem] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/signoffs.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(InstructorSignoffListResponse.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not load sign-offs"
                return
            }
            items = resp.items ?? []
        } catch {
            self.error = "Could not load instructor reviews."
        }
    }
}

@MainActor
final class InstructorReviewDetailViewModel: ObservableObject {
    @Published var detail: InstructorSignoffDetailResponse?
    @Published var instructorNotes = ""
    @Published var attested = false
    @Published var checklistState = ReviewChecklistState(checklist: nil)
    @Published var instructorProfileReady = true
    @Published var showModuleReview = false
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var resolved = false

    let requestId: Int

    init(requestId: Int) { self.requestId = requestId }

    var canApprove: Bool {
        let notesOk = !instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let ackOk = checklistState.ackRequired ? checklistState.instructorAck : attested
        return instructorProfileReady && checklistState.allRequiredChecked && ackOk && notesOk
    }

    var canDeny: Bool {
        !instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/signoffs/\(requestId).php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(InstructorSignoffDetailResponse.self, from: data)
            guard resp.ok, resp.request != nil else {
                error = resp.error ?? "Review not found"
                return
            }
            detail = resp
            instructorProfileReady = resp.instructorProfileReady ?? true
            checklistState = ReviewChecklistState(
                checklist: resp.reviewChecklist,
                ackStatement: resp.instructorReadinessStatement ?? ""
            )
            // Legacy attestation card hidden when API provides readiness statement.
            if checklistState.ackRequired {
                attested = false
            }
        } catch {
            self.error = "Could not load review details."
        }
    }

    func resolve(status: String) async -> Bool {
        let notes = instructorNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if status == "approved" {
            if !instructorProfileReady {
                error = "Complete your instructor profile (signature and license) before sign-off."
                return false
            }
            let ackOk = checklistState.ackRequired ? checklistState.instructorAck : attested
            if !checklistState.allRequiredChecked || !ackOk {
                error = "Check every required item and confirm the instructor readiness statement."
                return false
            }
        }
        if (status == "approved" || status == "failed") && notes.isEmpty {
            error = "Instructor notes are required."
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/signoffs/\(requestId)/resolve.php") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = SignoffResolveBody(
            status: status,
            notes: notes,
            instructorReadyAck: status == "approved" && (checklistState.instructorAck || attested) ? true : nil,
            reviewChecks: checklistState.reviewChecksPayload().isEmpty ? nil : checklistState.reviewChecksPayload()
        )
        req.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct R: Codable { let ok: Bool; let error: String? }
            let resp = try JSONDecoder().decode(R.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not save decision"
                return false
            }
            resolved = true
            return true
        } catch {
            self.error = "Could not save decision."
            return false
        }
    }
}

// MARK: - Instructor entry card

struct InstructorReviewEntryCard: View {
    let pendingCount: Int
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.amber.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "pencil.and.signature")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(colors.amber)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("INSTRUCTOR REVIEWS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(1.2)
                if pendingCount > 0 {
                    Text("\(pendingCount) awaiting review")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colors.text)
                } else {
                    Text("No students waiting")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.text)
                }
                Text("Review progress, quizzes, and sign off")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
            Spacer()
            if pendingCount > 0 {
                Text("\(pendingCount)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.amber)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.muted)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.amber.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - List

struct InstructorReviewListView: View {
    @StateObject private var vm = InstructorReviewViewModel()
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && vm.items.isEmpty {
                ProgressView().tint(colors.amber)
            } else if vm.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40))
                        .foregroundColor(colors.green)
                    Text("No students waiting for review")
                        .font(.headline)
                        .foregroundColor(colors.text)
                    Text("When a student sends a review lesson for sign-off, they will appear here.")
                        .font(.subheadline)
                        .foregroundColor(colors.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(vm.items) { item in
                            if item.isJumpSignoff {
                                NavigationLink(destination: InstructorJumpReviewDetailView(signoffId: item.id)) {
                                    InstructorReviewJumpRow(item: item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(destination: InstructorReviewDetailView(requestId: item.id)) {
                                    InstructorReviewRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Ready for Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable { await vm.load() }
        .onAppear { Task { await vm.load() } }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
    }
}

struct InstructorReviewRow: View {
    let item: InstructorSignoffItem
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.studentName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.text)
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.amber)
                Text(item.courseTitle)
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
                if let note = item.studentNote, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.submittedLabel)
                    .font(.system(size: 10))
                    .foregroundColor(colors.muted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
    }
}

struct InstructorReviewJumpRow: View {
    let item: InstructorSignoffItem
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.studentName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.text)
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.primary)
                Text("Jump log review")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
            Spacer()
            Text(item.submittedLabel)
                .font(.system(size: 10))
                .foregroundColor(colors.muted)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
    }
}

// MARK: - Detail (sign-off first)

struct InstructorReviewDetailView: View {
    let requestId: Int
    @StateObject private var vm: InstructorReviewDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    init(requestId: Int) {
        self.requestId = requestId
        _vm = StateObject(wrappedValue: InstructorReviewDetailViewModel(requestId: requestId))
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && vm.detail == nil {
                ProgressView().tint(colors.amber)
            } else if let req = vm.detail?.request, let mod = vm.detail?.moduleReview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        signoffHeader(req: req, mod: mod)
                        moduleStatusCard(mod: mod)
                        if let note = req.studentNote, !note.isEmpty {
                            studentNoteCard(note: note)
                        }
                        if vm.detail?.reviewChecklist != nil || vm.checklistState.ackRequired {
                            ReviewChecklistView(state: vm.checklistState)
                        } else {
                            attestationCard
                        }

                        if !vm.instructorProfileReady {
                            Text("Complete your instructor profile (USPA license, initials, signature) before approving.")
                                .font(.system(size: 12))
                                .foregroundColor(colors.amber)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colors.card)
                                .cornerRadius(10)
                        }

                        notesCard
                        actionButtons
                        reviewModuleButton(mod: mod)
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Sign Off")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await vm.load() }
        .sheet(isPresented: $vm.showModuleReview) {
            if let mod = vm.detail?.moduleReview, let req = vm.detail?.request {
                InstructorModuleReviewSheet(
                    moduleReview: mod,
                    studentName: req.studentName,
                    moduleTitle: req.moduleTitle
                )
            }
        }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
    }

    private func signoffHeader(req: InstructorSignoffRequest, mod: InstructorModuleReview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SIGN-OFF REVIEW")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.amber)
                .tracking(1.2)
            Text(req.studentName)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(colors.text)
            Text(req.moduleTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(colors.primary)
            Text(req.courseTitle)
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private func moduleStatusCard(mod: InstructorModuleReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MODULE STATUS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                Spacer()
                Text(mod.moduleComplete ? "READY FOR SIGN-OFF" : "INCOMPLETE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(mod.moduleComplete ? colors.green : colors.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((mod.moduleComplete ? colors.green : colors.amber).opacity(0.15))
                    .clipShape(Capsule())
            }
            HStack(spacing: 16) {
                statusMetric(
                    label: "Lessons",
                    value: "\(mod.lessonsComplete)/\(mod.lessonsTotal)",
                    ok: mod.lessonsComplete >= mod.lessonsTotal && mod.lessonsTotal > 0
                )
                statusMetric(
                    label: "Quizzes",
                    value: mod.quizzesPassed ? "Passed" : (mod.quizzes.isEmpty ? "N/A" : "Review"),
                    ok: mod.quizzesPassed || mod.quizzes.isEmpty
                )
                statusMetric(
                    label: "Progress",
                    value: "\(Int(mod.moduleProgressPct))%",
                    ok: mod.moduleProgressPct >= 100
                )
            }
            if mod.moduleComplete {
                Text("Student completed all lessons and quizzes for this module and is waiting for your sign-off.")
                    .font(.system(size: 12))
                    .foregroundColor(colors.green)
            } else {
                Text("Student has not finished all lessons or quizzes in this module yet.")
                    .font(.system(size: 12))
                    .foregroundColor(colors.amber)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private func statusMetric(label: String, value: String, ok: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(colors.muted)
            HStack(spacing: 4) {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ok ? colors.green : colors.amber)
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func studentNoteCard(note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STUDENT NOTE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            Text(note)
                .font(.system(size: 14))
                .foregroundColor(colors.text)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var attestationCard: some View {
        Button {
            vm.attested.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: vm.attested ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(vm.attested ? colors.green : colors.muted)
                Text("I have reviewed this module with the student, verified their lessons and quiz results, and confirm they are ready to jump.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.text)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(vm.attested ? colors.green.opacity(0.5) : colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INSTRUCTOR NOTES")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            Text("Required for approval — e.g. what you reviewed together, weather, jump plan.")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
            TextEditor(text: $vm.instructorNotes)
                .frame(minHeight: 88)
                .padding(8)
                .background(colors.card2)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colors.border))
                .foregroundColor(colors.text)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    if await vm.resolve(status: "approved") { dismiss() }
                }
            } label: {
                Text(vm.isSubmitting ? "Saving…" : "Approve — Cleared to Jump")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(vm.canApprove && !vm.isSubmitting ? colors.green : colors.green.opacity(0.35))
                    .cornerRadius(10)
            }
            .disabled(!vm.canApprove || vm.isSubmitting)

            Button {
                Task {
                    if await vm.resolve(status: "failed") { dismiss() }
                }
            } label: {
                Text("Deny — Not Ready")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(colors.card)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.danger.opacity(0.4)))
            }
            .disabled(vm.isSubmitting || !vm.canDeny)
        }
    }

    private func reviewModuleButton(mod: InstructorModuleReview) -> some View {
        Button {
            vm.showModuleReview = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 20))
                    .foregroundColor(colors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review Module Details")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colors.text)
                    Text("\(mod.lessons.count) lessons · \(mod.quizzes.count) quiz\(mod.quizzes.count == 1 ? "" : "zes")")
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Module review sheet (lessons + quizzes for this module only)

struct InstructorModuleReviewSheet: View {
    let moduleReview: InstructorModuleReview
    let studentName: String
    let moduleTitle: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(studentName)
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(colors.text)
                            Text(moduleTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(colors.amber)
                        }
                        .padding(.horizontal, 4)

                        if !moduleReview.quizzes.isEmpty {
                            reviewBlock(title: "Quizzes") {
                                ForEach(moduleReview.quizzes) { quiz in
                                    HStack(alignment: .top) {
                                        Image(systemName: quiz.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(quiz.passed ? colors.green : colors.danger)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(quiz.quizTitle)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(colors.text)
                                            if let score = quiz.bestScorePct {
                                                Text("Best: \(Int(score))% · \(quiz.attemptCount) attempt\(quiz.attemptCount == 1 ? "" : "s")")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(colors.muted)
                                            } else {
                                                Text("No attempts yet")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(colors.muted)
                                            }
                                        }
                                        Spacer()
                                        Text(quiz.passed ? "PASSED" : "FAILED")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(quiz.passed ? colors.green : colors.danger)
                                    }
                                    .padding(.vertical, 6)
                                    if quiz.id != moduleReview.quizzes.last?.id {
                                        Divider().background(colors.border)
                                    }
                                }
                            }
                        }

                        if !moduleReview.quizAttempts.isEmpty {
                            reviewBlock(title: "Quiz Attempt History") {
                                ForEach(moduleReview.quizAttempts) { at in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(at.quizTitle)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(colors.text)
                                            Text("Attempt #\(at.attemptNumber) · \(Int(at.scorePct))%")
                                                .font(.system(size: 11))
                                                .foregroundColor(colors.muted)
                                        }
                                        Spacer()
                                        Text(at.passed ? "PASSED" : "FAILED")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(at.passed ? colors.green : colors.danger)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        reviewBlock(title: "Lessons in This Module") {
                            ForEach(moduleReview.lessons) { lesson in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: lesson.completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(lesson.completed ? colors.green : colors.muted)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lesson.title)
                                            .font(.system(size: 13))
                                            .foregroundColor(colors.text)
                                        HStack(spacing: 6) {
                                            Text(lesson.lessonType.capitalized)
                                                .font(.system(size: 10))
                                                .foregroundColor(colors.muted)
                                            if lesson.required {
                                                Text("Required")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(colors.amber)
                                            }
                                            if let done = lesson.completedAt, !done.isEmpty, lesson.completed {
                                                Text("· \(done)")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(colors.muted)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Module Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
    }
}
