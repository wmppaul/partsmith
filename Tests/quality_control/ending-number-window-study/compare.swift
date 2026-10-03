import Foundation

@main enum PairComparison {
    typealias D = ScoreSharedEndingDetector
    struct Output: Decodable { var score: String; var page: Int; var result: D.PageResult; var errors: [String] }
    struct Checkpoint: Decodable { var result: D.PageResult }
    struct Baseline: Decodable { var pages: [Checkpoint]; var pairs: [D.Pair] }
    struct Summary: Encodable {
        var score: String; var pages: Int; var oldPairs: Int; var newPairs: Int
        var oldCandidates: Int; var newCandidates: Int
        var missingOriginalCandidates: [D.Candidate]; var missingOriginalPairs: [D.Pair]
        var addedPairs: [D.Pair]; var barrierPages: [Int]; var errors: [String]
    }
    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }()
    static func read<T: Decodable>(_ t: T.Type, _ path: String) throws -> T {
        try JSONDecoder().decode(t, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }
    static func key<T: Encodable>(_ value: T) throws -> Data { try encoder.encode(value) }
    static func main() throws {
        let root = ".build/ending-number-window-2026-10-03"
        let rows = try read([Output].self, root + "/results.json")
        let scores = Dictionary(grouping: rows, by: \.score)
        var summaries: [Summary] = []
        for score in scores.keys.sorted() {
            let base = try read(Baseline.self, ".build/ending-corpus-2026-10-03/" + score + "/result.json")
            let observed = scores[score]!.sorted { $0.page < $1.page }
            guard observed.count == base.pages.count else { throw NSError(domain: "IncompleteScore", code: 1) }
            var pages = observed.map(\.result)
            // Retain independently affirmed blank/unknown barriers from the same
            // immutable source and staff inventory. No-staff OCR is not blank proof.
            for i in pages.indices where !base.pages[i].result.ownershipVerified {
                pages[i] = base.pages[i].result
            }
            let pairs = D.pairs(in: pages)
            let candidates = pages.flatMap(\.candidates)
            let candidateKeys = Set(try candidates.map { try key($0) })
            let pairKeys = Set(try pairs.map { try key($0) })
            let basePairKeys = Set(try base.pairs.map { try key($0) })
            let oldCandidates = base.pages.flatMap { $0.result.candidates }
            let missingCandidates = try oldCandidates.filter { !candidateKeys.contains(try key($0)) }
            let missingPairs = try base.pairs.filter { !pairKeys.contains(try key($0)) }
            let added = try pairs.filter { !basePairKeys.contains(try key($0)) }
            summaries.append(.init(score: score, pages: pages.count, oldPairs: base.pairs.count,
                newPairs: pairs.count, oldCandidates: oldCandidates.count, newCandidates: candidates.count,
                missingOriginalCandidates: missingCandidates, missingOriginalPairs: missingPairs,
                addedPairs: added, barrierPages: pages.filter { !$0.ownershipVerified }.map(\.pageIndex),
                errors: observed.flatMap(\.errors)))
            print("\(score): pairs \(base.pairs.count) → \(pairs.count); changed/missing original candidates \(missingCandidates.count); missing pairs \(missingPairs.count)")
        }
        try encoder.encode(summaries).write(to: URL(fileURLWithPath: root + "/broad-comparison.json"))
    }
}
