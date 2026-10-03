import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

@main enum HairpinIndependentChallenge {
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let directory = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let width = 800, height = 720, space = 10, tops = [230, 450]
        let names = ["musical-diminuendo", "musical-crescendo", "same-pixel-footer", "left-margin-chevron",
            "right-margin-chevron", "near-footer", "distant-footer", "narrow-chevron", "closed-diamond",
            "between-staves", "reordered-staff-ids", "unobserved-later-staff"]
        let positives = Set(["musical-diminuendo", "musical-crescendo", "reordered-staff-ids"])
        var records: [[String: Any]] = []
        for name in names {
            var pixels = [UInt8](repeating: 255, count: width * height)
            var owned = [UInt8](repeating: 255, count: width * height)
            func mark(_ x: Int, _ y: Int, _ target: Bool = false) {
                if x >= 0 && x < width && y >= 0 && y < height {
                    pixels[y * width + x] = 0
                    if target { owned[y * width + x] = 0 }
                }
            }
            func rect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ target: Bool = false) {
                for y in y0..<y1 { for x in x0..<x1 { mark(x, y, target) } }
            }
            func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ target: Bool = false) {
                for x in x0...x1 {
                    let t = Double(x - x0) / Double(max(1, x1 - x0))
                    let y = Int((Double(y0) + Double(y1 - y0) * t).rounded())
                    mark(x, y, target); mark(x, y + 1, target)
                }
            }
            for top in tops {
                for index in 0..<5 { rect(150, top + index * space, 650, top + index * space + 1) }
                rect(220, top - 14, 223, top + 26, top == 450)
                rect(213, top + 21, 224, top + 27, top == 450)
            }
            if name == "unobserved-later-staff" {
                for index in 0..<5 { rect(150, 610 + index * space, 650, 611 + index * space) }
                rect(220, 600, 223, 637); rect(213, 631, 224, 638)
            }
            let x0 = name == "left-margin-chevron" ? 10 : name == "right-margin-chevron" ? 665 : 300
            let x1 = x0 + (name == "narrow-chevron" ? 26 : 124)
            let y0 = name == "near-footer" ? 549 : name == "distant-footer" ? 557 : name == "between-staves" ? 335 : 535
            let target = positives.contains(name)
            if name == "closed-diamond" {
                let middle = (x0 + x1) / 2
                line(x0, y0 + 8, middle, y0); line(x0, y0 + 8, middle, y0 + 16)
                line(middle, y0, x1, y0 + 8); line(middle, y0 + 16, x1, y0 + 8)
            } else if name == "musical-crescendo" {
                line(x0, y0 + 8, x1, y0, target); line(x0, y0 + 8, x1, y0 + 16, target)
            } else {
                line(x0, y0, x1, y0 + 8, target); line(x0, y0 + 16, x1, y0 + 8, target)
            }
            func image(_ bytes: [UInt8]) -> CGImage {
                CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: .init(rawValue: 0),
                    provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil,
                    shouldInterpolate: false, intent: .defaultIntent)!
            }
            for (suffix, bytes) in [("", pixels), ("-lower-owner", owned)] {
                let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(name + suffix + ".png") as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, image(bytes), nil)
                precondition(CGImageDestinationFinalize(destination))
            }
            var staves = tops.enumerated().map { index, top in
                StaffBandCandidate(id: index == 0 ? 51 : 7,
                    staffLineFractions: (0..<5).map { Double(top + $0 * space) / Double(height) },
                    topFraction: Double(top - 30) / Double(height), bottomFraction: Double(top + 70) / Double(height),
                    confidence: 1, warnings: [])
            }
            if name == "reordered-staff-ids" { staves.reverse() }
            let source = image(pixels)
            let before = BaselineAnalyzer.notationComponents(image: source, candidates: staves, skewDegrees: 0)!
            let after = NativeScorePageAnalyzer.notationComponents(image: source, candidates: staves, skewDegrees: 0)!
            let disabled = NativeScorePageAnalyzer.notationComponents(image: source, candidates: staves, skewDegrees: 0, retainMusicalEvidence: false)!
            let profile = ScoreExtractionProfile(parts: [.init(id: "upper", name: "Upper", staffCount: 1),
                .init(id: "lower", name: "Lower", staffCount: 1)], cropMode: "compact")
            func plan(_ components: [ScoreInkComponent]) -> ScoreExtractionPlan {
                ScoreExtractionPlanner.plan(pages: [.init(pageIndex: 0, pageWidth: Double(width), pageHeight: Double(height),
                    imageWidth: width, imageHeight: height, staves: staves.map(ScoreObservedStaff.init), warnings: [], inkComponents: components)], profile: profile)
            }
            let old = plan(before), new = plan(after)
            let oldLower = old.bands.first { $0.partID == "lower" }!, newLower = new.bands.first { $0.partID == "lower" }!
            func lost(_ band: ScorePlannedBand) -> Int {
                owned.indices.filter { owned[$0] == 0 && (Double($0 / width) < band.topFraction * Double(height) - 1e-9
                    || Double($0 / width + 1) > band.bottomFraction * Double(height) + 1e-9) }.count
            }
            let additions = after.filter { !before.contains($0) }
            var ordinaryPreserved = before.allSatisfy { after.contains($0) }
            ordinaryPreserved = ordinaryPreserved && after.filter { $0.isOwnershipAlternative != true } == before.filter { $0.isOwnershipAlternative != true }
            let started = Date()
            for _ in 0..<8 { _ = BaselineAnalyzer.notationComponents(image: source, candidates: staves, skewDegrees: 0) }
            let baseSeconds = Date().timeIntervalSince(started), candidateStart = Date()
            for _ in 0..<8 { _ = NativeScorePageAnalyzer.notationComponents(image: source, candidates: staves, skewDegrees: 0) }
            let candidateSeconds = Date().timeIntervalSince(candidateStart)
            records.append(["name": name, "positive": target,
                "sourceSHA256": SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined(),
                "sourceOwnerMaskSHA256": SHA256.hash(data: Data(owned)).map { String(format: "%02x", $0) }.joined(),
                "ordinaryComponentsPreserved": ordinaryPreserved, "disabledComponentsExact": disabled == before,
                "allCropsContainPrevious": old.bands.allSatisfy { band in new.bands.contains { $0.id == band.id && $0.topFraction <= band.topFraction && $0.bottomFraction >= band.bottomFraction } },
                "addedComponents": try JSONSerialization.jsonObject(with: JSONEncoder().encode(additions)),
                "beforeCrop": [oldLower.topFraction * Double(height), oldLower.bottomFraction * Double(height)],
                "afterCrop": [newLower.topFraction * Double(height), newLower.bottomFraction * Double(height)],
                "beforeLostPixels": lost(oldLower), "afterLostPixels": lost(newLower),
                "timingEightBaselineSeconds": baseSeconds, "timingEightCandidateSeconds": candidateSeconds])
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]).write(to: output)
        print("Completed \(records.count) independent frozen challenges")
    }
}
