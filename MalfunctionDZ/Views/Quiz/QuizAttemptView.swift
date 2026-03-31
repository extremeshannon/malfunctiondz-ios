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
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.amber))
                        .scaleEffect(1.4)
                    Text("Loading quiz...")
                        .font(.subheadline)
                        .foregroundColor(colors.muted)
                }
            } else if let quiz = vm.quiz {
                VStack(spacing: 0) {
                    // ── Top bar ─────────────────────────────
                    quizTopBar(quiz: quiz)

                    // ── Progress bar ─────────────────────────
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(colors.border).frame(height: 3)
                            Rectangle()
                                .fill(colors.amber)
                                .frame(width: geo.size.width * vm.progress, height: 3)
                                .animation(.easeInOut(duration: 0.3), value: vm.progress)
                        }
                    }
                    .frame(height: 3)

                    // ── Question ─────────────────────────────
                    if let question = vm.currentQuestion {
                        questionCard(question: question)
                    }

                    // ── Navigation ───────────────────────────
                    navBar
                }
            }
        }
        .navigationBarHidden(true)
        .task { await vm.loadQuiz() }
        .sheet(isPresented: $showQuestionList) {
            QuestionListSheet(vm: vm, onSelect: {
                showQuestionList = false
            })
        }
        .fullScreenCover(isPresented: $vm.showResult) {
            if let result = vm.submitResult {
                QuizResultView(result: result, quizTitle: vm.quiz?.title ?? "Quiz")
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

    // MARK: - Top Bar
    @ViewBuilder
    private func quizTopBar(quiz: QuizDetail) -> some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.muted)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(quiz.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(colors.text)
                    .lineLimit(1)
                Text("Question \(vm.currentIndex + 1) of \(vm.totalQuestions) · \(vm.answeredCount) answered")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }

            Spacer()

            // Timer
            if quiz.isTimed {
                Text(vm.timerDisplay)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(vm.timerColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vm.timerColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Question list button
            Button { showQuestionList = true } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.amber)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(colors.navyMid)
    }

    // MARK: - Question Card
    @ViewBuilder
    private func questionCard(question: QuizQuestion) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // Question image (tap to enlarge)
                if let path = question.imagePath, !path.isEmpty,
                   let url = URL(string: path.hasPrefix("http") ? path : "\(kServerURL)\(path.hasPrefix("/") ? "" : "/")\(path)") {
                    Button {
                        enlargedQuizImageURL = url
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFit()
                                case .failure: Image(systemName: "photo").font(.largeTitle).foregroundColor(colors.muted)
                                default: ProgressView().tint(colors.amber)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .clipped()
                            .cornerRadius(10)
                            Text("Tap to enlarge")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(colors.muted)
                                .padding(6)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // Question header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Q\(vm.currentIndex + 1)")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(colors.amber)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(colors.amber.opacity(0.15))
                                .clipShape(Capsule())

                            Text(question.type == "true_false" ? "TRUE / FALSE" : "MULTIPLE CHOICE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.muted)
                                .tracking(1)
                        }

                        Text(question.text)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(colors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    // Flag button
                    Button {
                        vm.toggleFlag(questionId: question.id)
                    } label: {
                        Image(systemName: vm.isFlagged(question) ? "flag.fill" : "flag")
                            .font(.system(size: 18))
                            .foregroundColor(vm.isFlagged(question) ? colors.amber : colors.border)
                    }
                }

                // Choices
                VStack(spacing: 10) {
                    ForEach(question.choices) { choice in
                        ChoiceButton(
                            choice: choice,
                            isSelected: vm.selectedChoice(for: question) == choice.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    vm.selectChoice(questionId: question.id, choiceId: choice.id)
                                }
                            }
                        )
                    }
                }
            }
            .padding(20)
        }
        .id(vm.currentIndex) // Force scroll reset on question change
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack(spacing: 12) {
            Button {
                vm.goBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(vm.canGoBack ? colors.text : colors.border)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(colors.card)
                .cornerRadius(10)
            }
            .disabled(!vm.canGoBack)

            if vm.isLastQuestion {
                Button {
                    showSubmitConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        if vm.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Submit")
                                .font(.system(size: 15, weight: .black))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(colors.green)
                    .cornerRadius(10)
                }
                .disabled(vm.isSubmitting)
            } else {
                Button {
                    vm.goNext()
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(colors.amber)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(colors.navyMid)
    }
}

// MARK: - Choice Button
struct ChoiceButton: View {
    let choice: QuizChoice
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.mdzColors) private var colors

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? colors.amber : colors.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(colors.amber)
                            .frame(width: 14, height: 14)
                    }
                }

                Text(choice.text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? colors.text : colors.text.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(14)
            .background(isSelected ? colors.amber.opacity(0.1) : colors.card)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? colors.amber : colors.border, lineWidth: isSelected ? 2 : 1)
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
                    Text("QUESTIONS")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(colors.amber)
                        .tracking(2)
                    Spacer()
                    Text("\(vm.answeredCount)/\(vm.totalQuestions) answered")
                        .font(.system(size: 12))
                        .foregroundColor(colors.muted)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(colors.muted)
                    }
                    .padding(.leading, 12)
                }
                .padding(16)
                .background(colors.navyMid)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        if let quiz = vm.quiz {
                            ForEach(Array(quiz.questions.enumerated()), id: \.offset) { idx, question in
                                Button {
                                    vm.jumpTo(index: idx)
                                    onSelect()
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(buttonColor(for: question, idx: idx))
                                        Text("\(idx + 1)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                        if vm.isFlagged(question) {
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    Image(systemName: "flag.fill")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(colors.amber)
                                                        .padding(3)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                    .frame(height: 44)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }

                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: colors.green, label: "Answered")
                    LegendItem(color: colors.card, label: "Unanswered")
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
                .frame(width: 16, height: 16)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
        }
    }
}
