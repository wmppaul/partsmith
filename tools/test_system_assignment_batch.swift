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
        // A section may split while another printed part uses fewer staves.
        // Names and the total staff count alone cannot preserve this grouping.
        var divided = full
        divided.staffCounts = ["voice": 2, "piano": 1]
        let withDivisi = try ScoreSystemAssignmentBatch.applying([silent, divided], to: initial)
        let lastSystem = withDivisi.overrides[0].systems[2]
        check(lastSystem.bands.first { $0.partID == "voice" }?.candidateIDs == [5, 6],
              "Explicit section divisi retains both selected staves in one part")
        check(lastSystem.bands.first { $0.partID == "piano" }?.candidateIDs == [7],
              "Following part begins after the locally expanded section")
        check(withDivisi.profile == profile, "Local grouping does not alter the global instrument setup")
        check(withDivisi.overrides[0].systems[0] == seed.systems[0], "Local grouping preserves earlier crop edits and source copies")
        check(withDivisi.plan.canApply && withDivisi.plan.bands.count == 6, "Divisi plan retains all systems and silent time")
        check(withDivisi.plan.bands.first { $0.partID == "voice" && $0.systemIndex == 2 }?.candidateIDs == [5, 6],
              "The crop planner consumes the actual local section grouping")
        let restored = try JSONDecoder().decode([ScorePageOverride].self, from: JSONEncoder().encode(withDivisi.overrides))
        check(restored == withDivisi.overrides, "Local grouping survives the existing saved override format")
        var oneLocalCount = silent; oneLocalCount.staffCounts = ["piano": 2]
        let explicitDefault = try ScoreSystemAssignmentBatch.applying([full, oneLocalCount], to: initial)
        check(explicitDefault.overrides == applied.overrides && explicitDefault.plan == applied.plan,
              "Explicit default count is identical to legacy behavior")
        for badCounts in [["voice": 0], ["voice": 5], ["voice": -1], ["voice": Int.max], ["unknown": 1], ["voice": 2]] {
            var badChoice = full; badChoice.staffCounts = badCounts
            rejects("Invalid or mismatched local counts cannot apply a partial batch: \(badCounts)") {
                _ = try ScoreSystemAssignmentBatch.applying([silent, badChoice], to: initial)
            }
        }
        var absentCount = silent; absentCount.staffCounts = ["voice": 1]
        rejects("A count for an absent part cannot silently change its rest assignment") {
            _ = try ScoreSystemAssignmentBatch.applying([absentCount], to: initial)
        }
        check(initial.overrides == [seed], "Failed local groupings leave all initial assignments intact")
        let identifiers = [90, 8, 42, 13, 99, 2, 88, 50]
        var renamedPage = page
        for i in renamedPage.staves.indices { renamedPage.staves[i].id = identifiers[i] }
        var renamedSeed = seed
        for i in renamedSeed.systems[0].bands.indices {
            renamedSeed.systems[0].bands[i].candidateIDs = seed.systems[0].bands[i].candidateIDs?.map { identifiers[$0] }
        }
        let renamedReview = ScoreDetectionReview.initial(profile: profile, analyses: [renamedPage], overrides: [renamedSeed],
            selectedPageIndices: [0], sourcePDFData: initial.sourcePDFData, rectifications: [])
        var renamedSilent = silent; renamedSilent.candidateIDs = silent.candidateIDs.map { identifiers[$0] }
        var renamedDivided = divided; renamedDivided.candidateIDs = divided.candidateIDs.map { identifiers[$0] }
        let renamedResult = try ScoreSystemAssignmentBatch.applying([renamedSilent, renamedDivided], to: renamedReview)
        check(renamedResult.plan.canApply && renamedResult.plan.bands.count == withDivisi.plan.bands.count,
              "Nonsequential staff identifiers remain valid through assignment and crop planning")
        check(renamedResult.plan.bands.first { $0.partID == "voice" && $0.systemIndex == 2 }?.candidateIDs == [2, 88],
              "Planner preserves original identifiers while validating actual reading order")
        var disconnected = renamedResult.overrides
        disconnected[0].systems[2].bands[0].candidateIDs = [2, 50]
        disconnected[0].systems[2].bands[1].candidateIDs = [88]
        let rejectedPlan = ScoreDetectionReview.initial(profile: profile, analyses: [renamedPage], overrides: disconnected,
            selectedPageIndices: [0], sourcePDFData: initial.sourcePDFData, rectifications: []).plan
        check(!rejectedPlan.canApply && rejectedPlan.bands.isEmpty,
              "Physical nonconsecutive grouping is rejected even when every source staff is accounted for")
        print("\(checks) batch system-assignment checks passed")
    }
}
