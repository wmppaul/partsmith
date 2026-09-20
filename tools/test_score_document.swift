import AppKit
import Foundation
import PDFKit

@main
enum ScoreDocumentTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }
    static func waitFor(_ complete: () -> Bool) {
        let deadline = Date().addingTimeInterval(30)
        while !complete() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(complete(), "Background operation completed within the fixture timeout")
    }
    static func main() throws {
        let source = try Data(contentsOf: URL(fileURLWithPath: "Partsmith/Resources/Fixtures/SampleScoreFixture.pdf"))
        let profile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "upper", name: "Upper instrument", staffCount: 1, topPaddingStaffSpaces: 8),
            ScorePartDefinition(id: "lower", name: "Lower instrument", staffCount: 1)
        ], topPaddingStaffSpaces: 7, bottomPaddingStaffSpaces: 7, leftTrimPoints: 10, rightTrimPoints: 12)
        let document = PartsmithDocument(sourcePDFData: source)
        var callback = false
        var detected: ScoreDetectionReview?
        document.detectScore(profile: profile) { callback = true; detected = $0 }
        check(document.scoreDetectionProgress?.totalPages == 2, "Whole-score progress inventories every source page")
        waitFor { callback }
        guard let review = detected else { fatalError("Whole-score fixture detection returned no review") }
        check(review.analyses.map(\.pageIndex) == [0, 1], "Background Auto analyzes both source pages in order")
        check(review.analyses.allSatisfy { $0.staves.count == 2 }, "Native Auto finds every fixture staff")
        check(review.plan.canApply && review.plan.bands.count == 4, "Reviewed two-instrument profile assigns both complete systems")
        check(document.project.bands.isEmpty && document.project.parts.isEmpty,
              "Detection alone never mutates parts or crops before review")
        check(document.scoreDetectionProgress == nil, "Completed Auto clears its progress state")
        check(document.isScoreDetectionCurrent(review), "Unchanged full-source review is current")

        var nonMusicReview = review
        nonMusicReview.analyses += [2, 3].map { page in
            ScorePageAnalysis(pageIndex: page, pageWidth: 600, pageHeight: 800,
                imageWidth: 1200, imageHeight: 1600, staves: [], warnings: [])
        }
        nonMusicReview.replan()
        check(nonMusicReview.excludedPageReasons.isEmpty && !nonMusicReview.plan.canApply
              && nonMusicReview.plan.pages.filter { !$0.unresolvedReasons.isEmpty }.map(\.pageIndex) == [2, 3],
              "Zero-staff pages remain included and unresolved until explicitly reviewed")
        check(nonMusicReview.nextPageNeedingReview(after: 2) == 3 && nonMusicReview.nextPageNeedingReview(after: 3) == 2,
              "Flagged-page navigation advances in source order and wraps")
        let beforeExclusion = nonMusicReview.plan
        do {
            try nonMusicReview.excludePageAsNonMusic(2, reason: "   ")
            fatalError("Nonmusic page excluded without a reviewed reason")
        } catch {
            check(nonMusicReview.plan == beforeExclusion && nonMusicReview.excludedPageReasons.isEmpty,
                  "Missing exclusion reason rejects the action without mutating the review")
        }
        let nextCatalog = try nonMusicReview.excludePageAsNonMusic(2, reason: "  Blank page reviewed  ")
        check(nextCatalog == 3 && nonMusicReview.excludedPageReasons == [2: "Blank page reviewed"],
              "Explicit blank-page exclusion records its reason and advances to the next flagged page")
        check(!nonMusicReview.plan.canApply && nonMusicReview.plan.pages.contains { $0.pageIndex == 3 && !$0.unresolvedReasons.isEmpty },
              "Excluding one empty page never silently excludes the next")
        let nextMusic = try nonMusicReview.excludePageAsNonMusic(3, reason: "Publisher catalogue reviewed")
        check(nextMusic == 0 && nonMusicReview.plan.canApply && nonMusicReview.excludedPageReasons.count == 2,
              "Resolving the last nonmusic page returns to music with the remaining assignments ready for review")
        check(nonMusicReview.plan.bands == review.plan.bands,
              "Nonmusic-page exclusions preserve every music assignment and crop exactly")
        do {
            try nonMusicReview.excludePageAsNonMusic(99, reason: "Not a source page")
            fatalError("Unavailable source page accepted for exclusion")
        } catch {
            check(nonMusicReview.excludedPageReasons.count == 2 && nonMusicReview.plan.bands == review.plan.bands,
                  "Invalid exclusion page leaves the review unchanged")
        }

        var cropReview = review
        let cropPage = review.analyses[0]
        let originalBands = review.plan.pages[0].assignments
        let firstBand = originalBands[0]
        let newTop = max(0, firstBand.topFraction * cropPage.pageHeight - 4)
        let newBottom = min(cropPage.pageHeight, firstBand.bottomFraction * cropPage.pageHeight + 6)
        try cropReview.setCropEdges(for: firstBand.id, top: newTop, bottom: newBottom)
        let expanded = cropReview.plan.bands.first { $0.id == firstBand.id }!
        check(abs(expanded.topFraction * cropPage.pageHeight - newTop) < 0.000001
              && abs(expanded.bottomFraction * cropPage.pageHeight - newBottom) < 0.000001,
              "Auto review applies explicit source-point crop edges before adding")
        check(expanded.candidateIDs == firstBand.candidateIDs && expanded.leftFraction == firstBand.leftFraction
              && expanded.rightFraction == firstBand.rightFraction,
              "Crop edits preserve instrument assignments and horizontal bounds")
        let untouched = cropReview.plan.bands.first { $0.id == originalBands[1].id }!
        check(untouched.topFraction == originalBands[1].topFraction && untouched.bottomFraction == originalBands[1].bottomFraction,
              "Editing one crop does not expand neighboring instruments")
        check(cropReview.plan.pages[1] == review.plan.pages[1] && document.project.bands.isEmpty,
              "Review crop edits do not touch other pages or the live document")
        let previousPlan = cropReview.plan
        let previousOverrides = cropReview.overrides
        let firstLine = cropPage.staves.first { firstBand.candidateIDs.contains($0.id) }!.staffLineFractions[0] * cropPage.pageHeight
        for (top, bottom) in [(Double.nan, newBottom), (-1.0, newBottom), (newTop, cropPage.pageHeight + 1),
                              (firstLine + 1, newBottom), (newBottom, newTop)] {
            do {
                try cropReview.setCropEdges(for: firstBand.id, top: top, bottom: bottom)
                fatalError("Invalid crop edge was accepted")
            } catch {
                check(cropReview.plan == previousPlan && cropReview.overrides == previousOverrides,
                      "Invalid crop edit is rejected atomically without losing assignments")
            }
        }
        var tiltedReview = review
        tiltedReview.analyses[0].analysisSkewDegrees = -1
        tiltedReview.replan()
        let skewReach = tan(Double.pi / 180) * cropPage.pageWidth / 2
        let lastLine = cropPage.staves.first { firstBand.candidateIDs.contains($0.id) }!.staffLineFractions[4] * cropPage.pageHeight
        let tiltedPlan = tiltedReview.plan
        for (top, bottom) in [(firstLine - skewReach + 0.1, newBottom),
                              (newTop, lastLine + skewReach - 0.1)] {
            do {
                try tiltedReview.setCropEdges(for: firstBand.id, top: top, bottom: bottom)
                fatalError("Crop cutting the tilted end of a staff line was accepted")
            } catch {
                check(tiltedReview.plan == tiltedPlan && tiltedReview.overrides.isEmpty,
                      "Crop edit rejects clipped tilted staff ends without mutating the review")
            }
        }
        try tiltedReview.setCropEdges(for: firstBand.id, top: firstLine - skewReach - 1, bottom: lastLine + skewReach + 1)
        check(tiltedReview.plan.canApply, "Crop containing both tilted staff ends remains editable")
        cropReview.overrides[0].systems[0].movementLabel = "Andante"
        cropReview.overrides[0].systems[0].bands[0].label = "espressivo"
        cropReview.overrides[0].systems[0].bands[0].pageBreakBefore = true
        cropReview.overrides[0].systems[0].bands[0].sourceMarkings = [[12, 5, 50, 10]]
        cropReview.replan()
        check(cropReview.plan.canApply, "Metadata-bearing crop fixture remains a valid reviewed page")
        try cropReview.setCropEdges(for: firstBand.id, top: newTop, bottom: newBottom + 1)
        let marked = cropReview.plan.bands.first { $0.id == firstBand.id }!
        check(marked.editorialLabel == "Andante — espressivo" && marked.pageBreakBefore && marked.sourceMarkings.count == 1,
              "Crop editing retains movement, local direction, page break and shared source glyphs")
        try cropReview.resetCropEdges(for: firstBand.id)
        let reset = cropReview.plan.bands.first { $0.id == firstBand.id }!
        check(reset.topFraction == firstBand.topFraction && reset.bottomFraction == firstBand.bottomFraction
              && reset.editorialLabel == marked.editorialLabel && reset.sourceMarkings == marked.sourceMarkings,
              "Restoring automatic edges preserves reviewed musical metadata")
        try cropReview.setCropEdges(for: firstBand.id, top: newTop, bottom: newBottom)
        let croppedDocument = PartsmithDocument(sourcePDFData: source)
        let cropUndo = UndoManager()
        cropUndo.groupsByEvent = false
        croppedDocument.undoManager = cropUndo
        cropUndo.beginUndoGrouping()
        check(croppedDocument.addScoreParts(from: cropReview) == 4, "Locally corrected crops use the same all-part apply transaction")
        cropUndo.endUndoGrouping()
        check(croppedDocument.project.bands.contains { abs($0.topFraction * cropPage.pageHeight - newTop) < 0.000001
              && abs($0.bottomFraction * cropPage.pageHeight - newBottom) < 0.000001 && $0.editorialLabel == "Andante — espressivo" },
              "Applied native band retains the exact reviewed crop and heading")
        cropUndo.undo()
        check(croppedDocument.project.bands.isEmpty && croppedDocument.project.parts.isEmpty,
              "One undo removes all locally corrected Auto parts together")

        let undo = UndoManager()
        undo.groupsByEvent = false
        document.undoManager = undo
        let before = document.project
        undo.beginUndoGrouping()
        check(document.addScoreParts(from: review) == 4, "Reviewed Auto adds all instrument bands")
        undo.endUndoGrouping()
        let after = document.project
        check(after.parts.map(\.name) == profile.parts.map(\.name), "Native parts retain instrumentation order and reviewed names")
        check(after.bands.count == 4 && after.bands.allSatisfy { $0.exclusions.isEmpty && $0.editorialLabel.isEmpty && !$0.pageBreakBefore },
              "Automatic assignments have no cleanup masks, debug labels, or source-page breaks")
        check(document.savedScoreProfile == profile, "Applying Auto stores the exact reviewed profile including padding and trim")
        check(document.sourcePDFData == source, "Auto never changes embedded score bytes")
        check(document.addScoreParts(from: review) == nil && document.project == after,
              "Repeating Auto cannot duplicate populated parts")
        undo.undo()
        check(document.project == before, "One undo removes every new part and band and restores settings")
        undo.redo()
        check(document.project == after, "One redo restores the exact whole-score transaction")
        let persisted = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(after))
        check(PartsmithDocument(project: persisted, sourcePDFData: source).savedScoreProfile == profile,
              "Reopened project retains the exact instrumentation profile")
        for part in after.parts {
            let pdf = try PartPDFExporter.previewDocument(for: part.id, in: document)
            check(pdf.pageCount > 0, "Every native Auto part reaches the production PDF exporter")
        }

        let empty = PartsmithDocument(sourcePDFData: source)
        var invalid = review
        invalid.analyses.removeLast()
        check(empty.addScoreParts(from: invalid) == nil, "Partial-source review is rejected")
        invalid = review
        invalid.sourcePDFData.append(0)
        check(empty.addScoreParts(from: invalid) == nil, "Changed source bytes invalidate a review")
        invalid = review
        invalid.rectifications = [.default(pageIndex: 0)]
        check(empty.addScoreParts(from: invalid) == nil, "Changed rectification invalidates a review")
        invalid = review
        invalid.plan.pages[0].unresolvedReasons = ["Unresolved staff grouping"]
        check(empty.addScoreParts(from: invalid) == nil, "Unresolved page assignments cannot be applied")
        invalid = review
        invalid.plan.pages.removeLast()
        check(empty.addScoreParts(from: invalid) == nil, "Missing plan pages require explicit exclusions")
        invalid = review
        invalid.excludedPageReasons[1] = "Catalog page reviewed; no score music"
        invalid.replan()
        check(empty.addScoreParts(from: invalid) == 2, "An explicit reviewed page exclusion retains the remaining parts")
        check(empty.project.bands.allSatisfy { $0.pageIndex == 0 }, "Excluded page adds no accidental music")
        let excludedAll = PartsmithDocument(sourcePDFData: source)
        invalid = review
        invalid.excludedPageReasons = [0: "No score music", 1: "No score music"]
        invalid.replan()
        check(excludedAll.addScoreParts(from: invalid) == nil, "Excluding every page cannot create empty parts")

        let reuse = PartsmithDocument(sourcePDFData: source)
        reuse.createPart(name: "Upper instrument", color: .systemBlue)
        let existingID = reuse.project.parts[0].id
        reuse.project.projectSettings.defaultScale = 0.9
        reuse.project.projectSettings.interSystemGap = 22
        check(reuse.addScoreParts(from: review) == 4 && reuse.project.parts.count == 2 && reuse.project.parts[0].id == existingID,
              "Auto reuses an existing empty named part without duplicating it")
        check(reuse.project.parts[1].layoutSettings.scale == 0.9 && reuse.project.parts[1].layoutSettings.interSystemGap == 22,
              "Auto-created parts inherit the project's layout defaults")

        let setup = PartsmithDocument(sourcePDFData: source)
        let setupUndo = UndoManager()
        setupUndo.groupsByEvent = false
        setup.undoManager = setupUndo
        setupUndo.beginUndoGrouping()
        setup.saveScoreProfile(profile)
        setupUndo.endUndoGrouping()
        check(setup.savedScoreProfile == profile, "Saving setup does not require adding generated parts")
        setupUndo.undo()
        check(setup.savedScoreProfile == nil, "Saved setup is undoable")
        setupUndo.redo()
        check(setup.savedScoreProfile == profile, "Saved setup redo is exact")

        var compactProfile = profile
        compactProfile.cropMode = "compact"
        compactProfile.parts[0].hasLyrics = true
        setupUndo.beginUndoGrouping()
        setup.saveScoreProfile(compactProfile)
        setupUndo.endUndoGrouping()
        check(setup.savedScoreProfile == compactProfile, "Compact mode and explicit lyric hints survive model conversion")
        let compactProject = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(setup.project))
        check(PartsmithDocument(project: compactProject).savedScoreProfile == compactProfile,
              "Compact mode and lyric settings survive saving and reopening")
        check(profile.cropMode == nil && document.savedScoreProfile?.cropMode == nil,
              "Legacy profiles retain fixed crop behavior instead of silently changing")

        callback = false
        setup.detectScore(profile: profile) { _ in callback = true }
        setup.cancelScoreDetection()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        check(!callback && setup.scoreDetectionProgress == nil, "Canceled Auto clears progress and suppresses completion")
        callback = false
        var stale: ScoreDetectionReview?
        setup.detectScore(profile: profile) { callback = true; stale = $0 }
        setup.project.pageRectifications = [.default(pageIndex: 0)]
        waitFor { callback }
        check(stale == nil && setup.scoreDetectionProgress == nil, "In-flight rectification changes reject stale whole-score results")
        print("PASS: \(checks) whole-score document assertions (background Auto, review gate, all-part apply, undo, persistence, production export, cancellation, stale guards)")
    }
}
