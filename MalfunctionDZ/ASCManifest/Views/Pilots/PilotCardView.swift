import SwiftUI

struct PilotCardView: View {
    let pilot: ManifestPilotCard
    var onAssign: () -> Void
    var onRemoveAssignment: (ManifestPilotAssignment) -> Void

    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NightOps.textMuted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pilot.resolvedName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        pillRow
                    }
                    Spacer(minLength: 0)
                    if pilot.checked_in == true {
                        Text("Checked in")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(NightOps.success.opacity(0.2))
                            .foregroundStyle(NightOps.success)
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)

            if expanded {
                assignmentsSection
                docRowsSection
                Button(action: onAssign) {
                    Label("Assign to load", systemImage: "airplane")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(NightOps.accent.opacity(0.2))
                        .foregroundStyle(NightOps.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .nightOpsCard()
    }

    private var pillRow: some View {
        HStack(spacing: 6) {
            readinessPill
            if pilot.airworthy == true {
                statusPill("Airworthy", tone: "ok")
            } else {
                statusPill("Pending check", tone: "warn")
            }
            if pilot.ready_to_fly == true {
                statusPill("Ready to fly", tone: "ok")
            }
            if pilot.cleared_to_solo == true {
                statusPill("Cleared solo", tone: "ok")
            }
            if pilot.is_active != true {
                statusPill("Inactive", tone: "bad")
            }
        }
    }

    private var readinessPill: some View {
        statusPill(pilot.ready_label ?? "Not ready", tone: pilot.ready_tone ?? "missing")
    }

    private func statusPill(_ text: String, tone: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(toneColor(tone).opacity(0.22))
            .foregroundStyle(toneColor(tone))
            .clipShape(Capsule())
    }

    private func toneColor(_ tone: String) -> Color {
        switch tone.lowercased() {
        case "ok", "current": NightOps.success
        case "warn", "warning", "expiring_soon": NightOps.accent
        case "bad", "missing", "expired": NightOps.danger
        default: NightOps.textMuted
        }
    }

    @ViewBuilder
    private var assignmentsSection: some View {
        let items = pilot.assignments ?? []
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's loads")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NightOps.textMuted)
            if items.isEmpty {
                Text("Not assigned to a load yet.")
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
            } else {
                ForEach(items) { assignment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loadLabel(assignment))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(assignment.roleLabel)
                                .font(.caption2)
                                .foregroundStyle(NightOps.textMuted)
                        }
                        Spacer()
                        Button {
                            onRemoveAssignment(assignment)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(NightOps.danger)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 4)
    }

    private func loadLabel(_ assignment: ManifestPilotAssignment) -> String {
        let num = assignment.load_num.map { "Load \($0)" } ?? "Load #\(assignment.load_id)"
        let plane = (assignment.aircraft_label ?? "").trimmingCharacters(in: .whitespaces)
        if plane.isEmpty { return num }
        return "\(num) · \(plane)"
    }

    @ViewBuilder
    private var docRowsSection: some View {
        let rows = pilot.doc_rows ?? []
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Documents")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NightOps.textMuted)
                ForEach(rows.filter { $0.is_waiver != true }) { row in
                    HStack(alignment: .top, spacing: 8) {
                        Text(row.icon ?? "•")
                            .font(.caption)
                            .foregroundStyle(toneColor(row.tone ?? "missing"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label ?? row.doc_key ?? "Doc")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            if let status = row.status_text, !status.isEmpty {
                                Text(status)
                                    .font(.caption2)
                                    .foregroundStyle(NightOps.textMuted)
                            }
                        }
                        Spacer(minLength: 0)
                        if let expires = row.expires_text, !expires.isEmpty {
                            Text(expires)
                                .font(.caption2)
                                .foregroundStyle(NightOps.textMuted)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
