// File: ASC/Views/Quiz/QuizLaunchCard.swift
// Embedded in CourseDetailView to show available quizzes for a course
import SwiftUI
import MalfunctionDZCore

struct QuizLaunchCard: View {
    let quizId: Int
    let title: String
    let passPercentage: Double
    let questionCount: Int
    let lastAttempt: QuizLastAttempt?
    @State private var showQuiz = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.amber)
                Text("QUIZ")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(2)
                Spacer()
                if let last = lastAttempt {
                    StatusPill(
                        label: last.passed ? "PASSED" : "FAILED",
                        color: last.passed ? colors.green : colors.danger
                    )
                }
            }

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(colors.text)

            HStack(spacing: 16) {
                Label("\(questionCount) questions", systemImage: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
                Label("Pass: \(Int(passPercentage))%", systemImage: "checkmark.shield")
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }

            if let last = lastAttempt {
                HStack {
                    Text(String(format: "Last score: %.0f%%", last.score))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(last.passed ? colors.green : colors.danger)
                    Spacer()
                }
            }

            Button {
                showQuiz = true
            } label: {
                Text(lastAttempt == nil ? "Start Quiz" : "Retake Quiz")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(colors.amber)
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(colors.amber.opacity(0.3), lineWidth: 1)
        )
        .fullScreenCover(isPresented: $showQuiz) {
            NavigationView {
                QuizAttemptView(quizId: quizId)
            }
        }
    }
}
