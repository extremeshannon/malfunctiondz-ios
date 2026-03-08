// File: ASC/Views/Quiz/QuizLaunchCard.swift
// Purpose: Card component that displays quiz info, lock state, attempt count,
//          last score, and launches the quiz attempt flow.
import SwiftUI

struct QuizLaunchCard: View {
    let quizId: Int
    let title: String
    let passPercentage: Double
    let questionCount: Int
    let isUnlocked: Bool
    let lockReason: String?
    let maxAttempts: Int?
    let attemptCount: Int
    let attemptsRemaining: Int?
    let lastAttempt: QuizLastAttempt?
    @State private var showQuiz = false
    @State private var showLockedAlert = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Header row ──────────────────────────────
            HStack {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isUnlocked ? colors.amber : colors.muted)
                Text("QUIZ")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(isUnlocked ? colors.amber : colors.muted)
                    .tracking(2)
                Spacer()
                if !isUnlocked {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("LOCKED")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1)
                    }
                    .foregroundColor(colors.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.border.opacity(0.5))
                    .clipShape(Capsule())
                } else if let last = lastAttempt {
                    StatusPill(
                        label: last.passed ? "PASSED" : "FAILED",
                        color: last.passed ? colors.green : colors.danger
                    )
                }
            }

            // ── Title ────────────────────────────────────
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isUnlocked ? colors.text : colors.muted)

            // ── Meta ─────────────────────────────────────
            HStack(spacing: 16) {
                Label("\(questionCount) questions", systemImage: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
                Label("Pass: \(Int(passPercentage))%", systemImage: "checkmark.shield")
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }

            // ── Last score ───────────────────────────────
            if let last = lastAttempt {
                Text(String(format: "Last score: %.0f%%", last.score))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(last.passed ? colors.green : colors.danger)
            }

            // ── Lock reason ──────────────────────────────
            if !isUnlocked, let reason = lockReason {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text(reason)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(colors.muted)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.border.opacity(0.3))
                .cornerRadius(8)
            }

            // ── Action button ────────────────────────────
            Button {
                if isUnlocked {
                    showQuiz = true
                } else {
                    showLockedAlert = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isUnlocked ? "play.fill" : "lock.fill")
                        .font(.system(size: 13))
                    Text(buttonLabel)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(isUnlocked ? .white : colors.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isUnlocked ? colors.amber : colors.border.opacity(0.4))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isUnlocked ? colors.amber.opacity(0.3) : colors.border,
                    lineWidth: 1
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.75)
        .fullScreenCover(isPresented: $showQuiz) {
            NavigationView {
                QuizAttemptView(quizId: quizId)
            }
        }
        .alert("Quiz Locked", isPresented: $showLockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockReason ?? "Complete the required lessons to unlock this quiz.")
        }
    }

    private var buttonLabel: String {
        if !isUnlocked { return "Locked" }
        if lastAttempt == nil { return "Start Quiz" }
        return lastAttempt?.passed == true ? "Retake Quiz" : "Retake Quiz"
    }
}
