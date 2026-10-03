import Foundation

@main enum HeadingOverrideTests {
    static var checks: [[String: Any]] = []
    static func check(_ value: Bool, _ name: String) {
        checks.append(["name": name, "passed": value])
    }
    static func staff(_ id: Int, _ top: Double) -> ScoreObservedStaff {
        ScoreObservedStaff(StaffBandCandidate(id: id,
            staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
            topFraction: top - 0.02, bottomFraction: top + 0.04, confidence: 1, warnings: []))
    }
    static func main() throws {
        let profile = ScoreExtractionProfile(parts: [
            .init(id: "a", name: "A", staffCount: 1), .init(id: "b", name: "B", staffCount: 1)
        ], cropMode: "compact")
        let clean = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1800, imageHeight: 2400,
            staves: [staff(0, 0.2), staff(1, 0.3), staff(2, 0.5), staff(3, 0.6)], warnings: [])
        let plain = ScoreExtractionPlanner.plan(pages: [clean], profile: profile)
        let binding = ScoreExtractionPlanner.headingRecognitionBinding(page: clean, plan: plain, anchorStaffID: 0)!
        let source = [0.2, 0.165, 0.3, 0.19]
        func heading(bound: Bool) -> ScoreSharedHeading {
            .init(anchorStaffID: 0, bounds: source, recognizedText: "Adagio",
                  inkBounds: [0.201, 0.166, 0.299, 0.189], recognitionBinding: bound ? binding : nil)
        }
        func correction() -> ScorePageOverride {
            .init(pageIndex: 0, reason: "Independent initial assignment fixture", systems: [
                .init(systemIndex: 0, bands: [.init(partID: "a", candidateIDs: [0]), .init(partID: "b", candidateIDs: [1])]),
                .init(systemIndex: 1, bands: [.init(partID: "a", candidateIDs: [2]), .init(partID: "b", candidateIDs: [3])])
            ])
        }
        func copies(_ plan: ScoreExtractionPlan, part: String = "b", system: Int = 0) -> [ScoreSourceMarking] {
            plan.bands.first { $0.partID == part && $0.systemIndex == system }?.sourceMarkings ?? []
        }
        func warned(_ plan: ScoreExtractionPlan) -> Bool {
            plan.bands.flatMap(\.warnings).contains { $0.localizedCaseInsensitiveContains("heading") }
        }
        for bound in [false, true] {
            let kind = bound ? "bound" : "legacy"
            var page = clean; page.sharedHeadings = [heading(bound: bound)]
            func plan(_ edit: ScorePageOverride? = nil) -> ScoreExtractionPlan {
                ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: edit.map { [$0] } ?? [])
            }
            let auto = plan(), noOp = plan(correction())
            check(auto.canApply && copies(auto).count == 1, "\(kind): automatic fixture supplies the complete source heading")
            check(noOp.canApply && copies(noOp) == copies(auto), "\(kind): unchanged initial nil-list override retains the same heading")
            check(noOp.bands.filter { $0.systemIndex == 1 }.allSatisfy { $0.sourceMarkings.isEmpty },
                  "\(kind): same part in another system never receives the earlier heading")
            var empty = correction(); empty.systems[0].bands[1].sourceMarkings = []
            check(plan(empty).canApply && copies(plan(empty)).isEmpty, "\(kind): explicit empty list remains authoritative")
            var explicit = correction(); explicit.systems[0].bands[1].sourceMarkings = [[330, 180, 360, 190]]
            check(copies(plan(explicit)).count == 1 && copies(plan(explicit))[0].leftFraction == 0.55,
                  "\(kind): explicit nonempty list is neither extended nor replaced")
            let materialized = ScoreSystemAssignment.pageOverride(page: page, pagePlan: auto.pages[0], existingOverride: nil)
            check(copies(plan(materialized)) == copies(auto), "\(kind): captured source copies survive no-op materialization")
            for sourceSide in [true, false] {
                let b = sourceSide ? 0 : 1, label = sourceSide ? "source" : "recipient"
                var moved = correction()
                moved.systems[0].bands[b].candidateIDs = [b + 2]
                moved.systems[1].bands[b].candidateIDs = [b]
                let changed = plan(moved)
                check(changed.canApply && changed.bands.allSatisfy { $0.sourceMarkings.isEmpty } && warned(changed),
                      "\(kind): moved \(label) yields a notice and no stale automatic copy")
                var cue = correction(); cue.systems[0].bands[b].kind = "cue"; cue.systems[0].bands[b].label = "Cue"
                let cued = plan(cue)
                check(cued.canApply && cued.bands.allSatisfy { $0.sourceMarkings.isEmpty } && warned(cued),
                      "\(kind): \(label) changed to cue cannot acquire a stale heading")
            }
            var swap = correction()
            swap.systems[0].bands[0].partID = "b"; swap.systems[0].bands[1].partID = "a"
            check(plan(swap).canApply && plan(swap).bands.allSatisfy { $0.sourceMarkings.isEmpty } && warned(plan(swap)),
                  "\(kind): changed part ownership is rejected even within the same system")
            var recrop = correction()
            recrop.systems[0].bands[1].rect = [0, 230, 600, 280]
            check(plan(recrop).canApply && copies(plan(recrop)) == copies(auto),
                  "\(kind): explicit crop edges with a nil marking list re-evaluate source containment")
        }

        check(ScoreExtractionPlanner.headingRecognitionBinding(page: clean, plan: plain, anchorStaffID: 1) == nil,
              "a lower instrument staff cannot masquerade as a global heading anchor")
        check(binding.assignments.map(\.partID) == ["a", "b"] && binding.staves.map(\.id) == [0, 1],
              "binding contains the actual source-system ownership and physical staff lines")
        let encoded = try JSONEncoder().encode(heading(bound: true))
        check(try JSONDecoder().decode(ScoreSharedHeading.self, from: encoded) == heading(bound: true),
              "binding survives serialization")
        let legacyData = Data("{\"anchorStaffID\":0,\"bounds\":[0.2,0.165,0.3,0.19],\"recognizedText\":\"Adagio\"}".utf8)
        check(try JSONDecoder().decode(ScoreSharedHeading.self, from: legacyData).recognitionBinding == nil,
              "old heading inventories decode without a recognition binding")
        for mutation in 0..<7 {
            var h = heading(bound: true)
            switch mutation {
            case 0: h.recognitionBinding!.pageIndex = 1
            case 1: h.recognitionBinding!.systemIndex = 1
            case 2: h.recognitionBinding!.pageWidth = 601
            case 3: h.recognitionBinding!.assignments[0].partID = "other"
            case 4: h.recognitionBinding!.assignments[0].kind = "cue"
            case 5: h.recognitionBinding!.assignments.removeLast()
            default: h.recognitionBinding!.staves[0].staffLineFractions[0] -= 0.001
            }
            var page = clean; page.sharedHeadings = [h]
            let result = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
            check(result.canApply && result.bands.allSatisfy { $0.sourceMarkings.isEmpty } && warned(result),
                  "malformed/stale recognition binding \(mutation) is nonblocking and cannot copy")
        }
        var movedInk = clean; movedInk.sharedHeadings = [heading(bound: true)]
        movedInk.staves[0].staffLineFractions = movedInk.staves[0].staffLineFractions.map { $0 + 0.001 }
        let shifted = ScoreExtractionPlanner.plan(pages: [movedInk], profile: profile)
        check(shifted.canApply && copies(shifted).isEmpty && warned(shifted),
              "changed physical staff coordinates invalidate an old binding")

        var first = ScoreSharedHeading(anchorStaffID: 0, bounds: [0.2, 0.12, 0.5, 0.15], recognizedText: "SCHERZO",
            inkBounds: [0.21, 0.13, 0.49, 0.149])
        var second = ScoreSharedHeading(anchorStaffID: 0, bounds: [0.25, 0.145, 0.6, 0.18], recognizedText: "Molto vivace.",
            inkBounds: [0.26, 0.15, 0.59, 0.179])
        let expected = [0.2, 0.12, 0.6, 0.18]
        let merged = ScoreSharedHeading.coalesced([first, second])
        check(merged.count == 1 && merged[0].bounds == expected && merged[0].inkBounds == nil,
              "overlapping title/tempo retains every padded source edge and discards incomplete ink evidence")
        check(merged[0].recognizedText == "SCHERZO\nMolto vivace.", "both detected labels remain visible in review")
        var page = clean; page.sharedHeadings = [first, second]
        let combined = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        let copy = copies(combined).first!
        check(copies(combined).count == 1 && copy.topFraction == expected[1] && copy.bottomFraction == expected[3]
            && copy.leftFraction == expected[0] && 1 - copy.rightFraction == expected[2],
              "legacy planner exports the complete overlapping title-plus-tempo block")
        check(copies(ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [correction()])) == copies(combined),
              "reviewed nil-list page exports the same complete coalesced block")
        let lone = ScoreSharedHeading.coalesced([first])
        check(lone == [first], "single-heading geometry and measured source ink remain exact")
        var distant = second; distant.bounds = [0.25, 0.4, 0.6, 0.43]
        check(ScoreSharedHeading.coalesced([first, distant]) == [first, distant], "same x at a remote vertical position is not coalesced")
        var touching = second; touching.bounds[1] = first.bounds[3]
        check(ScoreSharedHeading.coalesced([first, touching]) == [first, touching], "edge contact without overlap is not coalesced")
        var otherAnchor = second; otherAnchor.anchorStaffID = 2
        check(ScoreSharedHeading.coalesced([first, otherAnchor]) == [first, otherAnchor], "distinct source anchors never coalesce")
        first.recognitionBinding = binding
        check(ScoreSharedHeading.coalesced([first, second]) == [first, second], "bound and unbound source evidence never coalesce")
        second.recognitionBinding = binding
        check(ScoreSharedHeading.coalesced([first, second]).first?.recognitionBinding == binding,
              "coalesced recognition retains its identical physical ownership binding")
        var a = first, b = second, c = second
        a.bounds = [0.1, 0.1, 0.3, 0.2]; b.bounds = [0.2, 0.15, 0.4, 0.3]; c.bounds = [0.11, 0.25, 0.19, 0.28]
        let bridge = ScoreSharedHeading.coalesced([a, b, c])
        check(bridge.count == 2,
              "union bounding-box empty corners cannot bridge a separate event")
        check(ScoreSharedHeading.coalesced(bridge) == bridge,
              "repeated coalescing cannot bridge an empty union corner")
        let persistedBridge = try JSONDecoder().decode([ScoreSharedHeading].self, from: JSONEncoder().encode(bridge))
        check(ScoreSharedHeading.coalesced(persistedBridge) == persistedBridge,
              "original fragment overlap survives serialization before planning")
        var measuredBridge = persistedBridge
        measuredBridge[0].inkBounds = [0.11, 0.11, 0.39, 0.29]
        check(ScoreSharedHeading.coalesced(measuredBridge) == measuredBridge,
              "repeated coalescing retains a fresh measurement of the original union")
        check(bridge[0].fragmentBounds == [a.bounds, b.bounds] && bridge[1].fragmentBounds == nil,
              "merged source rectangles preserve their original constituents while singletons stay unchanged")
        var joining = c; joining.bounds = [0.31, 0.25, 0.42, 0.35]
        let extended = ScoreSharedHeading.coalesced([bridge[0], joining])
        check(extended.count == 1 && extended[0].fragmentBounds == [a.bounds, b.bounds, joining.bounds],
              "a newly overlapping original fragment still joins a persisted group")
        for bad in 0..<4 {
            var malformed = bridge[0]
            switch bad {
            case 0: malformed.fragmentBounds = []
            case 1: malformed.fragmentBounds = [a.bounds]
            case 2: malformed.fragmentBounds = [[0.1, 0.1, .nan, 0.3]]
            default: malformed.fragmentBounds = [[0, 0, 1, 1]]
            }
            check(ScoreSharedHeading.coalesced([malformed, joining]).count == 2,
                  "malformed original-fragment provenance cannot trigger a merge: \(bad)")
        }
        var invalid = second; invalid.bounds = [.nan, 0.1, 0.2, 0.3]
        check(ScoreSharedHeading.coalesced([first, invalid]).count == 2, "malformed rectangles never merge")

        let report: [String: Any] = ["checks": checks, "count": checks.count,
            "failures": checks.filter { $0["passed"] as? Bool != true }.count]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        if checks.contains(where: { $0["passed"] as? Bool != true }) { exit(1) }
    }
}
