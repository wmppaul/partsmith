import Foundation
import CoreGraphics
import ImageIO
import PDFKit
import CryptoKit

@main enum Diagnose {
    struct Case: Decodable {
        var id: String
        var source: String
        var sourceSHA256: String
        var page: ScorePageAnalysis
        var imagePath: String?
    }
    static func main() throws {
        let args = CommandLine.arguments
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        let output = URL(fileURLWithPath: args[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var results: [[String: Any]] = []
        for item in cases {
            try autoreleasepool {
                let source = try Data(contentsOf: URL(fileURLWithPath: item.source))
                precondition(SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined() == item.sourceSHA256)
                let image: CGImage
                if let path = item.imagePath {
                    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
                    image = CGImageSourceCreateImageAtIndex(src, 0, nil)!
                } else {
                    let document = PDFDocument(data: source)!
                    image = NativeScorePageAnalyzer.render(document.page(at: item.page.pageIndex)!)!
                }
                let candidates = item.page.staves.map { staff in
                    StaffBandCandidate(id: staff.id, staffLineFractions: staff.staffLineFractions,
                        topFraction: staff.topFraction, bottomFraction: staff.bottomFraction,
                        confidence: staff.confidence, warnings: staff.warnings)
                }
                NativeScorePageAnalyzer.witnessDiagnostics = []
                let components = NativeScorePageAnalyzer.notationComponents(image: image, candidates: candidates,
                    skewDegrees: item.page.analysisSkewDegrees ?? 0)!
                let actual = try components.map { String(data: try encoder.encode($0), encoding: .utf8)! }.sorted()
                let expected = try (item.page.inkComponents ?? []).map { String(data: try encoder.encode($0), encoding: .utf8)! }.sorted()
                let safeID = item.id.replacingOccurrences(of: ":", with: "-")
                let imageURL = output.appendingPathComponent(safeID + ".png")
                let sink = CGImageDestinationCreateWithURL(imageURL as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(sink, image, nil); precondition(CGImageDestinationFinalize(sink))
                results.append(["id": item.id, "source": item.source, "sourceSHA256": item.sourceSHA256,
                    "sourcePageIndex": item.page.pageIndex, "imagePath": imageURL.path,
                    "componentsEqualFrozenMultiset": actual == expected,
                    "componentCount": components.count, "witnesses": NativeScorePageAnalyzer.witnessDiagnostics])
                print(item.id, "components match", actual == expected, "witnesses", NativeScorePageAnalyzer.witnessDiagnostics.count)
                fflush(stdout)
            }
        }
        try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("witnesses.json"))
    }
}
