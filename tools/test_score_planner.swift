import Foundation
import PDFKit

@main
enum ScorePlannerTests {
    static var assertions = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        assertions += 1
        if !condition() { throw NSError(domain: "ScorePlannerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func main() throws {
        let profile = ScoreExtractionProfile(parts: [ScorePartDefinition(id: "voice", name: "Voice", staffCount: 1), ScorePartDefinition(id: "piano", name: "Piano", staffCount: 2)])
        let staves = [0.15, 0.22, 0.30, 0.53, 0.60, 0.68].enumerated().map { i, y in
            ScoreObservedStaff(StaffBandCandidate(id: i, staffLineFractions: (0..<5).map { y + Double($0) * 0.005 }, topFraction: y - 0.01, bottomFraction: y + 0.03, confidence: 0.9, warnings: []))
        }
        var page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800, imageWidth: 1500, imageHeight: 2000, staves: staves, warnings: [])
        let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        try check(plan.canApply && plan.bands.count == 4, "Two-system voice/piano cadence failed")
        try check(plan.bands[1].candidateIDs == [1, 2] && plan.bands[3].candidateIDs == [4, 5], "Grand-staff grouping is wrong")
        try check(plan.bands.allSatisfy { $0.editorialLabel.isEmpty && !$0.pageBreakBefore }, "Automatic plans added debug labels or forced page breaks")
        try check(plan.bands[0].topFraction < staves[0].staffLineFractions[0] - 0.03, "Preserving context padding missing")
        page.staves.removeLast()
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile).canApply, "Nondivisible count silently shifted part identity")
        page.staves = staves
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, isCancelled: { true }).canApply, "Canceled plan is applicable")
        var trimmed = profile; trimmed.leftTrimPoints = 20; trimmed.rightTrimPoints = 15
        let trimmedPlan = ScoreExtractionPlanner.plan(pages: [page], profile: trimmed)
        try check(abs(trimmedPlan.bands[0].leftFraction - 20.0/600) < 1e-10 && abs(trimmedPlan.bands[0].rightFraction - 15.0/600) < 1e-10, "Reviewed horizontal trims not applied")
        trimmed.rightTrimPoints = 600
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: trimmed).canApply, "Invalid trims accepted")
        page.analysisSkewDegrees = 1
        let skewed = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        try check(skewed.bands[0].topFraction < plan.bands[0].topFraction && skewed.bands[0].bottomFraction > plan.bands[0].bottomFraction, "Skew envelope clips one end")
        page.analysisSkewDegrees = 0
        var override = ScorePageOverride(pageIndex: 0, reason: "Source reviewed", systems: [
            ScoreSystemOverride(systemIndex: 0, bands: [ScoreBandOverride(partID: "voice", candidateIDs: [0]), ScoreBandOverride(partID: "piano", candidateIDs: [1, 2])]),
            ScoreSystemOverride(systemIndex: 1, bands: [ScoreBandOverride(partID: "voice", candidateIDs: [3]), ScoreBandOverride(partID: "piano", candidateIDs: [4, 5])])
        ])
        try check(ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Valid source-reviewed assignments rejected")
        override.systems[1].bands[0].candidateIDs = [0]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Repeated music candidate accepted")
        override.systems[1].bands[0].candidateIDs = [3]
        override.systems[1].bands[1].candidateIDs = [4]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Unaccounted detected staff accepted")
        override.ignoredCandidateIDs = [5]
        try check(ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Explicitly ignored false detection rejected")
        override.systems[1].bands[1].rect = [0, 0, 600, 30]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Source-reviewed crop clips recorded staff")
        override.systems[1].bands[1].rect = nil
        override.systems[0].bands[0].sourceMarkings = [[30, 15, 230, 35]]
        let marked = ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override])
        try check(marked.bands[0].sourceMarkings.count == 1 && marked.bands[0].sourceMarkings[0].topFraction == 15.0/800, "Shared marking coordinate conversion failed")
        override.systems[0].bands[0].sourceMarkings = [[-1, 15, 230, 35]]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Out-of-page source marking accepted")
        let blank = ScorePageAnalysis(pageIndex: 1, pageWidth: 600, pageHeight: 800, imageWidth: 1500, imageHeight: 2000, staves: [], warnings: [])
        try check(!ScoreExtractionPlanner.plan(pages: [page, blank], profile: profile).canApply, "Undetected page silently treated as tacet")
        let nonmusic = ScorePageOverride(pageIndex: 1, reason: "Back matter reviewed", systems: [], nonMusicReason: "Blank leaf")
        let omitted = ScoreExtractionPlanner.plan(pages: [page, blank], profile: profile, overrides: [nonmusic])
        try check(omitted.canApply && omitted.pages[1].omissions.count == 2, "Explicit nonmusic page is not accounted for")
        try check(!ScoreExtractionPlanner.plan(pages: [blank], profile: profile, overrides: [nonmusic]).canApply, "All-nonmusic score permits empty extraction")
        if CommandLine.arguments.contains("--corpus") { try corpusTests() }
        print("PASS \(assertions) native planner checks: cadence, grouping, crop padding, skew bounds, invalid counts, ignored candidates, nonmusic pages, shared markings and cancellation.")
    }
    struct SourceConfig: Decodable { var source: String; var profile: ScoreExtractionProfile }
    static func corpusTests() throws {
        let sources = try JSONDecoder().decode([String: SourceConfig].self,
            from: Data(contentsOf: URL(fileURLWithPath: "Tests/full_scores/sources.json")))
        let expected: [String: [Int]] = [
            "ave": [16,16,16,16], "notte": [13,15,15,15],
            "quartet": [16,20,20,20,20,20,20,20,20,20,16,16,16,16,20,20,20,20,20,20,20,20,20,20,20],
            "schumann": [12] + Array(repeating: 15, count: 13) + [12,12],
            "trio": [12] + Array(repeating: 16, count: 32) + [0,0]
        ]
        var pageCount = 0, staffCount = 0
        for name in ["ave", "notte", "quartet", "schumann", "trio"] {
            let config = sources[name]!
            guard let document = PDFDocument(url: URL(fileURLWithPath: config.source)) else {
                throw NSError(domain: "ScorePlannerTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing \(config.source)"])
            }
            try check(document.pageCount == expected[name]!.count, "Independent source page count changed: \(name)")
            for index in 0..<document.pageCount {
                try autoreleasepool {
                    let page = document.page(at: index)!, bounds = page.bounds(for: .mediaBox)
                    let image = NativeScorePageAnalyzer.render(page)!
                    let analysis = NativeScorePageAnalyzer.analyze(pageIndex: index, image: image, pageWidth: bounds.width, pageHeight: bounds.height)
                    try check(analysis.staves.count == expected[name]![index], "\(name) p\(index+1): expected \(expected[name]![index]) staves, found \(analysis.staves.count)")
                    if name == "quartet" && index == 8 {
                        // Independently checked cello staff: an earlier 20-staff result
                        // fitted a narrow pattern inside the true five-line staff.
                        let cello = analysis.staves[3]
                        let height = (cello.staffLineFractions[4] - cello.staffLineFractions[0]) * bounds.height
                        try check(height > 13.5 && height < 15.5,
                            "Quartet p9 first cello staff uses a narrow false line pattern")
                        try check(abs(cello.staffLineFractions[4] * bounds.height - 172.4) < 1.5,
                            "Quartet p9 first cello staff omits its actual bottom line")
                    }
                    if name == "trio" && index == 15 {
                        // Independent source-center measurements from score_survey.
                        // Matching only the count once hid piano beam/staff confusion.
                        let centers = [75.7,107.7,156.6,207.5,258.6,292.7,338.2,389.5,450,481.2,521.9,565.7,629.4,659.6,702.2,742.8]
                        for (staff, center) in zip(analysis.staves, centers) {
                            try check(abs(staff.staffLineFractions[2] * bounds.height - center) < 1.5,
                                "Trio p16 staff \(staff.id) is aligned with beams instead of the actual staff")
                        }
                    }
                    pageCount += 1; staffCount += analysis.staves.count
                }
            }
            print("PASS full-source native detection: \(name), \(document.pageCount) pages")
        }
        print("PASS full corpus: \(pageCount) pages, \(staffCount) musical staves; blank/catalog leaves detected empty but still require explicit source classification.")
    }

}
