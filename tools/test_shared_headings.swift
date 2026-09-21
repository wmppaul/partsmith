import CoreGraphics
import Foundation

@main enum SharedHeadingTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }
    static func staff(_ id: Int, _ top: Double) -> ScoreObservedStaff {
        ScoreObservedStaff(StaffBandCandidate(id: id,
            staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
            topFraction: top - 0.01, bottomFraction: top + 0.03, confidence: 1, warnings: []))
    }
    static func main() throws {
        typealias Line = ScoreSharedHeadingDetector.TextLine
        let anchor = staff(0, 0.2), size = CGSize(width: 1800, height: 2600)
        let select: ([Line]) -> [ScoreSharedHeading] = {
            ScoreSharedHeadingDetector.select(from: $0, anchor: anchor, previousStaffBottom: 0.12, imageSize: size)
        }
        for name in ["Vivace.", "Andantr.", "Agitato. (Allegretto non troppo.)", "Poco Allegretto con Variazioni.", "Trio.", "Irio.", "Coda."] {
            let line = Line(text: name, bounds: CGRect(x: 0.15, y: 0.175, width: 0.3, height: 0.017), confidence: 1)
            let result = select([line])
            check(result.count == 1, "Printed heading survives a normal scan/OCR variant: \(name)")
            check(CGRect(x: result[0].bounds[0], y: result[0].bounds[1], width: result[0].bounds[2] - result[0].bounds[0], height: result[0].bounds[3] - result[0].bounds[1]).contains(line.bounds), "Entire source heading is padded")
        }
        for name in ["Violine", "Violoncello", "poco cresc.", "con sordino", "pizz.", "dolce", "in tempo", "Doppio", "Johannes Brahms", "Da Capo sin al segno e poi la Coda"] {
            check(select([Line(text: name, bounds: CGRect(x: 0.15, y: 0.175, width: 0.3, height: 0.017), confidence: 1)]).isEmpty,
                  "Staff expressions, credits and end-of-system navigation are not movement headings: \(name)")
        }
        let halves = [Line(text: "Doppio", bounds: CGRect(x: 0.15, y: 0.175, width: 0.07, height: 0.018), confidence: 1),
                      Line(text: "Movimento.", bounds: CGRect(x: 0.23, y: 0.176, width: 0.12, height: 0.018), confidence: 1)]
        let joined = select(halves)
        check(joined.count == 1 && joined[0].bounds[2] > 0.35, "Split OCR words retain the complete two-word heading")
        // Real failure: Vision omitted the upper contours of Agitato's A,
        // dotted i and parentheses. The independently reviewed source oracle
        // starts at25pt, before this OCR word box. Do not fit that guard to OCR.
        let scannedStaff = ScoreObservedStaff(StaffBandCandidate(id: 0,
            staffLineFractions: [0.07328637566722582, 0.07867935811792397, 0.08407441224090965,
                                 0.08946798470757826, 0.09468853717257937],
            topFraction: 0.05501705738495657, bottomFraction: 0.10618618210598058, confidence: 1, warnings: []))
        let scannedHeading = ScoreSharedHeadingDetector.select(from: [Line(text: "AfItato. (Allekrettp non troppo.)",
            bounds: CGRect(x: 0.18200837685804416, y: 0.04505813962553096,
                           width: 0.32845187100497164, height: 0.018979715172800726), confidence: 1)],
            anchor: scannedStaff, previousStaffBottom: 0, imageSize: CGSize(width: 2200, height: 3169))
        check(scannedHeading.count == 1 && scannedHeading[0].bounds[1] * 615 <= 25,
              "Brahms93521p22 Agitato's independently verified upper contours survive")
        var local = halves[0]; local.text = "Allegro"; local.bounds.origin.y = 0.125
        check(select([local]).isEmpty, "A label below the previous staff is not assigned to the next system")
        local.bounds.origin.y = 0.21
        check(select([local]).isEmpty, "Words inside the staff are not shared headings")
        local.bounds.origin.y = 0.175; local.confidence = 0.3
        check(select([local]).isEmpty, "Uncertain OCR cannot manufacture a source-copy obligation")
        local.confidence = 1; local.bounds.origin.x = .nan
        check(select([local]).isEmpty, "Non-finite geometry is rejected")

        let profile = ScoreExtractionProfile(parts: [ScorePartDefinition(id: "v1", name: "Violin I", staffCount: 1),
                                                    ScorePartDefinition(id: "v2", name: "Violin II", staffCount: 1)], cropMode: "compact")
        var page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1800, imageHeight: 2400,
            staves: [staff(0, 0.20), staff(1, 0.28), staff(2, 0.50), staff(3, 0.58)], warnings: [])
        let baseline = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        page.sharedHeadings = joined
        let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        check(plan.canApply && plan.bands.count == 4, "Copying does not change assignment or coverage")
        for item in plan.bands {
            let old = baseline.bands.first { $0.id == item.id }!
            check(item.topFraction == old.topFraction && item.bottomFraction == old.bottomFraction,
                  "Source music crop remains intact")
            if item.systemIndex == 1 { check(item.sourceMarkings.isEmpty, "Heading stays with its own source system") }
            if item.partID == "v2" && item.systemIndex == 0 {
                check(item.sourceMarkings.count == 1, "Lower instrument receives full shared source heading")
                check(item.sourceMarkings[0].rightFraction == 1 - joined[0].bounds[2], "Copied fragment uses right-trim convention")
            }
        }
        page.sharedHeadings = [ScoreSharedHeading(anchorStaffID: 0, bounds: [0.3, 0.201, 0.5, 0.21], recognizedText: "test-contained")]
        let contained = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        check(contained.bands.first!.sourceMarkings.isEmpty, "Already contained heading is not duplicated")
        page.sharedHeadings = [ScoreSharedHeading(anchorStaffID: 0, bounds: [.nan, 0.1, 0.5, 0.12], recognizedText: "bad")]
        check(ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands.allSatisfy { $0.sourceMarkings.isEmpty }, "Malformed metadata cannot poison layout")
        page.sharedHeadings = nil
        let oldJSON = try JSONEncoder().encode(page)
        var object = try JSONSerialization.jsonObject(with: oldJSON) as! [String: Any]
        object.removeValue(forKey: "sharedHeadings")
        let oldPage = try JSONDecoder().decode(ScorePageAnalysis.self, from: JSONSerialization.data(withJSONObject: object))
        check(oldPage.sharedHeadings == nil, "Legacy inventories remain readable")
        print("\(checks) shared heading checks passed")
    }
}
