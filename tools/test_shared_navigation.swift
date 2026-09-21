import CoreGraphics
import Foundation

@main enum SharedNavigationTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }
    static func staff(_ id: Int, _ top: Double, space: Double = 0.005) -> ScoreObservedStaff {
        ScoreObservedStaff(StaffBandCandidate(id: id,
            staffLineFractions: (0..<5).map { top + Double($0) * space },
            topFraction: max(0, top - space * 2), bottomFraction: top + space * 6, confidence: 1, warnings: []))
    }
    static func main() throws {
        typealias Detector = ScoreSharedNavigationDetector
        typealias Line = Detector.TextLine
        let positives: [(String, Detector.Kind)] = [
            ("Da Capo", .daCapo), ("Du Capo sin'ul # e pui il Coda.", .daCapo),
            ("DaCapo al Fine", .daCapo), ("D.C. al Coda", .daCapo), ("D. C.", .daCapo),
            ("D.C", .daCapo), ("D.C.", .daCapo), ("DC al Fine", .daCapo),
            ("Dal Segno al Fine", .dalSegno), ("D.S. al Coda", .dalSegno),
            ("D. S.", .dalSegno), ("DS al Fine", .dalSegno), ("Fine.", .fine), ("FINE", .fine)]
        for (text, kind) in positives { check(Detector.navigationKind(text) == kind, "Navigation spelling: \(text)") }
        for text in ["Coda.", ". Coda.", "Trio", "2da volta", "dim.", "dol.", "Doppio Movimento",
                     "poco a poco in tempo", "Da", "Capo", "Segno", "D", "C", "S", "DC", "DS",
                     "al Fine", "fine tuning", "Da Capone", "Dal Segnography", "Andante", "D.Cello"] {
            check(Detector.navigationKind(text) == nil, "Unrelated text must not create a jump: \(text)")
        }
        let profile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "v1", name: "Violin I", staffCount: 1),
            ScorePartDefinition(id: "v2", name: "Violin II", staffCount: 1)], cropMode: "compact")
        var page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1800, imageHeight: 2400,
            staves: [staff(10, 0.2), staff(2, 0.28), staff(8, 0.5), staff(3, 0.58)], warnings: [])
        let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        check(plan.canApply, "Fixture has a verified two-system plan")
        let select: ([Line]) -> [ScoreSharedNavigation] = { Detector.select(from: $0, page: page, plan: plan) }
        let below = Line(text: "D.C. al Fine", bounds: CGRect(x: 0.6, y: 0.305, width: 0.25, height: 0.015), confidence: 1)
        let result = select([below])
        check(result.count == 1 && result[0].anchorStaffID == 2 && result[0].isBelow,
              "Direction below last staff uses physical order, not minimum/maximum candidate ID")
        check(result[0].bounds[0] <= below.bounds.minX - 0.005 * 800 / 600 + 1e-12,
              "Horizontal padding preserves physical staff space on a nonsquare page")
        check(result[0].bounds[1] < below.bounds.minY && result[0].bounds[3] > below.bounds.maxY,
              "Complete observed glyph envelope is padded")
        var line = below
        line.bounds.origin.y = 0.175
        let above = select([line])
        check(above.count == 1 && above[0].anchorStaffID == 10 && !above[0].isBelow,
              "Direction above first staff stays with that source system")
        line.bounds.origin.y = 0.265
        check(select([line]).isEmpty, "Text above an interior staff is not globally shared")
        line.bounds.origin.y = 0.225
        check(select([line]).isEmpty, "Text below a nonfinal staff is not globally shared")
        line.bounds.origin.y = 0.205
        check(select([line]).isEmpty, "In-staff navigation remains unresolved")
        line.bounds.origin.y = 0.39
        check(select([line]).isEmpty, "Text midway between systems remains unresolved")
        line = below; line.confidence = 0.3
        check(select([line]).isEmpty, "Weak OCR cannot manufacture a navigation copy")
        line = below; line.bounds.origin.x = .nan
        check(select([line]).isEmpty, "Nonfinite rectangle rejected")
        line = below; line.bounds.origin.x = -0.01
        check(select([line]).isEmpty, "Off-page rectangle rejected")
        line = below; line.text = "Fine"; line.bounds.origin.x = 0.15
        check(select([line]).isEmpty, "Standalone Fine requires end-of-system horizontal placement")
        line.bounds.origin.x = 0.7
        check(select([line]).count == 1, "Right-side Fine at an established boundary is eligible")
        check(select([below, below]).count == 1, "Overlapping OCR windows do not duplicate a direction")
        line = below; line.bounds = CGRect(x: 0.05, y: 0.305, width: 0.2, height: 0.015)
        check(select([below, line]).count == 2, "Separate text columns are not merged through unrelated source ink")
        check(Detector.select(from: [below], page: page, plan: plan, isCancelled: { true }).isEmpty,
              "Cancelled recognition returns no partial result")
        let noPlan = ScoreExtractionPlan(parts: profile.parts, pages: [], warnings: [])
        check(Detector.select(from: [below], page: page, plan: noPlan).isEmpty,
              "Missing system assignments cannot imply instrument identity")
        let regions = Detector.regions(for: page.staves)
        check(regions.count == 5 && regions[2].afterStaffID == 2 && regions[2].beforeStaffID == 8,
              "Inter-system OCR window records both surrounding physical staves")
        check(regions.last?.afterStaffID == 3 && regions.last?.beforeStaffID == nil,
              "Final system also receives a below-staff window")
        page.staves[0].staffLineFractions[1] = .nan
        check(Detector.regions(for: page.staves).isEmpty, "Invalid staff geometry cannot form OCR windows")

        // Real frozen93521p28 geometry, OCR and independent source envelope.
        // OCR finds the Da Capo sentence in a window BEFORE staff8/Coda, but
        // the sentence belongs BELOW staff7/cello in the preceding system.
        let tops = [41.59, 71.18, 107.96, 137.72, 184.74, 213.53, 247.94,
                    275.69547304711864, 327.8933680104031, 357.48, 397.07, 426.9,
                    472.24, 501.84, 536.23, 566.22]
        let quartet = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "violin1", name: "Violin I", staffCount: 1),
            ScorePartDefinition(id: "violin2", name: "Violin II", staffCount: 1),
            ScorePartDefinition(id: "viola", name: "Viola", staffCount: 1),
            ScorePartDefinition(id: "cello", name: "Cello", staffCount: 1)], cropMode: "compact")
        let realPage = ScorePageAnalysis(pageIndex: 27, pageWidth: 427, pageHeight: 615,
            imageWidth: 1800, imageHeight: 2593,
            staves: tops.enumerated().map { staff($0.offset, $0.element / 615, space: 3.253305481428569 / 615) }, warnings: [])
        let realPlan = ScoreExtractionPlanner.plan(pages: [realPage], profile: quartet)
        check(realPlan.canApply, "Real sampled geometry has complete assignment")
        let direction = Line(text: "Du Capo sin'ul # e pui il Coda.",
            bounds: CGRect(x: 0.6264534925954826, y: 0.4747642236538404,
                           width: 0.9040697645681388 - 0.6264534925954826,
                           height: 0.4949397336364793 - 0.4747642236538404), confidence: 1)
        let coda = Line(text: ". Coda.", bounds: CGRect(x: 0.08284884115662093, y: 0.5087665793354995,
            width: 0.24127906780050118 - 0.08284884115662093,
            height: 0.5318320948318537 - 0.5087665793354995), confidence: 1)
        let real = Detector.select(from: [coda, direction], page: realPage, plan: realPlan)
        check(real.count == 1 && real[0].anchorStaffID == 7 && real[0].isBelow,
              "p28 navigation stays with system2; following Coda is not navigation")
        let b = real[0].bounds
        check(b[0] * 427 <= 266.4 && b[1] * 615 <= 289.2 && b[2] * 427 >= 387 && b[3] * 615 >= 306.5,
              "Full independent source envelope including destination symbol survives")
        var uncertain = quartet; uncertain.requiresSystemAssignment = true
        let uncertainPlan = ScoreExtractionPlanner.plan(pages: [realPage], profile: uncertain)
        check(Detector.select(from: [direction], page: realPage, plan: uncertainPlan).isEmpty,
              "A variable roster without verified system identity does not share instructions")
        print("\(checks) shared navigation checks passed")
    }
}
