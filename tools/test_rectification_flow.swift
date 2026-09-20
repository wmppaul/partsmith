import AppKit
import Foundation
import PDFKit

@main
enum RectificationFlowTests {
    static var checks = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }

    static func waitFor(_ complete: () -> Bool) {
        let deadline = Date().addingTimeInterval(30)
        while !complete() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        check(complete(), "Deskew completes within the fixture timeout")
    }

    static func tiltedScore() -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 600, height: 800)
        let consumer = CGDataConsumer(data: data)!
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        for _ in 0..<2 {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)
            context.translateBy(x: 300, y: 400)
            context.rotate(by: 1.5 * .pi / 180)
            context.translateBy(x: -300, y: -400)
            context.setStrokeColor(gray: 0, alpha: 1)
            context.setLineWidth(1)
            for system in 0..<4 {
                for line in 0..<5 {
                    let y = CGFloat(140 + system * 145 + line * 8)
                    context.move(to: CGPoint(x: 40, y: y))
                    context.addLine(to: CGPoint(x: 560, y: y))
                }
            }
            context.strokePath()
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    static func main() {
        let source = tiltedScore()
        var fixtureProject = ProjectData.empty
        fixtureProject.pageCount = 2
        let empty = PartsmithDocument()
        var unavailable: RectificationAutoResult?
        let emptyRun = empty.autoEstimateAllPageRectifications { unavailable = $0 }
        check(emptyRun == nil && unavailable == .unavailable && !empty.isAutoEstimatingPageRectifications,
              "Missing source reports unavailable without starting progress")

        let all = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
        let undo = UndoManager()
        undo.groupsByEvent = false
        all.undoManager = undo
        undo.beginUndoGrouping()
        var completed: RectificationAutoResult?
        var completionOnMain = false
        let allRun = all.autoEstimateAllPageRectifications {
            completed = $0
            completionOnMain = Thread.isMainThread && !all.isAutoEstimatingPageRectifications
        }
        check(allRun != nil && all.rectificationAutoProgress?.totalPageCount == 2,
              "Deskew starts with whole-source progress and an ownership token")
        waitFor { completed != nil }
        undo.endUndoGrouping()
        check(completed == .completed(appliedPageCount: 2) && all.project.pageRectifications.count == 2,
              "Both tilted pages receive automatic corrections; got \(String(describing: completed)), \(all.project.pageRectifications.count) corrections")
        check(completionOnMain, "Completion runs on main after progress has cleared")
        check(!all.cancelAutoEstimateAllPageRectifications(runID: allRun),
              "Completed ownership token no longer cancels a run")
        undo.undo()
        check(all.project.pageRectifications.isEmpty, "Whole-score corrections undo in one step")

        let selected = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
        var selectedResult: RectificationAutoResult?
        let selectedRun = selected.autoEstimateAllPageRectifications(pageIndices: [1]) { selectedResult = $0 }
        check(selectedRun != nil && selected.rectificationAutoProgress?.totalPageCount == 1,
              "Page-limited deskew counts only its selected source pages")
        waitFor { selectedResult != nil }
        check(selectedResult == .completed(appliedPageCount: 1)
              && selected.project.pageRectifications.map(\.pageIndex) == [1],
              "Deskew corrects the selected later page without modifying or renumbering earlier pages")
        for badSelection: Set<Int> in [[], [-1], [2], [0, 2]] {
            let invalid = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
            var invalidResult: RectificationAutoResult?
            let run = invalid.autoEstimateAllPageRectifications(pageIndices: badSelection) { invalidResult = $0 }
            check(run == nil && invalidResult == .unavailable && !invalid.isAutoEstimatingPageRectifications
                  && invalid.project.pageRectifications.isEmpty,
                  "Empty or unavailable deskew page selections never expand to the full score")
        }

        let manual = PageRectification.default(pageIndex: 0)
        var existingProject = fixtureProject
        existingProject.pageRectifications = [manual]
        let preserving = PartsmithDocument(project: existingProject, sourcePDFData: source)
        var preservedResult: RectificationAutoResult?
        preserving.autoEstimateAllPageRectifications(onlyUnrectified: true) { preservedResult = $0 }
        waitFor { preservedResult != nil }
        check(preservedResult == .completed(appliedPageCount: 1),
              "Wand deskew estimates only pages without an existing correction")
        check(preserving.project.pageRectifications.first { $0.pageIndex == 0 } == manual,
              "Wand deskew preserves the user's existing page correction exactly")
        check(preserving.project.pageRectifications.map(\.pageIndex).sorted() == [0, 1],
              "Preserving existing corrections still processes the remaining source pages")
        var nothingNeeded: RectificationAutoResult?
        preserving.autoEstimateAllPageRectifications(onlyUnrectified: true) { nothingNeeded = $0 }
        waitFor { nothingNeeded != nil }
        check(nothingNeeded == .completed(appliedPageCount: 0),
              "Already-corrected source completes successfully without replacing corrections")

        let selectedPreserving = PartsmithDocument(project: existingProject, sourcePDFData: source)
        var selectedPreservedResult: RectificationAutoResult?
        selectedPreserving.autoEstimateAllPageRectifications(onlyUnrectified: true, pageIndices: [0]) {
            selectedPreservedResult = $0
        }
        waitFor { selectedPreservedResult != nil }
        check(selectedPreservedResult == .completed(appliedPageCount: 0)
              && selectedPreserving.project.pageRectifications == [manual],
              "A selected already-corrected page stays exact and unselected pages are not deskewed")

        let cancelling = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
        var cancellationResults: [RectificationAutoResult] = []
        let cancelledRun = cancelling.autoEstimateAllPageRectifications { cancellationResults.append($0) }!
        check(!cancelling.cancelAutoEstimateAllPageRectifications(runID: UUID())
              && cancelling.isAutoEstimatingPageRectifications && cancellationResults.isEmpty,
              "A different workflow's token cannot cancel active deskew")
        check(cancelling.cancelAutoEstimateAllPageRectifications(runID: cancelledRun),
              "The owning workflow can cancel deskew")
        check(cancellationResults == [.cancelled] && !cancelling.isAutoEstimatingPageRectifications,
              "Cancellation reports once and immediately clears progress")
        var nextResult: RectificationAutoResult?
        cancelling.autoEstimateAllPageRectifications { nextResult = $0 }
        waitFor { nextResult != nil }
        check(cancellationResults == [.cancelled] && nextResult == .completed(appliedPageCount: 2),
              "Cancelled worker cannot publish late output or disrupt the next run")

        let changedGeometry = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
        var geometryResult: RectificationAutoResult?
        changedGeometry.autoEstimateAllPageRectifications(onlyUnrectified: true) { geometryResult = $0 }
        changedGeometry.updatePageRectification(manual)
        waitFor { geometryResult != nil }
        check(geometryResult == .sourceChanged && changedGeometry.project.pageRectifications == [manual],
              "A correction changed during estimation is preserved and makes the old result stale")

        let changedSource = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
        var sourceResult: RectificationAutoResult?
        changedSource.autoEstimateAllPageRectifications { sourceResult = $0 }
        changedSource.sourcePDFData = source + Data([0x20])
        waitFor { sourceResult != nil }
        check(sourceResult == .sourceChanged && changedSource.project.pageRectifications.isEmpty,
              "Changing the source rejects all estimates from the previous PDF")

        let newCrop = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
        newCrop.createPart(name: "Violin", color: .systemBlue)
        var cropResult: RectificationAutoResult?
        newCrop.autoEstimateAllPageRectifications(onlyUnrectified: true) { cropResult = $0 }
        newCrop.createBand(on: 0, centerFraction: 0.3, partID: newCrop.project.parts[0].id)
        let addedBands = newCrop.project.bands
        waitFor { cropResult != nil }
        check(cropResult == .sourceChanged && newCrop.project.pageRectifications.isEmpty
              && newCrop.project.bands == addedBands,
              "Creating a crop during deskew prevents a late geometry change and preserves the crop")

        let newHeader = PartsmithDocument(project: fixtureProject, sourcePDFData: source)
        var headerResult: RectificationAutoResult?
        newHeader.autoEstimateAllPageRectifications(onlyUnrectified: true) { headerResult = $0 }
        newHeader.updateHeaderSelection(pageIndex: 0, topFraction: 0.04, bottomFraction: 0.10,
                                        leftFraction: 0.1, rightFraction: 0.1)
        let addedHeader = newHeader.project.projectSettings.headerSelection
        waitFor { headerResult != nil }
        check(headerResult == .sourceChanged && newHeader.project.pageRectifications.isEmpty
              && newHeader.project.projectSettings.headerSelection == addedHeader,
              "Selecting a source header during deskew preserves the selection and prevents a late geometry change")

        let preservedHeader = PartsmithDocument(project: existingProject, sourcePDFData: source)
        preservedHeader.updateHeaderSelection(pageIndex: 0, topFraction: 0.04, bottomFraction: 0.10,
                                              leftFraction: 0.1, rightFraction: 0.1)
        let unaffectedHeader = preservedHeader.project.projectSettings.headerSelection
        var otherPageResult: RectificationAutoResult?
        preservedHeader.autoEstimateAllPageRectifications(onlyUnrectified: true) { otherPageResult = $0 }
        waitFor { otherPageResult != nil }
        check(otherPageResult == .completed(appliedPageCount: 1)
              && preservedHeader.project.projectSettings.headerSelection == unaffectedHeader
              && preservedHeader.project.pageRectifications.first { $0.pageIndex == 0 } == manual,
              "A header on an already-corrected page remains intact while other pages are deskewed")

        print("PASS: \(checks) deskew workflow checks")
    }
}
