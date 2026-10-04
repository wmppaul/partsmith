import Foundation
import CoreGraphics
import PDFKit
import ImageIO
import CryptoKit

@main enum OnePage {
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let source = URL(fileURLWithPath: "sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf")
        let sourceData = try Data(contentsOf: source)
        let hash = SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined()
        precondition(hash == "662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a")
        let pdf = PDFDocument(data: sourceData)!
        let page = pdf.page(at: 33)!
        let bounds = page.bounds(for: .mediaBox)
        let start = Date()
        guard let image = NativeScorePageAnalyzer.render(page) else { fatalError("Native rendering failed") }
        let analysis = NativeScorePageAnalyzer.analyze(pageIndex: 33, image: image,
            pageWidth: bounds.width, pageHeight: bounds.height)
        let profile = try JSONDecoder().decode(ScoreExtractionProfile.self, from: Data(contentsOf:
            URL(fileURLWithPath: "Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json")))
        let plan = ScoreExtractionPlanner.plan(pages: [analysis], profile: profile)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(analysis).write(to: output)
        let folder = output.deletingLastPathComponent()
        try encoder.encode(plan).write(to: folder.appendingPathComponent("plan.json"))
        let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("native-source.png") as CFURL,
            "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination))
        print("Source \(hash), \(image.width)x\(image.height), skew \(analysis.analysisSkewDegrees ?? 0), bands \(plan.bands.count), canApply \(plan.canApply), elapsed \(Date().timeIntervalSince(start)) seconds")
    }
}
