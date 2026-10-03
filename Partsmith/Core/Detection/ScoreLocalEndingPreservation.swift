import CoreGraphics
import Foundation

/// Recipient evidence is kept separate from the global paired-ending stream.
/// It cannot create a global pair or change a source crop.
struct ScoreEndingLocalCounterpart: Codable, Equatable {
    var partID: String
    var globalMembers: [ScoreEndingMember]
    var members: [ScoreEndingMember]
}

enum ScoreLocalEndingPreservation {
    typealias D = ScoreSharedEndingDetector

    static func firstStaff(of band: ScorePlannedBand, on page: ScorePageAnalysis) -> ScoreObservedStaff? {
        guard band.kind == "music", !band.candidateIDs.isEmpty,
              Set(band.candidateIDs).count == band.candidateIDs.count else { return nil }
        let owned = page.staves.filter { band.candidateIDs.contains($0.id) }
        guard owned.count == band.candidateIDs.count, owned.allSatisfy({ staff in
            let lines = staff.staffLineFractions
            return lines.count == 5 && lines.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
                && zip(lines, lines.dropFirst()).allSatisfy { $0 < $1 }
        }) else { return nil }
        return owned.min { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
    }

    /// Uses precisely the existing geometry/OCR implementation, anchored above
    /// this recipient's own first physical staff, fenced by the preceding staff.
    /// Result is never passed into the global pairer.
    static func analyze(in image: CGImage, page: ScorePageAnalysis, profile: ScoreExtractionProfile,
                        plan: ScoreExtractionPlan, partID: String, systems: Set<Int>,
                        observedFailure: ((Error)->Void)? = nil,
                        isCancelled: ()->Bool = { false }) -> D.PageResult {
        let empty = D.PageResult(pageIndex: page.pageIndex, ownershipVerified: false,
            systemIndices: [], geometryProposalCount: 0, mergedProposalCount: 0, candidates: [])
        guard !isCancelled(), plan.canApply,
              D.systems(page: page, profile: profile, isCancelled: isCancelled) != nil else { return empty }
        let all = plan.bands.filter { $0.pageIndex == page.pageIndex && $0.kind == "music" }
        let ids = all.flatMap(\.candidateIDs)
        guard ids.count == Set(ids).count, Set(ids) == Set(page.staves.map(\.id)) else { return empty }
        let ordered = page.staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
        var anchors: [D.System] = []
        for system in systems.sorted() {
            let recipients = all.filter { $0.systemIndex == system && $0.partID == partID }
            guard recipients.count == 1, let first = firstStaff(of: recipients[0], on: page),
                  let index = ordered.firstIndex(where: { $0.id == first.id }) else { return empty }
            anchors.append(D.System(index: system, first: first, previous: index > 0 ? ordered[index-1] : nil))
        }
        return D.analyze(in: image, page: page, verifiedSystems: anchors,
            observedFailure: observedFailure, isCancelled: isCancelled)
    }

    static func samePosition(_ local: D.Candidate, _ global: D.Candidate) -> Bool {
        guard local.role == global.role, local.pageIndex == global.pageIndex,
              local.systemIndex == global.systemIndex,
              local.bounds.count == 4, global.bounds.count == 4,
              local.bounds.allSatisfy(\.isFinite), global.bounds.allSatisfy(\.isFinite),
              local.staffSpace > 0, global.staffSpace > 0 else { return false }
        // Both horizontal bracket endpoints must align, not just numeral text.
        // One staff-space is substantially smaller than a printed measure.
        let allowance = 1.25 * max(local.staffSpace, global.staffSpace)
        return abs(local.bounds[0] - global.bounds[0]) <= allowance
            && abs(local.bounds[2] - global.bounds[2]) <= allowance
    }

    static func member(_ candidate: D.Candidate) -> ScoreEndingMember? {
        guard let role = candidate.role.flatMap(ScoreEndingMember.Role.init(rawValue:)),
              candidate.pageWidth > 0, candidate.pageHeight > 0, candidate.copyBounds.count == 4 else { return nil }
        let b = candidate.copyBounds
        let bounds = [b[0]/candidate.pageWidth,b[1]/candidate.pageHeight,b[2]/candidate.pageWidth,b[3]/candidate.pageHeight]
        guard ScoreSharedEnding.validBounds(bounds) else { return nil }
        return ScoreEndingMember(sourcePageIndex: candidate.pageIndex, sourceSystemIndex: candidate.systemIndex,
            anchorStaffID: candidate.anchorStaffID, bounds: bounds, role: role,
            evidence: candidate.evidence.map { ScoreEndingTextEvidence(mode:$0.mode,text:$0.text,confidence:$0.confidence,bounds:$0.bounds) })
    }

    /// Requires exactly one supported local counterpart for BOTH global members.
    /// A first bracket alone, unrelated same-page pair, or another part is not enough.
    static func counterpart(global: D.Pair, partID: String, localPages: [D.PageResult],
                            pages: [ScorePageAnalysis], plan: ScoreExtractionPlan) -> ScoreEndingLocalCounterpart? {
        guard plan.canApply, Set(localPages.map(\.pageIndex)).count == localPages.count,
              let firstGlobal = member(global.first), let secondGlobal = member(global.second) else { return nil }
        var matches: [D.Candidate] = []
        for globalMember in [global.first, global.second] {
            guard let page = localPages.first(where: { $0.pageIndex == globalMember.pageIndex }), page.ownershipVerified,
                  page.systemIndices.contains(globalMember.systemIndex) else { return nil }
            let matched = page.candidates.filter { samePosition($0, globalMember) }
            guard matched.count == 1 else { return nil }
            matches.append(matched[0])
        }
        let gap = global.first.pageIndex == global.second.pageIndex && global.first.systemIndex == global.second.systemIndex ? 0 : 1
        guard D.pairable(matches[0], matches[1], systemGap: gap),
              let first = member(matches[0]), let second = member(matches[1]) else { return nil }
        let result = ScoreEndingLocalCounterpart(partID: partID, globalMembers: [firstGlobal, secondGlobal], members: [first, second])
        return retained(result, pages: pages, plan: plan) ? result : nil
    }

    static func retained(_ counterpart: ScoreEndingLocalCounterpart, pages: [ScorePageAnalysis],
                         plan: ScoreExtractionPlan) -> Bool {
        guard plan.canApply, !counterpart.partID.isEmpty, counterpart.members.count == 2,
              counterpart.globalMembers.count == 2,
              counterpart.members.map(\.role) == [.first,.second],
              counterpart.globalMembers.map(\.role) == [.first,.second] else { return false }
        for (local, global) in zip(counterpart.members, counterpart.globalMembers) {
            guard ScoreSharedEnding.validBounds(local.bounds), ScoreSharedEnding.validBounds(global.bounds),
                  local.sourcePageIndex == global.sourcePageIndex,
                  local.sourceSystemIndex == global.sourceSystemIndex,
                  let page = pages.first(where: { $0.pageIndex == local.sourcePageIndex }) else { return false }
            let bands = plan.bands.filter { $0.pageIndex == local.sourcePageIndex && $0.systemIndex == local.sourceSystemIndex
                && $0.partID == counterpart.partID && $0.kind == "music" }
            guard bands.count == 1, let first = firstStaff(of: bands[0], on: page), first.id == local.anchorStaffID,
                  let globalStaff = page.staves.first(where: { $0.id == global.anchorStaffID }),
                  first.staffLineFractions.count == 5, globalStaff.staffLineFractions.count == 5 else { return false }
            let band = bands[0], b = local.bounds
            let space = max(first.staffLineFractions[4] - first.staffLineFractions[0],
                globalStaff.staffLineFractions[4] - globalStaff.staffLineFractions[0]) / 4
            guard space.isFinite, space > 0, page.pageWidth > 0, page.pageHeight > 0,
                  b[1] < first.staffLineFractions[0], b[3] <= first.staffLineFractions[0] + space,
                  abs(b[0] - global.bounds[0]) <= 1.25*space*page.pageHeight/page.pageWidth,
                  abs(b[2] - global.bounds[2]) <= 1.25*space*page.pageHeight/page.pageWidth,
                  b[0] >= band.leftFraction - 1e-9, b[2] <= 1-band.rightFraction + 1e-9,
                  b[1] >= band.topFraction - 1e-9, b[3] <= band.bottomFraction + 1e-9 else { return false }
        }
        return true
    }

    /// Planner-time validation catches initial manual regrouping/recropping on
    /// either side as well as normal live review invalidation. Cancellation is atomic.
    static func apply(to original: ScoreExtractionPlan, pages: [ScorePageAnalysis],
                      overrides: [ScorePageOverride], isCancelled: ()->Bool = { false }) -> ScoreExtractionPlan {
        guard !isCancelled(), original.canApply else { return original }
        var result = original
        for page in pages {
            for ending in page.sharedEndings ?? [] where ending.isValid(on: page) {
                if isCancelled() { return original }
                for counterpart in ending.localCounterparts ?? [] {
                    guard counterpart.globalMembers == ending.members,
                          retained(counterpart, pages: pages, plan: original) else { continue }
                    // Both global halves must still be present and owned by the
                    // recorded system. Never rely on stale one-sided metadata.
                    let allCurrent = ending.members.allSatisfy { member in
                        guard let source = pages.first(where: { $0.pageIndex == member.sourcePageIndex }),
                              (source.sharedEndings ?? []).contains(where: {
                                  $0.members == ending.members && $0.isValid(on: source)
                                      && $0.sourcePageIndex == member.sourcePageIndex
                                      && $0.systemIndex == member.sourceSystemIndex
                                      && $0.anchorStaffID == member.anchorStaffID
                              }) else { return false }
                        let owners = original.bands.filter { $0.pageIndex == member.sourcePageIndex && $0.candidateIDs.contains(member.anchorStaffID) }
                        return owners.count == 1 && owners[0].kind == "music" && owners[0].systemIndex == member.sourceSystemIndex
                    }
                    guard allCurrent else { continue }
                    // Explicit user lists (including empty removal lists) win.
                    let manuallyListed = counterpart.members.contains { member in
                        overrides.first(where: { $0.pageIndex == member.sourcePageIndex })?.systems
                            .first(where: { $0.systemIndex == member.sourceSystemIndex })?.bands
                            .contains(where: { $0.partID == counterpart.partID && $0.sourceMarkings != nil
                                && !($0.automaticLocalEndingPairIDs ?? []).contains(ending.pairID) }) == true
                    }
                    guard !manuallyListed else { continue }
                    // If another category owns the same source box, retain it.
                    // Older inventories store title/tempo fragments separately;
                    // the planner copies their union. Preserve both that block
                    // and previously materialized individual heading copies.
                    let headings = page.sharedHeadings ?? []
                    guard !(headings + ScoreSharedHeading.coalesced(headings)).contains(where: { $0.bounds == ending.bounds }),
                          !(page.sharedNavigation ?? []).contains(where: { $0.bounds == ending.bounds }) else { continue }
                    guard let pi = result.pages.firstIndex(where: { $0.pageIndex == page.pageIndex }),
                          let bi = result.pages[pi].assignments.firstIndex(where: { $0.partID == counterpart.partID && $0.systemIndex == ending.systemIndex }),
                          !result.pages[pi].assignments[bi].candidateIDs.contains(ending.anchorStaffID) else { continue }
                    result.pages[pi].assignments[bi].sourceMarkings.removeAll { $0 == ending.sourceMarking }
                }
            }
        }
        return isCancelled() ? original : result
    }
}
