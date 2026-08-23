import SwiftUI

struct CheckInPayChip: View {
    let label: String
    var isDue: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
            if isDue {
                Text("due")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(NightOps.danger)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isDue ? NightOps.danger.opacity(0.18) : Color.white.opacity(0.12))
        .foregroundStyle(isDue ? NightOps.danger : .white.opacity(0.9))
        .clipShape(Capsule())
    }
}

struct CheckInPersonRow: View {
    let person: CheckInPoolPerson
    var showDragHandle: Bool = true
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(person.lineTitle)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let roles = person.roles, !roles.isEmpty, !compact {
                    HStack(spacing: 4) {
                        ForEach(roles.prefix(3), id: \.self) { role in
                            Text(role.replacingOccurrences(of: "_", with: " "))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .foregroundStyle(NightOps.textMuted)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            if let pay = person.pay_label?.trimmingCharacters(in: .whitespaces), !pay.isEmpty {
                CheckInPayChip(label: pay, isDue: person.payIsDue)
            }
            Text(person.weightLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(person.weightMissing ? Color.orange : NightOps.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 6 : 8)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var rowBackground: Color {
        switch (person.kind ?? "").lowercased() {
        case "jumper": Color.green.opacity(0.14)
        case "tandem": Color.teal.opacity(0.16)
        case "student": Color.purple.opacity(0.14)
        default: Color.white.opacity(0.12)
        }
    }
}
