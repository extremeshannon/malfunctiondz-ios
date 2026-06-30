// A-License Progress tab — USPA ISP sign-offs grouped by category A–H.
import SwiftUI
import MalfunctionDZCore

struct ALicenseProgressView: View {
    @StateObject private var vm = ALicenseProgressViewModel()
    @Environment(\.mdzColors) private var colors
    @State private var expandedKeys: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()
                if vm.isLoading && vm.blocks.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.amber))
                        .scaleEffect(1.3)
                } else if let err = vm.error, vm.blocks.isEmpty {
                    emptyState(message: err)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            summaryCard
                            ForEach(vm.blocks) { block in
                                categoryCard(block)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("A-License Progress")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let stats = vm.categoryProgress
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("USPA ISP PROGRESSION")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(colors.amber)
                        .tracking(2)
                    if !vm.studentName.isEmpty {
                        Text(vm.studentName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(colors.text)
                    }
                    Text("Categories A–H sign-offs for your A-License")
                        .font(.subheadline)
                        .foregroundColor(colors.muted)
                }
                Spacer()
                if let stats, stats.total > 0 {
                    progressRing(done: stats.done, total: stats.total, complete: stats.complete)
                }
            }
            if let stats, stats.total > 0 {
                ProgressView(value: Double(stats.done), total: Double(stats.total))
                    .tint(stats.complete ? colors.green : colors.accent)
                HStack {
                    Text("\(stats.done) of \(stats.total) sign-offs")
                        .font(.caption)
                        .foregroundColor(colors.muted)
                    Spacer()
                    if stats.complete {
                        Label("Complete", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(colors.green)
                    } else if let step = stats.currentStep, step != "Complete" {
                        Text("Next: \(shortStepLabel(step))")
                            .font(.caption)
                            .foregroundColor(colors.amber)
                            .lineLimit(1)
                    }
                }
            }
            if !vm.updatedAt.isEmpty {
                Text("Updated \(formatUpdated(vm.updatedAt))")
                    .font(.caption2)
                    .foregroundColor(colors.muted.opacity(0.8))
            }
        }
        .padding(16)
        .background(colors.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colors.border.opacity(0.35), lineWidth: 1)
        )
    }

    private func progressRing(done: Int, total: Int, complete: Bool) -> some View {
        let pct = total > 0 ? Double(done) / Double(total) : 0
        return ZStack {
            Circle()
                .stroke(colors.border.opacity(0.4), lineWidth: 5)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(complete ? colors.green : colors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(pct * 100))%")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(colors.text)
        }
        .frame(width: 52, height: 52)
    }

    // MARK: - Category cards

    private func categoryCard(_ block: ProgressionBlock) -> some View {
        let isExpanded = expandedKeys.contains(block.key)
        let stats = block.progress
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedKeys.remove(block.key) }
                    else { expandedKeys.insert(block.key) }
                }
            } label: {
                HStack(spacing: 12) {
                    categoryBadge(block.key, complete: stats.complete)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(block.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(colors.text)
                            .multilineTextAlignment(.leading)
                        Text("\(stats.done)/\(stats.total) sign-offs")
                            .font(.caption)
                            .foregroundColor(colors.muted)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(colors.muted)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(colors.border.opacity(0.3))
                VStack(alignment: .leading, spacing: 16) {
                    if let note = block.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(colors.muted)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                    }
                    ForEach(block.sections) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.bottom, 14)
            }
        }
        .background(colors.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(stats.complete ? colors.green.opacity(0.45) : colors.border.opacity(0.35), lineWidth: 1)
        )
    }

    private func categoryBadge(_ key: String, complete: Bool) -> some View {
        Text(key.uppercased())
            .font(.system(size: 14, weight: .black))
            .foregroundColor(complete ? .white : colors.text)
            .frame(width: 36, height: 36)
            .background(complete ? colors.green : colors.accent.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sectionBlock(_ section: ProgressionSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colors.amber)
                .tracking(1.2)
                .padding(.horizontal, 14)
            if let note = section.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(colors.muted)
                    .padding(.horizontal, 14)
            }
            if let fields = section.fields, !fields.isEmpty {
                ForEach(fields) { field in
                    fieldRow(field)
                }
            }
            if let rows = section.rows {
                ForEach(rows) { row in
                    signoffRow(row)
                }
            }
            if let qd = section.quizDate, !qd.isEmpty {
                HStack(spacing: 10) {
                    statusIcon(done: true)
                    Text("Category quiz — \(formatDate(qd))")
                        .font(.subheadline)
                        .foregroundColor(colors.text)
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private func signoffRow(_ row: ProgressionRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon(done: row.done)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.label)
                    .font(.subheadline)
                    .foregroundColor(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let checked = row.checked, !checked.isEmpty {
                    Text("Checked: \(checked.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(colors.muted)
                }
                HStack(spacing: 12) {
                    if let c = row.coach, !c.isEmpty {
                        let readSim = row.label.lowercased().contains("read sim")
                        initialsPill(label: readSim ? "Student" : "Coach", value: c)
                    }
                    if let i = row.instructor, !i.isEmpty, !row.label.lowercased().contains("read sim") {
                        initialsPill(label: "I", value: i)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }

    private func fieldRow(_ field: ProgressionField) -> some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon(done: field.done)
            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.subheadline)
                    .foregroundColor(colors.text)
                if let val = field.value?.displayText, !val.isEmpty {
                    let readSim = field.label.lowercased().contains("read sim")
                    Text(readSim ? val : (field.prefix == "I" ? "I \(val)" : val))
                        .font(.caption.weight(.medium))
                        .foregroundColor(colors.muted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private func statusIcon(done: Bool) -> some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18))
            .foregroundColor(done ? colors.green : colors.muted.opacity(0.5))
            .frame(width: 22)
    }

    private func initialsPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(colors.muted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(colors.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(colors.background.opacity(0.6))
                .cornerRadius(4)
        }
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(colors.muted)
            Text(message)
                .font(.subheadline)
                .foregroundColor(colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") { Task { await vm.load() } }
                .buttonStyle(.borderedProminent)
                .tint(colors.accent)
        }
    }

    // MARK: - Formatting

    private func shortStepLabel(_ step: String) -> String {
        if let range = step.range(of: " — ") {
            return String(step[range.upperBound...])
        }
        return step
    }

    private func formatDate(_ raw: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: String(raw.prefix(10))) else { return raw }
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    private func formatUpdated(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return f.localizedString(for: d, relativeTo: Date())
        }
        return raw
    }
}
