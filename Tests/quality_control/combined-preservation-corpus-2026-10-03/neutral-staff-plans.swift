import Foundation
struct Inventory: Decodable { let pages: [ScorePageAnalysis] }
struct Job: Decodable { let id: String; let page: Int; let beforeInventory: String; let afterInventory: String }
struct Row: Encodable { let id: String; let page: Int; let before: ScoreExtractionPlan; let after: ScoreExtractionPlan }
@main struct NeutralStaffProbe {
    static func main() throws {
        let jobs = try JSONDecoder().decode([Job].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        var rows: [Row] = []
        var cache: [String: Inventory] = [:]
        for job in jobs {
            let paths = [job.beforeInventory, job.afterInventory]
            for path in paths where cache[path] == nil {
                cache[path] = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            }
            let pages = paths.map { cache[$0]!.pages[job.page - 1] }
            guard pages[0].staves.map(\.id) == pages[1].staves.map(\.id) else {
                throw NSError(domain: "NeutralStaffProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Changed observed staff identities on \(job.id) p\(job.page); cannot assume equivalent neutral profiles."])
            }
            let profile = ScoreExtractionProfile(parts: pages[0].staves.enumerated().map { i, staff in
                ScorePartDefinition(id: "staff-\(staff.id)", name: "Diagnostic staff \(i + 1)", staffCount: 1)
            }, cropMode: "compact")
            rows.append(Row(id: job.id, page: job.page,
                before: ScoreExtractionPlanner.plan(pages: [pages[0]], profile: profile),
                after: ScoreExtractionPlanner.plan(pages: [pages[1]], profile: profile)))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rows).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("Diagnostic only: \(rows.count) pages; no instrument identity or musical system grouping inferred.")
    }
}
