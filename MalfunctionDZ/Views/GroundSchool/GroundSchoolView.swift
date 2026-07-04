// File: ASC/Views/GroundSchool/GroundSchoolView.swift
// Purpose: Main LMS view showing course list, module progression with sequential locking,
//          lessons, sign-off blocks, and quiz launch cards.

import SwiftUI
import MalfunctionDZCore

struct GroundSchoolView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.appShell) private var appShell
    @StateObject private var vm = GroundSchoolViewModel()
    @State private var selectedCourse: LMSCourse?
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var showInstructorDashboard: Bool {
        guard auth.currentUser?.isInstructorRole == true else { return false }
        return appShell == .staff || auth.currentUser?.isLMSInstructorRole == true
    }

    var body: some View {
        Group {
            if showInstructorDashboard {
                InstructorDashboardView(coursesVm: vm)
            } else if hSizeClass == .regular {
                GroundSchoolWideLayout(vm: vm, selectedCourse: $selectedCourse)
            } else {
                GroundSchoolStackView(vm: vm)
            }
        }
        .task(id: auth.currentUser?.id) {
            if !showInstructorDashboard {
                await vm.load(scope: appShell.groundSchoolScope)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }
}

// MARK: - iPad: Wide layout (avoids nested NavigationSplitView — lesson taps work)
struct GroundSchoolWideLayout: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.appShell) private var appShell
    @ObservedObject var vm: GroundSchoolViewModel
    @Binding var selectedCourse: LMSCourse?
    @State private var showInstructorReviews = false
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        HStack(spacing: 0) {
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
            .frame(width: 340)
            .background(colors.background)

            Divider().background(colors.border)

            NavigationStack {
                if let course = selectedCourse {
                    CourseDetailView(course: course, vm: vm)
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
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            applyPendingGroundSchoolResume()
            if selectedCourse == nil, tabSelect.pendingGroundSchoolResume == nil,
               let first = vm.courses.first { selectedCourse = first }
        }
        .onChange(of: vm.courses.count) { _, _ in
            if selectedCourse == nil, tabSelect.pendingGroundSchoolResume == nil,
               let first = vm.courses.first { selectedCourse = first }
        }
        .onChange(of: tabSelect.pendingGroundSchoolResume) { _, _ in
            applyPendingGroundSchoolResume()
        }
        .onChange(of: tabSelect.selected) { _, tag in
            if tag == 3 { applyPendingGroundSchoolResume() }
        }
        .onChange(of: tabSelect.openInstructorReviews) { _, open in
            if open {
                showInstructorReviews = true
                tabSelect.openInstructorReviews = false
            }
        }
        .navigationDestination(isPresented: $showInstructorReviews) {
            InstructorReviewListView()
        }
        .toolbar {
            if auth.currentUser?.canManageLMS == true && appShell == .staff {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: LMSEditRootView()) {
                        Label("Manage LMS", systemImage: "pencil.and.list.clipboard")
                    }
                }
            }
        }
        .refreshable { await vm.load() }
    }

    private func applyPendingGroundSchoolResume() {
        guard tabSelect.selected == 3,
              let target = tabSelect.pendingGroundSchoolResume else { return }

        func open(in courses: [LMSCourse]) {
            guard let course = courses.first(where: { $0.id == target.courseId }) else { return }
            selectedCourse = course
        }

        if let course = vm.courses.first(where: { $0.id == target.courseId }) {
            selectedCourse = course
        } else {
            Task {
                await vm.load(scope: appShell.groundSchoolScope)
                open(in: vm.courses)
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

// MARK: - iPad: Split view (legacy — nested split breaks lesson navigation in app shell)
struct GroundSchoolSplitView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.appShell) private var appShell
    @ObservedObject var vm: GroundSchoolViewModel
    @Binding var selectedCourse: LMSCourse?
    @State private var showInstructorReviews = false
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
                            if auth.currentUser?.isInstructorRole == true && appShell == .staff {
                                NavigationLink(destination: InstructorReviewListView()) {
                                    InstructorReviewEntryCard(pendingCount: vm.pendingInstructorReviews)
                                }
                                .listRowBackground(colors.card)
                            }
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
            .onChange(of: tabSelect.openInstructorReviews) { _, open in
                if open {
                    showInstructorReviews = true
                    tabSelect.openInstructorReviews = false
                }
            }
            .navigationDestination(isPresented: $showInstructorReviews) {
                InstructorReviewListView()
            }
            .toolbar {
                if auth.currentUser?.canManageLMS == true && appShell == .staff {
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
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.appShell) private var appShell
    @ObservedObject var vm: GroundSchoolViewModel
    @State private var showInstructorReviews = false
    @State private var resumeCourse: LMSCourse?
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
                                if auth.currentUser?.isInstructorRole == true && appShell == .staff {
                                    NavigationLink(destination: InstructorReviewListView()) {
                                        InstructorReviewEntryCard(pendingCount: vm.pendingInstructorReviews)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if auth.currentUser?.canManageLMS == true && appShell == .staff {
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
                                    NavigationLink {
                                        CourseDetailView(course: course, vm: vm)
                                    } label: {
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
            .navigationDestination(isPresented: $showInstructorReviews) {
                InstructorReviewListView()
            }
            .navigationDestination(item: $resumeCourse) { course in
                CourseDetailView(course: course, vm: vm)
            }
            .onAppear { applyPendingGroundSchoolResume() }
            .onChange(of: tabSelect.pendingGroundSchoolResume) { _, _ in
                applyPendingGroundSchoolResume()
            }
            .onChange(of: tabSelect.selected) { _, tag in
                if tag == 3 { applyPendingGroundSchoolResume() }
            }
            .onChange(of: tabSelect.openInstructorReviews) { _, open in
                if open {
                    showInstructorReviews = true
                    tabSelect.openInstructorReviews = false
                }
            }
            .refreshable { await vm.load() }
        }
    }

    private func applyPendingGroundSchoolResume() {
        guard tabSelect.selected == 3,
              let target = tabSelect.pendingGroundSchoolResume else { return }

        func open(in courses: [LMSCourse]) {
            guard let course = courses.first(where: { $0.id == target.courseId }) else { return }
            resumeCourse = nil
            DispatchQueue.main.async {
                resumeCourse = course
            }
        }

        if let course = vm.courses.first(where: { $0.id == target.courseId }) {
            resumeCourse = nil
            DispatchQueue.main.async {
                resumeCourse = course
            }
        } else {
            Task {
                await vm.load(scope: appShell.groundSchoolScope)
                open(in: vm.courses)
            }
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

// MARK: - Lesson navigation (programmatic — reliable on iPad wide layout)
struct LessonNavItem: Hashable {
    let lessonId: Int
    let lessonTitle: String
    let courseId: Int
    let moduleId: Int
    let allLessons: [LMSLesson]
}

// MARK: - Course Detail
struct CourseDetailView: View {
    let course: LMSCourse
    @ObservedObject var vm: GroundSchoolViewModel
    @EnvironmentObject private var tabSelect: TabSelection
    @State private var expandedModules: Set<Int> = []
    @State private var showModuleQuizzes = false
    @State private var showCompletedModules = false
    @State private var lessonNav: LessonNavItem?
    @State private var didApplyResume = false
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private var liveCourse: LMSCourse {
        vm.courses.first(where: { $0.id == course.id }) ?? course
    }

    /// Unlocked modules only — future modules stay hidden until prior level is complete.
    private var accessibleModules: [LMSModule] {
        liveCourse.modules.filter { !$0.isLocked }
    }

    private var readingAssignmentsModule: LMSModule? {
        accessibleModules.first(where: \.isReadingAssignmentsModule)
    }

    private var trainingModules: [LMSModule] {
        accessibleModules.filter { !$0.isReadingAssignmentsModule }
    }

    private var currentModule: LMSModule? {
        trainingModules.first(where: { !$0.isComplete })
    }

    private var completedModules: [LMSModule] {
        trainingModules.filter(\.isComplete)
    }

    private var currentModuleQuizzes: [LMSQuizSummary] {
        guard let current = currentModule else { return [] }
        return liveCourse.quizzesForModule(current)
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        courseHeaderCard

                        if let reading = readingAssignmentsModule {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("READING ASSIGNMENTS")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(colors.primary)
                                    .tracking(2)
                                Text("Complete each category reading before training — signs Read SIM on your A-card.")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.muted)
                                ModuleSection(
                                    module: reading,
                                    courseId: liveCourse.id,
                                    isExpanded: expandedModules.contains(reading.id) || !reading.isComplete,
                                    pinsOpen: false,
                                    moduleQuizzes: [],
                                    vm: vm,
                                    onToggle: { toggleModule(reading.id) },
                                    onSelectLesson: { lesson in
                                        lessonNav = LessonNavItem(
                                            lessonId: lesson.id,
                                            lessonTitle: lesson.title,
                                            courseId: liveCourse.id,
                                            moduleId: reading.id,
                                            allLessons: reading.lessons
                                        )
                                    }
                                )
                                .id("module-\(reading.id)")
                            }
                        }

                        if let current = currentModule {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CURRENT MODULE")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(colors.amber)
                                    .tracking(2)

                                ModuleSection(
                                    module: current,
                                    courseId: liveCourse.id,
                                    isExpanded: true,
                                    pinsOpen: true,
                                    moduleQuizzes: currentModuleQuizzes,
                                    vm: vm,
                                    onToggle: { },
                                    onSelectLesson: { lesson in
                                        lessonNav = LessonNavItem(
                                            lessonId: lesson.id,
                                            lessonTitle: lesson.title,
                                            courseId: liveCourse.id,
                                            moduleId: current.id,
                                            allLessons: current.lessons
                                        )
                                    }
                                )
                                .id("current-module")
                            }
                        } else if accessibleModules.isEmpty {
                            Text("No modules available yet.")
                                .font(.subheadline)
                                .foregroundColor(colors.muted)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colors.card)
                                .cornerRadius(12)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(colors.green)
                                Text("All available modules complete — great work!")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(colors.text)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colors.card)
                            .cornerRadius(12)
                        }

                        if !completedModules.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showCompletedModules.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text("COMPLETED MODULES (\(completedModules.count))")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(colors.muted)
                                            .tracking(2)
                                        Spacer()
                                        Image(systemName: showCompletedModules ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(colors.muted)
                                    }
                                }
                                .buttonStyle(.plain)

                                if showCompletedModules {
                                    ForEach(completedModules) { module in
                                        ModuleSection(
                                            module: module,
                                            courseId: liveCourse.id,
                                            isExpanded: expandedModules.contains(module.id),
                                            moduleQuizzes: liveCourse.quizzesForModule(module),
                                            vm: vm,
                                            onToggle: { toggleModule(module.id) },
                                            onSelectLesson: { lesson in
                                                lessonNav = LessonNavItem(
                                                    lessonId: lesson.id,
                                                    lessonTitle: lesson.title,
                                                    courseId: liveCourse.id,
                                                    moduleId: module.id,
                                                    allLessons: module.lessons
                                                )
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .onAppear {
                    if !didApplyResume {
                        didApplyResume = true
                        applyResumeNavigation(proxy: proxy)
                    }
                    Task { await vm.load() }
                }
                .onChange(of: tabSelect.pendingGroundSchoolResume) { _, pending in
                    guard let pending, pending.courseId == liveCourse.id else { return }
                    applyResumeFromPending(pending, proxy: proxy)
                }
            }
        }
        .navigationTitle(liveCourse.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !currentModuleQuizzes.isEmpty {
                    Button {
                        showModuleQuizzes = true
                    } label: {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colors.amber)
                    }
                    .accessibilityLabel("Module quiz")
                }
            }
        }
        .sheet(isPresented: $showModuleQuizzes) {
            ModuleQuizzesSheet(quizzes: currentModuleQuizzes, moduleTitle: currentModule?.title)
        }
        .navigationDestination(item: $lessonNav) { nav in
            LessonDetailView(
                lessonId: nav.lessonId,
                lessonTitle: nav.lessonTitle,
                allLessons: nav.allLessons,
                courseId: nav.courseId,
                moduleId: nav.moduleId,
                onBackToModule: { lessonNav = nil },
                onGoToLesson: { lessonNav = $0 }
            )
            .id(nav.lessonId)
        }
    }

    private var courseHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if !liveCourse.isActive {
                    StatusPill(label: "INACTIVE", color: colors.muted)
                }
                StatusPill(label: liveCourse.enrollmentStatus.label, color: enrollmentColor(liveCourse, colors))
                Spacer()
                Text("\(Int(min(liveCourse.progressPct, 100)))% complete")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(enrollmentColor(liveCourse, colors))
            }

            if let desc = liveCourse.description {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(colors.muted)
                    .lineLimit(3)
            }

            if liveCourse.enrolled {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colors.border)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(enrollmentColor(liveCourse, colors))
                            .frame(
                                width: geo.size.width * CGFloat(min(liveCourse.progressPct, 100)) / 100,
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                Text("\(liveCourse.completedLessons) of \(liveCourse.totalLessons) lessons completed")
                    .font(.caption)
                    .foregroundColor(colors.muted)
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(12)
    }

    private func applyResumeNavigation(proxy: ScrollViewProxy) {
        guard let pending = tabSelect.pendingGroundSchoolResume,
              pending.courseId == liveCourse.id else {
            scrollToCurrentModule(proxy: proxy)
            return
        }
        applyResumeFromPending(pending, proxy: proxy)
    }

    private func applyResumeFromPending(_ pending: GroundSchoolResumeTarget, proxy: ScrollViewProxy? = nil) {
        tabSelect.pendingGroundSchoolResume = nil
        expandedModules.insert(pending.moduleId)
        let scrollId = pending.moduleId == currentModule?.id ? "current-module" : "module-\(pending.moduleId)"
        if let proxy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation { proxy.scrollTo(scrollId, anchor: .top) }
            }
        }
        if let lid = pending.lessonId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openLesson(lessonId: lid, moduleId: pending.moduleId)
            }
        }
    }

    private func scrollToCurrentModule(proxy: ScrollViewProxy) {
        if let current = currentModule {
            expandedModules = [current.id]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { proxy.scrollTo("current-module", anchor: .top) }
            }
        }
    }

    private func openLesson(lessonId: Int, moduleId: Int) {
        guard let module = liveCourse.modules.first(where: { $0.id == moduleId }),
              let lesson = module.lessons.first(where: { $0.id == lessonId }) else { return }
        lessonNav = LessonNavItem(
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            courseId: liveCourse.id,
            moduleId: moduleId,
            allLessons: module.lessons
        )
    }

    private func toggleModule(_ id: Int) {
        if expandedModules.contains(id) {
            expandedModules.remove(id)
        } else {
            expandedModules.insert(id)
        }
    }
}

// MARK: - Module quizzes sheet
private struct ModuleQuizzesSheet: View {
    let quizzes: [LMSQuizSummary]
    var moduleTitle: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mdzColors) private var colors

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if quizzes.isEmpty {
                        Text("Complete all lessons in this module to unlock the quiz.")
                            .foregroundColor(colors.muted)
                            .padding(.top, 24)
                    } else {
                        ForEach(quizzes) { quiz in
                            QuizLaunchCard(
                                quizId: quiz.id,
                                title: quiz.title,
                                passPercentage: quiz.passPercentage,
                                questionCount: quiz.questionCount,
                                isUnlocked: true,
                                lockReason: nil,
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
                .padding(16)
            }
            .background(colors.background.ignoresSafeArea())
            .navigationTitle(moduleTitle ?? "Module Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Module Section
struct ModuleSection: View {
    let module: LMSModule
    let courseId: Int
    let isExpanded: Bool
    var pinsOpen: Bool = false
    var moduleQuizzes: [LMSQuizSummary] = []
    @ObservedObject var vm: GroundSchoolViewModel
    let onToggle: () -> Void
    var onSelectLesson: ((LMSLesson) -> Void)?
    @State private var showModuleQuizzes = false
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(spacing: 0) {

            // ── Module header ─────────────────────────────
            Button(action: { if !module.isLocked && !pinsOpen { onToggle() } }) {
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

                    if !moduleQuizzes.isEmpty {
                        Button {
                            showModuleQuizzes = true
                        } label: {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(colors.amber)
                                .padding(6)
                                .background(colors.amber.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Take module quiz")
                    }

                    if !module.isLocked && !pinsOpen {
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
                                Button {
                                    if !lesson.isLocked {
                                        onSelectLesson?(lesson)
                                    }
                                } label: {
                                    LessonRow(lesson: lesson, courseId: courseId, vm: vm)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .disabled(lesson.isLocked)

                                if lesson.id != module.lessons.last?.id {
                                    Rectangle()
                                        .fill(colors.border.opacity(0.4))
                                        .frame(height: 1)
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
        .sheet(isPresented: $showModuleQuizzes) {
            ModuleQuizzesSheet(quizzes: moduleQuizzes, moduleTitle: module.title)
        }
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
            ZStack {
                Circle()
                    .strokeBorder(
                        lesson.completed ? colors.green : (lesson.isLocked ? colors.border : colors.border),
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)

                if lesson.completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(colors.green)
                } else if lesson.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(colors.muted)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.system(size: 13, weight: lesson.completed ? .medium : .regular))
                    .foregroundColor(lesson.isLocked ? colors.muted : colors.text)
                    .multilineTextAlignment(.leading)
                if lesson.isLocked, let reason = ReadingAssignmentHelper.lockHint(
                    forLessonTitle: lesson.title,
                    serverReason: lesson.lockReason
                ), !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundColor(colors.muted)
                }
            }

            Spacer()

            if !lesson.isLocked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(colors.card)
        .opacity(lesson.isLocked ? 0.65 : 1)
    }
}

private func enrollmentColor(_ course: LMSCourse, _ colors: MDZColorSet) -> Color {
    switch course.enrollmentStatus {
    case .notEnrolled: return colors.muted
    case .enrolled: return colors.primary
    case .completed: return colors.green
    }
}
