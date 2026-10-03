import Foundation
import CoreGraphics
import PDFKit
import CryptoKit

/// Regressions for analysis-only structural separation. The fixture pixels
/// remain the independent source; expected notation extents are not derived
/// from the component boxes returned by the analyzer.
@main struct CropQualityTests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ description: String) {
        checks += 1
        guard value() else { fputs("FAIL: \(description)\n", stderr); exit(1) }
    }

    static func fixture(skewDegrees: Double = 0, notationBridge: Bool = false, wideBracket: Bool = false, narrowNotationBridge: Bool = false, rasterScale: Double = 1, localBow: Double = 0, nearFullNotationBridge: Bool = false, localBarline: Bool = false, harmonicBridge: Bool = false, continuousBow: Double = 0, continuousNotationBridge: Bool = false) -> ([ScoreInkComponent], [ScoreObservedStaff]) {
        let width = 720, height = 600, space = 12
        var pixels = [UInt8](repeating: 255, count: width * height)
        func black(_ left: Int, _ top: Int, _ right: Int, _ bottom: Int) {
            for y in top..<bottom { for x in left..<right { pixels[y * width + x] = 0 } }
        }
        var candidates: [StaffBandCandidate] = []
        for (index, top) in [200, 350].enumerated() {
            var fractions: [Double] = []
            for line in 0..<5 { fractions.append(Double(top + line * space) / Double(height)) }
            candidates.append(StaffBandCandidate(id: index, staffLineFractions: fractions,
                topFraction: Double(top - 3 * space) / Double(height),
                bottomFraction: Double(top + 7 * space) / Double(height), confidence: 1, warnings: []))
        }
        for top in [200, 350] {
            for line in 0..<5 { black(25, top + line * space, 700, top + line * space + 1) }
        }
        // The two strokes are separated on most rows. Each used to be mistaken
        // for a notation branch of the other, leaving the whole brace connected.
        let firstRight = wideBracket ? 32 : 24
        let secondLeft = wideBracket ? 37 : 29
        let secondRight = wideBracket ? 42 : 33
        black(20, 200, firstRight, 399)
        black(secondLeft, 200, secondRight, 399)
        black(20, 200, secondRight + 1, 202)
        black(20, 397, secondRight + 1, 399)
        black(160, 170, 164, 228)
        black(152, 221, 168, 229)
        black(162, 170, 206, 174)
        black(350, 379, 366, 387)
        black(362, 350, 366, 386)
        // A horizontal slur/direction touching the system line must survive the
        // analysis split; retain it even when it is detached from either staff.
        black(30, 283, 76, 286)
        if notationBridge {
            // A genuine wide cross-staff figure is not a structural line.
            black(450, 238, 454, 361)
            black(450, 273, 515, 278)
            black(511, 275, 515, 361)
            black(442, 238, 458, 245)
            black(504, 358, 520, 365)
        }
        if narrowNotationBridge {
            // The pair's dilated connector envelope is 26px, matching the wide
            // bracket above. It is still music: its stems enter only part of
            // each staff core, so the core-support requirement must reject it.
            black(450, 238, 460, 361)
            black(465, 275, 472, 361)
            black(450, 273, 472, 278)
            black(442, 238, 460, 245)
            black(466, 358, 480, 365)
        }
        if nearFullNotationBridge {
            // A long cross-staff stem still falls short of both outer staff
            // edges. Local staff curvature must not make it a structural
            // barline. The source noteheads establish musical ownership.
            black(450, 210, 453, 389)
            black(443, 209, 459, 217)
            black(443, 382, 459, 390)
        }
        if localBarline { black(continuousBow == 0 ? 450 : 680, 200, continuousBow == 0 ? 453 : 683, 399) }
        if continuousNotationBridge {
            black(600, 210, 603, 389)
            black(593, 209, 609, 217)
            black(593, 382, 609, 390)
        }
        if harmonicBridge {
            // Outer staff lines are interrupted near a long cross-staff stem.
            // Aligned ledger lines create a shifted five-line pattern, but
            // source noteheads make this musical ink, not a barline.
            for x in 380..<530 { pixels[200 * width + x] = 255; pixels[398 * width + x] = 255 }
            black(380, 260, 530, 261)
            black(380, 338, 530, 339)
            black(450, 212, 453, 387)
            black(443, 212, 459, 220)
            black(443, 379, 459, 387)
        }
        let slope = tan(skewDegrees * .pi / 180)
        if skewDegrees != 0 || localBow != 0 || continuousBow != 0 {
            let original = pixels
            pixels = [UInt8](repeating: 255, count: width * height)
            for x in 0..<width {
                // A local bend shifts the right-hand notation independently
                // of the page-wide skew and the detected central staff lines.
                let bow = localBow * min(1, max(0, (Double(x) - 300) / 100)) + continuousBow * min(1, max(0, (Double(x) - 360) / 240))
                let shift = Int((slope * (Double(x) - Double(width) / 2) + bow).rounded())
                for y in 0..<height where y + shift >= 0 && y + shift < height {
                    pixels[(y + shift) * width + x] = original[y * width + x]
                }
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        var analysisImage = image
        if rasterScale != 1 {
            let outputWidth = Int(Double(width) * rasterScale)
            let outputHeight = Int(Double(height) * rasterScale)
            let context = CGContext(data: nil, width: outputWidth, height: outputHeight, bitsPerComponent: 8,
                bytesPerRow: outputWidth, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
            analysisImage = context.makeImage()!
        }
        return (NativeScorePageAnalyzer.notationComponents(image: analysisImage, candidates: candidates,
            skewDegrees: skewDegrees)!, candidates.map(ScoreObservedStaff.init))
    }

    static func ownershipAlternativeRasterTests() throws {
        // Frozen independent raster from additive-ownership-code-review's
        // raster-relay-v2. A scan gap crosses the upper staff's last line;
        // musical evidence below it must not reassign nearby detached ink.
        let width = 720, height = 760, space = 12
        var pixels = [UInt8](repeating: 255, count: width * height)
        func rect(_ left: Int, _ top: Int, _ right: Int, _ bottom: Int) {
            for y in top..<bottom { for x in left..<right { pixels[y * width + x] = 0 } }
        }
        func head(_ cx: Int, _ cy: Int) {
            for y in (cy - 4)..<(cy + 4) { for x in (cx - 8)..<(cx + 8) {
                let a = (Double(x - cx) + 0.5) / 8, b = (Double(y - cy) + 0.5) / 4
                if a * a + b * b <= 1 { pixels[y * width + x] = 0 }
            } }
        }
        for top in [180, 330] {
            for line in 0..<5 { rect(40, top + space * line, 603, top + space * line + 1) }
            rect(160, top - 20, 163, top + 27)
            head(156, top + 24)
        }
        rect(600, 180, 603, 379)
        head(601, 184)
        head(601, 375)
        for y in 227...229 { for x in 600..<603 { pixels[y * width + x] = 255 } }
        // These source rectangles are annotation surrogates, not recognized
        // musical glyphs or expectations inferred from analyzer components.
        let annotations = [[610, 249, 620, 258], [610, 272, 620, 281], [610, 295, 620, 304]]
        for box in annotations { rect(box[0], box[1], box[2], box[3]) }
        let sourceHash = SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
        check(sourceHash == "1788d75e70532a70258a2e72120860080ceae28ef962ce1b7389e243df1754be",
            "Independent three-row-gap raster changed")
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent)!
        var candidates: [StaffBandCandidate] = []
        for (index, top) in [180, 330].enumerated() {
            let lines: [Double] = (0..<5).map { Double(top + $0 * space) / Double(height) }
            candidates.append(StaffBandCandidate(id: index, staffLineFractions: lines,
                topFraction: Double(top - space) / Double(height),
                bottomFraction: Double(top + 5 * space) / Double(height), confidence: 1, warnings: []))
        }
        let local = NativeScorePageAnalyzer.notationComponents(image: image, candidates: candidates,
            skewDegrees: 0, retainMusicalEvidence: false)!
        let retained = NativeScorePageAnalyzer.notationComponents(image: image, candidates: candidates,
            skewDegrees: 0)!
        let profile = ScoreExtractionProfile(parts: [ScorePartDefinition(id: "one", name: "One", staffCount: 1)],
            cropMode: "compact")
        func plan(_ components: [ScoreInkComponent]) -> ScoreExtractionPlan {
            let page = ScorePageAnalysis(pageIndex: 0, pageWidth: Double(width), pageHeight: Double(height),
                imageWidth: width, imageHeight: height, staves: candidates.map(ScoreObservedStaff.init),
                warnings: [], inkComponents: components)
            return ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        }
        let localPlan = plan(local), retainedPlan = plan(retained)
        check(localPlan.canApply && retainedPlan.canApply && localPlan.bands.count == 2
            && retainedPlan.bands.count == 2, "Three-row-gap fixture must yield two complete systems")
        func contains(_ band: ScorePlannedBand, _ box: [Int]) -> Bool {
            band.leftFraction * Double(width) <= Double(box[0])
                && band.topFraction * Double(height) <= Double(box[1])
                && (1 - band.rightFraction) * Double(width) >= Double(box[2])
                && band.bottomFraction * Double(height) >= Double(box[3])
        }
        for box in annotations.prefix(2) {
            check(contains(localPlan.bands[0], box), "Local analysis must retain source annotation \(box)")
            check(contains(retainedPlan.bands[0], box),
                "Additional musical ownership evidence clipped source annotation \(box)")
        }
        check(local.allSatisfy { retained.contains($0) }, "Musical evidence replaced an ordinary local component")
        check(retained.contains { $0.isOwnershipAlternative == true && $0.staffIDs == [1] },
            "Native raster did not exercise the lower-owned preservation alternative")
        for original in localPlan.bands {
            let updated = retainedPlan.bands.first { $0.id == original.id }!
            check(updated.topFraction <= original.topFraction && updated.bottomFraction >= original.bottomFraction,
                "Added ownership alternatives shrank the existing crop for \(original.id)")
        }
        // The third surrogate, y=295..<304, lies beyond the current detached
        // chain recovery. It was missed before this fix too. Keep its pixels
        // in the frozen source and disclose it; do not turn this test into a
        // claim of complete annotation recall or require the omission forever.
        if !contains(retainedPlan.bands[0], annotations[2]) {
            print("KNOWN LIMIT: three-row-gap source annotation [610,295,620,304] remains outside the upper crop")
        }
    }

    static func main() throws {
        if CommandLine.arguments.contains("--ownership-regression") {
            try ownershipAlternativeRasterTests()
            print("PASS: \(checks) ownership raster checks")
            return
        }
        if CommandLine.arguments.count == 5 && CommandLine.arguments[1] == "--inventory" {
            let source = CommandLine.arguments[2], profilePath = CommandLine.arguments[3]
            let pdf = PDFDocument(url: URL(fileURLWithPath: source))!
            let profile = try JSONDecoder().decode(ScoreExtractionProfile.self,
                from: Data(contentsOf: URL(fileURLWithPath: profilePath)))
            var pages: [ScorePageAnalysis] = []
            for index in 0..<pdf.pageCount {
                pages.append(autoreleasepool {
                    let page = pdf.page(at: index)!, bounds = page.bounds(for: .mediaBox)
                    return NativeScorePageAnalyzer.analyze(pageIndex: index,
                        image: NativeScorePageAnalyzer.render(page)!, pageWidth: bounds.width, pageHeight: bounds.height)
                })
            }
            struct Output: Encodable { var pages: [ScorePageAnalysis]; var plan: ScoreExtractionPlan }
            let output = Output(pages: pages, plan: ScoreExtractionPlanner.plan(pages: pages, profile: profile))
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(output).write(to: URL(fileURLWithPath: CommandLine.arguments[4]))
            print("Analyzed \(pdf.pageCount) pages, \(output.plan.bands.count) bands")
            return
        }
        for rasterScale in [1.0, 0.6, 0.5] {
            for wideBracket in [false, true] {
                for degrees in [0.0, -1.5, 1.5] {
                    let (components, staves) = fixture(skewDegrees: degrees, wideBracket: wideBracket, rasterScale: rasterScale)
                    check(!components.contains { $0.staffIDs.count > 1 },
                        "Parallel bracket strokes falsely join two staves at \(degrees) degrees, raster scale \(rasterScale)")
                    check(components.contains { $0.staffIDs == [0] && $0.bounds[0] < 160.0 / 720 && $0.bounds[1] < 180.0 / 600 },
                        "High target note and beam are retained at \(degrees) degrees, raster scale \(rasterScale)")
                    check(components.contains { $0.bounds[0] <= 34.0 / 720 && $0.bounds[2] >= 76.0 / 720
                        && $0.bounds[1] < 300.0 / 600 && $0.bounds[3] > 270.0 / 600 },
                        "Horizontal notation touching a bracket remains present at \(degrees) degrees, raster scale \(rasterScale)")
                    let profile = ScoreExtractionProfile(parts: [
                        ScorePartDefinition(id: "upper", name: "Upper", staffCount: 1),
                        ScorePartDefinition(id: "lower", name: "Lower", staffCount: 1)
                    ], cropMode: "compact")
                    let page = ScorePageAnalysis(pageIndex: 0, pageWidth: 720, pageHeight: 600,
                        imageWidth: 720, imageHeight: 600, staves: staves, warnings: [], analysisSkewDegrees: degrees,
                        inkComponents: components)
                    let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
                    check(plan.bands.count == 2 && plan.bands[0].bottomFraction * 600 < 350
                        && plan.bands[1].topFraction * 600 > 248,
                        "The compact plan excludes the other staff's core at \(degrees) degrees, raster scale \(rasterScale)")
                }
            }
        }
        let (bridged, _) = fixture(notationBridge: true)
        check(bridged.contains { $0.staffIDs == [0, 1] && $0.bounds[0] > 0.5 && $0.bounds[1] <= 238.0 / 600
            && $0.bounds[3] >= 365.0 / 600 }, "A real cross-staff figure remains complete and ambiguous")
        for rasterScale in [1.0, 0.6, 0.5] {
            for degrees in [0.0, -1.5, 1.5] {
                let (narrowBridge, _) = fixture(skewDegrees: degrees, wideBracket: true, narrowNotationBridge: true, rasterScale: rasterScale)
                check(narrowBridge.contains { $0.staffIDs == [0, 1] && $0.bounds[0] > 0.5
                    && $0.bounds[1] <= 245.0 / 600 && $0.bounds[3] >= 358.0 / 600 },
                    "Comparable-width musical bridge remains complete at \(degrees) degrees, raster scale \(rasterScale)")
            }
        }
        for rasterScale in [1.0, 0.6, 0.5] {
            for degrees in [0.0, -1.5, 1.5] {
                for bow in [7.0, -7.0, 12.0, -12.0, 17.0, -17.0] {
                    let (music, _) = fixture(skewDegrees: degrees, rasterScale: rasterScale,
                        localBow: bow, nearFullNotationBridge: true)
                    let upperGuard = abs(bow) == 7 ? 230.0 : 230.0 + bow
                    let lowerGuard = abs(bow) == 7 ? 370.0 : 370.0 + bow
                    check(music.contains { $0.staffIDs == [0, 1] && $0.bounds[2] >= 459.0 / 720
                        && $0.bounds[1] < upperGuard / 600 && $0.bounds[3] > lowerGuard / 600 },
                        "Near-full musical stem remains ambiguous at bow \(bow), tilt \(degrees), scale \(rasterScale)")
                }
            }
        }
        for bow in [7.0, -7.0] {
            let (structure, _) = fixture(localBow: bow, localBarline: true)
            check(!structure.contains { $0.staffIDs == [0, 1] && $0.bounds[2] > 440.0 / 720 },
                "Intact locally bowed barline separated at bow \(bow)")
        }
        for bow in [13.0, -13.0] {
            let (structure, _) = fixture(localBarline: true, continuousBow: bow)
            check(!structure.contains { $0.staffIDs == [0, 1] && $0.bounds[2] > 590.0 / 720 },
                "Continuously curved five-line path separates true barline at bow \(bow)")
        }
        for rasterScale in [1.0, 0.6, 0.5] {
            for degrees in [0.0, -1.5, 1.5] {
                let (harmonic, _) = fixture(skewDegrees: degrees, rasterScale: rasterScale, harmonicBridge: true)
                let harmonicRetained = harmonic.contains { $0.staffIDs == [0, 1] && $0.bounds[0] > 0.5 && $0.bounds[2] >= 459.0 / 720 }
                check(harmonicRetained,
                    "Ledger-line harmonic remains musical at tilt \(degrees), scale \(rasterScale)")
                for bow in [17.0, -17.0] {
                    let (music, _) = fixture(skewDegrees: degrees, rasterScale: rasterScale,
                        continuousBow: bow, continuousNotationBridge: true)
                    check(music.contains { $0.staffIDs == [0, 1] && $0.bounds[2] >= 609.0 / 720
                        && $0.bounds[1] < (240.0 + bow) / 600 && $0.bounds[3] > (370.0 + bow) / 600 },
                        "Continuous curve does not make a musical stem structural at bow \(bow), tilt \(degrees), scale \(rasterScale)")
                }
            }
        }
        // Curved ledger-line patterns can resemble a different five-line
        // staff. Protect the complete source musical envelope in BOTH parts;
        // component width and detached analysis endpoints are not clipping.
        let bends = [-12.0, -10, -8, -6, -5.5, -5, -4.75, -4.5, -4.25, -4,
                     -3.75, -3.5, -3.25, -3, -2.5, -2, 0, 2, 3, 3.5, 4,
                     4.5, 5, 5.5, 6, 8, 10, 12]
        let harmonicProfile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "upper", name: "Upper", staffCount: 1),
            ScorePartDefinition(id: "lower", name: "Lower", staffCount: 1)
        ], cropMode: "compact")
        for rasterScale in [0.25, 0.3, 0.4, 0.5, 0.6, 1.0, 1.5] {
            for degrees in [-1.5, 0.0, 1.5] {
                for bow in bends {
                    let (components, staves) = fixture(skewDegrees: degrees,
                        rasterScale: rasterScale, localBow: bow, harmonicBridge: true)
                    let slope = tan(degrees * .pi / 180)
                    var sourceTop = Int.max, sourceBottom = Int.min
                    // These are the source stem and two noteheads, before the
                    // known fixture warp. Never derive a guard from analyzer output.
                    for x in 443..<459 {
                        let shift = Int((slope * (Double(x) - 360) + bow).rounded())
                        for y in 212..<387 where (450..<453).contains(x) || y < 220 || y >= 379 {
                            sourceTop = min(sourceTop, y + shift)
                            sourceBottom = max(sourceBottom, y + shift + 1)
                        }
                    }
                    let page = ScorePageAnalysis(pageIndex: 0, pageWidth: 720, pageHeight: 600,
                        imageWidth: 720, imageHeight: 600, staves: staves, warnings: [],
                        analysisSkewDegrees: degrees, inkComponents: components)
                    let plan = ScoreExtractionPlanner.plan(pages: [page], profile: harmonicProfile)
                    check(plan.bands.count == 2 && plan.bands.allSatisfy {
                        $0.topFraction * 600 <= Double(sourceTop)
                            && $0.bottomFraction * 600 >= Double(sourceBottom)
                            && $0.leftFraction * 720 <= 443
                            && (1 - $0.rightFraction) * 720 >= 459
                    }, "Both crops retain the complete curved musical figure at bow \(bow), tilt \(degrees), scale \(rasterScale)")
                }
            }
        }
        try ownershipAlternativeRasterTests()
        print("PASS: \(checks) crop quality checks")
    }
}
