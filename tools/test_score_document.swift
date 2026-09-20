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
    static func checkRealSourceHeaderFlow() throws {
        let source = try Data(contentsOf: URL(fileURLWithPath:
            "sample_scores/normal/04_choir/mozart_ave_verum_corpus_kv618_cpdl18715_complete_score.pdf"))
        let profile = try JSONDecoder().decode(ScoreExtractionProfile.self,
            from: Data(contentsOf: URL(fileURLWithPath: "Tests/full_scores/ave-compact-profile.json")))
        let document = PartsmithDocument(sourcePDFData: source)
        document.project.pageCount = PDFDocument(data: source)!.pageCount
        let before = document.project
        var completed = false
        var detected: ScoreDetectionReview?
        document.detectScore(profile: profile, findSourceHeader: true) { completed = true; detected = $0 }
        waitFor { completed }
        guard let review = detected, let header = review.suggestedSourceHeader else {
            fatalError("Opt-in Auto must return the Ave Verum printed source header")
        }
        check(document.project == before && document.sourcePDFData == source,
              "Real printed-header detection proposes its crop without changing the source or project")
        check(header.pageIndex == 0 && header.bottomFraction < review.analyses[0].staves[0].staffLineFractions[0],
              "Real opt-in Auto locates the opening printed header entirely above the first staff")
        check(review.plan.canApply && review.plan.bands.count == 64,
              "Printed-header detection preserves all 64 Ave Verum instrument assignments")
        check(document.addScoreParts(from: review, sourceHeader: header) == 64
              && document.project.parts.count == 8
              && document.project.projectSettings.headerSelection == header.normalized(),
              "The real detected header passes the native all-part transaction with every instrument")
        let persisted = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(document.project))
        let reopened = PartsmithDocument(project: persisted, sourcePDFData: source)
        check(reopened.project.projectSettings.headerSelection == header.normalized()
              && reopened.project.projectSettings.headerDisplayMode == .sourceSelection
              && reopened.project.projectSettings.showTitleBlock,
              "The real automatic header remains selected after saving and reopening the project")
        let plan = try PartLayoutEngine.makePlan(project: reopened.project,
            pageBoundsProvider: { reopened.pdfDocument?.page(at: $0)?.bounds(for: .mediaBox) },
            partID: reopened.project.parts[0].id)
        let sourceBounds = reopened.pdfDocument!.page(at: header.pageIndex)!.bounds(for: .mediaBox)
        let expectedHeaderRect = header.cropRect(in: sourceBounds)
        let actualHeaderRect = plan.headerPlacement?.sourceRect ?? .zero
        check(plan.headerPlacement?.sourcePageIndex == header.pageIndex
              && abs(actualHeaderRect.minX - expectedHeaderRect.minX) < 0.000001
              && abs(actualHeaderRect.minY - expectedHeaderRect.minY) < 0.000001
              && abs(actualHeaderRect.width - expectedHeaderRect.width) < 0.000001
              && abs(actualHeaderRect.height - expectedHeaderRect.height) < 0.000001,
              "The production layout uses the detected printed crop from the saved source page")
        let pdf = try PartPDFExporter.previewDocument(for: reopened.project.parts[0].id, in: reopened)
        check(pdf.pageCount > 0, "The reopened automatic printed header reaches the production part exporter")
        print("Ave Verum opt-in header: page \(header.pageIndex + 1), top \(header.topFraction), bottom \(header.bottomFraction)")
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
        check(review.suggestedSourceHeader == nil, "Existing Auto callers do not opt into printed-header detection implicitly")

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

        let sourceHeader = SourceHeaderSelection(pageIndex: 0, topFraction: 0.025, bottomFraction: 0.12,
            leftFraction: 0.08, rightFraction: 0.06)
        let withHeader = PartsmithDocument(sourcePDFData: source)
        withHeader.project.pageCount = PDFDocument(data: source)!.pageCount
        withHeader.project.projectSettings.headerDisplayMode = .typed
        withHeader.project.projectSettings.showTitleBlock = false
        withHeader.project.projectSettings.defaultTitleText = "Existing typed title"
        let headerUndo = UndoManager()
        headerUndo.groupsByEvent = false
        withHeader.undoManager = headerUndo
        let beforeHeader = withHeader.project
        headerUndo.beginUndoGrouping()
        check(withHeader.addScoreParts(from: review, sourceHeader: sourceHeader) == 4,
              "Auto can add the selected printed header with all instrument bands")
        headerUndo.endUndoGrouping()
        let afterHeader = withHeader.project
        check(afterHeader.projectSettings.headerSelection == sourceHeader
              && afterHeader.projectSettings.headerDisplayMode == .sourceSelection
              && afterHeader.projectSettings.showTitleBlock,
              "Accepting a printed header enables its exact source crop on every part")
        check(afterHeader.projectSettings.defaultTitleText == "Existing typed title",
              "Choosing a printed header retains the existing editable title text")
        headerUndo.undo()
        check(withHeader.project == beforeHeader,
              "One undo removes the automatic header and every part together, restoring header settings")
        headerUndo.redo()
        check(withHeader.project == afterHeader,
              "One redo restores the exact source header and all instrument parts")
        let persistedHeader = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(afterHeader))
        check(persistedHeader.projectSettings.headerSelection == sourceHeader
              && persistedHeader.projectSettings.headerDisplayMode == .sourceSelection,
              "Saving and reopening retains the accepted printed header crop")
        for part in afterHeader.parts {
            let pdf = try PartPDFExporter.previewDocument(for: part.id, in: withHeader)
            check(pdf.pageCount > 0, "A part with the accepted printed header reaches the production exporter")
        }

        let typedHeader = PartsmithDocument(sourcePDFData: source)
        typedHeader.project.pageCount = withHeader.project.pageCount
        typedHeader.project.projectSettings.headerDisplayMode = .typed
        typedHeader.project.projectSettings.showTitleBlock = false
        typedHeader.project.projectSettings.defaultTitleText = "Keep my title"
        typedHeader.project.projectSettings.defaultComposerText = "Keep my composer"
        check(typedHeader.addScoreParts(from: review) == 4
              && typedHeader.project.projectSettings.headerDisplayMode == .typed
              && !typedHeader.project.projectSettings.showTitleBlock
              && typedHeader.project.projectSettings.headerSelection == nil
              && typedHeader.project.projectSettings.defaultTitleText == "Keep my title"
              && typedHeader.project.projectSettings.defaultComposerText == "Keep my composer",
              "Adding parts without a source header preserves typed title, composer and visibility")

        let manualHeader = PartsmithDocument(sourcePDFData: source)
        manualHeader.project.pageCount = withHeader.project.pageCount
        let priorHeader = SourceHeaderSelection(pageIndex: 1, topFraction: 0.04, bottomFraction: 0.15,
            leftFraction: 0.12, rightFraction: 0.09)
        manualHeader.project.projectSettings.headerSelection = priorHeader
        let beforeManualHeader = manualHeader.project
        check(manualHeader.addScoreParts(from: review, sourceHeader: sourceHeader) == nil
              && manualHeader.project == beforeManualHeader,
              "A competing automatic header cannot overwrite an existing manual header or partially add parts")
        check(manualHeader.addScoreParts(from: review) == 4
              && manualHeader.project.projectSettings.headerSelection == priorHeader,
              "Auto still adds all parts while preserving an existing manually selected header")

        var malformedHeaders: [SourceHeaderSelection] = []
        for keyPath in [\SourceHeaderSelection.topFraction, \.bottomFraction, \.leftFraction, \.rightFraction] {
            for badValue in [Double.nan, Double.infinity, -0.01, 1.01] {
                var malformed = sourceHeader
                malformed[keyPath: keyPath] = badValue
                malformedHeaders.append(malformed)
            }
        }
        var reversedHeader = sourceHeader
        reversedHeader.topFraction = sourceHeader.bottomFraction
        reversedHeader.bottomFraction = sourceHeader.topFraction
        malformedHeaders.append(reversedHeader)
        var zeroHeightHeader = sourceHeader
        zeroHeightHeader.bottomFraction = sourceHeader.topFraction
        malformedHeaders.append(zeroHeightHeader)
        var zeroWidthHeader = sourceHeader
        zeroWidthHeader.leftFraction = 0.5
        zeroWidthHeader.rightFraction = 0.5
        malformedHeaders.append(zeroWidthHeader)
        for badPage in [-1, 2] {
            var malformed = sourceHeader
            malformed.pageIndex = badPage
            malformedHeaders.append(malformed)
        }
        let invalidHeaderDocument = PartsmithDocument(sourcePDFData: source)
        invalidHeaderDocument.project.pageCount = withHeader.project.pageCount
        let beforeInvalidHeader = invalidHeaderDocument.project
        for malformed in malformedHeaders {
            check(invalidHeaderDocument.addScoreParts(from: review, sourceHeader: malformed) == nil
                  && invalidHeaderDocument.project == beforeInvalidHeader
                  && invalidHeaderDocument.sourcePDFData == source,
                  "Invalid automatic header geometry or source page rejects the entire addition without mutation")
        }
        var excludedHeaderReview = review
        excludedHeaderReview.excludedPageReasons[0] = "Blank page"
        excludedHeaderReview.replan()
        check(invalidHeaderDocument.addScoreParts(from: excludedHeaderReview, sourceHeader: sourceHeader) == nil
              && invalidHeaderDocument.project == beforeInvalidHeader,
              "A header on an excluded page cannot be applied with the remaining parts")

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
        // Apple Vision requires its local system service, so this integration
        // check is opt-in when running the compiled test binary outside a restricted sandbox.
        if CommandLine.arguments.contains("--source-header") { try checkRealSourceHeaderFlow() }
        print("PASS: \(checks) whole-score document assertions (background Auto, review gate, all-part apply, undo, persistence, production export, cancellation, stale guards)")
    }
}
