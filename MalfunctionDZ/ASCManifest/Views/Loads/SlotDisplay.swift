import Foundation

struct SlotBox: Identifiable, Hashable {
    let id: String
    let label: String
    let name: String
    let warn: Bool
    var weight: String? = nil
    var pay: String? = nil
    var gear: String? = nil
}

extension ManifestSlot {
    /// Counts "jumper seats" (student + instructor seats + outside video seats) for capacity gating.
    /// Pilot does *not* count toward jumper seats.
    var jumperSeatCount: Int {
        if isPilotSlot { return 0 }

        // Mirrors `manifest_load_slots_service.jumper_seats_for_person`.
        // Base: the jumper/student seat always counts as 1.
        var n = 1

        let ti = tandem_instructor_user_id ?? 0
        let i2 = second_instructor_user_id ?? 0
        let vg = videographer_user_id ?? 0

        if ti > 0 { n += 1 }
        if i2 > 0 && i2 != ti { n += 1 }
        if vg > 0 && vg != ti && vg != i2 { n += 1 }

        return n
    }

    var isPairedJump: Bool {
        if tandem_student_id != nil { return true }
        if tandem_instructor_user_id != nil || second_instructor_user_id != nil { return true }
        return InstructorPairing.spec(for: jump_type ?? "").needs
    }

    var isHandCamVideo: Bool {
        guard let ti = tandem_instructor_user_id, let vg = videographer_user_id, ti > 0 else { return false }
        return ti == vg
    }

    var hasOutsideVideo: Bool {
        guard let vg = videographer_user_id, vg > 0 else { return false }
        return !isHandCamVideo
    }

    func displayBoxes(staffName: (Int?) -> String?) -> [SlotBox] {
        let jt = (jump_type ?? "").lowercased()
        let spec = InstructorPairing.spec(for: jt)
        let studentName = name
        let tiName = staffName(tandem_instructor_user_id) ?? "—"
        let ti2Name = staffName(second_instructor_user_id) ?? "—"
        let vgName = staffName(videographer_user_id) ?? "—"
        let sid = id

        if InstructorPairing.needsVideo(for: jt) || jt == "tandem" || jt.hasPrefix("tan") {
            return [
                SlotBox(id: "\(sid)-i", label: "I", name: tandem_instructor_user_id != nil ? tiName : "—", warn: tandem_instructor_user_id == nil),
                SlotBox(
                    id: "\(sid)-s",
                    label: "S",
                    name: studentName,
                    warn: false,
                    weight: weightLabel,
                    pay: moneyLabel,
                    gear: gearLabel
                ),
                SlotBox(
                    id: "\(sid)-v",
                    label: "Video",
                    name: isHandCamVideo ? "Hand Cam" : (hasOutsideVideo ? vgName : "—"),
                    warn: false
                ),
            ]
        }

        if spec.mode == "2_instructor" {
            return [
                SlotBox(id: "\(sid)-i1", label: "Instr. 1", name: tandem_instructor_user_id != nil ? tiName : "—", warn: tandem_instructor_user_id == nil),
                SlotBox(
                    id: "\(sid)-s",
                    label: "Student",
                    name: studentName,
                    warn: false,
                    weight: weightLabel,
                    pay: moneyLabel,
                    gear: gearLabel
                ),
                SlotBox(id: "\(sid)-i2", label: "Instr. 2", name: second_instructor_user_id != nil ? ti2Name : "—", warn: second_instructor_user_id == nil),
            ]
        }

        if spec.needs {
            let staffLabel: String = {
                switch spec.mode {
                case "coach": return "Coach"
                case "iad": return "IAD"
                case "sl": return "SL"
                default: return "Instr. 1"
                }
            }()
            return [
                SlotBox(id: "\(sid)-i", label: staffLabel, name: tandem_instructor_user_id != nil ? tiName : "—", warn: tandem_instructor_user_id == nil),
                SlotBox(
                    id: "\(sid)-s",
                    label: "Student",
                    name: studentName,
                    warn: false,
                    weight: weightLabel,
                    pay: moneyLabel,
                    gear: gearLabel
                ),
            ]
        }

        return [
            SlotBox(
                id: "\(sid)-j",
                label: (jump_type ?? "JUMPER").uppercased(),
                name: studentName,
                warn: false,
                weight: weightLabel,
                pay: moneyLabel,
                gear: gearLabel
            )
        ]
    }
}

enum VideoAssignment: Equatable {
    case none
    case handCam
    case outside(Int)

    var videographerUserID: Int? {
        switch self {
        case .none: nil
        case .handCam: nil // resolved to primary instructor at save time
        case .outside(let id): id
        }
    }
}
