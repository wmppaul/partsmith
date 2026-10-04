import CoreGraphics
import Foundation
import ImageIO

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
        for name in ["Vivace.", "Andantr.", "Agitato. (Allegretto non troppo.)", "Poco Allegretto con Variazioni.", "Trio.", "Irio.", "Coda.", "Menuetto.", "MENUETTO",
                     "2da volta rit.", "1ma volta rallentando", "2ª volta ritard.", "II. volta poco rit.", "Seconda volta molto rall.", "3a volta accelerando"] {
            let line = Line(text: name, bounds: CGRect(x: 0.15, y: 0.175, width: 0.3, height: 0.017), confidence: 1)
            let result = select([line])
            check(result.count == 1, "Printed heading survives a normal scan/OCR variant: \(name)")
            check(CGRect(x: result[0].bounds[0], y: result[0].bounds[1], width: result[0].bounds[2] - result[0].bounds[0], height: result[0].bounds[3] - result[0].bounds[1]).contains(line.bounds), "Entire source heading is padded")
        }
        for name in ["Violine", "Violoncello", "poco cresc.", "con sordino", "pizz.", "dolce", "in tempo", "Doppio", "Johannes Brahms", "Da Capo sin al segno e poi la Coda", "Menu", "Menuetxo.", "Menuetto Viola",
                     "rit.", "poco rit.", "2da volta", "2da volta pizz.", "2da volta p", "2da volta con sordino", "2da volta rit. Violine", "volta rit.", "0a volta rit."] {
            check(select([Line(text: name, bounds: CGRect(x: 0.15, y: 0.175, width: 0.3, height: 0.017), confidence: 1)]).isEmpty,
                  "Staff expressions, credits and end-of-system navigation are not movement headings: \(name)")
        }
        let halves = [Line(text: "Doppio", bounds: CGRect(x: 0.15, y: 0.175, width: 0.07, height: 0.018), confidence: 1),
                      Line(text: "Movimento.", bounds: CGRect(x: 0.23, y: 0.176, width: 0.12, height: 0.018), confidence: 1)]
        let joined = select(halves)
        check(joined.count == 1 && joined[0].bounds[2] > 0.35, "Split OCR words retain the complete two-word heading")
        let repeatWords = [Line(text: "2da", bounds: CGRect(x: 0.40, y: 0.172, width: 0.035, height: 0.020), confidence: 1),
                           Line(text: "volta rit.", bounds: CGRect(x: 0.44, y: 0.177, width: 0.10, height: 0.015), confidence: 1)]
        let repeatHeading = select(repeatWords)
        check(repeatHeading.count == 1 && repeatHeading[0].bounds[1] < 0.172
              && repeatHeading[0].bounds[2] > 0.54,
              "Separated repeat ordinal and tempo retain the complete original source instruction")
        var localRepeat = repeatWords
        localRepeat[0].bounds.origin.y += 0.05; localRepeat[1].bounds.origin.y += 0.05
        check(select(localRepeat).isEmpty, "Numbered tempo inside an instrument staff is not copied across the ensemble")
        localRepeat = repeatWords; localRepeat[0].confidence = 0.4
        check(select(localRepeat).isEmpty, "Uncertain ordinal cannot make an otherwise unrecognized tempo into a shared heading")
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

        var samples = [UInt8](repeating: 255, count: 100 * 100)
        samples[30 * 100 + 20] = 0
        samples[31 * 100 + 21] = 254 // very faint antialiasing remains evidence
        samples[80 * 100 + 80] = 0 // outside this padded copy
        let provider = CGDataProvider(data: Data(samples) as CFData)!
        let raster = CGImage(width: 100, height: 100, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: 100, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let measuredPixels = ScoreSharedHeadingDetector.measuredInkBounds(in: raster, bounds: [0.1, 0.2, 0.5, 0.5])
        check(measuredPixels == [0.19, 0.29, 0.23, 0.33], "Original dark and faint source pixels are measured in top-down coordinates with one-pixel guard")
        check(ScoreSharedHeadingDetector.measuredInkBounds(in: raster, bounds: [0, 0, 0.1, 0.1]) == nil,
              "Blank source gives no evidence for suppression")
        check(ScoreSharedHeadingDetector.measuredInkBounds(in: raster, bounds: [.nan, 0, 1, 1]) == nil,
              "Invalid source rectangle gives no evidence for suppression")

        let serifURL = URL(fileURLWithPath: "Tests/quality_control/heading-ink-containment/brahms-p22-serif-negative.png")
        let serifSource = CGImageSourceCreateWithURL(serifURL as CFURL, nil)!
        let serifImage = CGImageSourceCreateImageAtIndex(serifSource, 0, nil)!
        let serifInk = ScoreSharedHeadingDetector.measuredInkBounds(in: serifImage, bounds: [0, 0, 1, 1])!
        let ocrBasedCropTop = (27.71075586970154 - 24.4) * 10 / Double(serifImage.height)
        check(serifInk[1] < ocrBasedCropTop,
              "Real Brahms A cap extends above OCR-only crop: complete source copy must remain")

        let profile = ScoreExtractionProfile(parts: [ScorePartDefinition(id: "v1", name: "Violin I", staffCount: 1),
                                                    ScorePartDefinition(id: "v2", name: "Violin II", staffCount: 1)], cropMode: "compact")
        var page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1800, imageHeight: 2400,
            staves: [staff(0, 0.20), staff(1, 0.28), staff(2, 0.50), staff(3, 0.58)], warnings: [])
        let baseline = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        page.sharedHeadings = repeatHeading
        let repeatPlan = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        check(repeatPlan.canApply && repeatPlan.bands.map(\.candidateIDs) == baseline.bands.map(\.candidateIDs),
              "Copying a conditional tempo preserves every assigned staff")
        check(repeatPlan.bands.filter { $0.systemIndex == 0 }.allSatisfy {
            let r = repeatHeading[0].bounds
            let contained = $0.topFraction <= r[1] && $0.bottomFraction >= r[3]
                && $0.leftFraction <= r[0] && 1 - $0.rightFraction >= r[2]
            let copied = $0.sourceMarkings.contains {
                $0.topFraction <= r[1] && $0.bottomFraction >= r[3]
                    && $0.leftFraction <= r[0] && 1 - $0.rightFraction >= r[2] - 1e-12
            }
            return contained || copied
        }, "Every part at the entrance retains or receives the entire numbered tempo source block")
        check(repeatPlan.bands.first { $0.systemIndex == 0 && $0.partID == "v2" }!.sourceMarkings.count == 1,
              "A lower part outside the original heading receives one complete copy")
        check(repeatPlan.bands.filter { $0.systemIndex == 1 }.allSatisfy { $0.sourceMarkings.isEmpty },
              "The conditional tempo does not leak to later systems")
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
        let own = baseline.bands.first!
        let padded = [0.2, own.topFraction - 0.01, 0.4, own.topFraction + 0.02]
        let complete = [0.21, own.topFraction + 0.002, 0.39, own.topFraction + 0.015]
        var measured = ScoreSharedHeading(anchorStaffID: 0, bounds: padded, recognizedText: "Measured")
        measured.inkBounds = complete
        page.sharedHeadings = [measured]
        check(ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands.first!.sourceMarkings.isEmpty,
              "Complete source ink inside own crop suppresses padding-only duplicate")
        check(ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands[1].sourceMarkings.count == 1,
              "Lower recipient still receives complete padded source copy")
        measured.inkBounds = [0.21, own.topFraction - 0.001, 0.39, own.topFraction + 0.015]
        page.sharedHeadings = [measured]
        check(ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands.first!.sourceMarkings.count == 1,
              "A real glyph outside main crop retains complete padded copy")
        measured.inkBounds = nil
        page.sharedHeadings = [measured]
        check(ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands.first!.sourceMarkings.count == 1,
              "Missing source-raster evidence cannot suppress a copy")
        measured.inkBounds = [.nan, 0, 1, 1]
        page.sharedHeadings = [measured]
        check(ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands.first!.sourceMarkings.count == 1,
              "Malformed source-raster evidence cannot suppress a copy")
        measured.inkBounds = complete
        measured.bounds = [0.6, own.topFraction - 0.01, 0.8, own.topFraction + 0.02]
        page.sharedHeadings = [measured]
        check(ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands.first!.sourceMarkings.count == 1,
              "Disjoint valid ink metadata inside main crop cannot suppress a different source heading")
        page.sharedHeadings = nil
        let oldJSON = try JSONEncoder().encode(page)
        var object = try JSONSerialization.jsonObject(with: oldJSON) as! [String: Any]
        object.removeValue(forKey: "sharedHeadings")
        let oldPage = try JSONDecoder().decode(ScorePageAnalysis.self, from: JSONSerialization.data(withJSONObject: object))
        check(oldPage.sharedHeadings == nil, "Legacy inventories remain readable")
        print("\(checks) shared heading checks passed")
    }
}
