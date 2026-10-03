import Foundation

private struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
private struct Outcome: Codable {
    var bandCount: Int; var sourceCopyCount: Int; var materializedIssues: [String]; var implicitIssues: [String]
    var maximumFractionalRoundoff: Double
}
@main enum ActualScoreNoOp {
    static func main() throws {
        let args=CommandLine.arguments
        let inventory=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:args[1])))
        let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
        let pages=inventory.pages.filter { !$0.staves.isEmpty }
        let automatic=ScoreExtractionPlanner.plan(pages:pages,profile:profile)
        var maxDelta=0.0
        func coordinates(_ band: ScorePlannedBand) -> [Double] { [band.leftFraction,band.topFraction,band.rightFraction,band.bottomFraction] }
        func coordinates(_ mark: ScoreSourceMarking) -> [Double] { [mark.leftFraction,mark.topFraction,mark.rightFraction,mark.bottomFraction] }
        func differs(_ a: [Double],_ b:[Double]) -> Bool {
            guard a.count == b.count else { return true }
            let delta=zip(a,b).map { abs($0-$1) }.max() ?? 0
            maxDelta=max(maxDelta,delta);return delta > 1e-12
        }
        func compare(_ other: ScoreExtractionPlan) -> [String] {
            var failures:[String]=[]
            if !automatic.canApply || !other.canApply { failures.append("Plan is unresolved") }
            let previous=Dictionary(uniqueKeysWithValues:automatic.bands.map { ($0.id,$0) })
            if Set(previous.keys) != Set(other.bands.map(\.id)) { failures.append("Band IDs changed") }
            for band in other.bands {
                guard let before=previous[band.id] else { continue }
                if before.candidateIDs != band.candidateIDs || before.partID != band.partID || before.systemIndex != band.systemIndex || before.kind != band.kind {
                    failures.append("\(band.id): ownership changed")
                }
                if differs(coordinates(before),coordinates(band)) { failures.append("\(band.id): music crop changed") }
                if before.sourceMarkings.count != band.sourceMarkings.count { failures.append("\(band.id): source copy count changed") }
                else { for (a,b) in zip(before.sourceMarkings,band.sourceMarkings) {
                    if a.isBelow != b.isBelow || differs(coordinates(a),coordinates(b)) { failures.append("\(band.id): source copy changed") }
                } }
            }
            return failures
        }
        let initial=pages.map { page in
            ScoreSystemAssignment.pageOverride(page:page,pagePlan:automatic.pages.first { $0.pageIndex == page.pageIndex },existingOverride:nil)
        }
        // Roundtrip exact app materialization before comparing to automatic.
        let materialized=try JSONDecoder().decode([ScorePageOverride].self,from:JSONEncoder().encode(initial))
        let retained=ScoreExtractionPlanner.plan(pages:pages,profile:profile,overrides:materialized)
        var implicit=materialized
        for p in implicit.indices { for s in implicit[p].systems.indices { for b in implicit[p].systems[s].bands.indices {
            implicit[p].systems[s].bands[b].sourceMarkings=nil
            implicit[p].systems[s].bands[b].sourceMarkingsBelow=nil
        } } }
        let rebuilt=ScoreExtractionPlanner.plan(pages:pages,profile:profile,overrides:implicit)
        let first=compare(retained),second=compare(rebuilt)
        let outcome=Outcome(bandCount:automatic.bands.count,sourceCopyCount:automatic.bands.reduce(0) { $0+$1.sourceMarkings.count },
            materializedIssues:first,implicitIssues:second,maximumFractionalRoundoff:maxDelta)
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(outcome).write(to:URL(fileURLWithPath:args[3]))
        print("\(outcome.bandCount) bands, \(outcome.sourceCopyCount) copies; materialized=\(first.count), implicit=\(second.count), max roundoff=\(maxDelta)")
        if !first.isEmpty || !second.isEmpty { exit(1) }
    }
}
