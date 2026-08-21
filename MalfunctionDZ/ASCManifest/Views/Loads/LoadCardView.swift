import SwiftUI

struct LoadCardView: View {
    @EnvironmentObject private var store: ManifestStore

    let load: ManifestLoad
    let loadNumber: Int
    let onTapHeader: () -> Void
    let onAdvance: () -> Void
    let onAssignPilot: () -> Void
    let onAddJumper: () -> Void

    @State private var jumperDrop = false
    @State private var pilotDrop = false

    private var jumperSlots: [ManifestSlot] {
        (load.slots ?? []).filter { !$0.isPilotSlot }
    }

    private var maxSeats: Int {
        load.max_pax_per_load ?? load.total ?? 0
    }

    private var filledSeats: Int {
        load.filled ?? 0
    }

    private var isFull: Bool {
        maxSeats > 0 && filledSeats >= maxSeats
    }

    private var headerNavy: Color { Color(red: 0.102, green: 0.141, blue: 0.200) }
    private var bodyWhite: Color { Color.white }
    private var pilotBlue: Color { Color(red: 0.82, green: 0.90, blue: 0.97) }
    private var chipGray: Color { Color(red: 0.91, green: 0.93, blue: 0.95) }
    private var ink: Color { Color(red: 0.067, green: 0.094, blue: 0.153) }
    private var muted: Color { Color(red: 0.29, green: 0.33, blue: 0.39) }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NightOps.gradientBar)
                .frame(height: 6)
            header
            cardBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(bodyWhite)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(jumperDrop || load.statusKey == .called ? Color.red.opacity(0.85) : Color.white.opacity(0.12), lineWidth: jumperDrop || load.statusKey == .called ? 2 : 1)
        )
        .opacity(load.statusKey == .completed ? 0.65 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(loadNumber)")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(NightOps.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Button(action: onAdvance) {
                Text(load.statusKey.label.uppercased())
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .foregroundStyle(headerNavy)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(load.statusKey.next == nil)

            VStack(alignment: .trailing, spacing: 2) {
                Text(load.aircraft ?? "Aircraft TBD")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                Text(load.slotCountLabel)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.8))
                if let notes = load.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(notes)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
                Button {
                    Task { await store.deleteLoad(load) }
                } label: {
                    Text("×")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
            .frame(minWidth: 72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(headerNavy)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapHeader)
    }

    private var cardBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pilotRow
                slotsRow
            }
            .padding(.bottom, 12)
        }
        .background(bodyWhite)
    }

    private var pilotRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("PILOT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(red: 0.15, green: 0.35, blue: 0.65))
                .frame(width: 52, alignment: .leading)
                .padding(.top, 10)

            HStack(spacing: 8) {
                if let pid = load.pilot_user_id {
                    personChip(
                        label: "PILOT",
                        name: store.pilotName(for: load) ?? "PIC #\(pid)",
                        weight: nil,
                        pay: store.pilotPayLabel(for: load).isEmpty ? "($20.00)" : store.pilotPayLabel(for: load),
                        payPaid: false,
                        gear: nil,
                        onRemove: onAssignPilot
                    )
                } else {
                    emptyPlus(title: "Assign PIC", highlighted: pilotDrop, action: onAssignPilot)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 10)
        .background(pilotBlue)
        .dropDestination(for: BoardPerson.self) { items, _ in
            guard let person = items.first else { return false }
            Task { await store.dropOnLoad(person, loadID: load.id, asPilot: true) }
            return true
        } isTargeted: { pilotDrop = $0 }
    }

    private var slotsRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SLOTS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(muted)
                Text("SOLO / FUN")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(muted)
            }
            .frame(width: 72, alignment: .leading)
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(jumperSlots) { slot in
                    if slot.isPairedJump {
                        groupedSlotRow(slot)
                    } else {
                        personChip(
                            label: (slot.jump_type ?? "JUMPER").uppercased(),
                            name: slot.name,
                            weight: slot.weightLabel,
                            pay: slot.moneyLabel,
                            payPaid: slot.moneyIsPaidTone,
                            gear: slot.gearLabel,
                            onRemove: {
                                Task { await store.removeSlot(slot, loadID: load.id) }
                            }
                        )
                    }
                }
                if !isFull {
                    emptyPlus(
                        title: jumperDrop ? "Drop jumper here" : "Add jumper",
                        highlighted: jumperDrop,
                        action: onAddJumper
                    )
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .background(bodyWhite)
        .dropDestination(for: BoardPerson.self) { items, _ in
            guard !isFull else { return false }
            guard let person = items.first else { return false }
            Task { await store.dropOnLoad(person, loadID: load.id, asPilot: false) }
            return true
        } isTargeted: { jumperDrop = $0 }
    }

    private func groupedSlotRow(_ slot: ManifestSlot) -> some View {
        let boxes = slot.displayBoxes { store.staffName(for: $0) }
        return ZStack(alignment: .topTrailing) {
            HStack(spacing: 6) {
                ForEach(boxes) { box in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(box.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(box.warn ? Color.red : muted)
                        Text(box.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if let weight = box.weight {
                            Text(weight)
                                .font(.system(size: 9))
                                .foregroundStyle(muted)
                        }
                        if let pay = box.pay, !pay.isEmpty {
                            Text(pay)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Color(red: 0.85, green: 0.18, blue: 0.18))
                        }
                        if let gear = box.gear, !gear.isEmpty {
                            Text(gear)
                                .font(.system(size: 8))
                                .foregroundStyle(muted)
                                .lineLimit(1)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(box.warn ? Color.red.opacity(0.08) : chipGray)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(6)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )

            Button("×") {
                Task { await store.removeSlot(slot, loadID: load.id) }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(muted)
            .padding(4)
        }
    }

    private func personChip(
        label: String,
        name: String,
        weight: String?,
        pay: String,
        payPaid: Bool,
        gear: String?,
        onRemove: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(muted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    if let weight {
                        Text(weight)
                            .font(.caption2)
                            .foregroundStyle(muted)
                    }
                }
                Text(pay)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(payPaid ? Color(red: 0.12, green: 0.62, blue: 0.29) : Color(red: 0.85, green: 0.18, blue: 0.18))
                if let gear, !gear.isEmpty {
                    Text(gear)
                        .font(.system(size: 9))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chipGray)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button("×", action: onRemove)
                .font(.caption.weight(.bold))
                .foregroundStyle(muted)
                .padding(4)
        }
    }

    private func emptyPlus(title: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("+")
                .font(.title3.weight(.bold))
                .foregroundStyle(highlighted ? NightOps.accent : muted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(highlighted ? NightOps.accent : Color.gray.opacity(0.45))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
