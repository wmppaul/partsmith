import AppKit
import Foundation
import PDFKit

@main enum NumberWindowStudy {
    struct Job: Decodable {
        var id: String; var source: String; var inventory: String; var profile: String
        var targetPageIndex: Int; var targetSystemIndex: Int
    }
    struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
    struct Output: Codable {
        var score: String; var page: Int; var system: Int
        var result: ScoreSharedEndingDetector.PageResult
        var pairs: [ScoreSharedEndingDetector.Pair]
        var errors: [String]
    }
    static func read<T: Decodable>(_ t: T.Type, _ p: String) throws -> T {
        try JSONDecoder().decode(t, from: Data(contentsOf: URL(fileURLWithPath: p)))
    }
    static func main() throws {
        let root = ".build/ending-number-window-2026-10-03"
        let jobs = try read([Job].self, root + "/jobs.json")
        var results: [Output] = []
        for job in jobs {
            try autoreleasepool {
                let profile = try read(ScoreExtractionProfile.self, job.profile)
                let page = try read(Inventory.self, job.inventory).pages.first { $0.pageIndex == job.targetPageIndex }!
                let pdf = PDFDocument(url: URL(fileURLWithPath: job.source))!
                let image = NativeScorePageAnalyzer.render(pdf.page(at: page.pageIndex)!, maximumWidth: 2400, maximumHeight: 3500)!
                var errors: [String] = []
                let result = ScoreSharedEndingDetector.analyze(in: image, page: page, profile: profile,
                    observedFailure: { errors.append($0.localizedDescription) })
                let pairs = ScoreSharedEndingDetector.pairs(in: [result])
                results.append(.init(score: job.id, page: page.pageIndex, system: job.targetSystemIndex, result: result, pairs: pairs, errors: errors))
                print("\(job.id) p\(page.pageIndex + 1): \(result.candidates.count) candidates, \(pairs.count) pairs, \(errors.count) failures")
                fflush(stdout)
            }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: URL(fileURLWithPath: root + "/results.json"))
    }
}
