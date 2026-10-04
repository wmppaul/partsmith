import Foundation

/// A user's choice of one printed system. Reusing its instrument layout never
/// reuses its measure count: silent time must be established for each system.
struct ScoreSystemAssignmentChoice: Equatable, Identifiable {
    var pageIndex: Int
    var systemIndex: Int
    var candidateIDs: [Int]
    var presentPartIDs: Set<String>
    var startBarNumber: Int?
    var barCount: Int?
    var staffCounts: [String: Int] = [:]

    var id: String { "\(pageIndex):\(systemIndex)" }
}

enum ScoreSystemAssignmentBatch {
    enum ApplyError: LocalizedError {
        case emptySelection, unavailablePage, duplicateSystem, overlappingStaves, existingAssignment, outOfOrder, cancelled

        var errorDescription: String? {
            switch self {
            case .emptySelection: return "Choose at least one matching system."
            case .unavailablePage: return "A selected page is excluded or no longer available. Find matching systems again."
            case .duplicateSystem: return "Two selected layouts refer to the same system. Choose one layout for each system."
            case .overlappingStaves: return "The selected systems share staves. Check the system boundaries before assigning them."
            case .existingAssignment: return "A selected system already has an assignment. Find matching systems again to preserve your edits."
            case .outOfOrder: return "The selected system numbers do not follow the printed score order. Check their boundaries before assigning them."
            case .cancelled: return "Layout assignment stopped. Existing assignments were kept."
            }
        }
    }

    /// Validate the whole selection before returning any mutation. Existing
    /// assignments, explicit crop edits, copies and omitted-part counts survive.
    static func applying(_ choices: [ScoreSystemAssignmentChoice], to review: ScoreDetectionReview,
                         isCancelled: () -> Bool = { false }) throws -> ScoreDetectionReview {
        guard !isCancelled() else { throw ApplyError.cancelled }
        guard !choices.isEmpty else { throw ApplyError.emptySelection }
        guard Set(choices.map(\.id)).count == choices.count else { throw ApplyError.duplicateSystem }
        var usedByPage: [Int: Set<Int>] = [:]
        let pages = Dictionary(grouping: review.analyses, by: \.pageIndex)
        for choice in choices {
            guard !isCancelled() else { throw ApplyError.cancelled }
            guard pages[choice.pageIndex]?.count == 1,
                  review.excludedPageReasons[choice.pageIndex] == nil,
                  review.selectedPageIndices?.contains(choice.pageIndex) != false else { throw ApplyError.unavailablePage }
            let selected = Set(choice.candidateIDs)
            guard (usedByPage[choice.pageIndex] ?? []).isDisjoint(with: selected) else { throw ApplyError.overlappingStaves }
            usedByPage[choice.pageIndex, default: []].formUnion(selected)
            let corrections = review.overrides.filter { $0.pageIndex == choice.pageIndex }
            guard corrections.count <= 1 else { throw ApplyError.existingAssignment }
            if let correction = corrections.first {
                guard correction.nonMusicReason == nil,
                      Set(correction.ignoredCandidateIDs ?? []).isDisjoint(with: selected),
                      !correction.systems.contains(where: { system in
                          (system.systemIndex == choice.systemIndex &&
                           (!system.bands.isEmpty || !(system.omittedParts ?? []).isEmpty || system.requiresAssignmentReview == true)) ||
                          !Set(system.bands.flatMap { $0.candidateIDs ?? [] }).isDisjoint(with: selected)
                      }) else { throw ApplyError.existingAssignment }
            } else if review.plan.bands.contains(where: {
                $0.pageIndex == choice.pageIndex &&
                    ($0.systemIndex == choice.systemIndex || !Set($0.candidateIDs).isDisjoint(with: selected))
            }) { throw ApplyError.existingAssignment }
        }

        var result = review
        for choice in choices.sorted(by: {
            $0.pageIndex == $1.pageIndex ? $0.systemIndex < $1.systemIndex : $0.pageIndex < $1.pageIndex
        }) {
            guard !isCancelled() else { throw ApplyError.cancelled }
            let page = pages[choice.pageIndex]![0]
            let correction = try ScoreSystemAssignment.assign(page: page, profile: review.profile,
                pagePlan: nil, existingOverride: result.overrides.first { $0.pageIndex == choice.pageIndex },
                systemIndex: choice.systemIndex, candidateIDs: choice.candidateIDs,
                presentPartIDs: choice.presentPartIDs, startBarNumber: choice.startBarNumber, barCount: choice.barCount,
                staffCounts: choice.staffCounts)
            result.overrides.removeAll { $0.pageIndex == choice.pageIndex }
            result.overrides.append(correction)
        }
        // Numeric staff IDs are identifiers, not positions. A disjoint choice
        // can still reorder music if its system number is wrong. Check all
        // existing and proposed groups together in the original page geometry.
        for pageIndex in usedByPage.keys {
            let ordered = pages[pageIndex]![0].staves.sorted {
                ($0.staffLineFractions.first ?? -1) < ($1.staffLineFractions.first ?? -1)
            }
            let positions = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset) })
            let correction = result.overrides.first { $0.pageIndex == pageIndex }!
            var lastPosition = -1
            for system in correction.systems.sorted(by: { $0.systemIndex < $1.systemIndex }) {
                let music = system.bands.filter { ($0.kind ?? "music") == "music" }
                if music.isEmpty { continue }
                let ids = music.flatMap { $0.candidateIDs ?? [] }
                let indices = ids.compactMap { positions[$0] }
                guard !indices.isEmpty, indices.count == ids.count,
                      music.allSatisfy({ !($0.candidateIDs ?? []).isEmpty }) else { throw ApplyError.existingAssignment }
                guard indices.min()! > lastPosition else { throw ApplyError.outOfOrder }
                lastPosition = indices.max()!
            }
        }
        result.replan()
        guard !isCancelled() else { throw ApplyError.cancelled }
        return result
    }
}
