import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

@main enum IndependentProbe {
    static func candidate(_ id: Int, _ top: Double, _ height: Double, _ spacing: Double) -> StaffBandCandidate {
        StaffBandCandidate(id: id, staffLineFractions: (0..<5).map { (top + Double($0) * spacing) / height },
            topFraction: (top - spacing) / height, bottomFraction: (top + 5 * spacing) / height,
            confidence: 1, warnings: [])
    }
    static func hash(_ components: [ScoreInkComponent]) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(components)).map { String(format: "%02x", $0) }.joined()
    }
    static func main() throws {
        let w = 1400, h = 1900
        var pixels = [UInt8](repeating: 255, count: w*h)
        // A deliberately noisy scan surrogate: isolated two-by-two dark specks.
        // No terminal safeguard can fire with a single supplied staff.
        for y in stride(from: 2, to: h-2, by: 10) {
            for x in stride(from: 2, to: w-2, by: 10) {
                for dy in 0..<2 { for dx in 0..<2 { pixels[(y+dy)*w+x+dx] = 0 } }
            }
        }
        let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent)!
        let staves = [candidate(0, 500, Double(h), 12)]
        var measurements: [[String: Any]] = []
        var totalChecks = 0
        for retain in [false, true] {
            var checks = 0
            var lastCheck = Date()
            let start = Date()
            let result = NativeScorePageAnalyzer.notationComponents(image: image, candidates: staves,
                skewDegrees: 0, isCancelled: { checks += 1; lastCheck = Date(); return false },
                retainMusicalEvidence: retain)!
            measurements.append(["retainMusicalEvidence": retain, "seconds": Date().timeIntervalSince(start),
                "components": result.count, "cancellationChecks": checks,
                "secondsAfterLastCancellationCheck": Date().timeIntervalSince(lastCheck),
                "orderedComponentsSHA256": try hash(result)])
            if retain { totalChecks = checks }
        }
        var checks = 0
        var cancellationScheduledFor: Date?
        let cancellationStart = Date()
        let cancelledResult = NativeScorePageAnalyzer.notationComponents(image: image, candidates: staves,
            skewDegrees: 0, isCancelled: {
                checks += 1
                if checks == totalChecks { cancellationScheduledFor = Date().addingTimeInterval(0.01) }
                return cancellationScheduledFor.map { Date() >= $0 } ?? false
            })
        let cancellation: [String: Any] = ["scheduledAfterCalibrationFinalCheck": totalChecks,
            "callbackChecks": checks, "deadlineElapsedBeforeReturn": cancellationScheduledFor.map { Date() >= $0 } ?? false,
            "returnedNil": cancelledResult == nil, "seconds": Date().timeIntervalSince(cancellationStart)]

        // Planner-level non-monotonicity control. This is an explicitly
        // constructed evidence fixture, not a claim about a recognized score.
        let profile = ScoreExtractionProfile(parts: [.init(id: "one", name: "One", staffCount: 1)], cropMode: "compact")
        let observed = [candidate(0, 200, 1000, 10), candidate(1, 600, 1000, 10)].map(ScoreObservedStaff.init)
        let components: [ScoreInkComponent] = [
            .init(bounds: [0.1, 0.20, 0.15, 0.25], staffIDs: [0]),
            .init(bounds: [0.1, 0.26, 0.15, 0.275], staffIDs: []),
            .init(bounds: [0.1, 0.287, 0.15, 0.3], staffIDs: []),
            .init(bounds: [0.1, 0.311, 0.15, 0.324], staffIDs: []),
            .init(bounds: [0.1, 0.60, 0.15, 0.64], staffIDs: [1])]
        var page = ScorePageAnalysis(pageIndex: 0, pageWidth: 1000, pageHeight: 1000,
            imageWidth: 1000, imageHeight: 1000, staves: observed, warnings: [], inkComponents: components)
        let before = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        page.inkComponents!.append(.init(bounds: [0.1, 0.27, 0.15, 0.64], staffIDs: [1]))
        let after = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        let planner: [String: Any] = ["fixtureType": "constructed component-evidence API control, not a native-source reproduction",
            "allOriginalComponentsRetained": components.allSatisfy { page.inkComponents!.contains($0) },
            "beforeCropBottom": before.bands[0].bottomFraction, "afterCropBottom": after.bands[0].bottomFraction,
            "beforeCanApply": before.canApply, "afterCanApply": after.canApply]
        let result: [String: Any] = ["noisyImageDimensions": [w,h], "measurements": measurements,
            "lateCancellation": cancellation, "nonMonotonicPlanner": planner]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print(String(data: data, encoding: .utf8)!)
    }
}
