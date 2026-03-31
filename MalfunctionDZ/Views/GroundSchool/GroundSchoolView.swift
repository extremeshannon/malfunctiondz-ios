// File: ASC/Views/GroundSchool/GroundSchoolView.swift
// Purpose: Main LMS view showing course list, module progression with sequential locking,
//          lessons, sign-off blocks, and quiz launch cards.

import SwiftUI
import MalfunctionDZCore

struct GroundSchoolView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var vm = GroundSchoolViewModel()
    @State private var selectedCourse: LMSCourse?
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        Group {
            if hSizeClass == .regular {
                GroundSchoolSplitView(vm: vm, selectedCourse: $selectedCourse)
            } else {
                GroundSchoolStackView(vm: vm)
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}

// MARK: - iPad: Split view (course list | course detail)
struct GroundSchoolSplitView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject var vm: GroundSchoolViewModel
    @Binding var selectedCourse: LMSCourse?
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        NavigationSplitView {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    groundSchoolHeader
                    if vm.isLoading && vm.courses.isEmpty {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: colors.amber)).scaleEffect(1.4)
                        Spacer()
                    } else if vm.courses.isEmpty {
                        Spacer()
                        EmptyStateView(icon: "graduationcap", title: "No Courses", subtitle: "No courses available.")
                        Spacer()
                    } else {
                        List(selection: $selectedCourse) {
                            ForEach(vm.courses) { course in
                                GroundSchoolCourseRow(course: course)
                                    .tag(course)
                                    .listRowBackground(colors.card)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .background(colors.background)
                    }
                }
            }
            .navigationTitle("Courses")
            .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
            .toolbarBackground(colors.navyMid, for: .navigationBar)
            .onAppear { if selectedCourse == nil, let first = vm.courses.first { selectedCourse = first } }
            .onChange(of: vm.courses.count) { _, _ in
                if selectedCourse == nil, let first = vm.courses.first { selectedCourse = first }
            }
            .toolbar {
                if auth.currentUser?.canManageLMS == true {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: LMSEditRootView()) {
                            Label("Manage LMS", systemImage: "pencil.and.list.clipboard")
                        }
                    }
                }
            }
        } detail: {
            if let course = selectedCourse {
                NavigationStack {
                    CourseDetailView(course: course, vm: vm)
                }
            } else {
                ZStack {
                    colors.background.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 48))
                            .foregroundColor(colors.muted.opacity(0.5))
                        Text("Select a course")
                            .font(.headline)
                            .foregroundColor(colors.muted)
                    }
                }
            }
        }
    }

    private var groundSchoolHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.amber)
                Text("GROUND SCHOOL")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(2)
                Spacer()
                Text("\(vm.courses.count) COURSES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
            }
            Text("Training & LMS")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.navyMid)
    }
}

// Compact row for iPad sidebar
struct GroundSchoolCourseRow: View {
    let course: LMSCourse
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(course.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.text)
                    .lineLimit(2)
                Spacer()
                StatusPill(label: course.enrollmentStatus.label, color: enrollmentColor(course, colors))
            }
            Text("\(course.completedLessons)/\(course.totalLessons) lessons")
                .font(.system(size: 12))
                .foregroundColor(colors.muted)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - iPhone: Stack navigation (original behavior)
struct GroundSchoolStackView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject var vm: GroundSchoolViewModel
    @Environment(\.mdzColors) private var colors

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(colors.amber)
                            Text("GROUND SCHOOL")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(colors.amber)
                                .tracking(2)
                            Spacer()
                            Text("\(vm.courses.count) COURSES")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.muted)
                                .tracking(1)
                        }
                        Text("Training & LMS")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colors.navyMid)

                    if vm.isLoading && vm.courses.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: colors.amber))
                            .scaleEffect(1.4)
                        Spacer()
                    } else if vm.courses.isEmpty {
                        Spacer()
                        EmptyStateView(icon: "graduationcap", title: "No Courses", subtitle: "No courses available.")
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                // Manage LMS card for admins/instructors
                                if auth.currentUser?.canManageLMS == true {
                                    NavigationLink(destination: LMSEditRootView()) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "pencil.and.list.clipboard")
                                                .font(.system(size: 22))
                                                .foregroundColor(colors.accent)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Manage LMS")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(colors.text)
                                                Text("Edit courses, modules, lessons & quizzes")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(colors.muted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(colors.muted)
                                        }
                                        .padding(14)
                                        .background(colors.card)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.accent.opacity(0.5), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                                ForEach(vm.courses) { course in
                                    NavigationLink(destination: CourseDetailView(course: course, vm: vm)) {
                                        CourseCard(course: course)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Course Card
struct CourseCard: View {
    let course: LMSCourse
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(colors.text)
                        .multilineTextAlignment(.leading)

                    if let desc = course.description {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(colors.muted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if !course.isActive {
                    StatusPill(label: "INACTIVE", color: colors.muted)
                }
                StatusPill(label: course.enrollmentStatus.label, color: enrollmentColor(course, colors))
            }

            // Progress bar
            if course.enrolled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(course.completedLessons) of \(course.totalLessons) lessons")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(colors.muted)
                        Spacer()
                        Text("\(Int(course.progressPct))%")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(enrollmentColor(course, colors))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colors.border)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(enrollmentColor(course, colors))
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
                    .foregroundColor(colors.muted)

                Label("\(course.totalLessons) lessons", systemImage: "doc.text.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colors.muted)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    course.progressPct == 100 ? colors.green.opacity(0.4) : colors.border,
                    lineWidth: 1
                )
        )
        .overlay(
            VStack {
                Rectangle()
                    .fill(enrollmentColor(course, colors))
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
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    // Course header
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            if !course.isActive {
                                StatusPill(label: "INACTIVE", color: colors.muted)
                            }
                            StatusPill(label: course.enrollmentStatus.label, color: enrollmentColor(course, colors))
                            Spacer()
                            Text("\(Int(course.progressPct))% complete")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(enrollmentColor(course, colors))
                        }

                        if let desc = course.description {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(colors.muted)
                        }

                        // Progress bar
                        if course.enrolled {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(colors.border)
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(enrollmentColor(course, colors))
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
                                    .foregroundColor(colors.muted)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(colors.card)
                    .cornerRadius(12)

                    // Quizzes for this course
                    if !(course.quizzes ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ASSESSMENTS")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(colors.muted)
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
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            // Auto-expand first incomplete module
            if let first = course.modules.first(where: { !$0.isComplete }) {
                expandedModules.insert(first.id)
            }
            // Refresh course data when returning to course detail (e.g. from a lesson)
            Task { await vm.load() }
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
    @Environment(\.mdzColors) private var colors

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
                            .foregroundColor(module.isLocked ? colors.muted : colors.text)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            if module.isLocked {
                                Label("Locked", systemImage: "lock.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(colors.muted)
                            } else {
                                Text("\(module.completedCount)/\(module.lessonCount) lessons")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.muted)

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
                            .foregroundColor(colors.muted)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // ── Expanded content ──────────────────────────
            if isExpanded && !module.isLocked {
                VStack(spacing: 0) {
                    Divider().background(colors.border)

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
                                ) {
                                    LessonRow(lesson: lesson, courseId: courseId, vm: vm)
                                }
                                .buttonStyle(.plain)

                                if lesson.id != module.lessons.last?.id {
                                    Divider()
                                        .background(colors.border)
                                        .padding(.leading, 48)
                                }
                            }
                        }
                    }

                    // Sign-off block
                    if let signoffBlock = module.signoffBlock {
                        Divider().background(colors.border)

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
                .foregroundColor(colors.muted)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(colors.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .opacity(module.isLocked ? 0.6 : 1.0)
    }

    private var headerCircleColor: Color {
        if module.isLocked { return colors.border }
        if module.isComplete { return colors.green }
        switch module.unlockStatusEnum {
        case .awaitingInstructor, .awaitingJump: return colors.amber
        case .jumpFailed: return colors.danger
        default: return colors.primary
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
        case .awaitingInstructor, .awaitingJump: return colors.amber
        case .jumpFailed: return colors.danger
        case .complete: return colors.green
        default: return colors.muted
        }
    }

    private var borderColor: Color {
        if module.isLocked { return colors.border }
        if module.isComplete { return colors.green.opacity(0.3) }
        switch module.unlockStatusEnum {
        case .awaitingInstructor, .awaitingJump: return colors.amber.opacity(0.4)
        case .jumpFailed: return colors.danger.opacity(0.4)
        default: return colors.border
        }
    }
}

struct LessonRow: View {
    let lesson: LMSLesson
    let courseId: Int
    @ObservedObject var vm: GroundSchoolViewModel
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            // Visual indicator only — not tappable
            ZStack {
                Circle()
                    .strokeBorder(lesson.completed ? colors.green : colors.border, lineWidth: 2)
                    .frame(width: 24, height: 24)

                if lesson.completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(colors.green)
                }
            }

            Text(lesson.title)
                .font(.system(size: 13, weight: lesson.completed ? .medium : .regular))
                .foregroundColor(lesson.completed ? colors.muted : colors.text)
                .strikethrough(lesson.completed, color: colors.muted)
                .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private func enrollmentColor(_ course: LMSCourse, _ colors: MDZColorSet) -> Color {
    switch course.enrollmentStatus {
    case .notEnrolled: return colors.muted
    case .enrolled: return colors.primary
    case .completed: return colors.green
    }
}
