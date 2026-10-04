import AppKit
import Foundation

@main enum SystemSelectionTests {
    static var checks = 0
    static func check(_ result: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !result() { fatalError(message) }
    }

    static func main() throws {
        let ids = [12, 4, 31, 18, 6, 29]
        let staves = [0.10, 0.18, 0.26, 0.50, 0.58, 0.66].enumerated().map { index, top in
            ScoreObservedStaff(StaffBandCandidate(id: ids[index],
                staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
                topFraction: top - 0.04, bottomFraction: top + 0.06,
                confidence: 1, warnings: []))
        }
        for scale in [0.5, 1.0, 1.25, 2.0, 4.0] {
            let size = CGSize(width: 600 * scale, height: 800 * scale)
            let top = CGPoint(x: 100 * scale, y: 0.11 * size.height)
            let bottom = CGPoint(x: 450 * scale, y: 0.27 * size.height)
            for reverse in [false, true] {
                var selection = ScoreStaffRangeSelection(initialSelection: [29], additive: false)
                selection.update(from: reverse ? bottom : top, to: reverse ? top : bottom, pageSize: size)
                check(selection.selectedIDs(staves: staves, pageHeight: size.height) == [12, 4, 31],
                      "Drag selects the same three staves in both directions at every zoom")
                check(selection.anchorID(staves: staves, pageHeight: size.height) == (reverse ? 31 : 12),
                      "Shift-click anchor follows the drag's starting staff, not its smallest ID")
                check(selection.rect.minY == top.y && selection.rect.maxY == bottom.y,
                      "Marquee stays in rendered page coordinates")
            }
            var additive = ScoreStaffRangeSelection(initialSelection: [29], additive: true)
            additive.update(from: top, to: bottom, pageSize: size)
            check(additive.selectedIDs(staves: staves, pageHeight: size.height) == [12, 4, 31, 29],
                  "Shift-drag adds the touched staff range to the initial selection")
            additive.update(from: top, to: CGPoint(x: top.x, y: 0.19 * size.height), pageSize: size)
            check(additive.selectedIDs(staves: staves, pageHeight: size.height) == [12, 4, 29],
                  "Reversing an additive drag releases rows outside the current marquee")
            var gutter = ScoreStaffRangeSelection(initialSelection: [], additive: false)
            gutter.update(from: CGPoint(x: -12, y: top.y), to: CGPoint(x: -12, y: bottom.y), pageSize: size)
            check(gutter.selectedIDs(staves: staves, pageHeight: size.height) == [12, 4, 31],
                  "A vertical drag over numbered staff badges selects the same range")
            var blank = ScoreStaffRangeSelection(initialSelection: [12], additive: false)
            blank.update(from: CGPoint(x: 0, y: 0.34 * size.height),
                         to: CGPoint(x: size.width, y: 0.40 * size.height), pageSize: size)
            check(blank.selectedIDs(staves: staves, pageHeight: size.height).isEmpty,
                  "Dragging between systems does not select larger overlapping crop padding")
            var horizontal = ScoreStaffRangeSelection(initialSelection: [], additive: false)
            horizontal.update(from: CGPoint(x: 0, y: 0.59 * size.height),
                              to: CGPoint(x: size.width, y: 0.59 * size.height), pageSize: size)
            check(horizontal.selectedIDs(staves: staves, pageHeight: size.height) == [6],
                  "A horizontal drag through one staff selects it")
            var outside = ScoreStaffRangeSelection(initialSelection: [], additive: false)
            outside.update(from: CGPoint(x: -40, y: -50), to: CGPoint(x: size.width + 50, y: size.height + 80), pageSize: size)
            check(outside.selectedIDs(staves: staves, pageHeight: size.height) == Set(ids),
                  "Dragging past a page edge finishes selecting its outer staves")
            check(outside.rect == CGRect(x: -24, y: 0, width: size.width + 24, height: size.height),
                  "Selection feedback remains bounded by the page and numbered gutter")
        }

        let profile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "winds", name: "Winds", staffCount: 1),
            ScorePartDefinition(id: "piano", name: "Piano", staffCount: 2)
        ], requiresSystemAssignment: true)
        let page0 = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1200, imageHeight: 1600, staves: staves, warnings: [])
        var page1 = page0; page1.pageIndex = 1
        let assigned0 = try ScoreSystemAssignment.assign(page: page0, profile: profile, pagePlan: nil,
            existingOverride: nil, systemIndex: 0, candidateIDs: [12, 4, 31], presentPartIDs: ["winds", "piano"],
            startBarNumber: 1, barCount: 6)
        let assigned1 = try ScoreSystemAssignment.assign(page: page1, profile: profile, pagePlan: nil,
            existingOverride: nil, systemIndex: 0, candidateIDs: [12, 4], presentPartIDs: ["piano"],
            startBarNumber: 20, barCount: 9)
        let persisted = try JSONDecoder().decode([ScorePageOverride].self,
            from: JSONEncoder().encode([assigned0, assigned1]))
        // Candidate IDs restart on each page. Moving back and forth must recover
        // the reviewed span and roster from that page, never a previous selection.
        for page in [0, 1, 0, 1, 0] {
            let selected: Set<Int> = page == 0 ? [12, 4, 31] : [12, 4]
            let recalled = ScoreSystemSelectionRecall.matchingSystem(in: persisted, pageIndex: page, selectedIDs: selected)
            check(recalled?.barCount == (page == 0 ? 6 : 9), "Selection recalls the assigned bar count on the correct page")
            check(recalled?.startBarNumber == (page == 0 ? 1 : 20), "Selection recalls the first bar independently of page-local system IDs")
            check(recalled?.bands.map(\.partID) == (page == 0 ? ["winds", "piano"] : ["piano"]),
                  "Selection recalls the correct changing instrument roster")
        }
        check(ScoreSystemSelectionRecall.matchingSystem(in: persisted, pageIndex: 1, selectedIDs: [12, 4])?.omittedParts?.first?.partID == "winds",
              "Recalling an assignment preserves the silent instrument and its rest interval")
        check(ScoreSystemSelectionRecall.matchingSystem(in: persisted, pageIndex: 0, selectedIDs: [12]) == nil,
              "A partial selection remains editable instead of snapping to a full assigned system")
        check(ScoreSystemSelectionRecall.matchingSystem(in: persisted, pageIndex: 0, selectedIDs: [12, 4, 31, 18]) == nil,
              "A selection crossing systems cannot reuse a saved bar count")
        check(ScoreSystemSelectionRecall.matchingSystem(in: persisted, pageIndex: 0, selectedIDs: []) == nil,
              "Clearing selection does not recall an empty system")
        check(ScoreSystemSelectionRecall.matchingSystem(in: persisted, pageIndex: 2, selectedIDs: [12, 4, 31]) == nil,
              "A different page cannot reuse counts from identical staff IDs")
        var changed = persisted
        changed[0].systems[0].requiresAssignmentReview = true
        check(ScoreSystemSelectionRecall.matchingSystem(in: changed, pageIndex: 0, selectedIDs: [12, 4, 31]) == nil,
              "An invalidated assignment cannot silently supply a trusted measure span")

        // Selecting System 3 before System 2 creates an empty placeholder in
        // the actual planner output. Navigation must skip that unsaved slot.
        let later = try ScoreSystemAssignment.assign(page: page0, profile: profile, pagePlan: nil,
            existingOverride: assigned0, systemIndex: 2, candidateIDs: [18, 6, 29],
            presentPartIDs: ["winds", "piano"], startBarNumber: 12, barCount: 4)
        let navigation = [later, assigned1]
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: navigation, pageIndex: 0, preferred: 3) == 3,
              "Returning to a saved exact system preserves that navigation target")
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: navigation, pageIndex: 0, preferred: 4) == 3,
              "The auto-advanced empty slot reopens the preceding assigned system")
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: navigation, pageIndex: 0, preferred: 2) == 1,
              "An empty placeholder between assignments cannot hide the preceding saved system")
        let firstSavedLater = try ScoreSystemAssignment.assign(page: page0, profile: profile, pagePlan: nil,
            existingOverride: nil, systemIndex: 2, candidateIDs: [18, 6, 29],
            presentPartIDs: ["winds", "piano"], startBarNumber: 12, barCount: 4)
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: [firstSavedLater], pageIndex: 0, preferred: 1) == 3,
              "If no earlier system is saved, navigation opens the first actual assignment")
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: navigation, pageIndex: 1, preferred: 4) == 1,
              "System numbers saved on another page never influence the current page")
        var needsReview = navigation
        needsReview[0].systems[2].requiresAssignmentReview = true
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: needsReview, pageIndex: 0, preferred: 3) == 1,
              "Navigation skips an invalidated later assignment and empty placeholder")
        var onlyInvalid = firstSavedLater
        onlyInvalid.systems[2].requiresAssignmentReview = true
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: [onlyInvalid], pageIndex: 0, preferred: 3) == 1,
              "A page with no valid saved assignments starts at system one")
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: navigation, pageIndex: 2, preferred: 3) == 1,
              "A page with no override starts at system one")
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: [], pageIndex: 0, preferred: 7) == 1,
              "An empty review starts at system one")
        let emptyPage = ScorePageOverride(pageIndex: 0, reason: "No assignments", systems: [])
        check(ScoreSystemSelectionRecall.recalledSystemNumber(in: [emptyPage], pageIndex: 0, preferred: 7) == 1,
              "An existing override with no systems starts at system one")
        print("PASS: \(checks) staff drag and assigned-system recall checks")
    }
}
