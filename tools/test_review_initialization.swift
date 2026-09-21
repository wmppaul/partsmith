import Foundation

@main enum ReviewInitializationTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1; if !condition() { fatalError(message) }
    }
    static func main() {
        let source = Data([1, 2, 3])
        let header = SourceHeaderSelection(pageIndex: 5, topFraction: 0.02, bottomFraction: 0.10,
                                           leftFraction: 0.08, rightFraction: 0.08)
        let corrections = [PageRectification.default(pageIndex: 5)]
        let profile = ScoreExtractionProfile(parts: [.init(id: "vln", name: "Violin", staffCount: 1)], cropMode: "compact")
        let staff = ScoreObservedStaff(StaffBandCandidate(id: 0, staffLineFractions: [0.25, 0.26, 0.27, 0.28, 0.29],
            topFraction: 0.20, bottomFraction: 0.34, confidence: 1, warnings: ["Source warning"]))
        let music = ScorePageAnalysis(pageIndex: 5, pageWidth: 600, pageHeight: 800, imageWidth: 1200, imageHeight: 1600,
            staves: [staff], warnings: [], inkComponents: [],
            sharedHeadings: [.init(anchorStaffID: 0, bounds: [0.1, 0.1, 0.5, 0.13], recognizedText: "Allegro")])
        let blank = ScorePageAnalysis(pageIndex: 1, pageWidth: 600, pageHeight: 800, imageWidth: 1200, imageHeight: 1600,
            staves: [], warnings: ["No staves"], inkComponents: [])
        var failed = blank; failed.pageIndex = 3; failed.imageWidth = 0; failed.imageHeight = 0
        var narrowBlank = blank; narrowBlank.pageIndex = 7; narrowBlank.pageWidth = 1
        let override = ScorePageOverride(pageIndex: 1, reason: "Existing reviewed nonmusic page", systems: [],
                                         nonMusicReason: "Cover")
        for analyses in [[blank, music], [failed, music], [blank, failed, music], [blank], [music], [], [narrowBlank, music]] {
            for overrides in [[], [override]] {
                var legacy = ScoreDetectionReview(profile: profile, analyses: analyses,
                    plan: ScoreExtractionPlanner.plan(pages: analyses, profile: profile, overrides: overrides),
                    overrides: overrides, selectedPageIndices: Set(analyses.map(\.pageIndex)),
                    suggestedSourceHeader: header, sourcePDFData: source, rectifications: corrections)
                legacy.automaticallyExcludePagesWithoutStaves()
                let review = ScoreDetectionReview.initial(profile: profile, analyses: analyses, overrides: overrides,
                    selectedPageIndices: Set(analyses.map(\.pageIndex)), suggestedSourceHeader: header,
                    sourcePDFData: source, rectifications: corrections)
                check(review.plan == legacy.plan, "One-pass initialization changed plan, warnings or order")
                check(review.excludedPageReasons == legacy.excludedPageReasons && review.autoSkippedPageIndices == legacy.autoSkippedPageIndices,
                      "One-pass initialization changed nonmusic exclusions")
                check(review.analyses == analyses && review.overrides == overrides && review.selectedPageIndices == legacy.selectedPageIndices,
                      "Initialization dropped source analyses, stored overrides or input scope")
                check(review.suggestedSourceHeader == header && review.sourcePDFData == source && review.rectifications == corrections,
                      "Initialization changed source header/data/rectification identity")
            }
        }
        var review = ScoreDetectionReview.initial(profile: profile, analyses: [blank, music], sourcePDFData: source, rectifications: [])
        check(review.plan.canApply && review.autoSkippedPageIndices == [1], "Valid music with optional blank was blocked")
        check(review.plan.bands[0].sourceMarkings.count == 1, "Single-pass initialization dropped a shared source heading")
        review.restoreExcludedPage(1)
        check(review.excludedPageReasons.isEmpty && review.autoSkippedPageIndices.isEmpty, "Restored page stayed excluded")
        check(review.plan.pages.map(\.pageIndex) == [1, 5] && !review.plan.canApply,
              "Restored zero-staff page must return to the review plan")
        var withOverride = ScoreDetectionReview.initial(profile: profile, analyses: [blank, music], overrides: [override],
                                                        sourcePDFData: source, rectifications: [])
        withOverride.restoreExcludedPage(1)
        check(withOverride.plan.canApply && withOverride.overrides == [override] && !withOverride.plan.pages[0].omissions.isEmpty,
              "Restoring a skipped page lost its saved reviewed override")
        var trimmed = profile; trimmed.leftTrimPoints = 4
        var reference = ScoreDetectionReview(profile: trimmed, analyses: [narrowBlank, music],
            plan: ScoreExtractionPlanner.plan(pages: [narrowBlank, music], profile: trimmed), sourcePDFData: source, rectifications: [])
        reference.automaticallyExcludePagesWithoutStaves()
        let trimmedReview = ScoreDetectionReview.initial(profile: trimmed, analyses: [narrowBlank, music], sourcePDFData: source, rectifications: [])
        check(trimmedReview.plan == reference.plan && trimmedReview.plan.canApply,
              "Planning after exclusion must rerun global profile validation on the retained pages")
        let canceled = ScoreDetectionReview.initial(profile: profile, analyses: [blank, music], sourcePDFData: source,
                                                    rectifications: [], isCancelled: { true })
        check(canceled.plan.pages.isEmpty && !canceled.plan.canApply && canceled.analyses.count == 2,
              "Canceled initial planning exposed partial output or dropped source analyses")
        print("PASS: \(checks) initial-review equality, source metadata, exclusion/restoration, shared heading, global validation and cancellation checks")
    }
}
