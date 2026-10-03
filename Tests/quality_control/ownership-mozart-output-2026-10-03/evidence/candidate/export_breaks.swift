// Native whole-score batch export, deliberately using the app's apply transaction
// and production layout/exporter. It never supplies its own staff detection.
import AppKit
import CryptoKit
import Foundation
import PDFKit

@main
enum ExportScorePlan {
    struct Inventory: Codable {
        var source: String
        var sourceSHA256: String
        var pages: [ScorePageAnalysis]
        var rectifications: [PageRectification]? = nil
    }
    struct Envelope: Codable { var project: ProjectData }
    struct Marking: Encodable { var sourceRect: [Double]; var destinationRect: [Double]; var isBelow: Bool? }
    struct Placement: Encodable {
        var id: String
        var sourcePage: Int
        var system: Int
        var candidateIDs: [Int]
        var outputPage: Int
        var sourceRect: [Double]
        var destinationRect: [Double]
        var staffLineYs: [[Double]]
        var editorialLabel: String
        var kind: String
        var provenance: String
        var sourceMarkings: [Marking]
        var generatedRest: ScoreGeneratedRest?
    }
    struct Part: Encodable {
        var id: String
        var name: String
        var file: String
        var sha256: String
        var outputPages: Int
        var bandCount: Int
        var systemsPerPage: [Int]
        var placements: [Placement]
    }
    struct Manifest: Encodable {
        var schemaVersion = 2
        var notationPolicy = "preserve-target"
        var status = "draft — visual review required"
        var renderer = "Partsmith native Auto planner, addScoreParts, PartLayoutEngine and PartPDFExporter"
        var coordinates = "top-down PDF points; source/output pages and systems are one-based. For generated-rest items, sourceRect is an ordering/inspection anchor, not a source crop."
        var source: String
        var sourceSHA256: String
        var profile: ScoreExtractionProfile
        var reviewedOverrides: [ScorePageOverride]
        var rectifications: [PageRectification]
        var reviewSourceFile: String?
        var reviewSourceSHA256: String?
        var project: String
        var parts: [Part]
    }
    static func error(_ message: String) -> NSError {
        NSError(domain: "ExportScorePlan", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func topDown(_ rect: CGRect, _ bounds: CGRect) -> [Double] {
        [rect.minX - bounds.minX, bounds.maxY - rect.maxY, rect.maxX - bounds.minX, bounds.maxY - rect.minY]
    }
    /// Full corrected pages for source-context review. No part crops, masks or
    /// assignments participate; the embedded original PDF remains immutable.
    static func writeReviewSource(_ pdf: PDFDocument, corrections: [PageRectification], to url: URL) throws {
        guard let consumer = CGDataConsumer(url: url as CFURL) else { throw error("Cannot create review source") }
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { throw error("Cannot create review source context") }
        for index in 0..<pdf.pageCount {
            try autoreleasepool {
                guard let page = pdf.page(at: index) else { throw error("Missing review source page") }
                var bounds = page.bounds(for: .mediaBox)
                let info = [kCGPDFContextMediaBox as String: NSData(bytes: &bounds, length: MemoryLayout<CGRect>.size)] as CFDictionary
                context.beginPDFPage(info)
                try SourcePageRenderCache(pdfDocument: pdf).draw(pageIndex: index,
                    rectification: corrections.first { $0.pageIndex == index },
                    sourceRect: bounds, destinationRect: bounds, in: context)
                context.endPDFPage()
            }
        }
        context.closePDF()
    }
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        func option(_ name: String) -> String? {
            guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
            return args[index + 1]
        }
        guard let inventoryPath = option("--inventory"), let profilePath = option("--profile"),
              let outputPath = option("--out"), let title = option("--title") else {
            throw error("Use --inventory JSON --profile JSON [--overrides JSON] --title TEXT [--composer TEXT] --out DIRECTORY")
        }
        let decoder = JSONDecoder()
        let inventory = try decoder.decode(Inventory.self, from: Data(contentsOf: URL(fileURLWithPath: inventoryPath)))
        let profile = try decoder.decode(ScoreExtractionProfile.self, from: Data(contentsOf: URL(fileURLWithPath: profilePath)))
        let overrides = try option("--overrides").map { try decoder.decode([ScorePageOverride].self, from: Data(contentsOf: URL(fileURLWithPath: $0))) } ?? []
        let source = try Data(contentsOf: URL(fileURLWithPath: inventory.source))
        guard hash(source) == inventory.sourceSHA256 else { throw error("Source hash differs from detector inventory") }
        let review = ScoreDetectionReview.initial(profile: profile, analyses: inventory.pages,
            overrides: overrides, sourcePDFData: source, rectifications: inventory.rectifications ?? [])
        let plan = review.plan
        guard plan.canApply else { throw error("Unresolved plan: \(plan.pages.filter { !$0.unresolvedReasons.isEmpty })") }
        var project = ProjectData.empty
        project.id = UUID()
        project.projectName = title
        project.pageCount = inventory.pages.count
        project.sourceFilename = URL(fileURLWithPath: inventory.source).lastPathComponent
        project.pageRectifications = inventory.rectifications ?? []
        project.projectSettings.headerDisplayMode = .typed
        project.projectSettings.defaultTitleText = title
        project.projectSettings.defaultComposerText = option("--composer") ?? ""
        project.projectSettings.showPartNameInHeader = true
        var document = PartsmithDocument(project: project, sourcePDFData: source)
        guard document.addScoreParts(from: review) == plan.bands.count else { throw error("Native Auto apply rejected the review") }
        let requestedBreaks = try option("--breaks").map { try decoder.decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: $0))) } ?? []
        var appliedBreaks = Set<String>()
        for definition in profile.parts {
            guard let part = document.project.parts.first(where: { $0.name == definition.name }) else { throw error("Missing part for break") }
            let stored = document.project.bands.filter { $0.partID == part.id }
            let planned = plan.bands.filter { $0.partID == definition.id }
            guard stored.count == planned.count else { throw error("Part/plan mapping differs") }
            for (model, band) in zip(stored, planned) where requestedBreaks.contains(band.id) {
                document.updateBandPageBreakBefore(model.id, pageBreakBefore: true)
                appliedBreaks.insert(band.id)
            }
        }
        guard appliedBreaks == Set(requestedBreaks) else { throw error("An explicit page break was not found") }
        print("Explicit source-reviewed page breaks: \(requestedBreaks.sorted())")
        guard let pdf = document.pdfDocument else { throw error("Source unavailable after native apply") }
        let manager = FileManager.default
        let output = URL(fileURLWithPath: outputPath).standardizedFileURL
        let staging = output.deletingLastPathComponent().appendingPathComponent(".\(output.lastPathComponent)-staging-\(UUID().uuidString)")
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        var installed = false
        defer { if !installed { try? manager.removeItem(at: staging) } }
        let packageName = title.replacingOccurrences(of: "/", with: "-") + ".partsmithproject"
        let package = staging.appendingPathComponent(packageName)
        try manager.createDirectory(at: package, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(Envelope(project: document.project)).write(to: package.appendingPathComponent("project.json"))
        try source.write(to: package.appendingPathComponent("source.pdf"))
        let roundtripDecoder = JSONDecoder()
        roundtripDecoder.dateDecodingStrategy = .iso8601
        let savedJSON = try Data(contentsOf: package.appendingPathComponent("project.json"))
        let saved = try roundtripDecoder.decode(Envelope.self, from: savedJSON)
        guard try encoder.encode(saved) == savedJSON else { throw error("Project package JSON roundtrip changed") }
        let reopenedSource = try Data(contentsOf: package.appendingPathComponent("source.pdf"))
        guard reopenedSource == source else { throw error("Embedded source changed") }
        document = PartsmithDocument(project: saved.project, sourcePDFData: reopenedSource)
        guard document.savedScoreProfile == profile, document.project.pageRectifications == inventory.rectifications ?? [],
              document.project.bands.count == plan.bands.count else { throw error("Reopened project lost profile, corrections or bands") }
        print("Persistence verified: native apply, package encode/decode, reopen, identical JSON and source")
        try encoder.encode(plan).write(to: staging.appendingPathComponent("plan.json"))
        try encoder.encode(requestedBreaks).write(to: staging.appendingPathComponent("layout-page-breaks.json"))
        var reviewSourceFile: String?, reviewSourceHash: String?
        if !project.pageRectifications.isEmpty {
            let filename = "rectified-review-source.pdf"
            let url = staging.appendingPathComponent(filename)
            try writeReviewSource(pdf, corrections: project.pageRectifications, to: url)
            reviewSourceFile = filename
            reviewSourceHash = hash(try Data(contentsOf: url))
        }
        var parts: [Part] = []
        for definition in profile.parts {
            guard let part = document.project.parts.first(where: { $0.name == definition.name }) else { throw error("Missing part") }
            let stored = document.project.bands.filter { $0.partID == part.id }
            let planned = plan.bands.filter { $0.partID == definition.id }
            let byID = Dictionary(uniqueKeysWithValues: zip(stored.map(\.id), planned))
            let layout = try PartLayoutEngine.makePlan(project: document.project,
                pageBoundsProvider: { pdf.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
            guard layout.pages.flatMap(\.placements).map(\.bandID) == stored.map(\.id) else { throw error("Layout dropped or reordered a band") }
            let filename = definition.name.replacingOccurrences(of: "/", with: "-") + ".pdf"
            let destination = staging.appendingPathComponent(filename)
            try PartPDFExporter.export(partID: part.id, document: document, to: destination)
            let data = try Data(contentsOf: destination)
            guard PDFDocument(data: data)?.pageCount == layout.pages.count else { throw error("Export page count differs from layout") }
            var placements: [Placement] = []
            for page in layout.pages {
                for placed in page.placements {
                    let band = byID[placed.bandID]!
                    let bounds = pdf.page(at: placed.sourcePageIndex)!.bounds(for: .mediaBox)
                    let outputBounds = CGRect(origin: .zero, size: layout.pageSize)
                    let analysis = inventory.pages.first { $0.pageIndex == placed.sourcePageIndex }!
                    let lineYs = band.candidateIDs.map { id in analysis.staves.first { $0.id == id }!.staffLineFractions.map { $0 * bounds.height } }
                    placements.append(Placement(id: band.id, sourcePage: placed.sourcePageIndex + 1,
                        system: band.systemIndex + 1, candidateIDs: band.candidateIDs, outputPage: page.index + 1,
                        sourceRect: topDown(placed.sourceRect, bounds), destinationRect: topDown(placed.destinationRect, outputBounds),
                        staffLineYs: lineYs, editorialLabel: band.editorialLabel, kind: band.kind, provenance: band.provenance,
                        sourceMarkings: placed.sourceMarkings.map { Marking(sourceRect: topDown($0.sourceRect, bounds), destinationRect: topDown($0.destinationRect, outputBounds), isBelow: $0.isBelow ? true : nil) },
                        generatedRest: band.generatedRest))
                }
            }
            parts.append(Part(id: definition.id, name: definition.name, file: filename, sha256: hash(data),
                outputPages: layout.pages.count, bandCount: placements.count, systemsPerPage: layout.pages.map { $0.placements.count }, placements: placements))
            print("\(definition.name): \(placements.count) systems on \(layout.pages.count) pages \(layout.pages.map { $0.placements.count })")
        }
        var manifest = Manifest(source: inventory.source, sourceSHA256: inventory.sourceSHA256,
            profile: profile, reviewedOverrides: overrides, rectifications: inventory.rectifications ?? [],
            reviewSourceFile: reviewSourceFile, reviewSourceSHA256: reviewSourceHash, project: packageName, parts: parts)
        if reviewSourceFile != nil {
            manifest.coordinates += " Source rectangles refer to the recorded corrected page coordinates; use reviewSourceFile for geometric source comparison and inspect the immutable original for deskew preservation."
        }
        try encoder.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"))
        if manager.fileExists(atPath: output.path) {
            let backup = output.deletingLastPathComponent().appendingPathComponent(".\(output.lastPathComponent)-previous-\(UUID().uuidString)")
            try manager.moveItem(at: output, to: backup)
            do { try manager.moveItem(at: staging, to: output) }
            catch { try? manager.moveItem(at: backup, to: output); throw error }
            print("Previous generation: \(backup.path)")
        } else { try manager.moveItem(at: staging, to: output) }
        installed = true
        print("Native full-score output: \(output.path)")
    }
}
