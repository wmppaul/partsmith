import Foundation

@main enum SystemAssignmentBatchTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError(message) }
    }
    static func rejects(_ message: String, _ operation: () throws -> Void) {
        do { try operation(); fatalError(message) } catch { checks += 1 }
    }
    static func main() throws {
        let profile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "voice", name: "Voice", staffCount: 1),
            ScorePartDefinition(id: "piano", name: "Piano", staffCount: 2)
        ], requiresSystemAssignment: true)
        let staves = [0.12, 0.18, 0.24, 0.40, 0.47, 0.68, 0.75, 0.82].enumerated().map { index, top in
            ScoreObservedStaff(StaffBandCandidate(id: index,
                staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
                topFraction: top - 0.01, bottomFraction: top + 0.03, confidence: 1, warnings: []))
        }
        let page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1800, imageHeight: 2400, staves: staves, warnings: [])
        var seed = try ScoreSystemAssignment.assign(page: page, profile: profile, pagePlan: nil,
            existingOverride: nil, systemIndex: 0, candidateIDs: [0, 1, 2], presentPartIDs: ["voice", "piano"],
            startBarNumber: 1, barCount: 3)
        seed.systems[0].bands[0].rect = [0, 70, 600, 115]
        seed.systems[0].bands[0].sourceMarkings = [[30, 40, 95, 55]]
        seed.systems[0].bands[0].pageBreakBefore = true
        let initial = ScoreDetectionReview.initial(profile: profile, analyses: [page], overrides: [seed],
            selectedPageIndices: [0], sourcePDFData: Data("immutable-source".utf8), rectifications: [])
        check(!initial.plan.canApply, "Seed alone must leave unassigned source systems unresolved")
        let silent = ScoreSystemAssignmentChoice(pageIndex: 0, systemIndex: 1, candidateIDs: [3, 4],
            presentPartIDs: ["piano"], startBarNumber: 4, barCount: 4)
        let full = ScoreSystemAssignmentChoice(pageIndex: 0, systemIndex: 2, candidateIDs: [5, 6, 7],
            presentPartIDs: ["voice", "piano"], startBarNumber: nil, barCount: nil)
        let applied = try ScoreSystemAssignmentBatch.applying([full, silent], to: initial)
        check(applied.plan.canApply && applied.plan.bands.count == 6, "Reverse-ordered selection applies complete systems in source order")
        check(applied.overrides[0].systems[0] == seed.systems[0], "Existing crop, source copy, measure span and page break remain exact")
        check(initial.overrides == [seed], "Applying returns a new review without modifying the input")
        let rest = applied.plan.bands.first { $0.partID == "voice" && $0.systemIndex == 1 }
        check(rest?.generatedRest?.barCount == 4 && rest?.generatedRest?.startBarNumber == 4,
              "Explicit target count determines silence; three-bar seed count is never copied")
        check(applied.plan.bands.filter { $0.systemIndex == 2 }.allSatisfy { $0.barCount == nil && $0.startBarNumber == nil },
              "Full-profile match may remain unnumbered without inventing a measure span")
        check(applied.sourcePDFData == initial.sourcePDFData && applied.analyses == initial.analyses,
              "Applying layouts never mutates the source or detector evidence")
        var swappedSilent = silent; swappedSilent.systemIndex = 2
        var swappedFull = full; swappedFull.systemIndex = 1
        rejects("Disjoint systems must not reorder the actual printed music") {
            _ = try ScoreSystemAssignmentBatch.applying([swappedSilent, swappedFull], to: initial)
        }
        var noCount = silent; noCount.barCount = nil
        rejects("Silent layout must not use an absent or copied measure count") {
            _ = try ScoreSystemAssignmentBatch.applying([full, noCount], to: initial)
        }
        check(initial.overrides == [seed], "A later missing-count failure cannot partially apply the earlier valid choice")
        rejects("Repeating a chosen source system is ambiguous") {
            _ = try ScoreSystemAssignmentBatch.applying([silent, silent], to: initial)
        }
        var overlap = full; overlap.candidateIDs = [4, 5, 6]
        rejects("Two chosen systems cannot share a physical staff") {
            _ = try ScoreSystemAssignmentBatch.applying([silent, overlap], to: initial)
        }
        var stealing = full; stealing.candidateIDs = [2, 3, 4]
        rejects("A new match cannot steal an already reviewed staff") {
            _ = try ScoreSystemAssignmentBatch.applying([stealing], to: initial)
        }
        var overwrite = full; overwrite.systemIndex = 0
        rejects("A different staff range cannot replace an already reviewed system") {
            _ = try ScoreSystemAssignmentBatch.applying([overwrite], to: initial)
        }
        rejects("Applying a stale previously used result cannot overwrite current crops") {
            _ = try ScoreSystemAssignmentBatch.applying([silent, full], to: applied)
        }
        var excluded = initial; excluded.excludedPageReasons[0] = "Outside movement"
        rejects("An excluded page cannot receive a suggested assignment") {
            _ = try ScoreSystemAssignmentBatch.applying([silent], to: excluded)
        }
        var outside = initial; outside.selectedPageIndices = []
        rejects("A page outside the chosen input scope cannot receive an assignment") {
            _ = try ScoreSystemAssignmentBatch.applying([silent], to: outside)
        }
        var ignored = initial; ignored.overrides[0].ignoredCandidateIDs = [4]
        rejects("Ignored staff detections cannot return through a suggestion") {
            _ = try ScoreSystemAssignmentBatch.applying([silent], to: ignored)
        }
        var missing = full; missing.pageIndex = 1
        rejects("Missing source page fails without partial application") {
            _ = try ScoreSystemAssignmentBatch.applying([silent, missing], to: initial)
        }
        rejects("Empty selection changes nothing") {
            _ = try ScoreSystemAssignmentBatch.applying([], to: initial)
        }
        var duplicateID = full; duplicateID.candidateIDs = [5, 6, 6]
        rejects("Duplicate detected staff IDs are rejected by the assignment API") {
            _ = try ScoreSystemAssignmentBatch.applying([duplicateID], to: initial)
        }
        var discontinuous = full; discontinuous.candidateIDs = [3, 5, 7]
        rejects("Discontinuous selections cannot become one source system") {
            _ = try ScoreSystemAssignmentBatch.applying([discontinuous], to: initial)
        }
        var tooMany = silent; tooMany.barCount = 1000
        rejects("Out-of-range rest counts are not accepted by a bulk action") {
            _ = try ScoreSystemAssignmentBatch.applying([tooMany], to: initial)
        }
        var overflow = silent; overflow.startBarNumber = Int.max
        rejects("Counted rest span must not overflow its starting measure") {
            _ = try ScoreSystemAssignmentBatch.applying([overflow], to: initial)
        }
        rejects("Cancelled batch cannot publish any assignments") {
            _ = try ScoreSystemAssignmentBatch.applying([silent, full], to: initial, isCancelled: { true })
        }
        var cancellationChecks = 0
        rejects("Cancellation after a staged choice still leaves the original review intact") {
            _ = try ScoreSystemAssignmentBatch.applying([silent, full], to: initial, isCancelled: {
                cancellationChecks += 1
                return cancellationChecks >= 5
            })
        }
        check(initial.overrides == [seed], "Cancellation preserves the original assigned crop and source copy")
        print("\(checks) batch system-assignment checks passed")
    }
}
