import AppKit
import CoreGraphics
import Foundation
import PDFKit

/// Exercises the actual asynchronous OCR/document path and the same editable
/// pick list used by Auto Extract. No live application windows or user files.
@main
enum ManualInstrumentNameTests {
    static var checks: [String] = []
    static let output = URL(fileURLWithPath: ".build/manual-instrument-names-2026-10-05")
    static let firstBox = CGRect(x: 0.05, y: 0.20, width: 0.11, height: 0.035)
    static let secondBox = CGRect(x: 0.05, y: 0.40, width: 0.11, height: 0.035)

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
        checks.append(message)
        print("PASS: \(message)")
    }

    static func pump(_ seconds: Double = 0.1) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func waitForRecognition(_ document: PartsmithDocument) {
        let deadline = Date().addingTimeInterval(30)
        while document.isRecognizingInstrumentName && Date() < deadline { pump(0.01) }
        check(!document.isRecognizingInstrumentName, "Asynchronous recognition completes within the fixture timeout")
    }

    static func blankPDF(pages: Int = 2) -> Data {
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data)!
        var media = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: consumer, mediaBox: &media, nil)!
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(media)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    static func selectBlank(_ document: PartsmithDocument, box: CGRect = firstBox) -> ScoreInstrumentNameDraft {
        document.pickInstrumentName(in: box, pageIndex: document.currentPageIndex)
        waitForRecognition(document)
        guard let draft = document.instrumentNameDraft else { fatalError("Blank selection must offer manual naming") }
        check(draft.bounds == box && draft.pageIndex == document.currentPageIndex,
              "Manual naming retains the exact drawn box and source page")
        check(document.instrumentNamePick == nil, "A blank selection cannot publish an instrument before its name is confirmed")
        return draft
    }

    static func applyPick(_ document: PartsmithDocument, list: inout ScoreInstrumentPickList,
                          parts: inout [ScorePartDefinition]) -> ScoreInstrumentPickList.Outcome {
        guard let pick = document.instrumentNamePick,
              let outcome = list.apply(pick, to: &parts) else { fatalError("Confirmed manual name must use the ordinary pick-list path") }
        switch outcome {
        case let .added(_, name), let .updated(_, name), let .existing(_, name):
            document.updateInstrumentNameHighlight(id: pick.id, name: name)
        }
        return outcome
    }

    static func checkManualNamesAndList() throws {
        let source = blankPDF()
        try source.write(to: output.appendingPathComponent("blank-two-pages.pdf"))
        let document = PartsmithDocument(sourcePDFData: source)
        let originalProject = document.project
        document.pickInstrumentName(in: firstBox, pageIndex: 0)
        check(document.instrumentNameDraft == nil && !document.isRecognizingInstrumentName,
              "Selecting outside instrument picking mode cannot begin a manual name")
        document.isPickingInstrumentNames = true
        let draft = selectBlank(document)
        check(document.instrumentNameHighlights.isEmpty && document.project == originalProject,
              "An unnamed box creates no green success highlight or saved project edit")
        for name in ["", " ", "\n\t  "] {
            check(!document.confirmInstrumentNameDraft(name: name, staffCount: 1)
                  && document.instrumentNameDraft?.id == draft.id,
                  "An empty or whitespace-only name is rejected while keeping the box available to correct")
        }
        for count in [0, -1, 5, Int.max] {
            check(!document.confirmInstrumentNameDraft(name: "Violin", staffCount: count)
                  && document.instrumentNameDraft?.id == draft.id && document.instrumentNamePick == nil,
                  "Invalid staff counts cannot submit the pending manual name")
        }
        check(document.confirmInstrumentNameDraft(name: "Violin", staffCount: 1),
              "A typed instrument name confirms the blank score selection")
        check(document.instrumentNameDraft == nil && document.instrumentNamePick?.name == "Violin"
              && document.instrumentNamePick?.bounds == firstBox
              && document.instrumentNamePick?.suggestedStaffCount == 1,
              "Confirmation publishes the entered name, chosen staff count and selected geometry")
        check(document.instrumentNameHighlights.count == 1 && document.instrumentNameHighlights[0].bounds == firstBox,
              "A confirmed manual name receives the same on-score highlight as a printed label")
        var parts: [ScorePartDefinition] = []
        var list = ScoreInstrumentPickList()
        guard case let .added(firstID, "Violin") = applyPick(document, list: &list, parts: &parts) else {
            fatalError("First manual selection must create Violin")
        }
        _ = selectBlank(document, box: secondBox)
        check(document.confirmInstrumentNameDraft(name: "Violin", staffCount: 1),
              "A second unnamed staff can use the same entered instrument name")
        guard case let .added(secondID, "Violin 2") = applyPick(document, list: &list, parts: &parts) else {
            fatalError("Different manual boxes with the same name must remain separate instruments")
        }
        check(firstID != secondID && parts.map(\.name) == ["Violin", "Violin 2"]
              && document.instrumentNameHighlights.map(\.name) == ["Violin", "Violin 2"],
              "Duplicate typed names produce distinct, uniquely named parts and score highlights")

        _ = selectBlank(document, box: secondBox)
        check(document.confirmInstrumentNameDraft(name: "Violin", staffCount: 1),
              "A previously named empty box can be selected again")
        check(applyPick(document, list: &list, parts: &parts) == .existing(partID: secondID, name: "Violin 2")
              && parts.count == 2 && document.instrumentNameHighlights.count == 2,
              "Repeating the same empty-box selection reuses its row without adding another suffix or highlight")

        let expanded = firstBox.insetBy(dx: -0.01, dy: -0.005)
        _ = selectBlank(document, box: expanded)
        check(document.confirmInstrumentNameDraft(name: "Violin I", staffCount: 2),
              "A resized empty selection can be renamed and assigned two staves")
        check(applyPick(document, list: &list, parts: &parts) == .updated(partID: firstID, name: "Violin I")
              && parts.count == 2 && parts[0].staffCount == 2,
              "Resizing and renaming updates the original instrument row and the chosen staff count")
        check(document.instrumentNameHighlights.count == 2
              && document.instrumentNameHighlights.first(where: { $0.name == "Violin I" })?.bounds == expanded,
              "The resized manual highlight replaces the earlier box")

        let thirdBox = CGRect(x: 0.05, y: 0.60, width: 0.11, height: 0.06)
        _ = selectBlank(document, box: thirdBox)
        let customName = "Violoncello / Basso – II."
        check(document.confirmInstrumentNameDraft(name: customName, staffCount: 2)
              && document.instrumentNamePick?.name == customName,
              "Manual names retain the user's punctuation, capitalization and Unicode text")
        _ = applyPick(document, list: &list, parts: &parts)
        let fourthBox = CGRect(x: 0.05, y: 0.80, width: 0.11, height: 0.035)
        _ = selectBlank(document, box: fourthBox)
        check(document.confirmInstrumentNameDraft(name: "  Bass  \n Clarinet \t ", staffCount: 1)
              && document.instrumentNamePick?.name == "Bass Clarinet",
              "Accidental leading, trailing and repeated whitespace is normalized")
        _ = applyPick(document, list: &list, parts: &parts)

        let confirmedHighlights = document.instrumentNameHighlights
        _ = selectBlank(document, box: CGRect(x: 0.70, y: 0.70, width: 0.10, height: 0.04))
        document.cancelInstrumentNameDraft()
        check(document.instrumentNameDraft == nil && document.instrumentNamePick == nil
              && document.instrumentNameHighlights == confirmedHighlights && parts.count == 4,
              "Cancel discards only the unnamed box and preserves all already chosen instruments")
        check(!document.confirmInstrumentNameDraft(name: "Canceled", staffCount: 1),
              "A canceled draft cannot subsequently create a part")
        check(document.project == originalProject && document.sourcePDFData == source,
              "The entire manual naming and list-editing flow leaves saved project data and source PDF unchanged")

        document.pickInstrumentName(at: CGPoint(x: 0.8, y: 0.2), pageIndex: 0)
        waitForRecognition(document)
        guard let clickDraft = document.instrumentNameDraft else { fatalError("A blank click should also allow typing a name") }
        check(clickDraft.pageIndex == 0 && clickDraft.bounds.contains(CGPoint(x: 0.8, y: 0.2))
              && clickDraft.bounds.minX >= 0 && clickDraft.bounds.maxX <= 1
              && clickDraft.bounds.minY >= 0 && clickDraft.bounds.maxY <= 1,
              "A blank click offers a bounded manual selection surrounding the clicked location")
        document.cancelInstrumentNamePicking()
        check(document.instrumentNameDraft == nil && document.instrumentNameHighlights.isEmpty
              && !document.isPickingInstrumentNames,
              "Finishing name picking clears all transient manual geometry")
    }

    static func checkInvalidation() {
        let source = blankPDF()
        let document = PartsmithDocument(sourcePDFData: source)
        document.isPickingInstrumentNames = true
        _ = selectBlank(document)
        document.currentPageIndex = 1
        check(document.instrumentNameDraft == nil
              && !document.confirmInstrumentNameDraft(name: "Wrong page", staffCount: 1),
              "Navigating to another page immediately invalidates the pending name")
        document.currentPageIndex = 0
        check(document.instrumentNameDraft == nil, "Returning to a page cannot revive its discarded manual name")

        document.pickInstrumentName(in: firstBox, pageIndex: 0)
        check(document.isRecognizingInstrumentName, "Blank-box OCR begins asynchronously")
        document.currentPageIndex = 1
        document.currentPageIndex = 0
        pump(0.3)
        check(document.instrumentNameDraft == nil && document.instrumentNamePick == nil
              && !document.isRecognizingInstrumentName,
              "Navigating away and back while OCR runs cannot revive the old result")

        _ = selectBlank(document)
        document.sourcePDFData = blankPDF(pages: 3)
        check(document.instrumentNameDraft == nil
              && !document.confirmInstrumentNameDraft(name: "Old source", staffCount: 1),
              "Replacing the source PDF rejects a draft from the old document")
        document.sourcePDFData = source
        _ = selectBlank(document)
        document.isEditingPageRectification = true
        check(document.instrumentNameDraft == nil
              && !document.confirmInstrumentNameDraft(name: "Old geometry", staffCount: 1),
              "Entering deskew editing discards a pending manual selection")
        document.isEditingPageRectification = false
        _ = selectBlank(document)
        document.project.pageRectifications = [PageRectification(pageIndex: 0,
            topLeft: FractionPoint(x: 0, y: 0.002), topRight: FractionPoint(x: 1, y: 0),
            bottomRight: FractionPoint(x: 1, y: 0.998), bottomLeft: FractionPoint(x: 0, y: 1))]
        check(document.instrumentNameDraft == nil
              && !document.confirmInstrumentNameDraft(name: "Rectified old box", staffCount: 1),
              "Changing the displayed page rectification rejects stale manual geometry")
        document.project.pageRectifications = []

        _ = selectBlank(document)
        document.isPickingInstrumentNames = false
        check(document.instrumentNameDraft == nil
              && !document.confirmInstrumentNameDraft(name: "Outside session", staffCount: 1),
              "Ending the picking session directly prevents stale confirmation")
        document.isPickingInstrumentNames = true
        document.pickInstrumentName(in: firstBox, pageIndex: 0)
        document.pickInstrumentName(in: secondBox, pageIndex: 0)
        waitForRecognition(document)
        check(document.instrumentNameDraft?.bounds == secondBox,
              "Only the latest selection survives when a newer box supersedes an in-flight read")
        let latestID = document.instrumentNameDraft!.id
        document.pickInstrumentName(in: firstBox, pageIndex: 0)
        check(document.instrumentNameDraft == nil, "Starting another read clears the previous typing prompt immediately")
        waitForRecognition(document)
        check(document.instrumentNameDraft?.id != latestID && document.instrumentNameDraft?.bounds == firstBox,
              "Each new manual selection has its own identity and source geometry")
        document.cancelInstrumentNameDraft()

        for invalid in [CGRect.zero, CGRect.null,
                        CGRect(x: -0.01, y: 0.2, width: 0.1, height: 0.03),
                        CGRect(x: 0.95, y: 0.2, width: 0.1, height: 0.03),
                        CGRect(x: CGFloat.nan, y: 0.2, width: 0.1, height: 0.03)] {
            document.pickInstrumentName(in: invalid, pageIndex: 0)
            check(document.instrumentNameDraft == nil && document.instrumentNamePick == nil
                  && !document.isRecognizingInstrumentName,
                  "Invalid selection geometry cannot create a manual instrument draft")
        }
        check(document.project.parts.isEmpty && document.project.bands.isEmpty,
              "Cancellation, navigation and invalid selections never create saved parts or bands")
    }

    static func checkExistingPrintedRecognition() throws {
        let source = try Data(contentsOf: URL(fileURLWithPath:
            "sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf"))
        let document = PartsmithDocument(sourcePDFData: source)
        document.isPickingInstrumentNames = true
        let box = CGRect(x: 0.072, y: 0.217, width: 0.087, height: 0.019)
        document.pickInstrumentName(in: box, pageIndex: 0)
        waitForRecognition(document)
        check(document.instrumentNameDraft == nil && document.instrumentNamePick?.name == "1. Violine"
              && document.instrumentNameHighlights.count == 1,
              "Recognizable printed labels still add immediately with the complete instrument index")
        let originalHighlight = document.instrumentNameHighlights
        document.pickInstrumentName(in: CGRect(x: 0.08, y: 0.14, width: 0.07, height: 0.02), pageIndex: 0)
        waitForRecognition(document)
        check(document.instrumentNameDraft != nil && document.instrumentNameHighlights == originalHighlight,
              "A real score's blank margin offers manual naming while keeping the prior recognized name")
        document.cancelInstrumentNameDraft()
        document.pickInstrumentName(in: box, pageIndex: 0)
        document.cancelInstrumentNameDraft()
        pump(0.3)
        check(document.instrumentNameDraft == nil && document.instrumentNamePick == nil
              && !document.isRecognizingInstrumentName && document.instrumentNameHighlights == originalHighlight,
              "Canceling a pending read prevents late OCR from replacing existing selections")
    }

    static func main() throws {
        setbuf(stdout, nil)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try checkManualNamesAndList()
        checkInvalidation()
        try checkExistingPrintedRecognition()
        let result: [String: Any] = ["checks": checks.count, "failures": 0, "passed": checks,
            "scope": "Asynchronous OCR/document and editable instrument list; no live user application"]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("results.json"))
        print("PASS: \(checks.count) manual-instrument-name regression checks")
    }
}
