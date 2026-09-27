import Foundation

struct ScoreDirectionAssignment: Equatable {
    var systemIndex: Int
    var partID: String
    var candidateIDs: [Int]
    var kind: String
}

struct ScoreDirectionPageBinding {
    var profile: ScoreExtractionProfile
    var staves: [ScoreObservedStaff]
    var assignments: [ScoreDirectionAssignment]
    var ignoredCandidateIDs: [Int]
    var automaticMarkings: [String: [ScoreSourceMarking]]
}

extension ScoreDetectionReview {
    enum DirectionEditError: LocalizedError {
        case unavailableMarking
        var errorDescription: String? {
            "This copied direction is no longer available. Select it again in the current review."
        }
    }

    mutating func removeSourceMarking(from bandID: String, at index: Int) throws {
        guard let band = plan.bands.first(where: { $0.id == bandID }),
              band.sourceMarkings.indices.contains(index),
              let page = analyses.first(where: { $0.pageIndex == band.pageIndex }),
              let pagePlan = plan.pages.first(where: { $0.pageIndex == band.pageIndex }),
              pagePlan.unresolvedReasons.isEmpty, excludedPageReasons[band.pageIndex] == nil else {
            throw DirectionEditError.unavailableMarking
        }
        var correction = ScoreSystemAssignment.pageOverride(page: page, pagePlan: pagePlan,
            existingOverride: overrides.first { $0.pageIndex == page.pageIndex })
        guard let system = correction.systems.firstIndex(where: { $0.systemIndex == band.systemIndex }),
              let part = correction.systems[system].bands.firstIndex(where: { $0.partID == band.partID }) else {
            throw DirectionEditError.unavailableMarking
        }
        var markings = band.sourceMarkings
        markings.remove(at: index)
        correction.systems[system].bands[part].sourceMarkings = markings.map {
            [$0.leftFraction * page.pageWidth, $0.topFraction * page.pageHeight,
             (1 - $0.rightFraction) * page.pageWidth, $0.bottomFraction * page.pageHeight]
        }
        correction.systems[system].bands[part].sourceMarkingsBelow = markings.map { $0.isBelow == true }
        var proposal = self
        proposal.overrides.removeAll { $0.pageIndex == page.pageIndex }
        proposal.overrides.append(correction)
        proposal.replan()
        guard proposal.plan.pages.first(where: { $0.pageIndex == page.pageIndex })?.unresolvedReasons.isEmpty == true else {
            throw DirectionEditError.unavailableMarking
        }
        self = proposal
    }

    mutating func invalidateAutomaticDirections(on pageIndex: Int) {
        captureDirectionBindings()
        clearAutomaticDirections(on: pageIndex)
        replan()
    }

    /// Capture ownership once, while the plan still represents the recognized
    /// layout. Crop edits are intentionally absent from this identity.
    mutating func captureDirectionBindings() {
        for page in analyses where directionBindings[page.pageIndex] == nil
            && (page.sharedHeadings != nil || page.sharedNavigation != nil) {
            guard let pagePlan = plan.pages.first(where: { $0.pageIndex == page.pageIndex }),
                  pagePlan.unresolvedReasons.isEmpty else { continue }
            let reviewedBands = overrides.first { $0.pageIndex == page.pageIndex }?.systems ?? []
            let automaticBands = pagePlan.assignments.filter { band in
                // An override supplied before recognition review is an explicit
                // manual choice. Later UI materialization is covered by this
                // already-captured binding, so automatic copies remain known.
                !reviewedBands.contains { system in
                    system.systemIndex == band.systemIndex && system.bands.contains {
                        $0.partID == band.partID && $0.sourceMarkings != nil
                    }
                }
            }
            let automaticMarkings = Dictionary(uniqueKeysWithValues: automaticBands.map {
                ("\($0.systemIndex):\($0.partID)", $0.sourceMarkings)
            })
            directionBindings[page.pageIndex] = ScoreDirectionPageBinding(profile: profile, staves: page.staves,
                assignments: orderedDirectionAssignments(pagePlan.assignments.map {
                    .init(systemIndex: $0.systemIndex, partID: $0.partID, candidateIDs: $0.candidateIDs, kind: $0.kind)
                }), ignoredCandidateIDs: overrides.first { $0.pageIndex == page.pageIndex }?.ignoredCandidateIDs?.sorted() ?? [],
                automaticMarkings: automaticMarkings)
        }
    }

    func directionAssignments(on pageIndex: Int, plan: ScoreExtractionPlan) -> [ScoreDirectionAssignment] {
        if let correction = overrides.first(where: { $0.pageIndex == pageIndex }) {
            // Inspect the requested mapping even when its crop geometry is
            // temporarily invalid. A crop edit must not change mark ownership.
            return orderedDirectionAssignments(correction.systems.flatMap { system in
                system.bands.map {
                    ScoreDirectionAssignment(systemIndex: system.systemIndex, partID: $0.partID,
                        candidateIDs: $0.candidateIDs ?? [], kind: $0.kind ?? "music")
                } + (system.omittedParts ?? []).map {
                    ScoreDirectionAssignment(systemIndex: system.systemIndex, partID: $0.partID,
                        candidateIDs: [], kind: "generated-rest")
                }
            })
        }
        return orderedDirectionAssignments((plan.pages.first { $0.pageIndex == pageIndex }?.assignments ?? []).map {
            .init(systemIndex: $0.systemIndex, partID: $0.partID, candidateIDs: $0.candidateIDs, kind: $0.kind)
        })
    }

    private func orderedDirectionAssignments(_ assignments: [ScoreDirectionAssignment]) -> [ScoreDirectionAssignment] {
        assignments.sorted {
            $0.systemIndex == $1.systemIndex ? $0.partID < $1.partID : $0.systemIndex < $1.systemIndex
        }
    }

    mutating func clearAutomaticDirections(on pageIndex: Int) {
        guard let index = analyses.firstIndex(where: { $0.pageIndex == pageIndex }) else { return }
        let page = analyses[index]
        let binding = directionBindings[pageIndex]
        let knownByBand = binding?.automaticMarkings ?? [:]
        let hadRecognition = page.sharedHeadings != nil || page.sharedNavigation != nil || directionBindings[pageIndex] != nil
        analyses[index].sharedHeadings = nil
        analyses[index].sharedNavigation = nil
        directionBindings.removeValue(forKey: pageIndex)
        directionReferences.removeAll { $0.pageIndex == pageIndex }
        for correction in overrides.indices where overrides[correction].pageIndex == pageIndex {
            for system in overrides[correction].systems.indices {
                for band in overrides[correction].systems[system].bands.indices {
                    var value = overrides[correction].systems[system].bands[band]
                    let systemIndex = overrides[correction].systems[system].systemIndex
                    // A reassignment may rename the recipient while retaining
                    // its candidate staves and copied rectangles. Follow that
                    // original staff ownership first. In particular, an
                    // authoritative manual list must not inherit another
                    // recipient's automatic-copy provenance after a swap.
                    let originalOwner = binding?.assignments.first {
                        !$0.candidateIDs.isEmpty
                            && $0.candidateIDs.sorted() == (value.candidateIDs ?? []).sorted()
                    }
                    let owner = originalOwner?.partID ?? value.partID
                    let originalSystem = originalOwner?.systemIndex ?? systemIndex
                    let known = knownByBand["\(originalSystem):\(owner)"] ?? []
                    guard let rectangles = value.sourceMarkings,
                          value.sourceMarkingsBelow == nil || value.sourceMarkingsBelow?.count == rectangles.count else { continue }
                    let keep = rectangles.indices.filter { item in
                        let rect = rectangles[item]
                        guard rect.count == 4 else { return true }
                        let below = value.sourceMarkingsBelow?[item] == true
                        return !known.contains { marking in
                            let expected = [marking.leftFraction * page.pageWidth, marking.topFraction * page.pageHeight,
                                (1 - marking.rightFraction) * page.pageWidth, marking.bottomFraction * page.pageHeight]
                            return (marking.isBelow == true) == below
                                && zip(expected, rect).allSatisfy { abs($0 - $1) < 1e-7 }
                        }
                    }
                    value.sourceMarkings = keep.map { rectangles[$0] }
                    if let sides = value.sourceMarkingsBelow { value.sourceMarkingsBelow = keep.map { sides[$0] } }
                    overrides[correction].systems[system].bands[band] = value
                }
            }
        }
        if hadRecognition {
            let issue = ScoreDirectionIssue(pageIndex: pageIndex,
                message: "Directions need a new scan after changing this page's staff assignments. Existing music crops and manual markings are kept.")
            if !directionIssues.contains(issue) { directionIssues.append(issue) }
        }
    }
}
