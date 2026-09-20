import AppKit
import Combine
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
    static func paddedScore(_ source: Data) -> Data {
        let blankData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: blankData)!, mediaBox: &mediaBox, nil)!
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()
        let padded = PDFDocument()
        padded.insert(PDFDocument(data: blankData as Data)!.page(at: 0)!, at: 0)
        let score = PDFDocument(data: source)!
        for pageIndex in 0..<score.pageCount {
            padded.insert(score.page(at: pageIndex)!, at: padded.pageCount)
        }
        padded.insert(PDFDocument(data: blankData as Data)!.page(at: 0)!, at: padded.pageCount)
        return padded.dataRepresentation()!
    }

    static func checkInputPageSelection() {
        check(ScoreInputPageSelection.parse("1, 3-5, 8", pageCount: 8) == [0, 2, 3, 4, 7],
              "Printed page ranges translate to noncontiguous original zero-based source indices")
        check(ScoreInputPageSelection.parse(" 2–4, 3, 6—7 ", pageCount: 8) == [1, 2, 3, 5, 6],
              "Page ranges accept typographic dashes, spaces and repeated selections")
        check(ScoreInputPageSelection.parse("  ", pageCount: 8) == [],
              "Clearing the page field produces an empty selection instead of silently selecting everything")
        for invalid in ["0", "9", "4-2", "1-9", "1,,2", "1-", "-2", "one", "1.5", "1-2-3"] {
            check(ScoreInputPageSelection.parse(invalid, pageCount: 8) == nil,
                  "Invalid page input is rejected: \(invalid)")
        }
        let selection: Set<Int> = [0, 2, 3, 4, 7]
        let formatted = ScoreInputPageSelection.formatted(selection)
        check(formatted == "1, 3–5, 8" || formatted == "1, 3-5, 8",
              "The selected pages are displayed as a compact, readable printed-page range")
        check(ScoreInputPageSelection.parse(formatted, pageCount: 8) == selection
              && ScoreInputPageSelection.formatted([]).isEmpty,
              "Page range formatting round trips without adding pages or filling an empty selection")
    }

    static func checkInputPageFlow(source: Data, profile: ScoreExtractionProfile) throws {
        let paddedSource = paddedScore(source)
        let document = PartsmithDocument(sourcePDFData: paddedSource)
        document.project.pageCount = 4
        var callback = false
        var detected: ScoreDetectionReview?
        document.detectScore(profile: profile) { callback = true; detected = $0 }
        waitFor { callback }
        guard let review = detected else { fatalError("Padded score must produce a review") }
        check(review.autoSkippedPageIndices == [0, 3] && Set(review.excludedPageReasons.keys) == [0, 3],
              "Successfully analyzed blank pages are automatically skipped without manual confirmation")
        check(review.plan.canApply && review.plan.bands.count == 4
              && review.plan.pages.map(\.pageIndex) == [1, 2],
              "Blank-page skipping leaves every music page ready to add at its original source index")
        var restored = review
        restored.restoreExcludedPage(0)
        check(!restored.plan.canApply && restored.autoSkippedPageIndices == [3]
              && restored.excludedPageReasons[0] == nil
              && restored.plan.pages.contains { $0.pageIndex == 0 && !$0.unresolvedReasons.isEmpty },
              "Restoring a skipped page includes it for staff correction without silently skipping it again")
        restored.replan()
        check(restored.excludedPageReasons[0] == nil && !restored.plan.canApply,
              "Later replanning respects a restored blank page")
        try restored.excludePageAsNonMusic(0, reason: "No music on this page")
        check(restored.plan.canApply && restored.autoSkippedPageIndices == [3],
              "An optional manual exclusion after restoring a page allows accepting the music again")
        let undo = UndoManager()
        undo.groupsByEvent = false
        document.undoManager = undo
        let before = document.project
        undo.beginUndoGrouping()
        check(document.addScoreParts(from: review) == 4,
              "Add Parts accepts a real score containing untouched auto-skipped blank pages")
        undo.endUndoGrouping()
        let after = document.project
        check(Set(after.bands.map(\.pageIndex)) == [1, 2] && document.sourcePDFData == paddedSource,
              "Applying a padded score retains original source pages and source bytes")
        undo.undo()
        check(document.project == before, "Accepting automatic blank skips is one undoable all-part edit")
        undo.redo()
        check(document.project == after, "Redo restores every music crop exactly after automatic blank skips")

        let subset = PartsmithDocument(sourcePDFData: paddedSource)
        subset.project.pageCount = 4
        callback = false
        detected = nil
        var selectedProgress: [(completed: Int, total: Int)] = []
        let progressObserver = subset.$scoreDetectionProgress.sink {
            if let progress = $0 { selectedProgress.append((progress.completedPages, progress.totalPages)) }
        }
        defer { progressObserver.cancel() }
        subset.detectScore(profile: profile, pageIndices: [2]) { callback = true; detected = $0 }
        check(subset.scoreDetectionProgress?.totalPages == 1,
              "Input-page detection progress counts only selected pages")
        waitFor { callback }
        guard let selected = detected else { fatalError("Selected source page must produce a review") }
        check(selectedProgress.map(\.completed) == [0, 1] && selectedProgress.allSatisfy { $0.total == 1 },
              "Progress advances by processed selections, not the selected original page number")
        check(selected.selectedPageIndices == [2] && selected.analyses.map(\.pageIndex) == [2]
              && selected.autoSkippedPageIndices.isEmpty && selected.excludedPageReasons.isEmpty,
              "Selecting a later page analyzes only that original page and never inventories unselected blanks")
        check(subset.isScoreDetectionCurrent(selected) && selected.plan.canApply
              && selected.plan.bands.count == 2 && selected.plan.bands.allSatisfy { $0.pageIndex == 2 },
              "A selected-page review is complete while keeping its original source coordinates")
        var changedScope = selected
        changedScope.selectedPageIndices = [1, 2]
        check(!subset.isScoreDetectionCurrent(changedScope) && subset.addScoreParts(from: changedScope) == nil,
              "Expanding the reviewed input range without analyzing its missing pages is rejected")
        changedScope = selected
        changedScope.selectedPageIndices = []
        check(!subset.isScoreDetectionCurrent(changedScope), "An empty review scope cannot be accepted")
        changedScope = selected
        changedScope.analyses.append(selected.analyses[0])
        check(!subset.isScoreDetectionCurrent(changedScope), "Duplicated analyses cannot masquerade as a complete page selection")
        let selectedUndo = UndoManager()
        selectedUndo.groupsByEvent = false
        subset.undoManager = selectedUndo
        let beforeSubset = subset.project
        selectedUndo.beginUndoGrouping()
        check(subset.addScoreParts(from: selected) == 2,
              "Add Parts accepts a later original page even when its index exceeds selected-page count")
        selectedUndo.endUndoGrouping()
        let selectedProject = subset.project
        check(selectedProject.bands.allSatisfy { $0.pageIndex == 2 },
              "Selected input pages are never renumbered to the start of the source PDF")
        for part in selectedProject.parts {
            let layout = try PartLayoutEngine.makePlan(project: selectedProject,
                pageBoundsProvider: { subset.pdfDocument?.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
            check(layout.pages.flatMap(\.placements).allSatisfy { $0.sourcePageIndex == 2 },
                  "Production layout reads selected crops from their original source page")
            let pdf = try PartPDFExporter.previewDocument(for: part.id, in: subset)
            check(pdf.pageCount > 0, "Every selected-page part reaches the production exporter")
        }
        selectedUndo.undo()
        check(subset.project == beforeSubset, "Selected-page extraction undoes in one step")
        selectedUndo.redo()
        check(subset.project == selectedProject, "Selected-page extraction redoes with exact source coordinates")

        for badSelection: Set<Int> in [[], [-1], [4], [0, 4]] {
            let invalid = PartsmithDocument(sourcePDFData: paddedSource)
            var invalidCallback = false
            var invalidReview: ScoreDetectionReview?
            invalid.detectScore(profile: profile, pageIndices: badSelection) {
                invalidCallback = true; invalidReview = $0
            }
            check(invalidCallback && invalidReview == nil && invalid.scoreDetectionProgress == nil,
                  "Empty or unavailable input-page selections fail promptly instead of expanding to the full score")
        }
        let blanks = PartsmithDocument(sourcePDFData: paddedSource)
        callback = false
        detected = nil
        blanks.detectScore(profile: profile, pageIndices: [0, 3]) { callback = true; detected = $0 }
        waitFor { callback }
        guard let blankReview = detected else { fatalError("All-blank selection must remain inspectable") }
        check(blankReview.autoSkippedPageIndices == [0, 3] && blankReview.plan.bands.isEmpty
              && blanks.addScoreParts(from: blankReview) == nil && blanks.project.parts.isEmpty,
              "Selecting only blank pages yields no accidental empty parts")

        var failedRender = review
        failedRender.restoreExcludedPage(0)
        failedRender.analyses[0].imageWidth = 0
        failedRender.analyses[0].imageHeight = 0
        failedRender.analyses[0].warnings = ["Page could not be rendered; review or restore the source."]
        failedRender.automaticallyExcludePagesWithoutStaves()
        check(failedRender.excludedPageReasons[0] == nil && !failedRender.autoSkippedPageIndices.contains(0)
              && !failedRender.plan.canApply,
              "An unavailable page raster remains unresolved and cannot silently become an automatic blank skip")
        failedRender.autoSkippedPageIndices.insert(0)
        failedRender.excludedPageReasons[0] = "No staves found"
        failedRender.replan()
        let failureDocument = PartsmithDocument(sourcePDFData: paddedSource)
        check(failureDocument.addScoreParts(from: failedRender) == nil && failureDocument.project.parts.isEmpty,
              "A malformed review cannot label a failed render as a successful automatic blank skip")
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
        let paddedSource = paddedScore(source)
        let selectedDocument = PartsmithDocument(sourcePDFData: paddedSource)
        selectedDocument.project.pageCount = PDFDocument(data: paddedSource)!.pageCount
        var selectedReview: ScoreDetectionReview?
        completed = false
        selectedDocument.detectScore(profile: profile, findSourceHeader: true, pageIndices: [0, 1]) {
            completed = true; selectedReview = $0
        }
        waitFor { completed }
        guard let scopedReview = selectedReview, let scopedHeader = scopedReview.suggestedSourceHeader else {
            fatalError("Selected-page Auto must find a header after an included blank page")
        }
        check(scopedReview.analyses.map(\.pageIndex) == [0, 1]
              && scopedReview.autoSkippedPageIndices == [0] && scopedHeader.pageIndex == 1,
              "Printed-header detection searches the first included music page after selected blank pages")
        check(scopedReview.plan.canApply && scopedReview.plan.bands.allSatisfy { $0.pageIndex == 1 }
              && selectedDocument.addScoreParts(from: scopedReview, sourceHeader: scopedHeader) == scopedReview.plan.bands.count,
              "A detected header and its selected music page add successfully at original source indices")
        let selectedPart = selectedDocument.project.parts[0]
        let scopedPlan = try PartLayoutEngine.makePlan(project: selectedDocument.project,
            pageBoundsProvider: { selectedDocument.pdfDocument?.page(at: $0)?.bounds(for: .mediaBox) },
            partID: selectedPart.id)
        check(scopedPlan.headerPlacement?.sourcePageIndex == 1
              && scopedPlan.pages.flatMap(\.placements).allSatisfy { $0.sourcePageIndex == 1 },
              "A scoped extraction exports both header and notes from the original included page")
        let scopedPDF = try PartPDFExporter.previewDocument(for: selectedPart.id, in: selectedDocument)
        check(scopedPDF.pageCount > 0,
              "The printed header in a page-limited score reaches production export")
        let continuation = PartsmithDocument(sourcePDFData: paddedSource)
        completed = false
        selectedReview = nil
        continuation.detectScore(profile: profile, findSourceHeader: true, pageIndices: [2]) {
            completed = true; selectedReview = $0
        }
        waitFor { completed }
        check(selectedReview?.analyses.map(\.pageIndex) == [2] && selectedReview?.suggestedSourceHeader == nil,
              "Selecting only a continuation page does not borrow a printed header from an unselected opening page")
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

        checkInputPageSelection()
        try checkInputPageFlow(source: source, profile: profile)

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
