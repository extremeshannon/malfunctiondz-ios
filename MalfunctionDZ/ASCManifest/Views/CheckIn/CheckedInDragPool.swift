import SwiftUI

struct CheckedInDragPool: View {
    @EnvironmentObject private var store: ManifestStore
    var compact: Bool = false

    private var hasAnyone: Bool {
        !store.checkedIn.isEmpty || !store.checkedInTandem.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(compact ? "Checked in — hold, then drop on a load" : "Hold a name, then drop it on a load card")
                .font(.caption)
                .foregroundStyle(NightOps.textMuted)
            if !hasAnyone {
                Text("Nobody checked in yet.")
                    .font(.caption)
                    .foregroundStyle(NightOps.textMuted)
            } else {
                ForEach(store.checkedIn) { user in
                    dragRow(BoardPerson.user(id: user.user_id, name: user.resolvedName))
                }
                ForEach(store.checkedInTandem) { student in
                    dragRow(BoardPerson.tandem(id: student.tandemID, name: student.resolvedName))
                }
            }
        }
    }

    @ViewBuilder
    private func dragRow(_ person: BoardPerson) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(NightOps.textMuted)
            Text(person.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            if person.isTandem {
                Text("Tandem")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.25))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .draggable(person)
    }
}
