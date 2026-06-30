// Instructor-led A-License oral exam — 24 correct to pass, 3 misses to fail.
import SwiftUI
import MalfunctionDZCore

// MARK: - Models

struct OralExamChoice: Codable, Hashable {
    let text: String
    let isCorrect: Bool?

    enum CodingKeys: String, CodingKey {
        case text
        case isCorrect = "is_correct"
    }
}

struct OralExamQuestion: Codable, Hashable {
    let questionId: Int
    let category: String
    let text: String
    let questionType: String?
    let choices: [OralExamChoice]?
    let correctAnswers: [String]?

    enum CodingKeys: String, CodingKey {
        case text, category, choices
        case questionId = "question_id"
        case questionType = "question_type"
        case correctAnswers = "correct_answers"
    }
}

struct OralExamSession: Codable {
    let id: Int
    let status: String
    let instructorId: Int?
    let currentIndex: Int?
    let questions: [OralExamQuestion]?
    let responses: [OralExamResponse]?

    enum CodingKeys: String, CodingKey {
        case id, status, questions, responses
        case instructorId = "instructor_id"
        case currentIndex = "current_index"
    }
}

struct OralExamResponse: Codable, Hashable {
    let index: Int
    let passed: Bool
    let category: String?
    let questionId: Int?

    enum CodingKeys: String, CodingKey {
        case index, passed, category
        case questionId = "question_id"
    }
}

struct OralExamPayload: Codable {
    let ok: Bool
    let studentId: Int?
    let studentName: String?
    let eligible: Bool?
    let eligibilityReason: String?
    let totalQuestions: Int?
    let requiredCorrect: Int?
    let maxMisses: Int?
    let correctCount: Int?
    let missCount: Int?
    let questionNumber: Int?
    let gradedCount: Int?
    let canGrade: Bool?
    let instructorProfileReady: Bool?
    let currentQuestion: OralExamQuestion?
    let exam: OralExamSession?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, eligible, exam, message, error
        case studentId = "student_id"
        case studentName = "student_name"
        case eligibilityReason = "eligibility_reason"
        case totalQuestions = "total_questions"
        case requiredCorrect = "required_correct"
        case maxMisses = "max_misses"
        case correctCount = "correct_count"
        case missCount = "miss_count"
        case questionNumber = "question_number"
        case gradedCount = "graded_count"
        case canGrade = "can_grade"
        case instructorProfileReady = "instructor_profile_ready"
        case currentQuestion = "current_question"
    }
}

struct OralExamReadyRow: Codable, Identifiable, Hashable {
    let userId: Int
    let username: String?
    let displayName: String
    let courseTitle: String?

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case username
        case userId = "user_id"
        case displayName = "display_name"
        case courseTitle = "course_title"
    }
}

// MARK: - ViewModel

@MainActor
final class OralExamViewModel: ObservableObject {
    @Published var payload: OralExamPayload?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var showChoices = false
    @Published var error: String?
    @Published var completionMessage: String?

    let studentId: Int

    init(studentId: Int) { self.studentId = studentId }

    var sessionStatus: String { payload?.exam?.status ?? "" }
    var isPassed: Bool { sessionStatus == "passed" }
    var isFailed: Bool { sessionStatus == "failed" }
    var inProgress: Bool { sessionStatus == "in_progress" }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/oral-exam/\(studentId).php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(OralExamPayload.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not load oral exam"
                return
            }
            payload = resp
            error = nil
        } catch {
            self.error = "Could not load oral exam."
        }
    }

    func start() async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/oral-exam/\(studentId)/start.php") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = "{}".data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(OralExamPayload.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not start exam"
                return false
            }
            payload = resp
            showChoices = false
            return true
        } catch {
            self.error = "Could not start exam."
            return false
        }
    }

    func grade(passed: Bool) async -> Bool {
        guard let examId = payload?.exam?.id, payload?.canGrade == true else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/oral-exam/\(examId)/grade.php") else { return false }
        struct Body: Codable { let passed: Bool }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(Body(passed: passed))
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(OralExamPayload.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not save grade"
                return false
            }
            payload = resp
            showChoices = false
            if let msg = resp.message { completionMessage = msg }
            return true
        } catch {
            self.error = "Could not save grade."
            return false
        }
    }
}

// MARK: - Views

struct OralExamView: View {
    let studentId: Int
    @StateObject private var vm: OralExamViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    init(studentId: Int) {
        self.studentId = studentId
        _vm = StateObject(wrappedValue: OralExamViewModel(studentId: studentId))
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if vm.isLoading && vm.payload == nil {
                ProgressView().tint(colors.amber)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        if vm.payload?.instructorProfileReady == false {
                            profileWarning
                        }
                        if vm.isPassed {
                            passedCard
                        } else if vm.isFailed {
                            failedCard
                        } else if vm.inProgress, let q = vm.payload?.currentQuestion {
                            sessionCard(question: q)
                        } else {
                            startCard
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Oral Exam")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A-LICENSE ORAL EXAM")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.amber)
                .tracking(1.2)
            Text(vm.payload?.studentName ?? "Student")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(colors.text)
            Text("Read each question aloud. Tap Pass or Fail after the student answers.")
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var profileWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Complete your instructor profile (USPA license, initials, signature) before grading.")
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

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.payload?.eligible == false, let reason = vm.payload?.eligibilityReason {
                Label(reason, systemImage: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(colors.muted)
            } else {
                Text("24 questions (3 per category A–H). Need 24 correct; 3 misses ends the session.")
                    .font(.system(size: 13))
                    .foregroundColor(colors.muted)
            }
            Button {
                Task { _ = await vm.start() }
            } label: {
                Text(vm.isSubmitting ? "Starting…" : "Start oral exam")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(colors.green.opacity(canStart ? 1 : 0.4))
                    .cornerRadius(10)
            }
            .disabled(!canStart || vm.isSubmitting)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var canStart: Bool {
        vm.payload?.eligible == true && vm.payload?.instructorProfileReady != false
    }

    private func sessionCard(question: OralExamQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                statPill("Correct", "\(vm.payload?.correctCount ?? 0)/\(vm.payload?.requiredCorrect ?? 24)", colors.green)
                statPill("Misses", "\(vm.payload?.missCount ?? 0)/\(vm.payload?.maxMisses ?? 3)", colors.danger)
                Spacer()
                Text("Cat \(question.category)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.amber.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text("Question \(vm.payload?.questionNumber ?? 0)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(colors.muted)
            Text(question.text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(colors.text)
            if let answers = question.correctAnswers, !answers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CORRECT ANSWER")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(colors.green)
                        .tracking(0.8)
                    ForEach(answers, id: \.self) { a in
                        Text(a)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colors.green)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.green.opacity(0.08))
                .cornerRadius(8)
            }
            if let choices = question.choices, !choices.isEmpty {
                Button { vm.showChoices.toggle() } label: {
                    HStack {
                        Text(vm.showChoices ? "Hide all choices" : "Show all choices")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: vm.showChoices ? "chevron.up" : "chevron.down")
                    }
                    .foregroundColor(colors.primary)
                }
                .buttonStyle(.plain)
                if vm.showChoices {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(choices, id: \.text) { c in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: c.isCorrect == true ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(c.isCorrect == true ? colors.green : colors.muted)
                                Text(c.text)
                                    .font(.system(size: 13))
                                    .foregroundColor(colors.text)
                            }
                        }
                    }
                    .padding(12)
                    .background(colors.card2)
                    .cornerRadius(8)
                }
            }
            HStack(spacing: 12) {
                Button {
                    Task { _ = await vm.grade(passed: true) }
                } label: {
                    Text(vm.isSubmitting ? "…" : "Pass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.green.opacity(vm.payload?.canGrade == true ? 1 : 0.35))
                        .cornerRadius(10)
                }
                .disabled(vm.isSubmitting || vm.payload?.canGrade != true)
                Button {
                    Task { _ = await vm.grade(passed: false) }
                } label: {
                    Text("Fail")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(colors.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.card)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.danger.opacity(0.4)))
                }
                .disabled(vm.isSubmitting || vm.payload?.canGrade != true)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var passedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Oral exam passed — signed on progression card", systemImage: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.green)
            if let msg = vm.completionMessage ?? vm.payload?.message {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundColor(colors.muted)
            }
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(colors.primary)
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private var failedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Session failed — 3 misses", systemImage: "xmark.octagon.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.danger)
            Text("Start a new exam when the student is ready to try again.")
                .font(.system(size: 13))
                .foregroundColor(colors.muted)
            Button {
                Task { _ = await vm.start() }
            } label: {
                Text(vm.isSubmitting ? "Starting…" : "Start new exam")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(colors.amber)
                    .cornerRadius(10)
            }
            .disabled(vm.isSubmitting || vm.payload?.eligible != true)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private func statPill(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(colors.muted)
            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(tint)
        }
    }
}

struct InstructorOralExamListView: View {
    let items: [OralExamReadyRow]
    @Environment(\.mdzColors) private var colors

    var body: some View {
        List {
            if items.isEmpty {
                Text("No students ready for oral exam.")
                    .foregroundColor(colors.muted)
            } else {
                ForEach(items) { row in
                    NavigationLink {
                        OralExamView(studentId: row.userId)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(colors.text)
                            if let course = row.courseTitle {
                                Text(course)
                                    .font(.system(size: 12))
                                    .foregroundColor(colors.muted)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Oral Exam Ready")
        .navigationBarTitleDisplayMode(.inline)
    }
}
