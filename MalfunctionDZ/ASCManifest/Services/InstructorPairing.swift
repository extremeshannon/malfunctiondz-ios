import Foundation

/// Mirrors ``instructor_pairing_service.pairing_spec`` on the platform API.
struct InstructorPairingSpec: Equatable {
    let mode: String
    let needs: Bool
    let needsSecond: Bool
    let roles: [String]
    let roles2: [String]
    let label: String
    let label2: String
    let requiredMessage: String
    let requiredMessage2: String

    func rolesMatch(_ userRoles: [String]?, allowed: [String]) -> Bool {
        let have = Set((userRoles ?? []).map { $0.lowercased().replacingOccurrences(of: " ", with: "_") })
        let need = Set(allowed.map { $0.lowercased().replacingOccurrences(of: " ", with: "_") })
        return !have.isDisjoint(with: need)
    }

    func matchesPrimary(_ userRoles: [String]?) -> Bool { rolesMatch(userRoles, allowed: roles) }
    func matchesSecond(_ userRoles: [String]?) -> Bool {
        let allowed = roles2.isEmpty ? roles : roles2
        return rolesMatch(userRoles, allowed: allowed)
    }
}

enum InstructorPairing {
    static func spec(for jumpType: String?) -> InstructorPairingSpec {
        let n = normalizeJumpType(jumpType)
        let mode = instructorMode(for: n)

        if ["tandem", "tan1", "tan2", "tan3"].contains(n) || mode == "tandem" {
            return InstructorPairingSpec(
                mode: "tandem",
                needs: true,
                needsSecond: false,
                roles: ["tandem_instructor"],
                roles2: [],
                label: "Tandem Instructor",
                label2: "",
                requiredMessage: "Tandem Instructor is required.",
                requiredMessage2: ""
            )
        }
        if n == "iad" || mode == "iad" {
            return InstructorPairingSpec(
                mode: "iad",
                needs: true,
                needsSecond: false,
                roles: ["iad_instructor"],
                roles2: [],
                label: "IAD instructor",
                label2: "",
                requiredMessage: "An IAD instructor is required.",
                requiredMessage2: ""
            )
        }
        if n == "sl" || mode == "sl" {
            return InstructorPairingSpec(
                mode: "sl",
                needs: true,
                needsSecond: false,
                roles: ["sl_instructor"],
                roles2: [],
                label: "SL instructor",
                label2: "",
                requiredMessage: "A static line instructor is required.",
                requiredMessage2: ""
            )
        }
        if n == "coach" || mode == "coach" {
            return InstructorPairingSpec(
                mode: "coach",
                needs: true,
                needsSecond: false,
                roles: ["coach", "aff_instructor"],
                roles2: [],
                label: "Coach",
                label2: "",
                requiredMessage: "A coach-capable instructor is required.",
                requiredMessage2: ""
            )
        }
        if mode == "2_instructor" || ["aff", "student"].contains(n) {
            return InstructorPairingSpec(
                mode: "2_instructor",
                needs: true,
                needsSecond: true,
                roles: ["aff_instructor"],
                roles2: ["aff_instructor"],
                label: "Instr. 1",
                label2: "Instr. 2",
                requiredMessage: "AFF Instructor 1 is required.",
                requiredMessage2: "AFF Instructor 2 is required."
            )
        }
        if mode == "1_instructor" {
            return InstructorPairingSpec(
                mode: "1_instructor",
                needs: true,
                needsSecond: false,
                roles: ["aff_instructor"],
                roles2: [],
                label: "Instr. 1",
                label2: "",
                requiredMessage: "An AFF instructor is required.",
                requiredMessage2: ""
            )
        }
        return InstructorPairingSpec(
            mode: "",
            needs: false,
            needsSecond: false,
            roles: [],
            roles2: [],
            label: "Instructor",
            label2: "",
            requiredMessage: "",
            requiredMessage2: ""
        )
    }

    private static func normalizeJumpType(_ jumpType: String?) -> String {
        var n = (jumpType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if n == "static_line" || n == "staticline" { n = "sl" }
        return n
    }

    private static func instructorMode(for jumpType: String) -> String {
        if ["tandem", "tan1", "tan2", "tan3"].contains(jumpType) { return "tandem" }
        if jumpType == "iad" { return "iad" }
        if jumpType == "sl" { return "sl" }
        if jumpType == "coach" { return "coach" }
        if let level = aspLevel(from: jumpType) {
            if level <= 3 { return "2_instructor" }
            if level <= 7 { return "1_instructor" }
            return "coach"
        }
        if ["aff", "student"].contains(jumpType) { return "2_instructor" }
        return ""
    }

    private static func aspLevel(from jumpType: String) -> Int? {
        guard jumpType.hasPrefix("asp"), jumpType.count > 3 else { return nil }
        return Int(jumpType.dropFirst(3))
    }

    static func needsVideo(for jumpType: String?) -> Bool {
        let n = normalizeJumpType(jumpType)
        return ["tandem", "tan1", "tan2", "tan3"].contains(n)
    }
}

struct PendingStudentAdd: Identifiable {
    let id: String
    let loadID: Int
    let person: BoardPerson
    let jumpType: String
    let jumpLabel: String
    let pairing: InstructorPairingSpec

    init(loadID: Int, person: BoardPerson, jumpType: String, jumpLabel: String, pairing: InstructorPairingSpec) {
        let subjectKey = person.isTandem ? "t\(person.tandemStudentID ?? person.id)" : "u\(person.id)"
        self.id = "\(loadID)-\(subjectKey)-\(jumpType)"
        self.loadID = loadID
        self.person = person
        self.jumpType = jumpType
        self.jumpLabel = jumpLabel
        self.pairing = pairing
    }
}
