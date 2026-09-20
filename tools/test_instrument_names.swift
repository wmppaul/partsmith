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

    static func checkLabelBounds(_ bounds: CGRect, at point: CGPoint, description: String) {
        check(bounds.minX >= 0 && bounds.minY >= 0 && bounds.maxX <= 1 && bounds.maxY <= 1,
              "\(description): highlight stays in normalized displayed-page space")
        check(bounds.width > 0.025 && bounds.width < 0.20 && bounds.height > 0.004 && bounds.height < 0.03,
              "\(description): highlight is a printed label, not the OCR search region or whole staff")
        check(bounds.insetBy(dx: -0.008, dy: -0.004).contains(point),
              "\(description): highlight encloses the clicked printed label in top-down coordinates")
    }

    static func checkPickedListIdentity() {
        func pick(_ name: String = "Violine", page: Int = 0, y: Double = 0.22, staffCount: Int = 1,
                  bounds: CGRect? = nil) -> ScoreInstrumentNamePick {
            ScoreInstrumentNamePick(id: UUID(), name: name, suggestedStaffCount: staffCount,
                pageIndex: page, bounds: bounds ?? CGRect(x: 0.08, y: y, width: 0.075, height: 0.012))
        }
        var list = ScoreInstrumentPickList()
        var parts: [ScorePartDefinition] = []
        guard case let .added(firstID, firstName) = list.apply(pick(), to: &parts) else {
            fatalError("The first recognized instrument must create a list row")
        }
        check(firstName == "Violine" && parts.count == 1, "The first printed name keeps its original text")
        guard case let .added(secondID, secondName) = list.apply(pick(y: 0.26), to: &parts) else {
            fatalError("A second printed occurrence must create a separate row")
        }
        check(secondName == "Violine 2" && parts.map(\.name) == ["Violine", "Violine 2"],
              "Identical names on different staves receive distinct editable names")
        guard case let .added(thirdID, thirdName) = list.apply(pick(page: 1), to: &parts) else {
            fatalError("An identical label on another page must remain a separate occurrence")
        }
        check(thirdName == "Violine 3" && Set(parts.map(\.id)).count == 3,
              "Page identity distinguishes matching label coordinates on different pages")
        check(list.apply(pick(y: 0.26), to: &parts) == .existing(partID: secondID, name: "Violine 2")
              && parts.count == 3,
              "Rereading the same printed label reuses its existing row rather than suffixing it again")
        parts.removeAll { $0.id == firstID }
        check(list.apply(pick(y: 0.26), to: &parts) == .existing(partID: secondID, name: "Violine 2"),
              "A repeated reading keeps its assigned name when an earlier same-name row is removed")
        check(list.apply(pick("2. Violine", y: 0.26), to: &parts) == .updated(partID: secondID, name: "2. Violine")
              && parts.count == 2,
              "Expanding a selection to recover a printed number updates the same instrument row")
        let secondIndex = parts.firstIndex { $0.id == secondID }!
        parts[secondIndex].name = "Solo violin"
        parts[secondIndex].staffCount = 3
        check(list.apply(pick("Violin II", y: 0.26, staffCount: 2), to: &parts)
                == .existing(partID: secondID, name: "Solo violin")
              && parts[secondIndex].staffCount == 3,
              "Rereading a label preserves both manually edited names and staff counts")
        parts.removeAll { $0.id == secondID }
        guard case let .added(replacedID, _) = list.apply(pick("2. Violine", y: 0.26), to: &parts) else {
            fatalError("A deleted instrument row may be added again by picking its source label")
        }
        check(replacedID != secondID && parts.count == 2,
              "A deleted row does not leave stale source identity that suppresses a new pick")
        list.reset()
        guard case let .added(resetID, _) = list.apply(pick(page: 1), to: &parts) else {
            fatalError("Resetting source identity must allow a new pick")
        }
        check(resetID != thirdID && parts.count == 3, "A new picking list resets remembered source-label identities")

        var collisions = ScoreInstrumentPickList()
        var manualParts = [ScorePartDefinition(id: "manual-first", name: "VIOLINE", staffCount: 1),
                           ScorePartDefinition(id: "manual-second", name: "  Violine   2  ", staffCount: 1)]
        let originalManualParts = manualParts
        guard case let .added(_, uniqueName) = collisions.apply(pick(), to: &manualParts) else {
            fatalError("A printed name matching a manually entered name still creates its own row")
        }
        check(uniqueName == "Violine 3" && Array(manualParts.prefix(2)) == originalManualParts,
              "Automatic suffixes avoid case and whitespace collisions without renaming existing rows")
        let beforeInvalid = manualParts
        for invalid in [pick("   "), pick(page: -1), pick(staffCount: 0),
                        pick(bounds: CGRect(x: -0.1, y: 0.2, width: 0.1, height: 0.01)),
                        pick(bounds: .zero), pick(bounds: CGRect(x: 0.98, y: 0.2, width: 0.1, height: 0.01))] {
            check(collisions.apply(invalid, to: &manualParts) == nil && manualParts == beforeInvalid,
                  "Invalid picked labels cannot mutate or renumber the editable instrument list")
        }
    }

    static func checkRegionPicking() throws {
        let source = try Data(contentsOf: URL(fileURLWithPath:
            "sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf"))
        let document = PartsmithDocument(sourcePDFData: source)
        let image = document.scoreReviewImage(pageIndex: 0)!
        let completeBox = CGRect(x: 0.072, y: 0.217, width: 0.087, height: 0.019)
        let wordBox = CGRect(x: 0.093, y: 0.217, width: 0.066, height: 0.019)
        let result = ScoreInstrumentNameDetector.recognize(in: image, region: completeBox)
        check(result?.text == "1. Violine", "A drawn box reads the complete printed instrument label including its number")
        check(result != nil && completeBox.contains(result!.bounds)
              && result!.bounds.minX < 0.09 && result!.bounds.maxX > 0.145,
              "Box recognition returns tight source bounds enclosing both the number and instrument word")
        let wordOnly = ScoreInstrumentNameDetector.recognize(in: image, region: wordBox)
        check(wordOnly?.text == "Violine" && wordOnly!.bounds.minX >= wordBox.minX,
              "An explicit box controls the OCR input and does not borrow a number outside its edges")
        check(ScoreInstrumentNameDetector.recognize(in: image, region: completeBox, isCancelled: { true }) == nil,
              "Cancelled box recognition produces no label")
        for invalid in [CGRect.zero, CGRect.null,
                        CGRect(x: -0.01, y: 0.2, width: 0.1, height: 0.02),
                        CGRect(x: 0.95, y: 0.2, width: 0.1, height: 0.02),
                        CGRect(x: CGFloat.nan, y: 0.2, width: 0.1, height: 0.02)] {
            check(ScoreInstrumentNameDetector.recognize(in: image, region: invalid) == nil,
                  "Invalid OCR selection geometry never reads a different score region")
        }
        let blankBox = CGRect(x: 0.08, y: 0.14, width: 0.07, height: 0.02)
        check(ScoreInstrumentNameDetector.recognize(in: image, region: blankBox) == nil,
              "A box over blank margin cannot borrow a neighboring title or instrument")
        document.pickInstrumentName(in: completeBox, pageIndex: 0)
        check(!document.isRecognizingInstrumentName && document.instrumentNamePick == nil,
              "Drawing an OCR box outside picking mode cannot change the current result")
        document.isPickingInstrumentNames = true
        document.pickInstrumentName(in: wordBox, pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick?.name == "Violine" && document.instrumentNameHighlights.count == 1,
              "Document box recognition publishes the selected partial label")
        document.pickInstrumentName(in: completeBox, pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick?.name == "1. Violine" && document.instrumentNameHighlights.count == 1
              && document.instrumentNameHighlights[0].bounds == result?.bounds,
              "Expanding a label box replaces the previous highlight with its complete numbered text and bounds")
        let pickedID = document.instrumentNamePick!.id
        document.updateInstrumentNameHighlight(id: pickedID, name: "Violine 2")
        check(document.instrumentNameHighlights[0].name == "Violine 2"
              && document.instrumentNameHighlights[0].bounds == result?.bounds,
              "A unique editable list name can be shown on score without moving its source highlight")
        let previousHighlights = document.instrumentNameHighlights
        document.pickInstrumentName(in: blankBox, pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNameHighlights == previousHighlights,
              "An empty box leaves earlier successfully recognized labels visible")
        document.pickInstrumentName(in: completeBox, pageIndex: 0)
        document.cancelInstrumentNamePicking()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        check(!document.isRecognizingInstrumentName && document.instrumentNamePick == nil
              && document.instrumentNameHighlights.isEmpty,
              "Finishing picking cancels a pending box read and clears all transient highlights")
        document.isPickingInstrumentNames = true
        document.pickInstrumentName(in: completeBox, pageIndex: 0)
        document.sourcePDFData = nil
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNameHighlights.isEmpty,
              "Replacing the score invalidates an in-flight box read and its geometry")
    }

    static func checkNumberedStringLabels() throws {
        let fixtures: [(path: String, clicks: [CGPoint])] = [
            ("sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf",
             [CGPoint(x: 0.115, y: 0.227), CGPoint(x: 0.115, y: 0.268)]),
            ("sample_scores/lightly_skewed/10_brahms_string_quartet_no3_op67_imslp_242312.pdf",
             [CGPoint(x: 0.115, y: 0.213), CGPoint(x: 0.115, y: 0.253)])
        ]
        let expectedNames = ["1. Violine", "2. Violine"]
        for (fixtureIndex, fixture) in fixtures.enumerated() {
            let source = try Data(contentsOf: URL(fileURLWithPath: fixture.path))
            let document = PartsmithDocument(sourcePDFData: source)
            document.project.pageCount = document.pdfDocument!.pageCount
            for corrected in [false, true] {
                if corrected {
                    // These quartet openings are nearly level, so automatic
                    // deskew correctly proposes no change. A small explicit
                    // correction exercises the displayed corrected-raster path.
                    document.updatePageRectification(PageRectification(pageIndex: 0,
                        topLeft: FractionPoint(x: 0, y: 0.002), topRight: FractionPoint(x: 1, y: 0),
                        bottomRight: FractionPoint(x: 1, y: 0.998), bottomLeft: FractionPoint(x: 0, y: 1)))
                }
                let image = document.scoreReviewImage(pageIndex: 0)!
                let description = "Quartet \(fixtureIndex + 1) \(corrected ? "rectified" : "raw")"
                for (index, point) in fixture.clicks.enumerated() {
                    let expected = expectedNames[index]
                    let result = ScoreInstrumentNameDetector.recognize(in: image, at: point)
                    print("\(description) click \(point): \(result?.text ?? "nil")")
                    check(result?.text == expected,
                          "\(description): clicking the instrument word preserves its printed ordinal: \(expected)")
                    checkLabelBounds(result!.bounds, at: point, description: "\(description) \(expected)")
                    let numberPoint = CGPoint(x: 0.082, y: point.y)
                    check(result!.bounds.insetBy(dx: -0.002, dy: -0.004).contains(numberPoint),
                          "\(description): the highlight covers the printed number as well as Violine")
                    let numberResult = ScoreInstrumentNameDetector.recognize(in: image, at: numberPoint)
                    check(numberResult?.text == expected,
                          "\(description): clicking the ordinal selects the complete numbered instrument name")
                    if fixtureIndex == 0 {
                        document.isPickingInstrumentNames = true
                        document.pickInstrumentName(at: point, pageIndex: 0)
                        waitFor { !document.isRecognizingInstrumentName }
                        check(document.instrumentNamePick?.name == expected,
                              "\(description): document picking publishes the distinct numbered name")
                    }
                }
                if fixtureIndex == 0 {
                    check(document.instrumentNameHighlights.map(\.name) == expectedNames,
                          "\(description): first and second violins remain distinct simultaneous labels")
                    document.pickInstrumentName(at: fixture.clicks[0], pageIndex: 0)
                    waitFor { !document.isRecognizingInstrumentName }
                    check(document.instrumentNameHighlights.count == 2
                          && Set(document.instrumentNameHighlights.map(\.name)) == Set(expectedNames),
                          "\(description): repeating the first violin click never erases or duplicates the second violin")
                    document.cancelInstrumentNamePicking()
                }
            }
        }
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
        let violin = Candidate(text: "Violine", bounds: CGRect(x: 0.10, y: 0.22, width: 0.06, height: 0.012), confidence: 1)
        let violinPoint = CGPoint(x: 0.13, y: 0.226)
        let firstNumber = Candidate(text: "1.", bounds: CGRect(x: 0.085, y: 0.22, width: 0.009, height: 0.012), confidence: 1)
        let combined = ScoreInstrumentNameDetector.selectCandidate(from: [violin, firstNumber], at: violinPoint)
        check(combined?.text == "1. Violine" && combined?.bounds == violin.bounds.union(firstNumber.bounds),
              "A separately recognized ordinal joins its instrument name and expands the highlight to include it")
        check(ScoreInstrumentNameDetector.selectCandidate(from: [violin, firstNumber],
                at: CGPoint(x: firstNumber.bounds.midX, y: firstNumber.bounds.midY))?.text == "1. Violine",
              "A click on a separately recognized ordinal selects the complete name")
        let suffix = Candidate(text: "II", bounds: CGRect(x: 0.165, y: 0.22, width: 0.009, height: 0.012), confidence: 1)
        check(ScoreInstrumentNameDetector.selectCandidate(from: [violin, suffix], at: violinPoint)?.text == "Violine II",
              "A same-line Roman instrument number is retained after its name")
        let otherRow = Candidate(text: "2.", bounds: CGRect(x: 0.085, y: 0.26, width: 0.009, height: 0.012), confidence: 1)
        let farNumber = Candidate(text: "3.", bounds: CGRect(x: 0.04, y: 0.22, width: 0.009, height: 0.012), confidence: 1)
        let meter = Candidate(text: "6/8", bounds: firstNumber.bounds, confidence: 1)
        let uncertainNumber = Candidate(text: "2.", bounds: firstNumber.bounds, confidence: 0.1)
        for unrelated in [otherRow, farNumber, meter, uncertainNumber] {
            check(ScoreInstrumentNameDetector.selectCandidate(from: [violin, unrelated], at: violinPoint)?.text == "Violine",
                  "Unrelated, distant, meter or uncertain numbers never attach themselves to an instrument name")
        }
        check(ScoreInstrumentNameDetector.selectCandidate(from: [suffix],
                at: CGPoint(x: suffix.bounds.midX, y: suffix.bounds.midY)) == nil,
              "A Roman number without an instrument label cannot create a part")
        let alreadyNumbered = Candidate(text: "1. Violine", bounds: violin.bounds.union(firstNumber.bounds), confidence: 1)
        check(ScoreInstrumentNameDetector.selectCandidate(from: [alreadyNumbered, suffix], at: violinPoint)?.text == "1. Violine",
              "A complete numbered label does not acquire a second nearby number")
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
            checkLabelBounds(result!.bounds, at: point, description: "Raw \(expected)")
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
            checkLabelBounds(result!.bounds, at: point, description: "Deskewed \(expected)")
            rectifiedDocument.isPickingInstrumentNames = true
            rectifiedDocument.pickInstrumentName(at: point, pageIndex: 0)
            waitFor { !rectifiedDocument.isRecognizingInstrumentName }
            check(rectifiedDocument.instrumentNamePick?.name == expected
                  && rectifiedDocument.instrumentNamePick?.suggestedStaffCount == staffCount,
                  "Document picking uses the deskewed display raster: \(expected)")
            check(rectifiedDocument.instrumentNamePick?.bounds == result?.bounds,
                  "The displayed highlight uses the recognized deskewed geometry without converting it back to the source")
        }
        check(rectifiedDocument.instrumentNameHighlights.map(\.name) == targets.map { $0.1 },
              "All three deskewed names remain highlighted in click order")
        rectifiedDocument.cancelInstrumentNamePicking()
        check(rectifiedDocument.instrumentNameHighlights.isEmpty, "Finishing a deskewed picking session clears its highlights")
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
        checkLabelBounds(document.instrumentNamePick!.bounds, at: targets[0].0, description: "Document raw Klarinette")
        check(document.instrumentNameHighlights == [document.instrumentNamePick!],
              "Successful recognition immediately adds its visible label highlight")
        check(document.project.parts.isEmpty && document.project.bands.isEmpty,
              "A recognized label never directly creates score parts or crops")
        let firstEventID = document.instrumentNamePick?.id
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick?.id != firstEventID,
              "Repeated deliberate clicks publish distinct events for UI review")
        check(document.instrumentNameHighlights.count == 1
              && document.instrumentNameHighlights.first == document.instrumentNamePick,
              "Repeated clicks refresh a label without stacking duplicate highlights")
        let firstHighlights = document.instrumentNameHighlights
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        document.pickInstrumentName(at: targets[2].0, pageIndex: 0)
        check(document.instrumentNameHighlights == firstHighlights,
              "Existing successful highlights stay visible while another label is being read")
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick?.name == "Pianoforte" && document.instrumentNamePick?.suggestedStaffCount == 2,
              "A newer click supersedes the pending result")
        check(document.instrumentNameHighlights.map(\.name) == ["Klarinette in A", "Pianoforte"],
              "A second instrument adds to the visible highlighted list")
        let successfulHighlights = document.instrumentNameHighlights
        document.pickInstrumentName(at: CGPoint(x: 0.07, y: 0.15), pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNamePickMessage != nil
              && document.instrumentNameHighlights == successfulHighlights,
              "An unreadable click leaves earlier successful labels highlighted")
        document.currentPageIndex = 1
        check(document.instrumentNameHighlights == successfulHighlights,
              "Navigating keeps successful highlights associated with their original source page")
        document.currentPageIndex = 0
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        document.cancelInstrumentNamePicking()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        check(!document.isPickingInstrumentNames && !document.isRecognizingInstrumentName
              && document.instrumentNamePick == nil && document.instrumentNamePickMessage == nil
              && document.instrumentNameHighlights.isEmpty,
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
        waitFor { !document.isRecognizingInstrumentName }
        check(!document.instrumentNameHighlights.isEmpty, "A fresh session displays a successfully recognized name")
        document.pickInstrumentName(at: targets[2].0, pageIndex: 0)
        document.project.pageRectifications = [.default(pageIndex: 0)]
        check(document.instrumentNameHighlights.isEmpty && document.instrumentNamePick == nil,
              "Rectification clears old highlight geometry immediately, before any pending OCR finishes")
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNamePickMessage != nil,
              "Rectification changes reject a stale OCR result")
        document.project.pageRectifications = []
        document.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        waitFor { !document.isRecognizingInstrumentName }
        check(!document.instrumentNameHighlights.isEmpty, "Recognizing on the restored raw page produces a current highlight")
        document.pickInstrumentName(at: targets[2].0, pageIndex: 0)
        document.sourcePDFData = nil
        check(document.instrumentNameHighlights.isEmpty && document.instrumentNamePick == nil,
              "Replacing the source immediately removes old score highlights")
        waitFor { !document.isRecognizingInstrumentName }
        check(document.instrumentNamePick == nil && document.instrumentNamePickMessage != nil,
              "Source replacement rejects a stale OCR result")
        document.cancelInstrumentNamePicking()

        let undoDocument = PartsmithDocument(sourcePDFData: sourceData)
        undoDocument.project.pageCount = pdf.pageCount
        let undoManager = UndoManager()
        undoDocument.undoManager = undoManager
        undoManager.beginUndoGrouping()
        undoDocument.autoEstimateCurrentPageRectification()
        undoManager.endUndoGrouping()
        undoDocument.isPickingInstrumentNames = true
        undoDocument.pickInstrumentName(at: targets[0].0, pageIndex: 0)
        waitFor { !undoDocument.isRecognizingInstrumentName }
        check(!undoDocument.instrumentNameHighlights.isEmpty, "A deskewed score has a visible highlight before undo")
        undoManager.undo()
        check(undoDocument.currentPageRectification == nil && undoDocument.instrumentNameHighlights.isEmpty,
              "Undoing deskew invalidates highlights bound to the corrected page geometry")
        undoDocument.cancelInstrumentNamePicking()
        checkPickedListIdentity()
        try checkNumberedStringLabels()
        try checkRegionPicking()
        print("\(checks) instrument-name recognition checks passed.")
    }
}
