import AppKit
import CoreGraphics
import Foundation
import PDFKit

@main
enum InstrumentNameTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }

    static func waitFor(_ complete: () -> Bool) {
        let deadline = Date().addingTimeInterval(15)
        while !complete() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(complete(), "OCR operation completed within the fixture timeout")
    }

    static func main() throws {
        typealias Candidate = ScoreInstrumentNameDetector.Candidate
        let clarinet = Candidate(text: "  Klarinette   in A  ", bounds: CGRect(x: 0.02, y: 0.22, width: 0.13, height: 0.015), confidence: 0.9)
        let cello = Candidate(text: "Violoncello", bounds: CGRect(x: 0.045, y: 0.265, width: 0.09, height: 0.015), confidence: 0.99)
        let title = Candidate(text: "Trio", bounds: CGRect(x: 0.40, y: 0.10, width: 0.14, height: 0.03), confidence: 1)
        let candidates = [title, cello, clarinet]
        check(ScoreInstrumentNameDetector.selectCandidate(from: candidates, at: CGPoint(x: 0.1, y: 0.226))?.text == "Klarinette in A", "Click selects complete nearest label and normalizes whitespace")
        check(ScoreInstrumentNameDetector.selectCandidate(from: candidates, at: CGPoint(x: 0.09, y: 0.27))?.text == "Violoncello", "Nearby rows never substitute the previous instrument")
        check(ScoreInstrumentNameDetector.selectCandidate(from: candidates, at: CGPoint(x: 0.1, y: 0.31)) == nil, "Blank space does not select a nearby instrument")
        check(ScoreInstrumentNameDetector.selectCandidate(from: candidates, at: CGPoint(x: 0.1, y: 0.240))?.text == "Klarinette in A", "Small imprecision beside the printed line remains clickable")
        check(ScoreInstrumentNameDetector.selectCandidate(from: candidates, at: CGPoint(x: 0.8, y: 0.226)) == nil, "A staff click far from the label does not select it")
        check(ScoreInstrumentNameDetector.selectCandidate(from: candidates, at: CGPoint(x: .nan, y: 0.226)) == nil, "Invalid source coordinates do not produce a label")
        let invalid = [Candidate(text: "123", bounds: clarinet.bounds, confidence: 1), Candidate(text: "Piano", bounds: clarinet.bounds, confidence: 0.1)]
        check(ScoreInstrumentNameDetector.selectCandidate(from: invalid, at: CGPoint(x: 0.1, y: 0.226)) == nil, "Digits and uncertain OCR do not create instrument rows")
        for name in ["Piano", "Pianoforte", "KLAVIER", "Harpsichord", "Cembalo", "Clavecin I"] {
            check(ScoreInstrumentNameDetector.suggestedStaffCount(for: name) == 2, "Keyboard suggestion has two staves: \(name)")
        }
        for name in ["Klarinette in A", "Violoncello", "Violin", "Pianola", "Soprano"] {
            check(ScoreInstrumentNameDetector.suggestedStaffCount(for: name) == 1, "Other labels retain the editable one-staff default: \(name)")
        }
        check(ScoreInstrumentNameDetector.searchRegion(around: .zero).minX == 0 && ScoreInstrumentNameDetector.searchRegion(around: .zero).minY == 0, "Left/top edge clicks keep OCR search on the source page")

        // A real scan exercises Vision and its bottom-up to top-down conversion.
        // This is read-only: it renders the source, without authoring any PDF.
        let path = CommandLine.arguments.dropFirst().first ?? "sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf"
        let pdf = PDFDocument(url: URL(fileURLWithPath: path))!
        let page = pdf.page(at: 0)!
        let image = NativeScorePageAnalyzer.render(page)!
        let targets: [(CGPoint, String, Int)] = [
            (CGPoint(x: 0.080, y: 0.222), "Klarinette in A", 1),
            (CGPoint(x: 0.088, y: 0.266), "Violoncell", 1),
            (CGPoint(x: 0.083, y: 0.354), "Pianoforte", 2)
        ]
        for (point, expected, staffCount) in targets {
            let result = ScoreInstrumentNameDetector.recognize(in: image, at: point)
            print("Scan click \(point): \(result?.text ?? "nil")")
            check(result?.text == expected, "Real Trio label OCR matches clicked source: expected \(expected), got \(String(describing: result))")
            check(ScoreInstrumentNameDetector.suggestedStaffCount(for: result!.text) == staffCount, "Real label gives appropriate editable staff count")
        }
        check(ScoreInstrumentNameDetector.recognize(in: image, at: CGPoint(x: 0.07, y: 0.15)) == nil, "Real blank margin creates no spurious part")
        check(ScoreInstrumentNameDetector.recognize(in: image, at: targets[0].0, isCancelled: { true }) == nil, "Cancelled request does no recognition")
        let sourceData = try Data(contentsOf: URL(fileURLWithPath: path))
        let rectifiedDocument = PartsmithDocument(sourcePDFData: sourceData)
        rectifiedDocument.project.pageCount = pdf.pageCount
        rectifiedDocument.autoEstimateCurrentPageRectification()
        check(rectifiedDocument.currentPageRectification != nil,
              "Real scanned opening receives the app's automatic deskew estimate")
        let correctedImage = rectifiedDocument.scoreReviewImage(pageIndex: 0)!
        // Deskew changes the displayed coordinates slightly; these clicks stay
        // inside the source labels as displayed after this measured correction.
        for (point, expected, staffCount) in targets {
            let result = ScoreInstrumentNameDetector.recognize(in: correctedImage, at: point)
            check(result?.text == expected,
                  "Deskewed displayed label remains exact: expected \(expected), got \(String(describing: result))")
            rectifiedDocument.isPickingInstrumentNames = true
            rectifiedDocument.pickInstrumentName(at: point, pageIndex: 0)
            waitFor { !rectifiedDocument.isRecognizingInstrumentName }
            check(rectifiedDocument.instrumentNamePick?.name == expected
                  && rectifiedDocument.instrumentNamePick?.suggestedStaffCount == staffCount,
                  "Document picking uses the deskewed display raster: \(expected)")
        }
        rectifiedDocument.cancelInstrumentNamePicking()
        let document = PartsmithDocument(sourcePDFData: sourceData)
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        check(document.instrumentNamePick == nil && !document.isRecognizingInstrumentName,
              "Score clicks outside picking mode cannot recognize labels")
        document.isPickingInstrumentNames = true
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        check(document.isRecognizingInstrumentName, "Picking announces background OCR progress")
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick?.name == "Klarinette in A" && document.instrumentNamePick?.pageIndex == 0,
              "Document returns clicked label as one event in displayed page coordinates")
        check(document.project.parts.isEmpty && document.project.bands.isEmpty,
              "A recognized label never directly creates score parts or crops")
        let firstEventID = document.instrumentNamePick?.id
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick?.id != firstEventID,
              "Repeated deliberate clicks publish distinct events for UI review")
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        document.pickInstrumentName(at: targets[2].0, pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick?.name == "Pianoforte" && document.instrumentNamePick?.suggestedStaffCount == 2,
              "A newer click supersedes the pending result")
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        document.cancelInstrumentNamePicking()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        check(!document.isPickingInstrumentNames && !document.isRecognizingInstrumentName
              && document.instrumentNamePick == nil && document.instrumentNamePickMessage == nil,
              "Stopping picking cancels pending recognition and clears transient results")
        document.isPickingInstrumentNames = true
        document.pickInstrumentName(at: CGPoint(x: 0.07, y: 0.15), pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNamePickMessage != nil,
              "A blank click offers retry/manual entry without adding an empty name")
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        document.currentPageIndex = 1
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNamePickMessage != nil,
              "Page navigation rejects a stale OCR result")
        document.currentPageIndex = 0
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        document.project.pageRectifications = [.default(pageIndex: 0)]
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNamePickMessage != nil,
              "Rectification changes reject a stale OCR result")
        document.project.pageRectifications = []
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        document.sourcePDFData = nil
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNamePickMessage != nil,
              "Source replacement rejects a stale OCR result")
        document.cancelInstrumentNamePicking()
        print("\(checks) instrument-name recognition checks passed.")
    }
}
