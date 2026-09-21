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

    static func fixture(skewDegrees: Double = 0, notationBridge: Bool = false, wideBracket: Bool = false, narrowNotationBridge: Bool = false, rasterScale: Double = 1) -> ([ScoreInkComponent], [ScoreObservedStaff]) {
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
        let slope = tan(skewDegrees * .pi / 180)
        if skewDegrees != 0 {
            let original = pixels
            pixels = [UInt8](repeating: 255, count: width * height)
            for x in 0..<width {
                let shift = Int((slope * (Double(x) - Double(width) / 2)).rounded())
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

    static func main() throws {
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
        print("PASS: \(checks) crop quality checks")
    }
}
