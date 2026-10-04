import Foundation
import PDFKit
import CryptoKit

@main struct Reflow {
    struct Envelope: Codable { var project: ProjectData }
    struct PartResult: Codable {
        var name: String
        var originalPages: Int
        var newPages: Int
        var originalStartBars: [[Int?]]
        var newStartBars: [[Int?]]
        var bandCount: Int
        var filename: String
        var sha256: String
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let base = root.appendingPathComponent("output/pdf/auto-qc-2026-10-03/mendelssohn-verleih-uns-frieden-native-draft/Verleih uns Frieden — choir and organ.partsmithproject")
        let output = root.appendingPathComponent(".build/mendelssohn-rest-turn-2026-10-03/output")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let before = try decoder.decode(Envelope.self, from: Data(contentsOf: base.appendingPathComponent("project.json"))).project
        let source = try Data(contentsOf: base.appendingPathComponent("source.pdf"))
        let document = PartsmithDocument(project: before, sourcePDFData: source)
        let bass = before.parts.first { $0.name == "Bass" }!
        let target = before.bands.first { $0.partID == bass.id && $0.displayedBarNumber == 67 }!
        document.updateBandPageBreakBefore(target.id, pageBreakBefore: true)
        var after = document.project
        var reset = after
        reset.bands[reset.bands.firstIndex(where: { $0.id == target.id })!].pageBreakBefore = target.pageBreakBefore
        reset.modifiedAt = before.modifiedAt
        precondition(reset == before, "Unexpected project change")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let saved = try encoder.encode(Envelope(project: after))
        after = try decoder.decode(Envelope.self, from: saved).project
        let resaved = try encoder.encode(Envelope(project: after)); precondition(resaved == saved)
        let reopened = PartsmithDocument(project: after, sourcePDFData: source)
        let pdf = reopened.pdfDocument!
        var results: [PartResult] = []
        for part in after.parts {
            let old = try PartLayoutEngine.makePlan(project: before, pageBoundsProvider: { pdf.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
            let new = try PartLayoutEngine.makePlan(project: after, pageBoundsProvider: { pdf.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
            let oldRows = old.pages.flatMap(\.placements), newRows = new.pages.flatMap(\.placements)
            precondition(oldRows.flatMap(\.sourceBandIDs) == newRows.flatMap(\.sourceBandIDs))
            for (a,b) in zip(oldRows,newRows) {
                precondition(a.sourceRect == b.sourceRect && a.destinationRect.size == b.destinationRect.size)
                precondition(a.sourceMarkings.map(\.sourceRect) == b.sourceMarkings.map(\.sourceRect))
            }
            let lookup = Dictionary(uniqueKeysWithValues: after.bands.map { ($0.id, $0.displayedBarNumber) })
            let file = part.name + ".pdf"
            try PartPDFExporter.export(partID: part.id, document: reopened, to: output.appendingPathComponent(file))
            let data = try Data(contentsOf: output.appendingPathComponent(file))
            results.append(PartResult(name: part.name, originalPages: old.pages.count, newPages: new.pages.count,
                originalStartBars: old.pages.map { $0.placements.map { lookup[$0.bandID] ?? nil } },
                newStartBars: new.pages.map { $0.placements.map { lookup[$0.bandID] ?? nil } },
                bandCount: newRows.flatMap(\.sourceBandIDs).count, filename: file, sha256: hash(data)))
        }
        let pkg = output.appendingPathComponent(base.lastPathComponent)
        try FileManager.default.createDirectory(at: pkg, withIntermediateDirectories: true)
        try saved.write(to: pkg.appendingPathComponent("project.json"));try source.write(to: pkg.appendingPathComponent("source.pdf"))
        try encoder.encode(results).write(to: output.appendingPathComponent("reflow-report.json"))
        print(String(data: try encoder.encode(results), encoding: .utf8)!)
    }
}
