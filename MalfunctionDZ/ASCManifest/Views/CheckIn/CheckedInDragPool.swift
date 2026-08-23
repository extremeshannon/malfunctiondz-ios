import SwiftUI

struct CheckedInDragPool: View {
    @EnvironmentObject private var store: ManifestStore
    var compact: Bool = false

    private var poolPeople: [CheckInPoolPerson] {
        if let pools = store.checkInPools {
            return pools.staffList + pools.jumpersList + pools.studentsList + pools.tandemList
        }
        return fallbackPeople
    }

    private var fallbackPeople: [CheckInPoolPerson] {
        let users = store.checkedIn.map { user in
            CheckInPoolPerson(
                record_id: user.user_id,
                user_id: user.user_id,
                display_name: user.resolvedName,
                first_name: user.first_name,
                last_name: user.last_name,
                username: user.username,
                roles: user.roles,
                weight_lb: user.weight_lb,
                pay_state: user.pay_state,
                pay_label: user.pay_label,
                next_jump_label: user.next_jump_label,
                checked_in_at: user.checked_in_at
            )
        }
        let tandem = store.checkedInTandem.map { student in
            CheckInPoolPerson(
                record_id: student.tandemID,
                tandem_student_id: student.tandemID,
                display_name: student.resolvedName,
                first_name: student.first_name,
                last_name: student.last_name,
                email: student.email,
                kind: "tandem",
                weight_lb: student.weight_lb,
                pay_state: student.pay_state,
                pay_label: student.pay_label,
                pay_tone: student.pay_tone,
                due_cents: student.due_cents,
                checked_in_at: student.checked_in_at
            )
        }
        return users + tandem
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(compact ? "Checked in — hold, then drop on a load" : "Hold a name, then drop it on a load card")
                .font(.caption)
                .foregroundStyle(NightOps.textMuted)
            if poolPeople.isEmpty {
                Text("Nobody checked in yet.")
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
            } else {
                ForEach(poolPeople) { person in
                    CheckInPersonRow(person: person, compact: compact)
                        .draggable(person.boardPerson)
                }
            }
        }
    }
}
