import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

@main enum RealCases {
    struct Input: Decodable {
        struct Binding: Decodable { var path: String; var sha256: String }
        struct Raster: Decodable { var physicalPage: Int; var raster: String; var sha256: String }
        var baselineInventory: Binding
        var profile: Binding
        var sourceRasters: [Raster]
    }
    struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
    struct Timing: Codable { var physicalPage: Int; var analysisSeconds: Double }
    struct Output: Encodable { var pages: [ScorePageAnalysis]; var plan: ScoreExtractionPlan; var timings: [Timing]; var planningSeconds: Double }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func main() throws {
        let root = URL(fileURLWithPath: ".build/p34-local-ownership-real-cases-2026-10-03")
        let config = try JSONDecoder().decode(Input.self, from: Data(contentsOf: root.appendingPathComponent("protocol-before-results.json")))
        let inputData = try Data(contentsOf: URL(fileURLWithPath: config.baselineInventory.path))
        precondition(hash(inputData) == config.baselineInventory.sha256)
        let base = try JSONDecoder().decode(Inventory.self, from: inputData)
        let profileData = try Data(contentsOf: URL(fileURLWithPath: config.profile.path))
        precondition(hash(profileData) == config.profile.sha256)
        let profile = try JSONDecoder().decode(ScoreExtractionProfile.self, from: profileData)
        var pages: [ScorePageAnalysis] = [], timings: [Timing] = []
        for row in config.sourceRasters {
            let raw = try Data(contentsOf: URL(fileURLWithPath: row.raster))
            precondition(hash(raw) == row.sha256)
            let source = CGImageSourceCreateWithData(raw as CFData, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            let original = base.pages.first { $0.pageIndex == row.physicalPage - 1 }!
            let start = Date()
            let analysis = NativeScorePageAnalyzer.analyze(pageIndex: original.pageIndex, image: image,
                pageWidth: original.pageWidth, pageHeight: original.pageHeight)
            let elapsed = Date().timeIntervalSince(start)
            precondition(analysis.staves == original.staves, "Staff geometry changed")
            precondition(analysis.imageWidth == original.imageWidth && analysis.imageHeight == original.imageHeight)
            pages.append(analysis); timings.append(.init(physicalPage: row.physicalPage, analysisSeconds: elapsed))
            print("page \(row.physicalPage): \(elapsed) seconds, \(analysis.inkComponents?.count ?? -1) components")
            fflush(stdout)
        }
        let start = Date()
        let plan = ScoreExtractionPlanner.plan(pages: pages, profile: profile)
        let output = Output(pages: pages, plan: plan, timings: timings, planningSeconds: Date().timeIntervalSince(start))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(output).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Total \(pages.count) pages, \(plan.bands.count) bands, canApply \(plan.canApply)")
    }
}
