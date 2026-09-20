import AppKit
import CoreGraphics
import CoreText
import CryptoKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

struct NativeScoreInventory: Codable {
    var schemaVersion = 1
    var source: String
    var sourceSHA256: String
    var coordinateSystem = "Top-down fractions of the unrectified native image; multiply y by pageHeight for source PDF points. Candidate IDs and pageIndex are zero-based."
    var pages: [ScorePageAnalysis]
}

@main
enum ScoreExtractionBatch {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { throw failure("Use inventory --source PDF --out DIRECTORY, or plan --inventory JSON --profile JSON [--overrides JSON] --out JSON") }
        func option(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if command == "inventory" {
            guard let input = option("--source"), let destination = option("--out") else { throw failure("Missing source/output") }
            let url = URL(fileURLWithPath: input), out = URL(fileURLWithPath: destination)
            let data = try Data(contentsOf: url)
            guard let document = PDFDocument(data: data) else { throw failure("Cannot open PDF") }
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            var pages: [ScorePageAnalysis] = []
            for index in 0..<document.pageCount {
                let analysis: ScorePageAnalysis = try autoreleasepool {
                    guard let page = document.page(at: index), let image = NativeScorePageAnalyzer.render(page) else { throw failure("Cannot render page \(index + 1)") }
                    let bounds = page.bounds(for: .mediaBox)
                    var result = NativeScorePageAnalyzer.analyze(pageIndex: index, image: image, pageWidth: bounds.width, pageHeight: bounds.height)
                    if page.rotation != 0 || page.bounds(for: .cropBox) != bounds {
                        result.warnings.append("Nonstandard rotation or CropBox: source-coordinate overrides need explicit normalization review.")
                    }
                    if index == 0, let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        result.textSuggestions = [String(text.prefix(4000))]
                    }
                    try writeImage(image, candidates: [], to: out.appendingPathComponent(String(format: "page-%03d.png", index + 1)))
                    try writeImage(image, candidates: result.staves, to: out.appendingPathComponent(String(format: "page-%03d-staves.png", index + 1)))
                    return result
                }
                pages.append(analysis)
                print("\(url.lastPathComponent) page \(index + 1): \(analysis.staves.count) staves")
                fflush(stdout)
            }
            let inventory = NativeScoreInventory(source: url.path, sourceSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), pages: pages)
            try encoder.encode(inventory).write(to: out.appendingPathComponent("inventory.json"), options: .atomic)
            print("Inventory: \(out.path)/inventory.json")
        } else if command == "plan" {
            guard let input = option("--inventory"), let profilePath = option("--profile"), let destination = option("--out") else { throw failure("Missing inventory/profile/output") }
            let decoder = JSONDecoder()
            let inventory = try decoder.decode(NativeScoreInventory.self, from: Data(contentsOf: URL(fileURLWithPath: input)))
            let profile = try decoder.decode(ScoreExtractionProfile.self, from: Data(contentsOf: URL(fileURLWithPath: profilePath)))
            let overrides = try option("--overrides").map { try decoder.decode([ScorePageOverride].self, from: Data(contentsOf: URL(fileURLWithPath: $0))) } ?? []
            let plan = ScoreExtractionPlanner.plan(pages: inventory.pages, profile: profile, overrides: overrides)
            try encoder.encode(plan).write(to: URL(fileURLWithPath: destination), options: .atomic)
            print("Planned \(plan.bands.count) bands; unresolved pages: \(plan.pages.filter { !$0.unresolvedReasons.isEmpty }.map { $0.pageIndex + 1 }); canApply: \(plan.canApply)")
        } else { throw failure("Unknown command \(command)") }
    }

    static func failure(_ message: String) -> NSError { NSError(domain: "ScoreExtractionBatch", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }

    static func writeImage(_ image: CGImage, candidates: [ScoreObservedStaff], to url: URL) throws {
        let width = 1000, height = Int(Double(image.height) * 1000 / Double(image.width))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw failure("Image context unavailable") }
        context.setFillColor(gray: 1, alpha: 1); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 0.6)); context.setLineWidth(0.7)
        for staff in candidates {
            for fraction in staff.staffLineFractions {
                let y = fraction * Double(height)
                context.move(to: CGPoint(x: 10, y: y)); context.addLine(to: CGPoint(x: Double(width - 10), y: y))
            }
            context.strokePath()
            let y = staff.staffLineFractions[0] * Double(height)
            context.saveGState(); context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            context.textPosition = CGPoint(x: 4, y: y - 2)
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.systemRed]
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: String(staff.id), attributes: attributes)), context)
            context.restoreGState()
        }
        guard let rendered = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw failure("PNG destination unavailable") }
        CGImageDestinationAddImage(destination, rendered, nil)
        guard CGImageDestinationFinalize(destination) else { throw failure("PNG write failed") }
    }
}
