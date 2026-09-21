import Foundation
import AppKit
import PDFKit

@main enum ReviewInitializationTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1; if !condition() { fatalError(message) }
    }
    static func main() throws {
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
        var navigationPage = music
        navigationPage.pageIndex = 0
        navigationPage.sharedHeadings = nil
        navigationPage.staves = (0..<4).map { index in
            let top = 0.2 + Double(index) * 0.18
            return ScoreObservedStaff(StaffBandCandidate(id: index,
                staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
                topFraction: top - 0.02, bottomFraction: top + 0.04, confidence: 1, warnings: []))
        }
        navigationPage.sharedNavigation = [.init(anchorStaffID: 1,
            bounds: [0.4, 0.405, 0.85, 0.43], recognizedText: "Da Capo", isBelow: true)]
        let pairProfile = ScoreExtractionProfile(parts: [.init(id: "vln", name: "Violin", staffCount: 1),
            .init(id: "vc", name: "Cello", staffCount: 1)], cropMode: "compact")
        let data = NSMutableData()
        var bounds = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data as CFMutableData)!, mediaBox: &bounds, nil)!
        context.beginPDFPage(nil); context.endPDFPage(); context.closePDF()
        let sourcePDF = data as Data
        var navigationReview = ScoreDetectionReview.initial(profile: pairProfile, analyses: [navigationPage],
            sourcePDFData: sourcePDF, rectifications: [])
        check(navigationReview.plan.canApply && navigationReview.plan.bands.count == 4,
              "Shared navigation keeps complete ordered system assignment")
        let recipient = navigationReview.plan.bands.first { $0.partID == "vln" && $0.systemIndex == 0 }!
        let owner = navigationReview.plan.bands.first { $0.partID == "vc" && $0.systemIndex == 0 }!
        check(recipient.sourceMarkings.count == 1 && recipient.sourceMarkings[0].isBelow == true,
              "Shared end-of-system direction is copied below the correct recipient")
        check(owner.sourceMarkings.isEmpty && owner.bottomFraction >= 0.43,
              "Original instruction expands its crop without a duplicate annotation row")
        check(navigationReview.plan.bands.filter { $0.systemIndex == 1 }.allSatisfy { $0.sourceMarkings.isEmpty },
              "Instruction found before another system is not reassigned to it")
        var navigationOverride = ScoreSystemAssignment.pageOverride(page: navigationPage,
            pagePlan: navigationReview.plan.pages[0], existingOverride: nil)
        let replanned = ScoreExtractionPlanner.plan(pages: [navigationPage], profile: pairProfile, overrides: [navigationOverride])
        check(replanned.bands.first { $0.id == recipient.id }?.sourceMarkings == recipient.sourceMarkings,
              "Assignment review preserves direction side and source rectangle")
        try navigationReview.setCropEdges(for: recipient.id, top: recipient.topFraction * 800,
            bottom: recipient.bottomFraction * 800)
        check(navigationReview.plan.bands.first { $0.id == recipient.id }?.sourceMarkings == recipient.sourceMarkings,
              "Crop editing preserves below-system source directions")
        let ownerAfterRecipientEdit = navigationReview.plan.bands.first { $0.id == owner.id }!
        check([ownerAfterRecipientEdit.topFraction, ownerAfterRecipientEdit.bottomFraction,
               ownerAfterRecipientEdit.leftFraction, ownerAfterRecipientEdit.rightFraction]
              == [owner.topFraction, owner.bottomFraction, owner.leftFraction, owner.rightFraction],
              "Editing a recipient preserves the source owner's entire expanded crop")
        var unrelatedEdit = ScoreDetectionReview.initial(profile: pairProfile, analyses: [navigationPage],
            sourcePDFData: sourcePDF, rectifications: [])
        let unrelated = unrelatedEdit.plan.bands.first { $0.partID == "vln" && $0.systemIndex == 1 }!
        try unrelatedEdit.setCropEdges(for: unrelated.id, top: unrelated.topFraction * 800,
            bottom: unrelated.bottomFraction * 800)
        let ownerAfterUnrelatedEdit = unrelatedEdit.plan.bands.first { $0.id == owner.id }!
        check([ownerAfterUnrelatedEdit.topFraction, ownerAfterUnrelatedEdit.bottomFraction,
               ownerAfterUnrelatedEdit.leftFraction, ownerAfterUnrelatedEdit.rightFraction]
              == [owner.topFraction, owner.bottomFraction, owner.leftFraction, owner.rightFraction],
              "Editing an unrelated system preserves the source owner's entire expanded crop")
        try navigationReview.resetCropEdges(for: owner.id)
        let resetOwner = navigationReview.plan.bands.first { $0.id == owner.id }!
        check(resetOwner.bottomFraction >= 0.43 && resetOwner.sourceMarkings.isEmpty,
              "Resetting automatic owner cropping restores its complete printed instruction")
        let afterReset = navigationReview.plan.bands.first { $0.id == recipient.id }!
        check(afterReset.sourceMarkings == recipient.sourceMarkings
              && !afterReset.warnings.contains { $0.contains("repeat directions overlap") },
              "Replanning copied navigation is idempotent without false collision warnings")
        var recroppedOverride = ScoreSystemAssignment.pageOverride(page: navigationPage,
            pagePlan: navigationReview.plan.pages[0], existingOverride: nil)
        for s in recroppedOverride.systems.indices {
            for b in recroppedOverride.systems[s].bands.indices { recroppedOverride.systems[s].bands[b].rect = nil }
        }
        let recomputed = ScoreExtractionPlanner.plan(pages: [navigationPage], profile: pairProfile, overrides: [recroppedOverride])
        check(recomputed.bands.first { $0.id == owner.id }!.bottomFraction >= 0.43
              && recomputed.bands.first { $0.id == recipient.id }!.sourceMarkings == recipient.sourceMarkings,
              "Reviewed assignment recomputation retains original and copied directions")
        let document = PartsmithDocument(sourcePDFData: sourcePDF)
        check(document.addScoreParts(from: navigationReview) == 4, "Auto apply accepts valid navigation review")
        let applied = document.project.bands.flatMap(\.sourceMarkings)
        check(applied.count == 1 && applied[0].isBelow == true, "Auto apply persists navigation placement in the native project")
        let saved = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(document.project))
        check(saved.bands.flatMap(\.sourceMarkings) == applied, "Native save/reopen retains direction placement")
        navigationOverride.systems[0].bands[0].sourceMarkingsBelow = [true, false]
        check(!ScoreExtractionPlanner.plan(pages: [navigationPage], profile: pairProfile, overrides: [navigationOverride]).canApply,
              "Mismatched position metadata fails before silently assigning the wrong side")
        print("PASS: \(checks) initial-review equality, source metadata, exclusion/restoration, shared heading, global validation and cancellation checks")
    }
}
