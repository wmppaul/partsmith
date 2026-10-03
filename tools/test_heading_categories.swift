import Foundation

@main enum HeadingCategoryTests {
    typealias C = LocalEndingControls
    static var checks: [[String: Any]] = []
    static func check(_ value: Bool, _ name: String) {
        checks.append(["name": name, "passed": value])
    }
    static func fragments(_ ending: ScoreSharedEnding) -> [ScoreSharedHeading] {
        let b = ending.bounds, width = b[2] - b[0]
        return [
            .init(anchorStaffID: ending.anchorStaffID,
                  bounds: [b[0], b[1], b[0] + width * 0.65, b[3]], recognizedText: "SCHERZO"),
            .init(anchorStaffID: ending.anchorStaffID,
                  bounds: [b[0] + width * 0.35, b[1], b[2], b[3]], recognizedText: "Molto vivace.")
        ]
    }
    static func main() throws {
        let pair = C.D.Pair(first: C.candidate(first: true), second: C.candidate(first: false))
        let pages = C.annotated([C.page(0)], pair: pair)
        let base = ScoreExtractionPlanner.plan(pages: pages, profile: C.profile)
        let local = C.observed(0, [C.candidate(first: true, local: true), C.candidate(first: false, local: true)])
        let cp = C.L.counterpart(global: pair, partID: "cello", localPages: [local], pages: pages, plan: base)!
        var annotated = C.attach(cp, to: pages)
        let ending = annotated[0].sharedEndings![0]
        annotated[0].sharedHeadings = fragments(ending)
        check(ScoreSharedHeading.coalesced(annotated[0].sharedHeadings!).map(\.bounds) == [ending.bounds],
              "independent overlapping fragments exactly cover the coincident source block")
        let protected = ScoreExtractionPlanner.plan(pages: annotated, profile: C.profile)
        check(protected.bands.first { $0.partID == "cello" && $0.systemIndex == 0 }!.sourceMarkings.contains(ending.sourceMarking),
              "a local ending cannot suppress a coincident grouped heading")

        let cross = C.D.Pair(first: C.candidate(system: 1, first: true, split: true),
                            second: C.candidate(page: 1, first: false, split: true))
        let crossPages = C.annotated([C.page(0), C.page(1)], pair: cross)
        let crossPlan = ScoreExtractionPlanner.plan(pages: crossPages, profile: C.profile)
        let crossLocals = [C.observed(0, [C.candidate(system: 1, first: true, local: true, split: true)]),
                           C.observed(1, [C.candidate(page: 1, first: false, local: true, split: true)])]
        let crossCP = C.L.counterpart(global: cross, partID: "cello", localPages: crossLocals, pages: crossPages, plan: crossPlan)!
        for materializedFragment in [false, true] {
            var coincident = C.attach(crossCP, to: crossPages)
            let partner = coincident[1].sharedEndings![0]
            coincident[1].sharedHeadings = fragments(partner)
            var linked = ScoreDetectionReview.initial(profile: C.profile, analyses: coincident, sourcePDFData: Data(), rectifications: [])
            let pagePlan = linked.plan.pages.first { $0.pageIndex == 1 }!
            var edit = ScoreSystemAssignment.pageOverride(page: coincident[1], pagePlan: pagePlan, existingOverride: nil)
            let bandIndex = edit.systems[0].bands.firstIndex { $0.partID == "cello" }!
            // Materialize the already-required source copy directly so this
            // cleanup check remains independent of the preceding suppression bug.
            edit.systems[0].bands[bandIndex].sourceMarkings = [partner.bounds.enumerated().map { $1 * ($0 % 2 == 0 ? 600 : 800) }]
            edit.systems[0].bands[bandIndex].sourceMarkingsBelow = [false]
            if materializedFragment {
                // A pre-grouping saved project can still own the original box.
                // Include a second overlapping heading without changing that box.
                coincident[1].sharedHeadings = [
                    .init(anchorStaffID: partner.anchorStaffID, bounds: partner.bounds, recognizedText: "SCHERZO"),
                    .init(anchorStaffID: partner.anchorStaffID,
                          bounds: [partner.bounds[0], partner.bounds[1] - 0.005, partner.bounds[2], partner.bounds[3] - 0.005],
                          recognizedText: "Molto vivace.")
                ]
                linked = ScoreDetectionReview.initial(profile: C.profile, analyses: coincident, sourcePDFData: Data(), rectifications: [])
            }
            linked.overrides = [edit]
            linked.replan()
            linked.invalidateAutomaticDirections(on: 0)
            let output = linked.plan.bands.first { $0.pageIndex == 1 && $0.systemIndex == 0 && $0.partID == "cello" }!
            check(linked.analyses[1].sharedEndings == nil && output.sourceMarkings.contains(partner.sourceMarking),
                  "linked ending cleanup retains a coincident \(materializedFragment ? "legacy raw fragment" : "coalesced heading")")
        }
        let report: [String: Any] = ["checks": checks, "count": checks.count,
            "failures": checks.filter { $0["passed"] as? Bool != true }.count]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        if checks.contains(where: { $0["passed"] as? Bool != true }) { exit(1) }
    }
}
