// File: ASC/Views/GroundSchool/GroundSchoolView.swift
// Purpose: Main LMS view showing course list, module progression with sequential locking,
//          lessons, sign-off blocks, and quiz launch cards.

import SwiftUI

struct GroundSchoolView: View {
    @StateObject private var vm = GroundSchoolViewModel()
    @State private var selectedCourse: LMSCourse?

    var body: some View {
        NavigationView {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                VStack(spacing: 0) {

                    // ── Header ──────────────────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.mdzAmber)
                            Text("GROUND SCHOOL")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.mdzAmber)
                                .tracking(2)
                            Spacer()
                            Text("\(vm.courses.count) COURSES")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.mdzMuted)
                                .tracking(1)
                        }
                        Text("Training & LMS")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.mdzMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.mdzNavyMid)

                    if vm.isLoading && vm.courses.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                            .scaleEffect(1.4)
                        Spacer()
                    } else if vm.courses.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "graduationcap",
                            title: "No Courses",
                            subtitle: "No courses available."
                        )
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(vm.courses) { course in
                                    NavigationLink(
                                        destination: CourseDetailView(course: course, vm: vm)
                                    ) {
                                        CourseCard(course: course)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable { await vm.load() }
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await vm.load() }
            .alert("Error", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK", role: .cancel) { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
        }
    }
}

// MARK: - Course Card
struct CourseCard: View {
    let course: LMSCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.mdzText)
                        .multilineTextAlignment(.leading)

                    if let desc = course.description {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(.mdzMuted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                StatusPill(label: course.enrollmentStatus.label, color: enrollmentColor(course))
            }

            // Progress bar
            if course.enrolled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(course.completedLessons) of \(course.totalLessons) lessons")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.mdzMuted)
                        Spacer()
                        Text("\(Int(course.progressPct))%")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(enrollmentColor(course))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.mdzBorder)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(enrollmentColor(course))
                                .frame(
                                    width: geo.size.width * CGFloat(course.progressPct) / 100,
                                    height: 6
                                )
                        }
                    }
                    .frame(height: 6)
                }
            }

            // Module count
            HStack(spacing: 12) {
                Label("\(course.modules.count) modules", systemImage: "square.stack.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.mdzMuted)

                Label("\(course.totalLessons) lessons", systemImage: "doc.text.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.mdzMuted)
            }
        }
        .padding(16)
        .background(Color.mdzCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    course.progressPct == 100 ? Color.mdzGreen.opacity(0.4) : Color.mdzBorder,
                    lineWidth: 1
                )
        )
        .overlay(
            VStack {
                Rectangle()
                    .fill(enrollmentColor(course))
                    .frame(height: 3)
                    .cornerRadius(14)
                Spacer()
            }
        )
    }
}

// MARK: - Course Detail
struct CourseDetailView: View {
    let course: LMSCourse
    @ObservedObject var vm: GroundSchoolViewModel
    @State private var expandedModules: Set<Int> = []

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    // Course header
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            StatusPill(label: course.enrollmentStatus.label, color: enrollmentColor(course))
                            Spacer()
                            Text("\(Int(course.progressPct))% complete")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(enrollmentColor(course))
                        }

                        if let desc = course.description {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.mdzMuted)
                        }

                        // Progress bar
                        if course.enrolled {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.mdzBorder)
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(enrollmentColor(course))
                                        .frame(
                                            width: geo.size.width * CGFloat(course.progressPct) / 100,
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)

                            HStack {
                                Text("\(course.completedLessons) of \(course.totalLessons) lessons completed")
                                    .font(.caption)
                                    .foregroundColor(.mdzMuted)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.mdzCard)
                    .cornerRadius(12)

                    // Quizzes for this course
                    if !(course.quizzes ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ASSESSMENTS")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.mdzMuted)
                                .tracking(2)

                            ForEach(course.quizzes ?? []) { quiz in
                                QuizLaunchCard(
                                    quizId: quiz.id,
                                    title: quiz.title,
                                    passPercentage: quiz.passPercentage,
                                    questionCount: quiz.questionCount,
                                    isUnlocked: quiz.isUnlocked,
                                    lockReason: quiz.lockReason,
                                    maxAttempts: quiz.maxAttempts,
                                    attemptCount: quiz.attemptCount,
                                    attemptsRemaining: quiz.attemptsRemaining,
                                    lastAttempt: quiz.lastAttempt.map {
                                        QuizLastAttempt(id: 0, score: $0.score, passed: $0.passed, date: $0.date)
                                    }
                                )
                            }
                        }
                    }

                    // Quizzes for this course
                    if !(course.quizzes ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ASSESSMENTS")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.mdzMuted)
                                .tracking(2)

                            ForEach(course.quizzes ?? []) { quiz in
                                QuizLaunchCard(
                                    quizId: quiz.id,
                                    title: quiz.title,
                                    passPercentage: quiz.passPercentage,
                                    questionCount: quiz.questionCount,
                                    isUnlocked: quiz.isUnlocked,
                                    lockReason: quiz.lockReason,
                                    maxAttempts: quiz.maxAttempts,
                                    attemptCount: quiz.attemptCount,
                                    attemptsRemaining: quiz.attemptsRemaining,
                                    lastAttempt: quiz.lastAttempt.map {
                                        QuizLastAttempt(id: 0, score: $0.score, passed: $0.passed, date: $0.date)
                                    }
                                )
                            }
                        }
                    }

                    // Logbook (skydiver logbook for this course)
                    NavigationLink(destination: LogbookView(courseId: course.id, courseTitle: course.title)) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.mdzAmber)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Logbook")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.mdzText)
                                Text("Jump entries & sign-offs")
                                    .font(.system(size: 12))
                                    .foregroundColor(.mdzMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.mdzMuted)
                        }
                        .padding(14)
                        .background(Color.mdzCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.mdzBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // Modules
                    ForEach(course.modules) { module in
                        ModuleSection(
                            module: module,
                            courseId: course.id,
                            isExpanded: expandedModules.contains(module.id),
                            vm: vm,
                            onToggle: {
                                if expandedModules.contains(module.id) {
                                    expandedModules.remove(module.id)
                                } else {
                                    expandedModules.insert(module.id)
                                }
                            }
                        )
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            // Auto-expand first incomplete module
            if let first = course.modules.first(where: { !$0.isComplete }) {
                expandedModules.insert(first.id)
            }
        }
    }
}

// MARK: - Module Section
struct ModuleSection: View {
    let module: LMSModule
    let courseId: Int
    let isExpanded: Bool
    @ObservedObject var vm: GroundSchoolViewModel
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── Module header ─────────────────────────────
            Button(action: { if !module.isLocked { onToggle() } }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(headerCircleColor)
                            .frame(width: 28, height: 28)

                        Image(systemName: headerIcon)
                            .font(.system(size: module.isComplete ? 12 : 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(module.isLocked ? .mdzMuted : .mdzText)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            if module.isLocked {
                                Label("Locked", systemImage: "lock.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.mdzMuted)
                            } else {
                                Text("\(module.completedCount)/\(module.lessonCount) lessons")
                                    .font(.system(size: 11))
                                    .foregroundColor(.mdzMuted)

                                if module.signoffType != "none" {
                                    Text(module.unlockStatusEnum.label)
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(statusBadgeColor)
                                        .tracking(0.5)
                                }
                            }
                        }
                    }

                    Spacer()

                    if !module.isLocked {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.mdzMuted)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // ── Expanded content ──────────────────────────
            if isExpanded && !module.isLocked {
                VStack(spacing: 0) {
                    Divider().background(Color.mdzBorder)

                    // Lessons
                    if !module.lessons.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(module.lessons) { lesson in
                                NavigationLink(
                                    destination: LessonDetailView(
                                        lessonId: lesson.id,
                                        lessonTitle: lesson.title,
                                        allLessons: module.lessons,
                                        courseId: courseId
                                    )
                                    .onDisappear { Task { await vm.load() } }
                                ) {
                                    LessonRow(lesson: lesson, courseId: courseId, vm: vm)
                                }
                                .buttonStyle(.plain)

                                if lesson.id != module.lessons.last?.id {
                                    Divider()
                                        .background(Color.mdzBorder)
                                        .padding(.leading, 48)
                                }
                            }
                        }
                    }

                    // Sign-off block
                    if let signoffBlock = module.signoffBlock {
                        Divider().background(Color.mdzBorder)

                        ModuleSignoffBlock(
                            courseId: courseId,
                            moduleId: module.id,
                            signoffBlock: signoffBlock,
                            unlockStatus: module.unlockStatusEnum,
                            onRequestSent: { Task { await vm.load() } }
                        )
                        .padding(12)
                    }
                }
            }

            // ── Lock reason ───────────────────────────────
            if module.isLocked, let reason = module.lockReason {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text(reason)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.mdzMuted)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(Color.mdzCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .opacity(module.isLocked ? 0.6 : 1.0)
    }

    private var headerCircleColor: Color {
        if module.isLocked { return Color.mdzBorder }
        if module.isComplete { return Color.mdzGreen }
        switch module.unlockStatusEnum {
        case .awaitingInstructor, .awaitingJump: return Color.mdzAmber
        case .jumpFailed: return Color.mdzDanger
        default: return Color.mdzBlue
        }
    }

    private var headerIcon: String {
        if module.isLocked { return "lock.fill" }
        if module.isComplete { return "checkmark" }
        switch module.unlockStatusEnum {
        case .awaitingInstructor: return "pencil.and.signature"
        case .awaitingJump: return "parachute.fill"
        case .jumpFailed: return "xmark"
        default: return "\(min(module.sortOrder, 50)).circle"
        }
    }

    private var statusBadgeColor: Color {
        switch module.unlockStatusEnum {
        case .awaitingInstructor, .awaitingJump: return .mdzAmber
        case .jumpFailed: return .mdzDanger
        case .complete: return .mdzGreen
        default: return .mdzMuted
        }
    }

    private var borderColor: Color {
        if module.isLocked { return Color.mdzBorder }
        if module.isComplete { return Color.mdzGreen.opacity(0.3) }
        switch module.unlockStatusEnum {
        case .awaitingInstructor, .awaitingJump: return Color.mdzAmber.opacity(0.4)
        case .jumpFailed: return Color.mdzDanger.opacity(0.4)
        default: return Color.mdzBorder
        }
    }
}

struct LessonRow: View {
    let lesson: LMSLesson
    let courseId: Int
    @ObservedObject var vm: GroundSchoolViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Visual indicator only — not tappable
            ZStack {
                Circle()
                    .strokeBorder(lesson.completed ? Color.mdzGreen : Color.mdzBorder, lineWidth: 2)
                    .frame(width: 24, height: 24)

                if lesson.completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.mdzGreen)
                }
            }

            Text(lesson.title)
                .font(.system(size: 13, weight: lesson.completed ? .medium : .regular))
                .foregroundColor(lesson.completed ? .mdzMuted : .mdzText)
                .strikethrough(lesson.completed, color: .mdzMuted)
                .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(.mdzMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private func enrollmentColor(_ course: LMSCourse) -> Color {
    switch course.enrollmentStatus {
    case .notEnrolled: return .mdzMuted
    case .enrolled: return .mdzBlue
    case .completed: return .mdzGreen
    }
}
