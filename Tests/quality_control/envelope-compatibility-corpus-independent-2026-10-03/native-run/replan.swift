import Foundation

/// Reuse immutable native page analyses with the current planner only.
/// This executable does not load a PDF, rasterize a page, or invoke analysis.
@main enum ReplanFrozenCorpus {
    struct Input: Decodable { var pages: [ScorePageAnalysis] }
    static func main() throws {
        guard CommandLine.arguments.count == 4 else {
            throw NSError(domain: "replan", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Expected input inventory, unchanged profile, and output path"])
        }
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let profileURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let output = URL(fileURLWithPath: CommandLine.arguments[3])
        let data = try Data(contentsOf: source)
        let input = try JSONDecoder().decode(Input.self, from: data)
        let profile = try JSONDecoder().decode(ScoreExtractionProfile.self,
            from: Data(contentsOf: profileURL))
        let plan = ScoreExtractionPlanner.plan(pages: input.pages, profile: profile)
        // Keep the original untyped pages, including every optional/native
        // field. Only the plan value changes; no decoder roundtrip of pages.
        var raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        raw["plan"] = try JSONSerialization.jsonObject(with: encoder.encode(plan))
        try JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys])
            .write(to: output, options: .atomic)
        print("Replanned \(input.pages.count) existing page analyses; \(plan.bands.count) bands")
    }
}
