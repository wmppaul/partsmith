// Runs the same document-owned automatic rest workflow as the macOS app.
import AppKit
import CryptoKit
import Foundation
import PDFKit

@main enum CompressScoreRests {
    struct Envelope: Codable { var project: ProjectData }
    struct Recognized: Encodable {
        var bandID: UUID; var part: String; var sourcePage: Int; var bars: Int
        var originalRect: [Double]; var context: BandRestSourceContext?
    }
    struct Report: Encodable {
        var sourceSHA256: String; var status: String; var examinedBands: Int; var replacedBands: Int; var totalBars: Int
        var replacements: [Recognized]
    }
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        func option(_ name: String) -> String? { guard let i = args.firstIndex(of: name), i+1 < args.count else { return nil }; return args[i+1] }
        guard let input = option("--project"), let output = option("--out") else {
            throw NSError(domain: "RestCompression", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use --project PACKAGE --out NEW_DIRECTORY"])
        }
        let inputURL = URL(fileURLWithPath: input), out = URL(fileURLWithPath: output)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(Envelope.self, from: Data(contentsOf: inputURL.appendingPathComponent("project.json"))).project
        let source = try Data(contentsOf: inputURL.appendingPathComponent("source.pdf"))
        let document = PartsmithDocument(project: project, sourcePDFData: source)
        var result: RestAutoResult?
        document.autoDetectRestReplacements(completion: { result = $0 })
        let started = Date()
        var printedProgress = -1
        while result == nil && Date().timeIntervalSince(started) < 900 {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            if let progress = document.restAutoProgress, progress.completedBands != printedProgress {
                printedProgress = progress.completedBands
                print("Checked \(progress.completedBands)/\(progress.totalBands) strips; recognized \(progress.recognizedBands)")
            }
        }
        guard case .completed(let replaced, let bars, let examined) = result else {
            document.cancelAutoDetectRestReplacements()
            throw NSError(domain: "RestCompression", code: 2, userInfo: [NSLocalizedDescriptionKey: "Automatic rest run failed: \(String(describing: result))"])
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: out.path) else {
            throw NSError(domain: "RestCompression", code: 3, userInfo: [NSLocalizedDescriptionKey: "Output directory already exists; choose a new directory to preserve previous results."])
        }
        try manager.createDirectory(at: out, withIntermediateDirectories: true)
        let package = out.appendingPathComponent(inputURL.lastPathComponent)
        try manager.createDirectory(at: package, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(Envelope(project: document.project)).write(to: package.appendingPathComponent("project.json"))
        try source.write(to: package.appendingPathComponent("source.pdf"))
        try PartPDFExporter.exportAll(document: document, to: out)
        let existing = Set(project.bands.filter { $0.restReplacement != nil }.map(\.id))
        let replacements = document.project.bands.filter { $0.restReplacement != nil && !existing.contains($0.id) }.map { band in
            Recognized(bandID: band.id, part: document.project.parts.first { $0.id == band.partID }!.name,
                sourcePage: band.pageIndex+1, bars: band.restReplacement!.barCount,
                originalRect: [band.leftFraction, band.topFraction, 1-band.rightFraction, band.bottomFraction],
                context: band.restReplacement?.sourceContext)
        }
        let report = Report(sourceSHA256: SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined(),
            status: document.restAutoStatus ?? "", examinedBands: examined, replacedBands: replaced, totalBars: bars, replacements: replacements)
        try encoder.encode(report).write(to: out.appendingPathComponent("automatic-rest-report.json"))
        print("Saved \(replaced) automatic rest replacements (\(bars) bars) from \(examined) strips to \(out.path)")
    }
}
