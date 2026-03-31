// File: ASC/ViewModels/QuizViewModel.swift
import Foundation
import SwiftUI
import MalfunctionDZCore

@MainActor
class QuizViewModel: ObservableObject {
    // Quiz data
    @Published var quiz: QuizDetail?
    @Published var isLoading = false
    @Published var error: String?

    // Attempt state
    @Published var currentIndex: Int = 0
    @Published var answers: [Int: Int] = [:]      // [question_id: choice_id]
    @Published var flagged: Set<Int> = []          // flagged question_ids
    @Published var timeRemaining: Int = 0
    @Published var timerActive = false

    // Result
    @Published var submitResult: QuizSubmitResponse?
    @Published var isSubmitting = false
    @Published var showResult = false

    private var timerTask: Task<Void, Never>?
    private let quizId: Int

    init(quizId: Int) {
        self.quizId = quizId
    }

    // MARK: - Computed
    var currentQuestion: QuizQuestion? {
        guard let q = quiz, currentIndex < q.questions.count else { return nil }
        return q.questions[currentIndex]
    }

    var totalQuestions: Int { quiz?.questions.count ?? 0 }
    var answeredCount: Int { answers.count }
    var progress: Double { totalQuestions > 0 ? Double(currentIndex + 1) / Double(totalQuestions) : 0 }
    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < totalQuestions - 1 }
    var isLastQuestion: Bool { currentIndex == totalQuestions - 1 }
    var allAnswered: Bool { answeredCount == totalQuestions }

    func selectedChoice(for question: QuizQuestion) -> Int? {
        answers[question.id]
    }

    func isFlagged(_ question: QuizQuestion) -> Bool {
        flagged.contains(question.id)
    }

    // MARK: - Actions
    func selectChoice(questionId: Int, choiceId: Int) {
        answers[questionId] = choiceId
    }

    func toggleFlag(questionId: Int) {
        if flagged.contains(questionId) {
            flagged.remove(questionId)
        } else {
            flagged.insert(questionId)
        }
    }

    func goNext() {
        if currentIndex < totalQuestions - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex += 1
            }
        }
    }

    func goBack() {
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex -= 1
            }
        }
    }

    func jumpTo(index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex = index
        }
    }

    // MARK: - Network
    func loadQuiz() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/quiz.php?id=\(quizId)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(QuizDetailResponse.self, from: data)
            if resp.ok, let q = resp.quiz {
                quiz = q
                if q.isTimed, let limit = q.timeLimit {
                    timeRemaining = limit * 60
                    startTimer()
                }
            } else {
                error = "Failed to load quiz"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func submitQuiz() async {
        guard !answers.isEmpty else { return }
        isSubmitting = true
        timerTask?.cancel()
        defer { isSubmitting = false }

        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/quiz.php?id=\(quizId)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert [Int:Int] to [String:Int] for JSON
        let payload = ["answers": Dictionary(uniqueKeysWithValues: answers.map { (String($0.key), $0.value) })]
        req.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(QuizSubmitResponse.self, from: data)
            submitResult = resp
            showResult = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Timer
    private func startTimer() {
        timerActive = true
        timerTask = Task {
            while timeRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                timeRemaining -= 1
            }
            if timeRemaining == 0 {
                await submitQuiz()
            }
        }
    }

    var timerDisplay: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var timerColor: Color {
        if timeRemaining < 60  { return .mdzDanger }
        if timeRemaining < 300 { return .mdzAmber }
        return .mdzGreen
    }
}
