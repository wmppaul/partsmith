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
    }
    struct Envelope: Encodable { var project: ProjectData }
    struct Marking: Encodable { var sourceRect: [Double]; var destinationRect: [Double] }
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
        var schemaVersion = 1
        var notationPolicy = "preserve-target"
        var status = "draft — visual review required"
        var renderer = "Partsmith native Auto planner, addScoreParts, PartLayoutEngine and PartPDFExporter"
        var coordinates = "top-down PDF points; source/output pages and systems are one-based"
        var source: String
        var sourceSHA256: String
        var profile: ScoreExtractionProfile
        var reviewedOverrides: [ScorePageOverride]
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
        let plan = ScoreExtractionPlanner.plan(pages: inventory.pages, profile: profile, overrides: overrides)
        guard plan.canApply else { throw error("Unresolved plan: \(plan.pages.filter { !$0.unresolvedReasons.isEmpty })") }
        var project = ProjectData.empty
        project.id = UUID()
        project.projectName = title
        project.pageCount = inventory.pages.count
        project.sourceFilename = URL(fileURLWithPath: inventory.source).lastPathComponent
        project.projectSettings.headerDisplayMode = .typed
        project.projectSettings.defaultTitleText = title
        project.projectSettings.defaultComposerText = option("--composer") ?? ""
        project.projectSettings.showPartNameInHeader = true
        let document = PartsmithDocument(project: project, sourcePDFData: source)
        let review = ScoreDetectionReview(profile: profile, analyses: inventory.pages, plan: plan,
            overrides: overrides, sourcePDFData: source, rectifications: [])
        guard document.addScoreParts(from: review) == plan.bands.count else { throw error("Native Auto apply rejected the review") }
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
        try encoder.encode(plan).write(to: staging.appendingPathComponent("plan.json"))
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
                        sourceMarkings: placed.sourceMarkings.map { Marking(sourceRect: topDown($0.sourceRect, bounds), destinationRect: topDown($0.destinationRect, outputBounds)) }))
                }
            }
            parts.append(Part(id: definition.id, name: definition.name, file: filename, sha256: hash(data),
                outputPages: layout.pages.count, bandCount: placements.count, systemsPerPage: layout.pages.map { $0.placements.count }, placements: placements))
            print("\(definition.name): \(placements.count) systems on \(layout.pages.count) pages \(layout.pages.map { $0.placements.count })")
        }
        let manifest = Manifest(source: inventory.source, sourceSHA256: inventory.sourceSHA256,
            profile: profile, reviewedOverrides: overrides, project: packageName, parts: parts)
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
