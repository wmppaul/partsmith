import AppKit
import Foundation
import PDFKit

@main
enum RestAutoFlowTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
            exit(1)
        }
    }
    static func wait(_ done: () -> Bool) {
        let deadline = Date().addingTimeInterval(45)
        while !done(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        check(done(), "Background recognition completes without blocking the document")
    }
    static func sourcePDF(mark: Double = 0) -> Data {
        let data = NSMutableData()
        var media = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        for page in 0..<3 {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 1, alpha: 1); context.fill(media)
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 60 + mark, y: 650 - Double(page), width: 100, height: 2))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
    static func found(_ rect: CGRect, count: Int = 3) -> ScoreRestDetector.Detection {
        ScoreRestDetector.Detection(barCount: count,
            staffLineFractions: (0..<5).map { rect.minY + rect.height * (0.3 + Double($0) * 0.1) },
            skewDegrees: 0, staffLeftFraction: rect.minX + 0.02, staffRightFraction: rect.maxX - 0.02,
            prefixBounds: CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.12, height: rect.height),
            suffixBounds: CGRect(x: rect.maxX - 0.025, y: rect.minY, width: 0.025, height: rect.height),
            restBounds: [])
    }
    static var recognize: RestAutoBandRecognizer { { _, crop, _, _ in found(crop) } }

    static func main() throws {
        let source = sourcePDF()
        let p = UUID(), q = UUID()
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID(), f = UUID()
        var project = ProjectData.empty
        project.sourceFilename = "rest-auto-workflow.pdf"
        project.pageCount = 3
        project.parts = [p, q].enumerated().map {
            PartModel(id: $0.element, name: "Part \($0.offset + 1)", color: ColorData(nsColor: .systemBlue),
                      layoutSettings: .default, createdAt: .now)
        }
        project.bands = [(a, 0, p, 0.1), (b, 0, p, 0.3), (c, 1, p, 0.1),
                         (d, 0, q, 0.5), (e, 2, p, 0.1), (f, 1, p, 0.3)].map {
            BandModel(id: $0.0, pageIndex: $0.1, partID: $0.2, topFraction: $0.3,
                bottomFraction: $0.3 + 0.1, leftFraction: 0.05, rightFraction: 0.05,
                excluded: $0.0 == e, createdAt: .now, barNumberMode: .manual,
                restReplacement: $0.0 == f ? BandRestReplacement(barCount: 8) : nil)
        }
        func make(_ custom: ProjectData? = nil) -> PartsmithDocument {
            PartsmithDocument(project: custom ?? project, sourcePDFData: source)
        }
        func rest(_ document: PartsmithDocument, _ id: UUID) -> BandRestReplacement? {
            document.band(withID: id)?.restReplacement
        }
        func run(_ document: PartsmithDocument, partID: UUID? = nil, bandIDs: Set<UUID>? = nil,
                 recognizer: RestAutoBandRecognizer? = recognize,
                 afterStart: (() -> Void)? = nil) -> RestAutoResult {
            var result: RestAutoResult?
            document.autoDetectRestReplacements(partID: partID, bandIDs: bandIDs, recognizer: recognizer) { result = $0 }
            afterStart?()
            wait { result != nil }
            check(document.restAutoProgress == nil && document.restAutoStatus?.isEmpty == false,
                  "Finished runs clear progress and keep a readable result")
            return result!
        }

        let all = make()
        let undo = UndoManager(); undo.groupsByEvent = false; all.undoManager = undo
        let original = all.project
        undo.beginUndoGrouping()
        check(run(all) == .completed(replacedBands: 4, totalBars: 12, examinedBands: 4),
              "All parts recognize only included strips without existing replacements")
        undo.endUndoGrouping()
        check([a,b,c,d].allSatisfy { rest(all, $0)?.barCount == 3 }, "Each recognized original receives its own count")
        check(rest(all, e) == nil && rest(all, f)?.barCount == 8, "Excluded strips and manual rest choices remain intact")
        check([a,b,c,d].allSatisfy { rest(all, $0)?.joinWithPrevious == true }, "Automatic recognition enables joining; layout still checks source continuity and musical boundaries")
        let context = rest(all, a)!.sourceContext!
        check(context.isValid(in: all.band(withID: a)!) && context.suffix != nil,
              "Automatic replacements retain validated clef/key/meter and final-bar fragments")
        check(abs(context.prefix.rightFraction - (1 - (0.05 + 0.9 * 0.12))) < 0.000001,
              "Top-down detected rectangles convert right edge to the model's right-trim fraction")
        check(all.sourcePDFData == source && all.project.bands.map(\.sourceMarkings) == original.bands.map(\.sourceMarkings),
              "Recognition leaves original PDF and shared source directions unchanged")
        undo.undo()
        check(all.project == original && !undo.canUndo, "A single Undo restores all recognized strips together")
        check(all.restAutoStatus == nil, "Undo clears the now-stale automatic compression result")
        undo.redo()
        check(rest(all, a)?.sourceContext == context && rest(all, d)?.barCount == 3,
              "Redo restores counts and source context together")
        undo.beginUndoGrouping()
        all.updateBandRestReplacement(a, barCount: 7, joinWithPrevious: true)
        undo.endUndoGrouping()
        check(rest(all, a)?.sourceContext == context && rest(all, a)?.barCount == 7,
              "Changing an automatic count/join preserves its source prefix and suffix")

        let selected = make()
        check(run(selected, partID: p, bandIDs: [a,d]) == .completed(replacedBands: 1, totalBars: 3, examinedBands: 1),
              "Selected strip IDs intersect the chosen part")
        check(rest(selected,b) == nil && rest(selected,d) == nil, "Bands outside both selection boundaries remain unchanged")
        let selectedPart = make()
        check(run(selectedPart, partID: q) == .completed(replacedBands: 1, totalBars: 3, examinedBands: 1),
              "A part-scoped run does not touch other instruments")
        let empty = make()
        let emptyUndo = UndoManager(); empty.undoManager = emptyUndo
        let unchanged = empty.project
        check(run(empty, bandIDs: []) == .completed(replacedBands: 0, totalBars: 0, examinedBands: 0),
              "An explicit empty selection remains empty")
        check(empty.project == unchanged && !emptyUndo.canUndo, "An empty run does not dirty the project or add Undo")
        check(run(empty, partID: UUID()) == .unavailable, "A removed part cannot redirect recognition to all parts")
        let uncertain = make()
        let uncertainUndo = UndoManager(); uncertain.undoManager = uncertainUndo
        check(run(uncertain, recognizer: { _,_,_,_ in nil }) == .completed(replacedBands: 0, totalBars: 0, examinedBands: 4),
              "Uncertain recognition preserves every original music strip")
        check(uncertain.project == project && !uncertainUndo.canUndo, "No confident result causes no mutation or Undo")

        var markedProject = project
        markedProject.bands[0].sourceMarkings = [BandSourceMarking(topFraction: 0.02, bottomFraction: 0.04,
            leftFraction: 0.3, rightFraction: 0.4)]
        let marked = make(markedProject)
        var markedCalls = 0
        check(run(marked, bandIDs: [a,b], recognizer: { _, crop, _, _ in
            markedCalls += 1
            return found(crop)
        }) == .completed(replacedBands: 1, totalBars: 3, examinedBands: 2),
              "Separately copied tempo/rehearsal directions prevent automatic compression of their strip")
        check(markedCalls == 2 && marked.band(withID:a) == markedProject.bands[0] && rest(marked,b)?.barCount == 3,
              "Shared directions keep their original position while other eligible strips still compress")
        var openingProject = project
        openingProject.bands[0].sourceMarkings = [BandSourceMarking(topFraction: 0.02, bottomFraction: 0.04,
            leftFraction: 0.06, rightFraction: 0.92)]
        let opening = make(openingProject)
        check(run(opening, bandIDs: [a]) == .completed(replacedBands: 1, totalBars: 3, examinedBands: 1),
              "A copied opening bar number or tempo entirely left of the counted run remains eligible")
        check(opening.band(withID:a)?.sourceMarkings == openingProject.bands[0].sourceMarkings,
              "Compression retains copied opening directions verbatim")

        // Opening Allegro/TUTTI extends beyond the retained clef/meter prefix
        // on Mozart K488, but still finishes before the first counted rest.
        let openingRunRecognizer: RestAutoBandRecognizer = { _, crop, _, _ in
            var result = found(crop)
            result.prefixBounds.size.width = 0.191 // crop x .05 -> prefix ends .241
            result.restBounds = [0.55, 0.298, 0.80].map { x in
                CGRect(x: x, y: crop.minY + 0.04, width: 0.015, height: 0.005)
            }
            return result
        }
        var extendedOpeningProject = project
        extendedOpeningProject.bands[0].sourceMarkings = [BandSourceMarking(
            topFraction: 0.02, bottomFraction: 0.04, leftFraction: 0.06, rightFraction: 0.736)]
        let extendedOpening = make(extendedOpeningProject)
        check(run(extendedOpening, bandIDs: [a], recognizer: openingRunRecognizer)
                == .completed(replacedBands: 1, totalBars: 3, examinedBands: 1),
              "An opening direction ending after the prefix but before the first rest remains eligible")
        check(extendedOpening.band(withID:a)?.sourceMarkings == extendedOpeningProject.bands[0].sourceMarkings,
              "Recognition preserves the entire extended opening direction without shrinking its copied bounds")
        var laterDirectionProject = extendedOpeningProject
        laterDirectionProject.bands[0].sourceMarkings[0].rightFraction = 0.6 // ends .4, after first rest .298
        let laterDirection = make(laterDirectionProject)
        check(run(laterDirection, bandIDs: [a], recognizer: openingRunRecognizer)
                == .completed(replacedBands: 0, totalBars: 0, examinedBands: 1),
              "A direction crossing the earliest rest blocks compression even when rest bounds are unsorted")
        check(laterDirection.project == laterDirectionProject,
              "A later copied direction leaves both its source and rest output unchanged")
        let unknownRestLocation = make(extendedOpeningProject)
        check(run(unknownRestLocation, bandIDs: [a])
                == .completed(replacedBands: 0, totalBars: 0, examinedBands: 1),
              "Without located rest glyphs, an extended direction still requires the conservative prefix boundary")

        for count in [1, 1000] {
            let invalid = make()
            check(run(invalid, bandIDs: [a], recognizer: { _, crop, _, _ in found(crop, count: count) })
                    == .completed(replacedBands: 0, totalBars: 0, examinedBands: 1),
                  "An invalid detector count \(count) is rejected before changing the document")
        }
        let badContext = make()
        check(run(badContext, bandIDs: [a], recognizer: { _, crop, _, _ in
            var result = found(crop); result.prefixBounds.origin.x = -0.1; return result
        }) == .completed(replacedBands: 0, totalBars: 0, examinedBands: 1),
              "An out-of-crop source context never becomes an active replacement")

        let mutations: [(String, (PartsmithDocument) -> Void)] = [
            ("source bytes", { $0.sourcePDFData = sourcePDF(mark: 1) }),
            ("crop top", { $0.project.bands[0].topFraction += 0.002 }),
            ("crop bottom", { $0.project.bands[0].bottomFraction += 0.002 }),
            ("crop left", { $0.project.bands[0].leftFraction += 0.002 }),
            ("crop right", { $0.project.bands[0].rightFraction += 0.002 }),
            ("source page", { $0.project.bands[0].pageIndex = 1 }),
            ("instrument", { $0.project.bands[0].partID = q }),
            ("exclusion", { $0.project.bands[0].excluded = true }),
            ("band deletion", { $0.project.bands.removeAll { $0.id == a } }),
            ("part deletion", { $0.project.parts.removeAll { $0.id == p } }),
            ("whiteout", { $0.project.bands[0].exclusions = [BandExclusion(topFraction: 0.12, bottomFraction: 0.14, leftFraction: 0.1, rightFraction: 0.7)] }),
            ("source marking", { $0.project.bands[0].sourceMarkings = [BandSourceMarking(topFraction: 0.1, bottomFraction: 0.11, leftFraction: 0.1, rightFraction: 0.8)] }),
            ("deskew", { $0.project.pageRectifications = [.default(pageIndex: 0)] })
        ]
        for (name, mutate) in mutations {
            let stale = make()
            check(run(stale, bandIDs: [a,b], afterStart: { mutate(stale) }) == .sourceChanged,
                  "A changed \(name) discards the entire stale recognition result")
            check(rest(stale,b) == nil, "Stale recognition remains atomic across all its bands")
        }
        let cosmetic = make()
        check(run(cosmetic, bandIDs: [a], afterStart: {
            cosmetic.project.parts[0].name = "Clarinet"
            cosmetic.project.bands[0].barNumberValue = 31
            cosmetic.project.bands[0].editorialLabel = "Second movement"
            cosmetic.project.bands[0].pageBreakBefore = true
            cosmetic.project.pageRectifications = [.default(pageIndex: 2)]
        }) == .completed(replacedBands: 1, totalBars: 3, examinedBands: 1),
              "Names, labels, bar numbers, page breaks, and unrelated page corrections do not invalidate evidence")
        check(cosmetic.project.parts[0].name == "Clarinet" && cosmetic.band(withID:a)?.barNumberValue == 31,
              "Atomic application retains edits made while recognition was running")
        let manual = make()
        check(run(manual, bandIDs: [a,b], afterStart: { manual.updateBandRestReplacement(a, barCount: 19) })
                == .completed(replacedBands: 1, totalBars: 3, examinedBands: 2),
              "A manual rest choice made during recognition takes precedence")
        check(rest(manual,a)?.barCount == 19 && rest(manual,b)?.barCount == 3,
              "Concurrent manual choices are retained alongside newly recognized strips")

        let gate = DispatchSemaphore(value: 0), entered = DispatchSemaphore(value: 0)
        let cancelled = make()
        var cancelledResults: [RestAutoResult] = []
        let firstRun = cancelled.autoDetectRestReplacements(bandIDs: [a], recognizer: { _,crop,_,isCancelled in
            entered.signal()
            _ = gate.wait(timeout: .now() + 30)
            check(isCancelled(), "A running detector receives its cancellation signal")
            return found(crop)
        }) { cancelledResults.append($0) }!
        check(entered.wait(timeout: .now() + 30) == .success, "Cancellation test reaches active background recognition")
        check(!cancelled.cancelAutoDetectRestReplacements(runID: UUID()), "An unrelated cancellation token cannot stop a run")
        var secondResult: RestAutoResult?
        cancelled.autoDetectRestReplacements(bandIDs: [b], recognizer: recognize) { secondResult = $0 }
        check(cancelledResults == [.cancelled], "Starting a newer run cancels the old run once")
        check(!cancelled.cancelAutoDetectRestReplacements(runID: firstRun), "An old workflow cannot cancel the latest run")
        gate.signal()
        wait { secondResult != nil }
        check(secondResult == .completed(replacedBands: 1, totalBars: 3, examinedBands: 1)
              && rest(cancelled,a) == nil && rest(cancelled,b)?.barCount == 3,
              "Only the latest run may apply or publish its result")
        check(cancelledResults == [.cancelled] && cancelled.restAutoProgress == nil,
              "A late cancelled worker never calls completion twice or resurrects progress")

        var unreadableProject = project
        unreadableProject.bands[2].pageIndex = 99
        let unreadable = make(unreadableProject)
        check(run(unreadable, bandIDs: [a,c]) == .completed(replacedBands: 1, totalBars: 3, examinedBands: 2),
              "One unreadable page does not prevent safe results on another page")
        check(unreadable.restAutoStatus?.contains("1 source page could not be read") == true,
              "Unreadable source pages remain explicit in the final result")

        var correctedProject = project
        let correction = PageRectification.default(pageIndex: 0)
        correctedProject.pageRectifications = [correction]
        let corrected = make(correctedProject)
        let correctedImage = SourcePageRenderCache(pdfDocument: PDFDocument(data: source)!, rasterScale: 3)
            .rectifiedDisplayImage(for: 0, rectification: correction)
        check(correctedImage != nil, "The rectified raster is available; this test needs native macOS Core Image access")
        guard let expectedImage = correctedImage else { return }
        var receivedImage: CGImage?
        var reusedPageImage = true
        check(run(corrected, bandIDs: [a,b], recognizer: { image,crop,_,_ in
            if let previous = receivedImage { reusedPageImage = previous === image }
            receivedImage = image
            return found(crop)
        }) == .completed(replacedBands: 2, totalBars: 6, examinedBands: 2),
              "Corrected pages support the same automatic workflow")
        check(reusedPageImage, "Multiple crops from one page reuse its exact single rendered raster")
        check(receivedImage?.width == expectedImage.width && receivedImage?.height == expectedImage.height
              && (receivedImage?.dataProvider?.data as Data?) == (expectedImage.dataProvider?.data as Data?),
              "Recognition uses the corrected displayed pixels, never raw source coordinates")

        let blank = make()
        check(run(blank, bandIDs: [a], recognizer: nil) == .completed(replacedBands: 0, totalBars: 0, examinedBands: 1),
              "The actual production detector leaves a no-staff source crop unchanged")

        let realSource = try Data(contentsOf: URL(fileURLWithPath:
            "sample_scores/normal/02_orchestra/mozart_magic_flute_overture_kv620_score.pdf"))
        var realProject = ProjectData.empty
        realProject.parts = [project.parts[0]]
        realProject.parts[0].layoutSettings.usesSharedLayout = true
        realProject.pageCount = PDFDocument(data: realSource)!.pageCount
        realProject.bands = [(0.325,0.365),(0.513,0.553),(0.827,0.872)].map {
            BandModel(id: UUID(), pageIndex: 1, partID: p, topFraction: $0.0, bottomFraction: $0.1,
                leftFraction: 0, rightFraction: 0, excluded: false, createdAt: .now, barNumberMode: .manual)
        }
        let real = PartsmithDocument(project: realProject, sourcePDFData: realSource)
        let realUndo = UndoManager(); realUndo.groupsByEvent = false; real.undoManager = realUndo
        realUndo.beginUndoGrouping()
        check(run(real, recognizer: nil) == .completed(replacedBands: 2, totalBars: 16, examinedBands: 3),
              "Real Mozart trumpet/timpani eight-bar rests apply while the sounding contrabass entry stays original")
        realUndo.endUndoGrouping()
        check(real.project.bands.prefix(2).allSatisfy { $0.restReplacement?.sourceContext?.isValid(in: $0) == true },
              "Real detected source prefix, staff geometry, and double-bar fragments survive document validation")
        check(real.project.bands[2] == realProject.bands[2] && real.sourcePDFData == realSource,
              "Actual musical entries and original PDF bytes remain identical")
        let persisted = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(real.project))
        check(persisted == real.project, "Automatically counted rests and source fragments persist exactly")
        realUndo.undo()
        check(real.project == realProject && !realUndo.canUndo, "One Undo restores both real-score rest strips")

        // Exercise the real magic-wand order: deskew first, find fresh crops in
        // the corrected image, then recognize rests through the actual worker.
        // Reusing raw crop coordinates or injecting a successful recognizer
        // would miss real failures caused by corrected-image sampling.
        let trioSource = try Data(contentsOf: URL(fileURLWithPath:
            "sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf"))
        var trioProject = ProjectData.empty
        trioProject.pageCount = PDFDocument(data: trioSource)!.pageCount
        let correctedTrio = PartsmithDocument(project: trioProject, sourcePDFData: trioSource)
        correctedTrio.currentPageIndex = 2
        correctedTrio.autoEstimateCurrentPageRectification()
        check(correctedTrio.project.pageRectifications.map(\.pageIndex) == [2],
              "Native deskew estimates only the requested real Brahms page")
        let trioProfile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "clarinet", name: "Clarinet in A", staffCount: 1),
            ScorePartDefinition(id: "cello", name: "Cello", staffCount: 1),
            ScorePartDefinition(id: "piano", name: "Piano", staffCount: 2)
        ], cropMode: "compact")
        var correctedReview: ScoreDetectionReview?
        var correctedDetectionFinished = false
        correctedTrio.detectScore(profile: trioProfile, pageIndices: [2]) {
            correctedReview = $0; correctedDetectionFinished = true
        }
        wait { correctedDetectionFinished }
        check(correctedReview?.plan.canApply == true && correctedReview?.plan.bands.count == 12,
              "Fresh Auto finds all twelve instrument strips on the corrected page")
        check(correctedReview.flatMap { correctedTrio.addScoreParts(from: $0) } == 12,
              "Corrected crops apply without reusing or manually adjusting raw-source geometry")
        check(run(correctedTrio, recognizer: nil) == .completed(replacedBands: 0, totalBars: 0, examinedBands: 12),
              "Fresh corrected Auto retains original strips when its broad rest crop includes an unrelated page label")
        let correctedClarinet = correctedTrio.project.parts.first { $0.name == "Clarinet in A" }!
        let correctedFirstBand = correctedTrio.project.bands
            .filter { $0.partID == correctedClarinet.id }.min { $0.topFraction < $1.topFraction }!
        // Visual review of the corrected 1800x2544 raster confirms this edge
        // removes only the upper-right printed page label; the entire clef,
        // key signature, six rests, five staff lines and final bar remain.
        correctedTrio.updateBand(correctedFirstBand.id, topFraction: 0.072,
                                 bottomFraction: correctedFirstBand.bottomFraction)
        check(run(correctedTrio, recognizer: nil) == .completed(replacedBands: 1, totalBars: 6, examinedBands: 12),
              "The actual corrected-image worker recognizes six rests after a reviewed crop excludes the page label")
        let correctedMatches = correctedTrio.project.bands.filter { $0.restReplacement != nil }
        check(correctedMatches.count == 1 && correctedMatches[0].pageIndex == 2
              && correctedTrio.project.parts.first(where: { $0.id == correctedMatches[0].partID })?.name == "Clarinet in A"
              && correctedMatches[0].restReplacement?.sourceContext?.isValid(in: correctedMatches[0]) == true,
              "The corrected match belongs to the intended instrument and carries valid corrected source context")
        print("\(checks) automatic-rest workflow checks passed")
    }
}
