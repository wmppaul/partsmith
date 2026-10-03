import CoreGraphics
import Foundation

/// Tracks the printed labels used to build the editable instrument list. Names
/// are not identities: two separate staves may both be printed as "Violin".
struct ScoreInstrumentPickList {
    enum Outcome: Equatable {
        case added(partID: String, name: String)
        case updated(partID: String, name: String)
        case existing(partID: String, name: String)
    }

    private struct PickedLabel {
        var partID: String
        var pageIndex: Int
        var bounds: CGRect
        var recognizedName: String
        var assignedName: String
        var assignedStaffCount: Int
    }

    private var labels: [PickedLabel] = []

    mutating func reset() { labels.removeAll() }

    /// Repeated reads of one source label update its existing row. Field values
    /// changed by the user stay untouched, including names that collide with OCR.
    mutating func apply(_ pick: ScoreInstrumentNamePick, to parts: inout [ScorePartDefinition]) -> Outcome? {
        let name = pick.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, pick.pageIndex >= 0, pick.suggestedStaffCount > 0,
              [pick.bounds.minX, pick.bounds.minY, pick.bounds.width, pick.bounds.height].allSatisfy(\.isFinite),
              pick.bounds.minX >= 0, pick.bounds.minY >= 0,
              pick.bounds.maxX <= 1, pick.bounds.maxY <= 1,
              pick.bounds.width > 0, pick.bounds.height > 0 else { return nil }

        let currentPartIDs = Set(parts.map(\.id))
        labels.removeAll { !currentPartIDs.contains($0.partID) }
        let existing = labels.indices.compactMap { index -> (Int, CGFloat)? in
            guard labels[index].pageIndex == pick.pageIndex else { return nil }
            let intersection = labels[index].bounds.intersection(pick.bounds)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return nil }
            let smallerArea = min(labels[index].bounds.width * labels[index].bounds.height,
                                  pick.bounds.width * pick.bounds.height)
            let overlap = intersection.width * intersection.height / smallerArea
            return overlap >= 0.5 ? (index, overlap) : nil
        }.max { $0.1 < $1.1 }?.0

        if let labelIndex = existing, let partIndex = parts.firstIndex(where: { $0.id == labels[labelIndex].partID }) {
            let before = parts[partIndex]
            if before.name == labels[labelIndex].assignedName,
               Self.normalized(name) != Self.normalized(labels[labelIndex].recognizedName) {
                let assigned = Self.uniqueName(name, among: parts, excluding: before.id)
                parts[partIndex].name = assigned
                labels[labelIndex].assignedName = assigned
            }
            if before.staffCount == labels[labelIndex].assignedStaffCount {
                parts[partIndex].staffCount = pick.suggestedStaffCount
                labels[labelIndex].assignedStaffCount = pick.suggestedStaffCount
            }
            labels[labelIndex].bounds = pick.bounds
            labels[labelIndex].recognizedName = name
            let updated = parts[partIndex]
            return updated == before ? .existing(partID: updated.id, name: updated.name)
                : .updated(partID: updated.id, name: updated.name)
        }

        let part = ScorePartDefinition(id: UUID().uuidString,
            name: Self.uniqueName(name, among: parts), staffCount: pick.suggestedStaffCount)
        parts.append(part)
        labels.append(PickedLabel(partID: part.id, pageIndex: pick.pageIndex, bounds: pick.bounds,
                                  recognizedName: name, assignedName: part.name, assignedStaffCount: part.staffCount))
        return .added(partID: part.id, name: part.name)
    }

    private static func uniqueName(_ name: String, among parts: [ScorePartDefinition], excluding partID: String? = nil) -> String {
        let usedNames = Set(parts.filter { $0.id != partID }.map { normalized($0.name) })
        guard usedNames.contains(normalized(name)) else { return name }
        var number = 2
        while usedNames.contains(normalized("\(name) \(number)")) { number += 1 }
        return "\(name) \(number)"
    }

    private static func normalized(_ name: String) -> String {
        name.filter { !$0.isWhitespace }.lowercased()
    }
}
