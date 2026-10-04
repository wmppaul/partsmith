import AppKit
import Foundation
import PDFKit

@main enum SystemBarCountTests {
    static var checks = 0
    static var failures: [String] = []
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !ok() { failures.append(message); print("FAIL: \(message)") }
    }

    struct Control {
        var image: CGImage
        var staves: [ScoreObservedStaff]
    }
    static func control(staffCount: Int = 3, doubleBar: Bool = false,
                        missingClosure: Bool = false, extraStems: Bool = false,
                        disagree: Bool = false, skew: Double = 0,
                        connectors: Bool = true, closingConnectorOnly: Bool = false) -> Control {
        let width = 800, height = 520, space = 8
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
        pixels.initialize(repeating: 255, count: width * height)
        func black(_ x: Int, _ y: Int) {
            let shiftedY = y + Int((tan(skew * .pi / 180) * Double(x - width / 2)).rounded())
            if x >= 0 && x < width && shiftedY >= 0 && shiftedY < height { pixels[shiftedY * width + x] = 0 }
        }
        func vertical(_ x: Int, _ top: Int, _ bottom: Int) {
            for y in top...bottom { for dx in 0...1 { black(x + dx, y) } }
        }
        var staves: [ScoreObservedStaff] = []
        for index in 0..<staffCount {
            let top = 70 + index * 120
            let lines = (0..<5).map { top + $0 * space }
            for y in lines { for x in 80...740 { black(x, y) } }
            let boundaries = disagree && index == 1 ? [80, 330, 550, 740] : [80, 260, 440, 620, 740]
            for x in boundaries where !(missingClosure && x == 740) { vertical(x, top, top + 4 * space) }
            if doubleBar { vertical(445, top, top + 4 * space) }
            if extraStems && index == 0 { vertical(350, top - 10, top + 4 * space) }
            staves.append(ScoreObservedStaff(StaffBandCandidate(id: index,
                staffLineFractions: lines.map { Double($0) / Double(height) },
                topFraction: Double(top - 10) / Double(height), bottomFraction: Double(top + 42) / Double(height),
                confidence: 1, warnings: [])))
        }
        if connectors && !disagree && staffCount > 1 {
            for x in [80, 260, 440, 620, 740] where !(missingClosure && x == 740)
                && (!closingConnectorOnly || x == 740) {
                vertical(x, 70, 70 + (staffCount - 1) * 120 + 4 * space)
            }
            if doubleBar { vertical(445, 70, 70 + (staffCount - 1) * 120 + 4 * space) }
        }
        return Control(image: context.makeImage()!, staves: staves)
    }

    static func main() throws {
        let output = URL(fileURLWithPath: ".build/system-bar-count")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let plain = control()
        let ordinary = ScoreSystemBarCounter.suggest(in: plain.image, staves: plain.staves)
        check(ordinary?.barCount == 4, "Four complete measures are counted once across three staves")
        check(ordinary?.boundaryFractions.count == 5, "Four measures expose five reviewable boundaries")
        check(ordinary?.explanation.contains("pickups") == true, "Suggestion explains its rhythmic limitation")
        for (name, sample) in [("double bar", control(doubleBar: true)),
                               ("unshared note stem", control(extraStems: true)),
                               ("grand staff", control(staffCount: 2)),
                               ("modest scan skew", control(skew: 1.2))] {
            let result = ScoreSystemBarCounter.suggest(in: sample.image, staves: sample.staves,
                                                       skewDegrees: name == "modest scan skew" ? 1.2 : 0)
            check(result?.barCount == 4, "\(name) does not change the measure count")
        }
        for (name, sample) in [("missing final barline", control(missingClosure: true)),
                               ("conflicting staves", control(staffCount: 2, disagree: true)),
                               ("unsupported single staff", control(staffCount: 1)),
                               ("two disconnected staves", control(staffCount: 2, connectors: false)),
                               ("only closing bar connected", control(closingConnectorOnly: true))] {
            check(ScoreSystemBarCounter.suggest(in: sample.image, staves: sample.staves) == nil,
                  "\(name) leaves the bar count manual")
        }
        check(ScoreSystemBarCounter.suggest(in: plain.image, staves: []) == nil, "Empty selection is rejected")
        check(ScoreSystemBarCounter.suggest(in: plain.image, staves: [plain.staves[0], plain.staves[0]]) == nil,
              "Duplicating a staff cannot supply corroboration")
        check(ScoreSystemBarCounter.suggest(in: plain.image, staves: plain.staves, skewDegrees: .nan) == nil,
              "Invalid skew is rejected")
        check(ScoreSystemBarCounter.suggest(in: plain.image, staves: plain.staves, isCancelled: { true }) == nil,
              "Cancelled work returns no result")
        var invalid = plain.staves
        invalid[0].staffLineFractions = [.nan, 0.2, 0.3, 0.4, 0.5]
        check(ScoreSystemBarCounter.suggest(in: plain.image, staves: invalid) == nil, "Invalid staff coordinates are rejected")

        let mozartURL = URL(fileURLWithPath: "Tests/extraction/sources/mozart-k488-page-17.pdf")
        let mozart = PDFDocument(url: mozartURL)!
        let image = NativeScorePageAnalyzer.render(mozart.page(at: 0)!)!
        let found = StaffBandDetector.detect(in: image)
        check(found.candidates.count == 18, "Mozart page 17 retains eighteen detected staves")
        var realResults: [[String: Any]] = []
        let cases: [(String, ClosedRange<Int>, Int)] = [
            ("Mozart page 17 system 1, bars 144–149", 0...5, 6),
            ("Mozart page 17 system 2, bars 150–152", 6...7, 3),
            ("Mozart page 17 system 3, bars 153–156", 8...17, 4)
        ]
        for (name, staffIDs, expected) in cases {
            let selection = found.candidates.filter { staffIDs.contains($0.id) }.map(ScoreObservedStaff.init)
            var diagnostics: [String] = []
            let result = ScoreSystemBarCounter.suggest(in: image, staves: selection,
                skewDegrees: found.estimatedSkewDegrees, diagnostic: { diagnostics.append($0) })
            check(result?.barCount == expected, "\(name) suggests \(expected), got \(String(describing: result?.barCount))")
            realResults.append(["case": name, "expected": expected, "actual": result?.barCount as Any? ?? NSNull(),
                                "boundaries": result?.boundaryFractions as Any? ?? NSNull(), "diagnostics": diagnostics])
        }
        // The existing scan fixture preserves the exact original scanned page.
        // Its first system's flute staff has thirteen printed bars, cross-checked
        // against the barlines shared by the orchestral staves below it.
        let scan = PDFDocument(url: URL(fileURLWithPath: "Tests/extraction/sources/beethoven-op67-pages-7-8.pdf"))!
        let scanImage = NativeScorePageAnalyzer.render(scan.page(at: 0)!)!
        let scanStaffs = StaffBandDetector.detect(in: scanImage)
        let scanSelection = scanStaffs.candidates.map(ScoreObservedStaff.init)
        var scanDiagnostics: [String] = []
        let scanResult = ScoreSystemBarCounter.suggest(in: scanImage, staves: scanSelection,
            skewDegrees: scanStaffs.estimatedSkewDegrees, diagnostic: { scanDiagnostics.append($0) })
        check(scanResult?.barCount == 13, "Scanned Beethoven opening system suggests thirteen bars")
        print("Scanned Beethoven suggestion:", scanResult as Any)
        realResults.append(["case": "Beethoven original source page 7", "actual": scanResult?.barCount as Any? ?? NSNull(),
                            "diagnostics": scanDiagnostics])
        try JSONSerialization.data(withJSONObject: ["checks": checks, "failures": failures, "realScores": realResults],
            options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
        print("System bar-count checks: \(checks), failures: \(failures.count)")
        if !failures.isEmpty { exit(1) }
    }
}
