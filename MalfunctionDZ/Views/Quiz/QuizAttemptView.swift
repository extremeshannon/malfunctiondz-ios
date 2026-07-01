// File: ASC/Views/Quiz/QuizAttemptView.swift
import SwiftUI
import MalfunctionDZCore

struct QuizAttemptView: View {
    @StateObject private var vm: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors
    @State private var showQuestionList = false
    @State private var showSubmitConfirm = false
    @State private var enlargedQuizImageURL: URL?

    init(quizId: Int) {
        _vm = StateObject(wrappedValue: QuizViewModel(quizId: quizId))
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            if vm.isLoading {
                loadingState
            } else if let quiz = vm.quiz {
                VStack(spacing: 0) {
                    quizHeader(quiz: quiz)
                    progressRail
                    if let question = vm.currentQuestion {
                        QuizQuestionPage(
                            question: question,
                            questionNumber: vm.currentIndex + 1,
                            totalQuestions: vm.totalQuestions,
                            selectedChoiceId: vm.answers[question.id],
                            isFlagged: vm.isFlagged(question),
                            onSelectChoice: { choiceId in
                                vm.selectChoice(questionId: question.id, choiceId: choiceId)
                            },
                            onToggleFlag: { vm.toggleFlag(questionId: question.id) },
                            onEnlargeImage: { enlargedQuizImageURL = $0 }
                        )
                    }
                    bottomNav
                }
            }
        }
        .navigationBarHidden(true)
        .task { await vm.loadQuiz() }
        .sheet(isPresented: $showQuestionList) {
            QuestionListSheet(vm: vm, onSelect: { showQuestionList = false })
        }
        .fullScreenCover(isPresented: $vm.showResult) {
            Group {
                if let result = vm.submitResult {
                    QuizResultView(result: result, quizTitle: vm.quiz?.title ?? "Quiz")
                } else {
                    colors.background.ignoresSafeArea()
                }
            }
        }
        .alert("Submit Quiz?", isPresented: $showSubmitConfirm) {
            Button("Submit", role: .destructive) {
                Task { await vm.submitQuiz() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let unanswered = vm.totalQuestions - vm.answeredCount
            if unanswered > 0 {
                Text("You have \(unanswered) unanswered question\(unanswered == 1 ? "" : "s"). Submit anyway?")
            } else {
                Text("Submit your answers? This cannot be undone.")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.error ?? "") }
        .fullScreenCover(isPresented: Binding(
            get: { enlargedQuizImageURL != nil },
            set: { if !$0 { enlargedQuizImageURL = nil } }
        )) {
            if let url = enlargedQuizImageURL {
                EnlargeableImageSheet(imageURL: url, onDismiss: { enlargedQuizImageURL = nil })
            }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: colors.amber))
                .scaleEffect(1.4)
            Text("Preparing your quiz…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.text)
            Text("Loading questions")
                .font(.system(size: 13))
                .foregroundColor(colors.muted)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func quizHeader(quiz: QuizDetail) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colors.muted)
                        .frame(width: 36, height: 36)
                        .background(colors.card)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(quiz.title.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(colors.amber)
                        .tracking(1.2)
                        .lineLimit(1)
                    Text("Pass \(Int(quiz.passPercentage))% · \(vm.answeredCount) of \(vm.totalQuestions) answered")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colors.muted)
                }

                Spacer(minLength: 8)

                if quiz.isTimed {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text(vm.timerDisplay)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(vm.timerColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(vm.timerColor.opacity(0.14))
                    .clipShape(Capsule())
                }

                Button { showQuestionList = true } label: {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.amber)
                        .frame(width: 36, height: 36)
                        .background(colors.amber.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            quizGradientBar
        }
        .background(colors.navyMid)
    }

    private var quizGradientBar: some View {
        LinearGradient(
            colors: [Color(red: 0.75, green: 0.12, blue: 0.18), .white, Color(red: 0.12, green: 0.25, blue: 0.55)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 4)
    }

    // MARK: - Progress rail (no ScrollViewReader — scrollTo during navigation has crashed SwiftUI)

    private var progressRail: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(colors.border.opacity(0.45))
                    Capsule()
                        .fill(colors.amber)
                        .frame(
                            width: max(
                                8,
                                geo.size.width * CGFloat(vm.currentIndex + 1) / CGFloat(max(vm.totalQuestions, 1))
                            )
                        )
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let quiz = vm.quiz {
                        ForEach(0..<quiz.questions.count, id: \.self) { idx in
                            let question = quiz.questions[idx]
                            Button { vm.jumpTo(index: idx) } label: {
                                progressDot(index: idx, question: question)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
        .background(colors.card.opacity(0.35))
    }

    private func progressDot(index: Int, question: QuizQuestion) -> some View {
        let isCurrent = index == vm.currentIndex
        let isAnswered = vm.answers[question.id] != nil
        let isFlagged = vm.isFlagged(question)

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCurrent ? colors.amber : (isAnswered ? colors.green.opacity(0.85) : colors.border.opacity(0.55)))
                .frame(width: isCurrent ? 34 : 28, height: 28)
            Text("\(index + 1)")
                .font(.system(size: isCurrent ? 13 : 11, weight: .black))
                .foregroundColor(isCurrent || isAnswered ? .white : colors.muted)
            if isFlagged {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(colors.amber)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: -2)
                    }
                    Spacer()
                }
                .frame(width: 34, height: 28)
            }
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        VStack(spacing: 0) {
            Divider().background(colors.border)
            HStack(spacing: 12) {
                Button { vm.goBack() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(vm.canGoBack ? colors.text : colors.border)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(colors.card)
                    .cornerRadius(12)
                }
                .disabled(!vm.canGoBack)

                if vm.isLastQuestion {
                    Button { showSubmitConfirm = true } label: {
                        HStack(spacing: 8) {
                            if vm.isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Submit Quiz")
                                    .font(.system(size: 15, weight: .black))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.green)
                        .cornerRadius(12)
                    }
                    .disabled(vm.isSubmitting)
                } else {
                    Button { vm.goNext() } label: {
                        HStack(spacing: 6) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colors.amber)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(colors.navyMid)
        }
    }
}

// MARK: - Question page (isolated view — avoids navigation rebuild crashes)

private struct QuizQuestionPage: View {
    let question: QuizQuestion
    let questionNumber: Int
    let totalQuestions: Int
    let selectedChoiceId: Int?
    let isFlagged: Bool
    let onSelectChoice: (Int) -> Void
    let onToggleFlag: () -> Void
    let onEnlargeImage: (URL) -> Void

    @Environment(\.mdzColors) private var colors

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                questionCard

                if let path = question.imagePath, !path.isEmpty, let url = imageURL(path) {
                    imageBlock(url: url)
                }

                if let instructions = question.instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !instructions.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(colors.amber)
                        QuizRichText(html: instructions, fontSize: 14, weight: .medium, color: colors.muted)
                    }
                    .padding(14)
                    .background(colors.amber.opacity(0.08))
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(question.type == "true_false" ? "SELECT TRUE OR FALSE" : "SELECT ONE ANSWER")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(colors.muted)
                        .tracking(1.5)

                    if question.type == "true_false", question.choices.count == 2 {
                        HStack(spacing: 12) {
                            ForEach(0..<question.choices.count, id: \.self) { idx in
                                trueFalseCard(index: idx, choice: question.choices[idx])
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(0..<question.choices.count, id: \.self) { idx in
                                ChoiceButton(
                                    choice: question.choices[idx],
                                    letter: quizChoiceLetter(index: idx),
                                    isSelected: selectedChoiceId == question.choices[idx].id,
                                    onTap: { onSelectChoice(question.choices[idx].id) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text(String(format: "%02d", questionNumber))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(colors.amber)
                Text("/ \(String(format: "%02d", totalQuestions))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(colors.muted)
                Spacer()
                Button(action: onToggleFlag) {
                    Label(
                        isFlagged ? "Flagged" : "Flag",
                        systemImage: isFlagged ? "flag.fill" : "flag"
                    )
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isFlagged ? colors.amber : colors.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isFlagged ? colors.amber.opacity(0.15) : colors.border.opacity(0.35))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            QuizRichText(html: question.text, fontSize: 18, weight: .semibold, color: colors.text)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(colors.border.opacity(0.8), lineWidth: 1))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.75, green: 0.12, blue: 0.18), .white, Color(red: 0.12, green: 0.25, blue: 0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func trueFalseCard(index: Int, choice: QuizChoice) -> some View {
        let selected = selectedChoiceId == choice.id
        return Button {
            onSelectChoice(choice.id)
        } label: {
            VStack(spacing: 10) {
                Text(quizChoiceLetter(index: index))
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(selected ? colors.amber : colors.muted)
                QuizRichText(
                    html: choice.text,
                    fontSize: 16,
                    weight: .bold,
                    color: selected ? colors.text : colors.text.opacity(0.9),
                    alignment: .center
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(selected ? colors.amber.opacity(0.12) : colors.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? colors.amber : colors.border, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func imageBlock(url: URL) -> some View {
        Button { onEnlargeImage(url) } label: {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                case .failure:
                    Label("Image unavailable", systemImage: "photo")
                        .foregroundColor(colors.muted)
                        .frame(maxWidth: .infinity, minHeight: 100)
                default:
                    ProgressView().tint(colors.amber)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .frame(maxHeight: 220)
            .frame(maxWidth: .infinity)
            .background(colors.card)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func imageURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "\(kServerURL)\(path.hasPrefix("/") ? "" : "/")\(path)")
    }
}

// MARK: - Choice Button

struct ChoiceButton: View {
    let choice: QuizChoice
    let letter: String
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.mdzColors) private var colors

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? colors.amber : colors.border.opacity(0.45))
                        .frame(width: 36, height: 36)
                    Text(letter)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(isSelected ? .white : colors.muted)
                }

                QuizRichText(
                    html: choice.text,
                    fontSize: 15,
                    weight: isSelected ? .semibold : .regular,
                    color: isSelected ? colors.text : colors.text.opacity(0.88)
                )

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? colors.amber : colors.border)
            }
            .padding(16)
            .background(isSelected ? colors.amber.opacity(0.1) : colors.card)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? colors.amber : colors.border.opacity(0.85), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Question List Sheet

struct QuestionListSheet: View {
    @ObservedObject var vm: QuizViewModel
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QUESTION MAP")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(colors.amber)
                            .tracking(2)
                        Text("\(vm.answeredCount) of \(vm.totalQuestions) answered")
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(colors.muted)
                    }
                }
                .padding(16)
                .background(colors.navyMid)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        if let quiz = vm.quiz {
                            ForEach(Array(quiz.questions.enumerated()), id: \.offset) { idx, question in
                                Button {
                                    vm.jumpTo(index: idx)
                                    onSelect()
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(buttonColor(for: question, idx: idx))
                                        VStack(spacing: 2) {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundColor(.white)
                                            if vm.isFlagged(question) {
                                                Image(systemName: "flag.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(colors.amber)
                                            }
                                        }
                                    }
                                    .frame(height: 48)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }

                HStack(spacing: 20) {
                    LegendItem(color: colors.green, label: "Answered")
                    LegendItem(color: colors.card, label: "Open")
                    LegendItem(color: colors.amber, label: "Current")
                }
                .padding(16)
                .background(colors.navyMid)
            }
        }
    }

    private func buttonColor(for question: QuizQuestion, idx: Int) -> Color {
        if idx == vm.currentIndex { return colors.amber }
        if vm.answers[question.id] != nil { return colors.green }
        return colors.card
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    @Environment(\.mdzColors) private var colors
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(colors.muted)
        }
    }
}
