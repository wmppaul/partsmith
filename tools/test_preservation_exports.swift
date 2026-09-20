// Compile/run with tools/test_preservation_exports.sh from the repository root.
// Validates the portable recipe -> editable project -> production native PDF bridge.
import AppKit
import CryptoKit
import Foundation
import PDFKit

@main
enum PreservationExportTests {
    struct Envelope: Decodable { var project: ProjectData }
    struct Recipe: Decodable {
        var notationPolicy: String
        var sourceSHA256: String
        var parts: [RecipePart]
    }
    struct RecipePart: Decodable { var name: String; var bands: [RecipeBand] }
    struct ProtectedRegion: Codable { var rect: [Double]; var description: String }
    struct RecipeBand: Decodable {
        var id: String
        var page: Int
        var system: String
        var rect: [Double]
        var label: String?
        var pageBreakBefore: Bool?
        var exclusions: [[Double]]?
        var protectedRegions: [ProtectedRegion]
    }
    struct Placement: Encodable {
        var id: String
        var nativeBandID: String
        var sourcePage: Int
        var system: String
        var outputPage: Int
        var sourceRect: [Double]
        var destinationRect: [Double]
        var editorialLabel: String
        var editorialLabelRect: [Double]?
        var exclusions: [[Double]] = []
        var protectedRegions: [ProtectedRegion]
    }
    struct PartResult: Encodable {
        var name: String
        var file: String
        var sha256: String
        var outputPages: Int
        var bandCount: Int
        var placements: [Placement]
    }
    struct Manifest: Encodable {
        var schemaVersion = 1
        var notationPolicy = "preserve-target"
        var renderer = "Partsmith production PartLayoutEngine + PartPDFExporter"
        var coordinates = "top-down PDF points; page numbers are one-based"
        var geometryTolerancePoints = PreservationExportTests.geometryTolerance
        var maximumSourceCoordinateDeviationPoints: Double
        var source: String
        var sourceSHA256: String
        var project: String
        var recipe: String
        var parts: [PartResult]
    }

    static var checks = 0
    static var protectedCount = 0
    // PDFKit reads MediaBox decimals as doubles; PyMuPDF exposes float-rounded dimensions.
    // 0.0001 pt is below 0.001 pixel at 600 dpi. Record the measured deviation, too.
    static let geometryTolerance = 0.0001

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        guard condition() else {
            throw NSError(domain: "PreservationExportTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func topDown(_ rect: CGRect, in pageBounds: CGRect) -> [Double] {
        [rect.minX - pageBounds.minX, pageBounds.maxY - rect.maxY,
         rect.maxX - pageBounds.minX, pageBounds.maxY - rect.minY]
    }

    static func contains(_ outer: [Double], _ inner: [Double]) -> Bool {
        guard outer.count == 4, inner.count == 4,
              inner.allSatisfy({ $0.isFinite }), inner[0] < inner[2], inner[1] < inner[3] else { return false }
        let tolerance = geometryTolerance
        return inner[0] >= outer[0] - tolerance && inner[1] >= outer[1] - tolerance &&
               inner[2] <= outer[2] + tolerance && inner[3] <= outer[3] + tolerance
    }

    static func normalized(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func run(input: URL, output: URL) throws {
        let manager = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let recipeURL = input.appendingPathComponent("recipe.json")
        let recipe = try decoder.decode(Recipe.self, from: Data(contentsOf: recipeURL))
        let packages = try manager.contentsOfDirectory(at: input, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "partsmithproject" }
        try check(packages.count == 1, "\(input.path): expected exactly one editable project")
        try check(recipe.notationPolicy == "preserve-target", "Expected explicit preservation policy")
        let package = packages[0]
        let sourceURL = package.appendingPathComponent("source.pdf")
        let source = try Data(contentsOf: sourceURL)
        try check(hash(source) == recipe.sourceSHA256, "Embedded native source must match recipe SHA256")
        let project = try decoder.decode(Envelope.self, from: Data(contentsOf: package.appendingPathComponent("project.json"))).project
        let document = PartsmithDocument(project: project, sourcePDFData: source)
        try check(project.pageRectifications.isEmpty, "This exact-coordinate regression expects the original scan coordinates")
        try check(project.parts.count == recipe.parts.count, "Native and portable part counts differ")
        try manager.createDirectory(at: output, withIntermediateDirectories: true)
        var results: [PartResult] = []
        var maximumSourceDeviation = 0.0
        for recipePart in recipe.parts {
            let matched = project.parts.filter { $0.name == recipePart.name }
            try check(matched.count == 1, "Part identity must match uniquely: \(recipePart.name)")
            let part = matched[0]
            let storedBands = project.bands.filter { $0.partID == part.id }
            try check(storedBands.count == recipePart.bands.count, "All recipe bands must survive import")
            let plan = try PartLayoutEngine.makePlan(project: project,
                pageBoundsProvider: { document.pdfDocument?.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
            let flat = plan.pages.flatMap(\.placements)
            try check(flat.map(\.bandID) == storedBands.map(\.id), "Native layout must retain every band in recipe reading order")
            let recipeByID = Dictionary(uniqueKeysWithValues: zip(storedBands.map(\.id), recipePart.bands))
            let storedByID = Dictionary(uniqueKeysWithValues: storedBands.map { ($0.id, $0) })
            let filename = part.name.replacingOccurrences(of: "/", with: "-") + ".pdf"
            let exportURL = output.appendingPathComponent(filename)
            try PartPDFExporter.export(partID: part.id, document: document, to: exportURL)
            let data = try Data(contentsOf: exportURL)
            guard let pdf = PDFDocument(data: data) else { throw PartLayoutError.missingPDF }
            try check(pdf.pageCount == plan.pages.count, "Actual native PDF page count agrees with render plan")
            var placements: [Placement] = []
            for page in plan.pages {
                let text = normalized(pdf.page(at: page.index)?.string ?? "")
                for placed in page.placements {
                    let expected = recipeByID[placed.bandID]!
                    let native = storedByID[placed.bandID]!
                    guard let bounds = document.pdfDocument?.page(at: placed.sourcePageIndex)?.bounds(for: .mediaBox) else {
                        throw PartLayoutError.missingSourcePage(placed.sourcePageIndex)
                    }
                    let sourceRect = topDown(placed.sourceRect, in: bounds)
                    let outputRect = topDown(placed.destinationRect, in: CGRect(origin: .zero, size: plan.pageSize))
                    try check(placed.sourcePageIndex + 1 == expected.page, "\(expected.id): source page survives bridge")
                    let deviations = zip(sourceRect, expected.rect).map { abs($0 - $1) }
                    maximumSourceDeviation = max(maximumSourceDeviation, deviations.max() ?? 0)
                    try check(expected.rect.count == 4 && deviations.allSatisfy { $0 < geometryTolerance },
                              "\(expected.id): exact source crop survives native import and layout; native \(sourceRect), recipe \(expected.rect)")
                    try check(!native.excluded && native.exclusions.isEmpty && placed.exclusionRects.isEmpty &&
                              (expected.exclusions ?? []).isEmpty, "\(expected.id): preservation export has no hidden bands or masks")
                    try check(native.editorialLabel == (expected.label ?? "") &&
                              placed.editorialLabel == (expected.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                              "\(expected.id): complete editorial label survives native bridge")
                    try check(text.contains(normalized(placed.editorialLabel)), "\(expected.id): rendered PDF contains label text")
                    try check(native.pageBreakBefore == (expected.pageBreakBefore ?? false), "\(expected.id): explicit break survives bridge")
                    if native.pageBreakBefore {
                        try check(page.placements.first?.bandID == native.id, "\(expected.id): explicit break begins native output page")
                    }
                    try check(contains([0, 0, plan.pageSize.width, plan.pageSize.height], outputRect),
                              "\(expected.id): entire destination crop remains on output page")
                    try check(!expected.protectedRegions.isEmpty, "\(expected.id): recorded target protection is present")
                    for protected in expected.protectedRegions {
                        try check(contains(sourceRect, protected.rect), "\(expected.id): native crop contains protected \(protected.description)")
                        protectedCount += 1
                    }
                    placements.append(Placement(id: expected.id, nativeBandID: native.id.uuidString,
                        sourcePage: expected.page, system: expected.system, outputPage: page.index + 1,
                        sourceRect: sourceRect, destinationRect: outputRect, editorialLabel: placed.editorialLabel,
                        editorialLabelRect: placed.editorialLabelRect.map {
                            topDown($0, in: CGRect(origin: .zero, size: plan.pageSize))
                        }, protectedRegions: expected.protectedRegions))
                }
            }
            results.append(PartResult(name: part.name, file: filename, sha256: hash(data),
                outputPages: plan.pages.count, bandCount: flat.count, placements: placements))
            print("\(input.lastPathComponent): \(part.name), \(flat.count) bands, \(plan.pages.count) native pages; systems per page \(plan.pages.map { $0.placements.count })")
        }
        let manifest = Manifest(maximumSourceCoordinateDeviationPoints: maximumSourceDeviation,
                                source: sourceURL.path, sourceSHA256: recipe.sourceSHA256,
                                project: package.path, recipe: recipeURL.path, parts: results)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
    }

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let paths = CommandLine.arguments.count > 1 ? Array(CommandLine.arguments.dropFirst()) :
            ["output/pdf/brahms-preservation", "output/pdf/schumann-preservation", "output/pdf/trio-preservation"]
        let output = root.appendingPathComponent(".build/extraction/native-preservation")
        for path in paths {
            let input = URL(fileURLWithPath: path, relativeTo: root).standardizedFileURL
            try run(input: input, output: output.appendingPathComponent(input.lastPathComponent))
        }
        print("PASS: \(checks) native preservation bridge checks; all \(protectedCount) protected source regions retained")
    }
}
