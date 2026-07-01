// File: ASC/Views/Quiz/QuizResultView.swift
import SwiftUI
import MalfunctionDZCore

struct QuizResultView: View {
    let result: QuizSubmitResponse
    let quizTitle: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @State private var showReview = false

    private var accentColor: Color { result.passed ? colors.green : colors.danger }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                resultHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("QUESTION REVIEW")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.muted)
                                .tracking(2)
                            Spacer()
                            Text("\(result.correctCount)/\(result.totalCount) correct")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colors.muted)
                        }
                        .padding(.top, 4)

                        ForEach(Array(result.results.enumerated()), id: \.offset) { idx, r in
                            ResultQuestionRow(number: idx + 1, result: r)
                        }
                    }
                    .padding(16)
                }

                Button { dismiss() } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(accentColor)
                        .cornerRadius(12)
                }
                .padding(16)
                .background(colors.navyMid)
            }
        }
    }

    private var resultHeader: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 96, height: 96)
                Image(systemName: result.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(accentColor)
            }

            VStack(spacing: 6) {
                Text(result.passed ? "PASSED" : "NOT PASSED")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(accentColor)
                    .tracking(2)
                Text(quizTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.muted)
                    .multilineTextAlignment(.center)
            }

            ZStack {
                Circle()
                    .strokeBorder(colors.border, lineWidth: 7)
                    .frame(width: 112, height: 112)
                Circle()
                    .trim(from: 0, to: CGFloat(min(result.scorePct, 100) / 100))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 112, height: 112)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.9), value: result.scorePct)
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", result.scorePct))
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(colors.text)
                    Text("Score")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.muted)
                }
            }

            HStack(spacing: 0) {
                ResultStat(value: "\(result.correctCount)", label: "Correct", color: colors.green)
                Divider().background(colors.border).frame(height: 40)
                ResultStat(value: "\(result.totalCount - result.correctCount)", label: "Missed", color: colors.danger)
                Divider().background(colors.border).frame(height: 40)
                ResultStat(value: String(format: "%.0f%%", result.passPercentage), label: "To Pass", color: colors.muted)
            }
            .background(colors.card)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(colors.navyMid)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.75, green: 0.12, blue: 0.18), .white, Color(red: 0.12, green: 0.25, blue: 0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)
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
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(colors.muted)
                .tracking(0.8)
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

    private var rowColor: Color { result.isCorrect ? colors.green : colors.danger }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(rowColor)
                            .frame(width: 30, height: 30)
                        Text("\(number)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        QuizRichText(
                            html: result.questionText,
                            fontSize: 14,
                            weight: .semibold,
                            color: colors.text
                        )
                    }

                    Spacer(minLength: 4)

                    Image(systemName: result.isCorrect ? "checkmark" : "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(rowColor)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(colors.muted)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().background(colors.border)
                VStack(alignment: .leading, spacing: 14) {
                    answerBlock(
                        title: "Your answer",
                        html: result.selectedChoiceText,
                        tint: result.isCorrect ? colors.green : colors.danger,
                        icon: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    if !result.isCorrect {
                        answerBlock(
                            title: "Correct answer",
                            html: result.correctChoiceText,
                            tint: colors.green,
                            icon: "checkmark.circle.fill"
                        )
                    }
                }
                .padding(14)
            }
        }
        .background(colors.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(rowColor.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func answerBlock(title: String, html: String, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
                QuizRichText(html: html, fontSize: 14, weight: .medium, color: tint)
            }
        }
    }
}
