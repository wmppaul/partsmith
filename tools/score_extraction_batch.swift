import AppKit
import CoreGraphics
import CoreText
import CryptoKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

struct NativeScoreInventory: Codable {
    var schemaVersion = 2
    var source: String
    var sourceSHA256: String
    var coordinateSystem = "Top-down fractions of the unrectified native image; multiply y by pageHeight for source PDF points. Candidate IDs and pageIndex are zero-based."
    var rectifications: [PageRectification]? = nil
    var analysisConfiguration: String? = nil
    var pages: [ScorePageAnalysis]
}

@main
enum ScoreExtractionBatch {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { throw failure("Use inventory --source PDF [--deskew] --out DIRECTORY; plan --inventory JSON --profile JSON [--overrides JSON] --out JSON; or experimental headings|navigation|destinations --inventory JSON --profile JSON --out JSON") }
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
            var rectifications: [PageRectification] = []
            let deskew = args.contains("--deskew")
            for index in 0..<document.pageCount {
                let analysis: ScorePageAnalysis = try autoreleasepool {
                    guard let page = document.page(at: index) else { throw failure("Cannot read page \(index + 1)") }
                    let correction = deskew ? PageRectificationEstimator.estimate(for: page, pageIndex: index)?.rectification.normalized() : nil
                    let rendered: CGImage?
                    if let correction {
                        // Match the magic-wand worker exactly. Failed correction
                        // rendering cannot silently supply raw-coordinate crops.
                        rendered = SourcePageRenderCache(pdfDocument: document, rasterScale: 2.5)
                            .rectifiedDisplayImage(for: index, rectification: correction)
                        rectifications.append(correction)
                    } else { rendered = NativeScorePageAnalyzer.render(page) }
                    guard let image = rendered else { throw failure("Cannot render page \(index + 1)\(correction == nil ? "" : " with its saved deskew")") }
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
            var inventory = NativeScoreInventory(source: url.path, sourceSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), pages: pages)
            inventory.rectifications = rectifications
            inventory.analysisConfiguration = deskew ? "native-auto-deskew-v1" : "native-auto-raw-v1"
            if !rectifications.isEmpty {
                inventory.coordinateSystem = "Top-down fractions of the native display image after the recorded per-page rectification; multiply by original page size for corrected PDF coordinates. Original PDF bytes remain unchanged. Candidate IDs and pageIndex are zero-based."
            }
            try encoder.encode(inventory).write(to: out.appendingPathComponent("inventory.json"), options: .atomic)
            print("Inventory: \(out.path)/inventory.json")
        } else if command == "headings" || command == "navigation" || command == "destinations" {
            guard let input = option("--inventory"), let profilePath = option("--profile"), let destination = option("--out") else { throw failure("Missing inventory/profile/output") }
            let decoder = JSONDecoder()
            var inventory = try decoder.decode(NativeScoreInventory.self, from: Data(contentsOf: URL(fileURLWithPath: input)))
            let data = try Data(contentsOf: URL(fileURLWithPath: inventory.source))
            guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == inventory.sourceSHA256,
                  let pdf = PDFDocument(data: data) else { throw failure("Inventory source changed") }
            let profile = try decoder.decode(ScoreExtractionProfile.self, from: Data(contentsOf: URL(fileURLWithPath: profilePath)))
            let recognitionCorrections = inventory.rectifications ?? []
            func recognitionImage(_ analysis: ScorePageAnalysis) throws -> CGImage {
                guard let page = pdf.page(at: analysis.pageIndex) else { throw failure("Cannot read recognition page") }
                let bounds = page.bounds(for: .mediaBox)
                let maximumWidth = command == "headings" ? 2200 : 2400
                let maximumHeight = command == "headings" ? 3200 : 3500
                let image: CGImage?
                if let correction = recognitionCorrections.first(where: { $0.pageIndex == analysis.pageIndex }) {
                    image = SourcePageRenderCache(pdfDocument: pdf,
                        rasterScale: min(CGFloat(maximumWidth) / bounds.width, CGFloat(maximumHeight) / bounds.height))
                        .rectifiedDisplayImage(for: analysis.pageIndex, rectification: correction)
                } else { image = NativeScorePageAnalyzer.render(page, maximumWidth: maximumWidth, maximumHeight: maximumHeight) }
                guard let image else { throw failure("Cannot render recognition page") }
                return image
            }
            for index in inventory.pages.indices {
                if command == "destinations" { break }
                let analysis = inventory.pages[index]
                try autoreleasepool {
                    let image = try recognitionImage(analysis)
                    var recognitionFailures: [String] = []
                    func recordFailure(_ pass: String, _ error: Error) {
                        let detail = error as NSError
                        recognitionFailures.append("\(pass): \(detail.domain) code \(detail.code): \(detail.localizedDescription)")
                    }
                    if command == "navigation" {
                        inventory.pages[index].sharedNavigation = ScoreSharedNavigationDetector.detect(in: image,
                            page: analysis, profile: profile, observedFailure: { region, error in
                                let before = region.beforeStaffID.map(String.init) ?? "none"
                                let after = region.afterStaffID.map(String.init) ?? "none"
                                recordFailure("before staff \(before), after staff \(after)", error)
                            })
                    } else {
                        inventory.pages[index].sharedHeadings = ScoreSharedHeadingDetector.detect(in: image,
                            page: analysis, profile: profile, observedFailure: { anchor, error in
                                recordFailure(anchor < 0 ? "full-page" : "staff \(anchor)", error)
                            })
                    }
                    guard recognitionFailures.isEmpty else {
                        throw failure("Page \(analysis.pageIndex + 1) \(command) OCR failed; destination inventory was not updated "
                            + "(any pre-existing file remains unchanged). " + recognitionFailures.joined(separator: "; "))
                    }
                }
                let count = command == "navigation" ? inventory.pages[index].sharedNavigation?.count : inventory.pages[index].sharedHeadings?.count
                print("Page \(analysis.pageIndex + 1): \(count ?? 0) shared \(command)")
                fflush(stdout)
            }
            if command != "headings" {
                // Source symbols are score-level evidence. The sentence can
                // appear after its destination, so collect templates first.
                var templates: [ScoreSharedDestinationDetector.Template] = []
                for analysis in inventory.pages where analysis.sharedNavigation?.contains(where: { !$0.recognizedText.isEmpty }) == true {
                    try autoreleasepool {
                        templates += ScoreSharedDestinationDetector.templates(in: try recognitionImage(analysis),
                            page: analysis, profile: profile)
                    }
                }
                print("Printed navigation symbol templates: \(templates.count)")
                for template in templates {
                    print("Template page \(template.sourcePageIndex + 1): \(template.sourceBounds)")
                }
                for index in inventory.pages.indices {
                    var analysis = inventory.pages[index]
                    // Rerunning the experimental destination pass replaces its
                    // own glyph metadata, never duplicates it as new evidence.
                    analysis.sharedNavigation = analysis.sharedNavigation?.filter { !$0.recognizedText.isEmpty }
                    let symbols = try autoreleasepool {
                        ScoreSharedDestinationDetector.detect(in: try recognitionImage(analysis), page: analysis,
                            profile: profile, templates: templates, observedMatches: { matches in
                                for match in matches {
                                    print("Page \(analysis.pageIndex + 1) staff \(match.anchorStaffID): source-symbol match \(match.correlation), template page \(match.templatePageIndex + 1) bounds \(match.templateBounds)")
                                }
                            })
                    }
                    inventory.pages[index].sharedNavigation = (analysis.sharedNavigation ?? []) + symbols
                    print("Page \(analysis.pageIndex + 1): \(symbols.count) shared destination symbols")
                    fflush(stdout)
                }
            }
            inventory.analysisConfiguration = (inventory.analysisConfiguration ?? "legacy-inventory")
                + (command == "headings" ? "+shared-headings-v3" : "+shared-navigation-v2-source-symbols")
            try encoder.encode(inventory).write(to: URL(fileURLWithPath: destination), options: .atomic)
        } else if command == "plan" {
            guard let input = option("--inventory"), let profilePath = option("--profile"), let destination = option("--out") else { throw failure("Missing inventory/profile/output") }
            let decoder = JSONDecoder()
            let inventory = try decoder.decode(NativeScoreInventory.self, from: Data(contentsOf: URL(fileURLWithPath: input)))
            let profile = try decoder.decode(ScoreExtractionProfile.self, from: Data(contentsOf: URL(fileURLWithPath: profilePath)))
            let overrides = try option("--overrides").map { try decoder.decode([ScorePageOverride].self, from: Data(contentsOf: URL(fileURLWithPath: $0))) } ?? []
            let review = ScoreDetectionReview.initial(profile: profile, analyses: inventory.pages,
                overrides: overrides, sourcePDFData: Data(), rectifications: inventory.rectifications ?? [])
            let plan = review.plan
            try encoder.encode(plan).write(to: URL(fileURLWithPath: destination), options: .atomic)
            print("Planned \(plan.bands.count) bands; automatically skipped pages: \(review.autoSkippedPageIndices.sorted().map { $0 + 1 }); unresolved pages: \(plan.pages.filter { !$0.unresolvedReasons.isEmpty }.map { $0.pageIndex + 1 }); canApply: \(plan.canApply)")
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
