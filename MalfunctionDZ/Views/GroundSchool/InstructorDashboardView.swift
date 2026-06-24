// Instructor LMS dashboard — reviews, progression, jump-ready, enrolled students, my courses.
import SwiftUI
import PencilKit
import MalfunctionDZCore

// MARK: - API models

struct InstructorDashboardResponse: Codable {
    let ok: Bool
    let stats: InstructorDashboardStats?
    let readyForReview: [InstructorSignoffItem]?
    let jumpReady: [InstructorDashboardStudentRow]?
    let progressionForms: [InstructorProgressionRow]?
    let enrolledStudents: [InstructorEnrolledStudentRow]?
    let myCourses: [InstructorDashboardCourseRef]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, stats, error
        case readyForReview = "ready_for_review"
        case jumpReady = "jump_ready"
        case progressionForms = "progression_forms"
        case enrolledStudents = "enrolled_students"
        case myCourses = "my_courses"
    }
}

struct InstructorDashboardStats: Codable {
    let readyForReview: Int?
    let progressionFormComplete: Int?
    let jumpReadyStudents: Int?
    let studentsWithEnrollments: Int?
    let activeCourses: Int?

    enum CodingKeys: String, CodingKey {
        case readyForReview = "ready_for_review"
        case progressionFormComplete = "progression_form_complete"
        case jumpReadyStudents = "jump_ready_students"
        case studentsWithEnrollments = "students_with_enrollments"
        case activeCourses = "active_courses"
    }
}

struct InstructorDashboardStudentRow: Codable, Identifiable, Hashable {
    let userId: Int
    let displayName: String
    let courseId: Int
    let courseTitle: String
    let progressPct: Double
    let currentLessonLabel: String?
    let currentLessonId: Int?
    let currentModuleId: Int?
    let jumpSignoffId: Int?

    var id: String { "\(userId)-\(courseId)" }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case userId = "user_id"
        case courseId = "course_id"
        case courseTitle = "course_title"
        case progressPct = "progress_pct"
        case currentLessonLabel = "current_lesson_label"
        case currentLessonId = "current_lesson_id"
        case currentModuleId = "current_module_id"
        case jumpSignoffId = "jump_signoff_id"
    }
}

struct InstructorProgressionRow: Codable, Identifiable, Hashable {
    let userId: Int
    let displayName: String
    let courseId: Int
    let courseTitle: String
    let formDone: Int
    let formTotal: Int
    let formPct: Double
    let formComplete: Bool
    let currentStep: String

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case userId = "user_id"
        case courseId = "course_id"
        case courseTitle = "course_title"
        case formDone = "form_done"
        case formTotal = "form_total"
        case formPct = "form_pct"
        case formComplete = "form_complete"
        case currentStep = "current_step"
    }
}

struct InstructorEnrolledStudentRow: Codable, Identifiable, Hashable {
    let userId: Int
    let displayName: String
    let courseTitle: String
    let statusLabel: String
    let statusKind: String
    let currentLessonLabel: String
    let progressPct: Double

    var id: String { "\(userId)-\(courseTitle)" }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case userId = "user_id"
        case courseTitle = "course_title"
        case statusLabel = "status_label"
        case statusKind = "status_kind"
        case currentLessonLabel = "current_lesson_label"
        case progressPct = "progress_pct"
    }
}

struct InstructorDashboardCourseRef: Codable, Identifiable, Hashable {
    let id: Int
    let slug: String
    let title: String
}

// MARK: - ViewModel

@MainActor
final class InstructorDashboardViewModel: ObservableObject {
    @Published var stats = InstructorDashboardStats(
        readyForReview: 0,
        progressionFormComplete: 0,
        jumpReadyStudents: 0,
        studentsWithEnrollments: 0,
        activeCourses: 0
    )
    @Published var readyForReview: [InstructorSignoffItem] = []
    @Published var jumpReady: [InstructorDashboardStudentRow] = []
    @Published var progressionForms: [InstructorProgressionRow] = []
    @Published var enrolledStudents: [InstructorEnrolledStudentRow] = []
    @Published var myCourseRefs: [InstructorDashboardCourseRef] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = KeychainHelper.readToken(),
              let url = URL(string: "\(kServerURL)/api/lms/instructor/dashboard.php") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                error = "Session expired — sign in again."
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 403 {
                error = "LMS instructor access required for this account."
                return
            }
            let resp = try JSONDecoder().decode(InstructorDashboardResponse.self, from: data)
            guard resp.ok else {
                error = resp.error ?? "Could not load dashboard"
                return
            }
            stats = resp.stats ?? stats
            readyForReview = resp.readyForReview ?? []
            jumpReady = resp.jumpReady ?? []
            progressionForms = resp.progressionForms ?? []
            enrolledStudents = resp.enrolledStudents ?? []
            myCourseRefs = resp.myCourses ?? []
            error = nil
        } catch {
            guard !Task.isCancelled else { return }
            if let url = error as? URLError, url.code == .cancelled { return }
            if error is CancellationError { return }
            self.error = "Could not load instructor dashboard."
        }
    }
}

// MARK: - Root (phone + iPad)

struct InstructorDashboardView: View {
    @ObservedObject var coursesVm: GroundSchoolViewModel
    @StateObject private var dashVm = InstructorDashboardViewModel()
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var tabSelect: TabSelection
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private var myCourses: [LMSCourse] {
        let ids = Set(dashVm.myCourseRefs.map(\.id))
        return coursesVm.courses.filter { $0.enrolled || ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                if dashVm.isLoading && dashVm.readyForReview.isEmpty && myCourses.isEmpty {
                    ProgressView().tint(colors.amber).scaleEffect(1.3)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            instructorHeader
                            NavigationLink(destination: InstructorProfileView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.text.rectangle")
                                        .font(.system(size: 18))
                                        .foregroundColor(colors.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Instructor Profile")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(colors.text)
                                        Text("License, initials, and signature for sign-offs")
                                            .font(.system(size: 12))
                                            .foregroundColor(colors.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(colors.muted)
                                }
                                .padding(14)
                                .background(colors.card)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            if let err = dashVm.error {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundColor(colors.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                            }
                            sectionNavLink(
                                title: "Ready for Review",
                                subtitle: "Ground school and jump log sign-offs",
                                count: dashVm.readyForReview.count
                            ) {
                                InstructorReadyForReviewListView(items: dashVm.readyForReview)
                            }
                            sectionNavLink(
                                title: "Progression Card",
                                subtitle: "USPA ISP A-License check-off",
                                count: dashVm.progressionForms.count
                            ) {
                                InstructorProgressionListView(
                                    items: dashVm.progressionForms,
                                    pendingReviews: dashVm.readyForReview
                                )
                            }
                            sectionNavLink(
                                title: "Jump-Ready Students",
                                subtitle: "On jump sign-off lesson",
                                count: dashVm.jumpReady.count
                            ) {
                                InstructorJumpReadyListView(
                                    items: dashVm.jumpReady,
                                    pendingReviews: dashVm.readyForReview
                                )
                            }
                            sectionNavLink(
                                title: "Enrolled Students",
                                subtitle: "Status and current lesson",
                                count: dashVm.enrolledStudents.count
                            ) {
                                InstructorEnrolledStudentsListView(
                                    items: dashVm.enrolledStudents,
                                    pendingReviews: dashVm.readyForReview
                                )
                            }
                            sectionNavLink(
                                title: "My Courses",
                                subtitle: "Courses you teach",
                                count: myCourses.count
                            ) {
                                InstructorMyCoursesListView(courses: myCourses, coursesVm: coursesVm)
                            }
                            if auth.currentUser?.canManageLMS == true {
                                manageLmsLink
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                async let dashboard: Void = dashVm.load()
                async let courses: Void = coursesVm.load()
                _ = await (dashboard, courses)
            }
            .task {
                async let dashboard: Void = dashVm.load()
                async let courses: Void = coursesVm.load()
                _ = await (dashboard, courses)
            }
            .onChange(of: tabSelect.openInstructorReviews) { _, open in
                if open { tabSelect.openInstructorReviews = false }
            }
        }
    }

    private var instructorHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.amber)
                Text("INSTRUCTOR DASHBOARD")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.amber)
                    .tracking(2)
                Spacer()
                Text("\(dashVm.stats.activeCourses ?? myCourses.count) COURSES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(colors.muted)
                    .tracking(1)
            }
            Text("Students on your enrolled courses")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.navyMid)
    }

    private func sectionNavLink<Destination: View>(
        title: String,
        subtitle: String,
        count: Int,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            DashboardSectionCard(title: title, subtitle: subtitle, count: count)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var manageLmsLink: some View {
        NavigationLink {
            LMSEditRootView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 20))
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
                    .foregroundColor(colors.muted)
            }
            .padding(14)
            .background(colors.card)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Section summary card

private struct DashboardSectionCard: View {
    let title: String
    let subtitle: String
    let count: Int
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(colors.text)
                    .tracking(0.8)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(colors.muted)
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(count > 0 ? colors.amber : colors.muted)
                .frame(minWidth: 36, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colors.muted)
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(colors.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

// MARK: - Section list screens

struct InstructorReadyForReviewListView: View {
    let items: [InstructorSignoffItem]
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if items.isEmpty {
                InstructorDashboardEmptyState(message: "No students waiting for review", icon: "checkmark.seal")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            if item.isJumpSignoff {
                                NavigationLink {
                                    InstructorJumpReviewDetailView(signoffId: item.id)
                                } label: {
                                    InstructorReviewJumpRow(item: item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    InstructorReviewDetailView(requestId: item.id)
                                } label: {
                                    InstructorReviewRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Ready for Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct InstructorProgressionListView: View {
    let items: [InstructorProgressionRow]
    let pendingReviews: [InstructorSignoffItem]
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if items.isEmpty {
                InstructorDashboardEmptyState(message: "No progression forms on your courses", icon: "doc.text")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(items) { row in
                            NavigationLink {
                                InstructorStudentSummaryView(
                                    userId: row.userId,
                                    displayName: row.displayName,
                                    courseTitle: row.courseTitle,
                                    pendingReviews: pendingReviews,
                                    progression: row
                                )
                            } label: {
                                ProgressionRowCard(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Progression Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct InstructorJumpReadyListView: View {
    let items: [InstructorDashboardStudentRow]
    let pendingReviews: [InstructorSignoffItem]
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if items.isEmpty {
                InstructorDashboardEmptyState(message: "No jump-ready students", icon: "figure.fall")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(items) { row in
                            jumpReadyLink(for: row)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Jump-Ready")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    @ViewBuilder
    private func jumpReadyLink(for row: InstructorDashboardStudentRow) -> some View {
        if let lessonId = row.currentLessonId, let moduleId = row.currentModuleId, moduleId > 0 {
            NavigationLink {
                InstructorStudentJumpSignoffView(
                    studentId: row.userId,
                    studentName: row.displayName,
                    lessonId: lessonId,
                    moduleId: moduleId,
                    courseTitle: row.courseTitle,
                    lessonLabel: row.currentLessonLabel ?? "Jump sign-off"
                )
            } label: {
                JumpReadyRowCard(row: row, badge: row.jumpSignoffId != nil ? "Review log" : "Log jump")
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                InstructorStudentSummaryView(
                    userId: row.userId,
                    displayName: row.displayName,
                    courseTitle: row.courseTitle,
                    pendingReviews: pendingReviews,
                    jumpReady: row
                )
            } label: {
                JumpReadyRowCard(row: row, badge: "On sign-off")
            }
            .buttonStyle(.plain)
        }
    }
}

struct InstructorEnrolledStudentsListView: View {
    let items: [InstructorEnrolledStudentRow]
    let pendingReviews: [InstructorSignoffItem]
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if items.isEmpty {
                InstructorDashboardEmptyState(message: "No enrolled students", icon: "person.3")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(items) { row in
                            NavigationLink {
                                InstructorStudentSummaryView(
                                    userId: row.userId,
                                    displayName: row.displayName,
                                    courseTitle: row.courseTitle,
                                    pendingReviews: pendingReviews,
                                    enrolled: row
                                )
                            } label: {
                                EnrolledStudentRowCard(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Enrolled Students")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct InstructorMyCoursesListView: View {
    let courses: [LMSCourse]
    @ObservedObject var coursesVm: GroundSchoolViewModel
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            if courses.isEmpty {
                InstructorDashboardEmptyState(message: "Not enrolled on any course", icon: "graduationcap")
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(courses) { course in
                            NavigationLink {
                                CourseDetailView(course: course, vm: coursesVm)
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
        .navigationTitle("My Courses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct InstructorStudentSummaryView: View {
    let userId: Int
    let displayName: String
    let courseTitle: String
    let pendingReviews: [InstructorSignoffItem]
    var progression: InstructorProgressionRow?
    var jumpReady: InstructorDashboardStudentRow?
    var enrolled: InstructorEnrolledStudentRow?
    @Environment(\.mdzColors) private var colors
    @Environment(\.mdzColorScheme) private var mdzColorScheme

    private var studentReviews: [InstructorSignoffItem] {
        pendingReviews.filter { $0.studentId == userId }
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(colors.text)
                        Text(courseTitle)
                            .font(.system(size: 14))
                            .foregroundColor(colors.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.card)
                    .cornerRadius(12)

                    if let p = progression {
                        summaryBlock("PROGRESSION CARD") {
                            Text("Current: \(p.currentStep)")
                                .font(.system(size: 13))
                                .foregroundColor(colors.amber)
                            if p.formComplete {
                                Text("Form complete").foregroundColor(colors.green)
                            } else {
                                Text("\(p.formDone) of \(p.formTotal) items (\(Int(p.formPct))%)")
                                    .foregroundColor(colors.text)
                            }
                        }
                    }

                    if let j = jumpReady {
                        summaryBlock("JUMP SIGN-OFF") {
                            Text(j.currentLessonLabel ?? "Jump sign-off lesson")
                                .font(.system(size: 13))
                                .foregroundColor(colors.amber)
                            Text("Course progress: \(Int(j.progressPct))%")
                                .foregroundColor(colors.text)
                            if let lessonId = j.currentLessonId, let moduleId = j.currentModuleId, moduleId > 0 {
                                NavigationLink {
                                    InstructorStudentJumpSignoffView(
                                        studentId: j.userId,
                                        studentName: j.displayName,
                                        lessonId: lessonId,
                                        moduleId: moduleId,
                                        courseTitle: j.courseTitle,
                                        lessonLabel: j.currentLessonLabel ?? "Jump sign-off"
                                    )
                                } label: {
                                    Text(j.jumpSignoffId != nil ? "Review jump log" : "Record jump & sign off")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(colors.primary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }

                    if let e = enrolled {
                        summaryBlock("ENROLLMENT") {
                            Text(e.statusLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(colors.primary)
                            Text(e.currentLessonLabel)
                                .font(.system(size: 13))
                                .foregroundColor(colors.amber)
                            Text("\(Int(e.progressPct))% course progress")
                                .font(.system(size: 12))
                                .foregroundColor(colors.muted)
                        }
                    }

                    if !studentReviews.isEmpty {
                        summaryBlock("PENDING REVIEWS") {
                            ForEach(studentReviews) { item in
                                if item.isJumpSignoff {
                                    NavigationLink {
                                        InstructorJumpReviewDetailView(signoffId: item.id)
                                    } label: {
                                        Text("Review jump: \(item.displayTitle)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(colors.primary)
                                    }
                                } else {
                                    NavigationLink {
                                        InstructorReviewDetailView(requestId: item.id)
                                    } label: {
                                        Text("Review module: \(item.displayTitle)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(colors.primary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Student")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(mdzColorScheme, for: .navigationBar)
        .toolbarBackground(colors.navyMid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func summaryBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(colors.muted)
                .tracking(1)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .cornerRadius(12)
    }
}

private struct ProgressionRowCard: View {
    let row: InstructorProgressionRow
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.text)
                Text(row.courseTitle)
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
                Text(row.currentStep)
                    .font(.system(size: 11))
                    .foregroundColor(colors.amber)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if row.formComplete {
                    Text("Done").font(.system(size: 11, weight: .bold)).foregroundColor(colors.green)
                } else {
                    Text("\(row.formDone)/\(row.formTotal)")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(colors.text)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

private struct JumpReadyRowCard: View {
    let row: InstructorDashboardStudentRow
    let badge: String
    @Environment(\.mdzColors) private var colors

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.text)
                Text(row.courseTitle)
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
                if let lesson = row.currentLessonLabel, !lesson.isEmpty {
                    Text(lesson)
                        .font(.system(size: 11))
                        .foregroundColor(colors.amber)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(badge)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(colors.amber)
                Text("\(Int(row.progressPct))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colors.green)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

private struct EnrolledStudentRowCard: View {
    let row: InstructorEnrolledStudentRow
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.text)
                Spacer()
                Text(row.statusLabel.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.primary.opacity(0.12))
                    .clipShape(Capsule())
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(colors.muted)
            }
            Text(row.courseTitle)
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
            Text(row.currentLessonLabel)
                .font(.system(size: 11))
                .foregroundColor(colors.amber)
                .lineLimit(2)
        }
        .padding(14)
        .background(colors.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(colors.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

private struct InstructorDashboardEmptyState: View {
    let message: String
    let icon: String
    @Environment(\.mdzColors) private var colors

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(colors.muted.opacity(0.5))
            Text(message)
                .font(.headline)
                .foregroundColor(colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Signature pad (white paper, dark ink)

struct InstructorSignaturePadRepresentable: UIViewRepresentable {
    @Binding var canvas: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.tool = PKInkingTool(.pen, color: .black, width: 2)
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
