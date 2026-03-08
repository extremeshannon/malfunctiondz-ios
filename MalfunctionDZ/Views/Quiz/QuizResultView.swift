// File: ASC/Views/Quiz/QuizResultView.swift
import SwiftUI

struct QuizResultView: View {
    let result: QuizSubmitResponse
    let quizTitle: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @State private var showReview = false

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {

                // ── Result Header ────────────────────────────
                VStack(spacing: 20) {
                    // Pass/Fail badge
                    ZStack {
                        Circle()
                            .fill(result.passed ? colors.green.opacity(0.15) : colors.danger.opacity(0.15))
                            .frame(width: 100, height: 100)
                        VStack(spacing: 2) {
                            Image(systemName: result.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .font(.system(size: 36))
                                .foregroundColor(result.passed ? colors.green : colors.danger)
                        }
                    }

                    VStack(spacing: 6) {
                        Text(result.passed ? "PASSED" : "FAILED")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(result.passed ? colors.green : colors.danger)
                            .tracking(2)
                        Text(quizTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colors.muted)
                    }

                    // Score circle
                    ZStack {
                        Circle()
                            .strokeBorder(colors.border, lineWidth: 8)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: CGFloat(result.scorePct / 100))
                            .stroke(result.passed ? colors.green : colors.danger,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: result.scorePct)
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f%%", result.scorePct))
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(colors.text)
                            Text("Score")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(colors.muted)
                        }
                    }

                    // Stats row
                    HStack(spacing: 0) {
                        ResultStat(value: "\(result.correctCount)", label: "Correct",
                                   color: colors.green)
                        Divider().background(colors.border).frame(height: 40)
                        ResultStat(value: "\(result.totalCount - result.correctCount)",
                                   label: "Wrong", color: colors.danger)
                        Divider().background(colors.border).frame(height: 40)
                        ResultStat(value: String(format: "%.0f%%", result.passPercentage),
                                   label: "To Pass", color: colors.muted)
                    }
                    .background(colors.card)
                    .cornerRadius(12)
                }
                .padding(24)
                .background(colors.navyMid)

                // ── Review list ──────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("QUESTION REVIEW")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.muted)
                                .tracking(2)
                            Spacer()
                        }
                        .padding(.top, 4)

                        ForEach(Array(result.results.enumerated()), id: \.offset) { idx, r in
                            ResultQuestionRow(number: idx + 1, result: r)
                        }
                    }
                    .padding(16)
                }

                // ── Actions ──────────────────────────────────
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(colors.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(colors.card)
                            .cornerRadius(10)
                    }
                }
                .padding(16)
                .background(colors.navyMid)
            }
        }
    }
}

struct ResultStat: View {
    let value: String
    let label: String
    let color: Color
    @Environment(\.mdzColors) private var colors
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct ResultQuestionRow: View {
    let number: Int
    let result: QuizQuestionResult
    @State private var expanded = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Number + indicator
                    ZStack {
                        Circle()
                            .fill(result.isCorrect ? colors.green : colors.danger)
                            .frame(width: 28, height: 28)
                        Text("\(number)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                    }

                    Text(result.questionText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: result.isCorrect ? "checkmark" : "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(result.isCorrect ? colors.green : colors.danger)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().background(colors.border)
                VStack(alignment: .leading, spacing: 10) {
                    // Question text would need to be passed through - for now show answers
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.isCorrect ? colors.green : colors.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your answer")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(colors.muted)
                            Text(result.selectedChoiceText)
                                .font(.system(size: 13))
                                .foregroundColor(result.isCorrect ? colors.green : colors.danger)
                        }
                    }

                    if !result.isCorrect {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(colors.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Correct answer")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colors.muted)
                                Text(result.correctChoiceText)
                                    .font(.system(size: 13))
                                    .foregroundColor(colors.green)
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(colors.card)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(result.isCorrect ? colors.green.opacity(0.2) : colors.danger.opacity(0.2),
                              lineWidth: 1)
        )
    }
}
