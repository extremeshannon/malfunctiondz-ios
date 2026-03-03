// File: ASC/Views/GroundSchool/LMSEditRootView.swift
// Manage LMS: courses, modules, lessons, quizzes, question bank (admin/instructor).

import SwiftUI

struct LMSEditRootView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mdzBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        LMSEditCard(icon: "book.fill", title: "Courses", subtitle: "Create and manage courses") {
                            LMSCoursesListView()
                        }
                        LMSEditCard(icon: "square.stack.fill", title: "Modules", subtitle: "Reusable across courses") {
                            LMSModulesListView()
                        }
                        LMSEditCard(icon: "doc.text.fill", title: "Lessons", subtitle: "Assign to courses and modules") {
                            LMSLessonsListView()
                        }
                        LMSEditCard(icon: "list.clipboard.fill", title: "Quizzes", subtitle: "Built from question bank") {
                            LMSQuizzesListView()
                        }
                        LMSEditCard(icon: "questionmark.circle.fill", title: "Question Bank", subtitle: "Questions for any quiz") {
                            LMSQuestionBankView()
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Manage LMS")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
            .toolbarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Card

private struct LMSEditCard<Destination: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.mdzAmber)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.mdzText)
                    Text(subtitle)
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
    }
}

// MARK: - Courses List

struct LMSCoursesListView: View {
    @StateObject private var vm = LMSCoursesEditViewModel()
    @State private var showAdd = false

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.courses.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber)).scaleEffect(1.4)
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted).multilineTextAlignment(.center)
                        Button("Retry") { Task { await vm.load() } }
                            .foregroundColor(.mdzAmber)
                    }
                } else {
                    List {
                        ForEach(vm.courses) { c in
                            NavigationLink(destination: LMSCourseEditView(courseId: c.id, existing: c)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title).font(.headline).foregroundColor(.mdzText)
                                    HStack(spacing: 6) {
                                        Text(c.slug).font(.caption).foregroundColor(.mdzMuted)
                                        Text("•").foregroundColor(.mdzMuted)
                                        Text(c.is_active == 1 ? "Active" : "Inactive")
                                            .font(.caption).foregroundColor(c.is_active == 1 ? .mdzGreen : .mdzMuted)
                                    }
                                }
                            }
                            .listRowBackground(Color.mdzCard)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { Task { await vm.delete(id: c.id) } } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Courses")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                LMSCourseEditView(courseId: 0, existing: nil, onSaved: {
                    showAdd = false
                    Task { await vm.load() }
                })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAdd = false }
                    }
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

// MARK: - Course Edit

struct LMSCourseEditView: View {
    let courseId: Int
    let existing: LMSEditCourse?
    var onSaved: (() -> Void)?

    @State private var slug = ""
    @State private var title = ""
    @State private var descriptionText = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { courseId == 0 }

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Form {
                Section("Course Details") {
                    TextField("Slug", text: $slug).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Title", text: $title)
                    TextField("Description", text: $descriptionText, axis: .vertical).lineLimit(3...6)
                    Toggle("Active", isOn: $isActive)
                }
                if !isNew {
                    Section {
                        NavigationLink("Module Order (drag to reorder)") {
                            LMSCourseModuleOrderView(courseId: courseId, courseTitle: title)
                        }
                        NavigationLink("Quiz Order (drag to reorder)") {
                            LMSCourseQuizOrderView(courseId: courseId, courseTitle: title)
                        }
                    }
                }
                if let error {
                    Section { Text(error).foregroundColor(.mdzDanger).font(.caption) }
                }
            }
        }
        .navigationTitle(isNew ? "New Course" : "Edit Course")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .disabled(isSaving)
        .onAppear {
            if let e = existing {
                slug = e.slug
                title = e.title
                descriptionText = e.description ?? ""
                isActive = e.is_active == 1
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(slug.isEmpty || title.isEmpty || isSaving)
            }
        }
    }

    private func save() async {
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            if isNew {
                _ = try await LMSEditService.createCourse(slug: slug, title: title, description: descriptionText, isActive: isActive)
            } else {
                try await LMSEditService.updateCourse(id: courseId, slug: slug, title: title, description: descriptionText, isActive: isActive)
            }
            onSaved?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Course Module Order (drag-and-drop)
struct LMSCourseModuleOrderView: View {
    let courseId: Int
    let courseTitle: String
    @StateObject private var vm = LMSCourseModuleOrderViewModel()

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.modules.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted)
                        Button("Retry") { Task { await vm.load(courseId: courseId) } }.foregroundColor(.mdzAmber)
                    }
                } else if vm.modules.isEmpty {
                    Text("No modules in this course.\nAdd modules via the Modules list and link them to this course.")
                        .font(.subheadline).foregroundColor(.mdzMuted).multilineTextAlignment(.center).padding()
                } else {
                    List {
                        ForEach(vm.modules) { m in
                            HStack {
                                Image(systemName: "line.3.horizontal").foregroundColor(.mdzMuted)
                                Text(m.title ?? "Module").foregroundColor(.mdzText)
                            }
                            .listRowBackground(Color.mdzCard)
                        }
                        .onMove(perform: vm.move)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Module Order")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .task { await vm.load(courseId: courseId) }
        .refreshable { await vm.load(courseId: courseId) }
    }
}

@MainActor
final class LMSCourseModuleOrderViewModel: ObservableObject {
    @Published var modules: [LMSEditCourseModule] = []
    @Published var isLoading = false
    @Published var error: String?
    private var courseIdLoaded = 0

    func load(courseId: Int) async {
        guard courseId > 0 else { return }
        isLoading = true
        error = nil
        courseIdLoaded = courseId
        defer { isLoading = false }
        do {
            let res = try await LMSEditService.fetchCourseDetail(id: courseId)
            modules = res.linked_modules ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }

    func move(from source: IndexSet, to dest: Int) {
        modules.move(fromOffsets: source, toOffset: dest)
        Task {
            let ids = modules.compactMap { $0.id }
            do {
                try await LMSEditService.reorderCourseModules(courseId: courseIdLoaded, moduleIds: ids)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// Make LMSEditCourseModule Identifiable for ForEach
extension LMSEditCourseModule: Identifiable {}

// MARK: - Course Quiz Order (drag-and-drop)
struct LMSCourseQuizOrderView: View {
    let courseId: Int
    let courseTitle: String
    @StateObject private var vm = LMSCourseQuizOrderViewModel()

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.quizzes.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted)
                        Button("Retry") { Task { await vm.load(courseId: courseId) } }.foregroundColor(.mdzAmber)
                    }
                } else if vm.quizzes.isEmpty {
                    Text("No quizzes assigned to this course.\nAssign quizzes via the web platform.")
                        .font(.subheadline).foregroundColor(.mdzMuted).multilineTextAlignment(.center).padding()
                } else {
                    List {
                        ForEach(vm.quizzes) { q in
                            HStack {
                                Image(systemName: "line.3.horizontal").foregroundColor(.mdzMuted)
                                Text(q.title ?? "Quiz").foregroundColor(.mdzText)
                            }
                            .listRowBackground(Color.mdzCard)
                        }
                        .onMove(perform: vm.move)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Quiz Order")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .task { await vm.load(courseId: courseId) }
        .refreshable { await vm.load(courseId: courseId) }
    }
}

@MainActor
final class LMSCourseQuizOrderViewModel: ObservableObject {
    @Published var quizzes: [LMSEditCourseQuiz] = []
    @Published var isLoading = false
    @Published var error: String?
    private var courseIdLoaded = 0

    func load(courseId: Int) async {
        guard courseId > 0 else { return }
        isLoading = true
        error = nil
        courseIdLoaded = courseId
        defer { isLoading = false }
        do {
            quizzes = try await LMSEditService.fetchCourseQuizzes(courseId: courseId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func move(from source: IndexSet, to dest: Int) {
        quizzes.move(fromOffsets: source, toOffset: dest)
        Task {
            let ids = quizzes.map { $0.id }
            do {
                try await LMSEditService.reorderCourseQuizzes(courseId: courseIdLoaded, quizIds: ids)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - ViewModels

@MainActor
final class LMSCoursesEditViewModel: ObservableObject {
    @Published var courses: [LMSEditCourse] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let list = try await LMSEditService.fetchCourses()
            courses = list.sorted { $0.is_active > $1.is_active }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(id: Int) async {
        do {
            try await LMSEditService.deleteCourse(id: id)
            courses.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Modules List (simplified)

struct LMSModulesListView: View {
    @StateObject private var vm = LMSModulesEditViewModel()
    @State private var showAdd = false

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.modules.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted)
                        Button("Retry") { Task { await vm.load() } }.foregroundColor(.mdzAmber)
                    }
                } else {
                    List {
                        ForEach(vm.modules) { m in
                            NavigationLink(destination: LMSModuleEditView(moduleId: m.id, existing: m)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.title).font(.headline).foregroundColor(.mdzText)
                                    Text("Sort: \(m.sort_order)").font(.caption).foregroundColor(.mdzMuted)
                                }
                            }
                            .listRowBackground(Color.mdzCard)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { Task { await vm.delete(id: m.id) } } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Modules")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                LMSModuleEditView(moduleId: 0, existing: nil, onSaved: {
                    showAdd = false
                    Task { await vm.load() }
                })
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAdd = false } } }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

struct LMSModuleEditView: View {
    let moduleId: Int
    let existing: LMSEditModule?
    var onSaved: (() -> Void)?

    @State private var title = ""
    @State private var sortOrder = 0
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { moduleId == 0 }

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Form {
                Section("Module") {
                    TextField("Title", text: $title)
                    TextField("Sort Order", value: $sortOrder, format: .number).keyboardType(.numberPad)
                }
                if !isNew {
                    Section {
                        NavigationLink("Lesson Order (drag to reorder)") {
                            LMSModuleLessonOrderView(moduleId: moduleId, moduleTitle: title)
                        }
                    }
                }
                if let error { Section { Text(error).foregroundColor(.mdzDanger).font(.caption) } }
            }
        }
        .navigationTitle(isNew ? "New Module" : "Edit Module")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .disabled(isSaving)
        .onAppear {
            if let e = existing { title = e.title; sortOrder = e.sort_order }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }.disabled(title.isEmpty || isSaving)
            }
        }
    }

    private func save() async {
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            if isNew { _ = try await LMSEditService.createModule(title: title, sortOrder: sortOrder) }
            else { try await LMSEditService.updateModule(id: moduleId, title: title, sortOrder: sortOrder) }
            onSaved?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
final class LMSModulesEditViewModel: ObservableObject {
    @Published var modules: [LMSEditModule] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do { modules = try await LMSEditService.fetchModules() }
        catch { self.error = error.localizedDescription }
    }

    func delete(id: Int) async {
        do {
            try await LMSEditService.deleteModule(id: id)
            modules.removeAll { $0.id == id }
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Module Lesson Order (drag-and-drop)
struct LMSModuleLessonOrderView: View {
    let moduleId: Int
    let moduleTitle: String
    @StateObject private var vm = LMSModuleLessonOrderViewModel()

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.lessons.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted)
                        Button("Retry") { Task { await vm.load(moduleId: moduleId) } }.foregroundColor(.mdzAmber)
                    }
                } else if vm.lessons.isEmpty {
                    Text("No lessons in this module.\nAssign lessons to this module from the Lessons list.")
                        .font(.subheadline).foregroundColor(.mdzMuted).multilineTextAlignment(.center).padding()
                } else {
                    List {
                        ForEach(vm.lessons) { l in
                            HStack {
                                Image(systemName: "line.3.horizontal").foregroundColor(.mdzMuted)
                                Text(l.title).foregroundColor(.mdzText)
                            }
                            .listRowBackground(Color.mdzCard)
                        }
                        .onMove(perform: vm.move)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Lesson Order")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .task { await vm.load(moduleId: moduleId) }
        .refreshable { await vm.load(moduleId: moduleId) }
    }
}

@MainActor
final class LMSModuleLessonOrderViewModel: ObservableObject {
    @Published var lessons: [LMSEditLesson] = []
    @Published var isLoading = false
    @Published var error: String?
    private var moduleIdLoaded = 0

    func load(moduleId: Int) async {
        guard moduleId > 0 else { return }
        isLoading = true
        error = nil
        moduleIdLoaded = moduleId
        defer { isLoading = false }
        do {
            lessons = try await LMSEditService.fetchLessons(moduleId: moduleId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func move(from source: IndexSet, to dest: Int) {
        lessons.move(fromOffsets: source, toOffset: dest)
        Task {
            let ids = lessons.map { $0.id }
            do {
                try await LMSEditService.reorderModuleLessons(moduleId: moduleIdLoaded, lessonIds: ids)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Lessons List (simplified)

struct LMSLessonsListView: View {
    @StateObject private var vm = LMSLessonsEditViewModel()

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.lessons.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted)
                        Button("Retry") { Task { await vm.load() } }.foregroundColor(.mdzAmber)
                    }
                } else {
                    List {
                        ForEach(vm.lessons) { l in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.title).font(.headline).foregroundColor(.mdzText)
                                HStack(spacing: 6) {
                                    if let ct = l.course_title, !ct.isEmpty {
                                        Text(ct).font(.caption).foregroundColor(.mdzMuted)
                                    }
                                    if let mt = l.module_title, !mt.isEmpty {
                                        Text("•").foregroundColor(.mdzMuted)
                                        Text(mt).font(.caption).foregroundColor(.mdzMuted)
                                    }
                                }
                            }
                            .listRowBackground(Color.mdzCard)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Lessons")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

@MainActor
final class LMSLessonsEditViewModel: ObservableObject {
    @Published var lessons: [LMSEditLesson] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do { lessons = try await LMSEditService.fetchLessons() }
        catch { self.error = error.localizedDescription }
    }
}

// MARK: - Quizzes List (simplified)

struct LMSQuizzesListView: View {
    @StateObject private var vm = LMSQuizzesEditViewModel()

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.quizzes.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted)
                        Button("Retry") { Task { await vm.load() } }.foregroundColor(.mdzAmber)
                    }
                } else {
                    List {
                        ForEach(vm.quizzes) { q in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.title).font(.headline).foregroundColor(.mdzText)
                                if let pct = q.pass_percentage {
                                    Text("Pass: \(Int(pct))%").font(.caption).foregroundColor(.mdzMuted)
                                }
                            }
                            .listRowBackground(Color.mdzCard)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Quizzes")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

@MainActor
final class LMSQuizzesEditViewModel: ObservableObject {
    @Published var quizzes: [LMSEditQuiz] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do { quizzes = try await LMSEditService.fetchQuizzes() }
        catch { self.error = error.localizedDescription }
    }
}

// MARK: - Question Bank

struct LMSQuestionBankView: View {
    @StateObject private var vm = LMSQuestionBankEditViewModel()

    var body: some View {
        ZStack {
            Color.mdzBackground.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.questions.isEmpty {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .mdzAmber))
                } else if let err = vm.error {
                    VStack(spacing: 12) {
                        Text(err).font(.subheadline).foregroundColor(.mdzMuted)
                        Button("Retry") { Task { await vm.load() } }.foregroundColor(.mdzAmber)
                    }
                } else {
                    List {
                        ForEach(vm.questions) { q in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.text).font(.subheadline).foregroundColor(.mdzText)
                                HStack(spacing: 6) {
                                    if let t = q.type, !t.isEmpty {
                                        Text(t).font(.caption2).foregroundColor(.mdzMuted)
                                    }
                                    if let c = q.categories, !c.isEmpty {
                                        Text("•").foregroundColor(.mdzMuted)
                                        Text(c).font(.caption2).foregroundColor(.mdzMuted).lineLimit(1)
                                    }
                                }
                            }
                            .listRowBackground(Color.mdzCard)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Question Bank")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.mdzNavyMid, for: .navigationBar)
        .toolbarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if !vm.questions.isEmpty {
                Text("Create and edit questions on the web.")
                    .font(.caption).foregroundColor(.mdzMuted).padding(8)
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

@MainActor
final class LMSQuestionBankEditViewModel: ObservableObject {
    @Published var questions: [LMSEditQuestion] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do { questions = try await LMSEditService.fetchQuestions() }
        catch { self.error = error.localizedDescription }
    }
}
