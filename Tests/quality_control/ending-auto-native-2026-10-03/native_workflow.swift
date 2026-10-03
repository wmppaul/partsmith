import AppKit
import CryptoKit
import Foundation
import PDFKit

/// Prepared full-score native recognition harness. Building is harmless; running
/// performs the expensive real Mac Vision passes and is intentionally separate
/// from the frozen-evidence integration tests.
@main enum NativeEndingWorkflow {
    struct Inventory: Decodable {
        var source: String
        var sourceSHA256: String
        var pages: [ScorePageAnalysis]
        var rectifications: [PageRectification]?
    }
    static func read<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func write(_ value: Any, _ path: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: path)
    }
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3, ["brahms", "kv498", "all"].contains(args[1]) else {
            fputs("Use native_workflow brahms|kv498|all NEW-OUTPUT-DIRECTORY\n", stderr)
            exit(2)
        }
        let output = URL(fileURLWithPath: args[2], isDirectory: true)
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw NSError(domain: "EndingWorkflow", code: 1, userInfo: [NSLocalizedDescriptionKey: "Output already exists; choose a new folder."])
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var allMatch = true
        for (name, inventoryPath, profilePath, sourceHash) in [
            ("brahms", ".build/qc-brahms-traced-ending-combination/inventory.json",
             "Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json",
             "662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a"),
            ("kv498", ".build/qc-algorithm-audit/heading-dedup/kv498-native-inventory.json",
             "Tests/quality_control/profiles/normal-mozart-trio-eb-major-kv498-score.json",
             "f4b64106fa23d408943ec49e86d4bc0177f634c73ce7e146f7ee2f8f5ecbe9c9")
        ] where args[1] == "all" || args[1] == name {
            let input = try read(Inventory.self, inventoryPath)
            let source = try Data(contentsOf: URL(fileURLWithPath: input.source))
            guard input.sourceSHA256 == sourceHash, hash(source) == sourceHash,
                  let pdf = PDFDocument(data: source), pdf.pageCount == input.pages.count,
                  input.pages.map(\.pageIndex) == Array(0..<pdf.pageCount) else {
                throw NSError(domain: "EndingWorkflow", code: 2, userInfo: [NSLocalizedDescriptionKey: "Source hash or complete page roster differs."])
            }
            let profile = try read(ScoreExtractionProfile.self, profilePath)
            let expectedPath = ".build/ending-auto-integration/expected-plans/\(name).json"
            let expected = try read(ScoreExtractionPlan.self, expectedPath)
            let started = Date()
            let result = ScoreSharedDirectionWorkflow.run(pdf: pdf, analyses: input.pages,
                profile: profile, rectifications: input.rectifications ?? [], progress: { p in
                    print("\(name) \(p.phase.rawValue) \(p.completedPages)/\(p.totalPages)")
                    fflush(stdout)
                }, isCancelled: { false })
            let review = ScoreDetectionReview.initial(profile: profile, analyses: result.analyses,
                sourcePDFData: source, rectifications: input.rectifications ?? [],
                directionIssues: result.issues, directionReferences: result.references)
            let scoreOutput = output.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: scoreOutput, withIntermediateDirectories: true)
            var inventory = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: inventoryPath))) as! [String: Any]
            inventory["pages"] = try JSONSerialization.jsonObject(with: encoder.encode(result.analyses))
            try write(inventory, scoreOutput.appendingPathComponent("inventory.json"))
            try encoder.encode(review.plan).write(to: scoreOutput.appendingPathComponent("plan.json"))
            let expectedByID = Dictionary(uniqueKeysWithValues: expected.bands.map { ($0.id, $0) })
            let actualByID = Dictionary(uniqueKeysWithValues: review.plan.bands.map { ($0.id, $0) })
            let ids = Set(expectedByID.keys).union(actualByID.keys).sorted()
            let changed = ids.filter { expectedByID[$0] != actualByID[$0] }
            let complete = review.plan.canApply && review.plan.bands == expected.bands
            allMatch = allMatch && complete
            let endings = result.analyses.flatMap { $0.sharedEndings ?? [] }
            let report: [String: Any] = [
                "source": input.source, "sourceSHA256": sourceHash,
                "inputInventory": inventoryPath, "inputInventorySHA256": hash(try Data(contentsOf: URL(fileURLWithPath: inventoryPath))),
                "profile": profilePath, "profileSHA256": hash(try Data(contentsOf: URL(fileURLWithPath: profilePath))),
                "expectedPlan": expectedPath, "expectedPlanSHA256": hash(try Data(contentsOf: URL(fileURLWithPath: expectedPath))),
                "actualPlanSHA256": hash(try encoder.encode(review.plan)),
                "pages": input.pages.count, "savedRectifications": input.rectifications?.count ?? 0,
                "seconds": Date().timeIntervalSince(started), "nativeVisionRun": true,
                "bands": review.plan.bands.count, "copies": review.plan.bands.reduce(0) { $0 + $1.sourceMarkings.count },
                "pairedEndings": Set(endings.map(\.pairID)).count, "endingSourceRows": endings.count,
                "exactBandPlanMatch": complete, "changedBandIDs": changed,
                "issues": result.issues.map { ["pageIndex": $0.pageIndex, "message": $0.message] as [String: Any] },
                "unresolved": review.plan.pages.filter { !$0.unresolvedReasons.isEmpty }.map {
                    ["pageIndex": $0.pageIndex, "reasons": $0.unresolvedReasons] as [String: Any]
                },
                "destinationReferences": result.references.map { r in [
                    "pageIndex": r.pageIndex, "anchorStaffID": r.match.anchorStaffID,
                    "bounds": r.match.bounds, "correlation": r.match.correlation,
                    "templatePageIndex": r.match.templatePageIndex, "templateBounds": r.match.templateBounds
                ] as [String: Any] },
                "limits": "Recognition-only integration check; compare exported PDFs and review labels/highlights/removal in the packaged app before promotion. Frozen six Brahms ending-envelope failures remain; margins were not enlarged."
            ]
            try write(report, scoreOutput.appendingPathComponent("comparison.json"))
            print("\(name): \(complete ? "EXACT" : "DIFFERENT") \(review.plan.bands.count) bands, \(changed.count) changed. All evidence saved.")
        }
        if !allMatch { exit(1) }
    }
}
