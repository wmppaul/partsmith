import Foundation
import CoreGraphics
import PDFKit

/// Regressions for analysis-only structural separation. The fixture pixels
/// remain the independent source; expected notation extents are not derived
/// from the component boxes returned by the analyzer.
@main struct CropQualityTests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ description: String) {
        checks += 1
        guard value() else { fputs("FAIL: \(description)\n", stderr); exit(1) }
    }

    static func fixture(skewDegrees: Double = 0, notationBridge: Bool = false, wideBracket: Bool = false, narrowNotationBridge: Bool = false, rasterScale: Double = 1, localBow: Double = 0, nearFullNotationBridge: Bool = false, localBarline: Bool = false, harmonicBridge: Bool = false, continuousBow: Double = 0, continuousNotationBridge: Bool = false, internalBarlineGap: Bool = false, nearEdgeInset: Int? = nil) -> ([ScoreInkComponent], [ScoreObservedStaff]) {
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
        if internalBarlineGap {
            // Full-height structural stroke with an interior scan break.
            // All five staff lines and both true outer endpoints remain.
            black(680, 200, 683, 399)
            for y in 388..<396 { for x in 680..<683 { pixels[y * width + x] = 255 } }
        }
        if let inset = nearEdgeInset {
            // A genuine cross-staff figure starts/ends just inside the true
            // outer lines, so occupancy alone may exceed 88% in both cores.
            black(600, 200 + inset, 603, 399 - inset)
            black(593, 200 + inset, 609, 208 + inset)
            black(593, 391 - inset, 609, 399 - inset)
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

    struct Result: Codable {
        var kind: String, scale: Double, tilt: Double, inset: Int?
        var sourceEnvelope: [Double]?
        var bothCropsPreserveSource: Bool?
        var preservesUpperTarget: Bool
        var ambiguousEdgeStructure: Bool
        var bounds: [[Double]]
    }
    static func main() throws {
        var results: [Result] = []
        let profile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "upper", name: "Upper", staffCount: 1),
            ScorePartDefinition(id: "lower", name: "Lower", staffCount: 1)
        ], cropMode: "compact")
        for scale in [0.5, 0.6, 1.0, 1.5] {
            for tilt in [-1.5, 0.0, 1.5] {
                for inset in [nil, 2, 3, 4, 5] as [Int?] {
                    let (ink, staves) = fixture(skewDegrees: tilt, rasterScale: scale,
                        internalBarlineGap: inset == nil, nearEdgeInset: inset)
                    let page = ScorePageAnalysis(pageIndex: 0, pageWidth: 720, pageHeight: 600,
                        imageWidth: Int(720 * scale), imageHeight: Int(600 * scale), staves: staves,
                        warnings: [], analysisSkewDegrees: tilt, inkComponents: ink)
                    let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
                    var envelope: [Double]? = nil, preserved: Bool? = nil
                    if let inset {
                        var minY = Int.max, maxY = Int.min
                        for x in 593..<609 {
                            let shift = Int((tan(tilt * .pi / 180) * (Double(x) - 360)).rounded())
                            for y in (200 + inset)..<(399 - inset)
                                where (600..<603).contains(x) || y < 208 + inset || y >= 391 - inset {
                                minY = min(minY, y + shift); maxY = max(maxY, y + shift + 1)
                            }
                        }
                        envelope = [593, Double(minY), 609, Double(maxY)]
                        preserved = plan.bands.count == 2 && plan.bands.allSatisfy {
                            $0.topFraction * 600 <= Double(minY) && $0.bottomFraction * 600 >= Double(maxY)
                        }
                    }
                    let highNotePreserved = ink.contains { $0.staffIDs == [0] && $0.bounds[0] < 160.0 / 720 && $0.bounds[1] < 180.0 / 600 }
                    results.append(Result(kind: inset == nil ? "interior-gap barline" : "edge-terminating musical stem",
                        scale: scale, tilt: tilt, inset: inset, sourceEnvelope: envelope,
                        bothCropsPreserveSource: preserved, preservesUpperTarget: highNotePreserved,
                        ambiguousEdgeStructure: ink.contains { $0.staffIDs == [0,1] && $0.bounds[2] >= 680.0 / 720 },
                        bounds: plan.bands.map { [$0.topFraction * 600,$0.bottomFraction * 600] }))
                }
            }
        }
        let e = JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys]
        try e.encode(results).write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
        print("Measured \(results.count) source-defined controls")
        print("Musical preservation failures: \(results.filter { $0.bothCropsPreserveSource == false }.count) / \(results.filter { $0.inset != nil }.count)")
        print("Broken structural strokes still ambiguous: \(results.filter { $0.inset == nil && $0.ambiguousEdgeStructure }.count) / \(results.filter { $0.inset == nil }.count)")
    }
}
