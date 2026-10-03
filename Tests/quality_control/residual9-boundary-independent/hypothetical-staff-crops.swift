import Foundation
struct Inventory: Decodable { let pages: [ScorePageAnalysis] }
struct Job: Decodable { let id: String; let page: Int }
struct Row: Encodable {
    let id: String
    let page: Int
    let before: ScoreExtractionPlan
    let after: ScoreExtractionPlan
}
@main struct Probe {
    static func main() throws {
        let args = CommandLine.arguments
        let jobs = try JSONDecoder().decode([Job].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        var rows: [Row] = []
        for job in jobs {
            let inputs = try ["baseline", "candidate-v2"].map { variant in
                try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: URL(fileURLWithPath: ".build/residual9-boundary-2026-10-03/\(variant)/corpus/\(job.id).json")))
            }
            let pages = inputs.map { $0.pages[job.page - 1] }
            let profile = ScoreExtractionProfile(parts: pages[0].staves.enumerated().map { i, staff in
                ScorePartDefinition(id: "staff-\(staff.id)", name: "Diagnostic staff \(i + 1)", staffCount: 1)
            }, cropMode: "compact")
            rows.append(Row(id: job.id, page: job.page,
                before: ScoreExtractionPlanner.plan(pages: [pages[0]], profile: profile),
                after: ScoreExtractionPlanner.plan(pages: [pages[1]], profile: profile)))
        }
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try e.encode(rows).write(to: URL(fileURLWithPath: args[2]))
        print("Planned \(rows.count) pages with diagnostic-only one-part-per-observed-staff profiles. No instrument identity or system grouping inferred.")
    }
}
