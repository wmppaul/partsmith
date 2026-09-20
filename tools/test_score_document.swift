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
