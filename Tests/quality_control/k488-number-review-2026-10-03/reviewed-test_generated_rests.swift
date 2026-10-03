import AppKit
import CryptoKit
import Foundation
import PDFKit

@main enum GeneratedRestTests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !value() { fatalError(message) }
    }
    static func wait(_ complete: () -> Bool) {
        let deadline = Date().addingTimeInterval(60)
        while !complete() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(complete(), "Native background operation completed")
    }
    static func edit(_ undo: UndoManager, _ body: () -> Void) {
        undo.beginUndoGrouping(); body(); undo.endUndoGrouping()
    }
    static func source(red: Bool) -> Data {
        let data = NSMutableData()
        var bounds = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &bounds, nil)!
        for _ in 0..<2 {
            context.beginPDFPage(nil)
            context.setFillColor((red ? NSColor.red : NSColor.blue).cgColor)
            context.fill(bounds)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
    static func pixels(_ data: Data) -> Data {
        let document = PDFDocument(data: data)!
        let page = document.page(at: 0)!
        let bounds = page.bounds(for: .mediaBox)
        let context = CGContext(data: nil, width: Int(bounds.width), height: Int(bounds.height),
            bitsPerComponent: 8, bytesPerRow: Int(bounds.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1, alpha: 1); context.fill(bounds)
        withExtendedLifetime(document) { page.draw(with: .mediaBox, to: context) }
        return Data(bytes: context.data!, count: Int(bounds.width * bounds.height) * 4)
    }
    static func main() throws {
        let sourceData = source(red: true)
        let profile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "flute", name: "Flute", staffCount: 1),
            ScorePartDefinition(id: "piano", name: "Piano", staffCount: 2)
        ], requiresSystemAssignment: true)
        let tops = [0.12, 0.35, 0.40, 0.62, 0.73, 0.79]
        let staves = tops.enumerated().map { index, top in
            ScoreObservedStaff(StaffBandCandidate(id: index,
                staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
                topFraction: top - 0.01, bottomFraction: top + 0.03, confidence: 1, warnings: []))
        }
        let page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1800, imageHeight: 2400, staves: staves, warnings: [])
        var correction: ScorePageOverride?
        for (system, ids, present, start, count) in [
            (0, [0], Set(["flute"]), 21, 1),
            (1, [1, 2], Set(["piano"]), 22, 7),
            (2, [3, 4, 5], Set(["flute", "piano"]), 29, 4)
        ] {
            correction = try ScoreSystemAssignment.assign(page: page, profile: profile, pagePlan: nil,
                existingOverride: correction, systemIndex: system, candidateIDs: ids,
                presentPartIDs: present, startBarNumber: start, barCount: count)
        }
        let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [correction!])
        var review = ScoreDetectionReview(profile: profile, analyses: [page], plan: plan,
            overrides: [correction!], selectedPageIndices: [0], sourcePDFData: sourceData, rectifications: [])
        check(plan.canApply && plan.bands.count == 6, "Every part has an item in each of three systems")
        check(plan.bands.allSatisfy { $0.startBarNumber == [21, 22, 29][$0.systemIndex]
            && $0.barCount == [1, 7, 4][$0.systemIndex] },
              "Entered system measures survive planning on music and inserted rests")
        let materialized = ScoreSystemAssignment.pageOverride(page: page, pagePlan: plan.pages.first, existingOverride: nil)
        check(materialized.systems.map(\.startBarNumber) == [21, 22, 29]
              && materialized.systems.map(\.barCount) == [1, 7, 4],
              "Crop review materialization keeps measure spans even when every instrument is printed")
        var unnumbered = correction!
        for i in unnumbered.systems.indices { unnumbered.systems[i].startBarNumber = nil }
        let unnumberedPlan = ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [unnumbered])
        check(unnumberedPlan.canApply && unnumberedPlan.bands.allSatisfy { $0.startBarNumber == nil },
              "Optional blank starting measures never invent bar numbers")
        let generatedPlan = plan.bands.filter { $0.generatedRest != nil }
        check(generatedPlan.count == 2 && generatedPlan.map { $0.generatedRest!.barCount } == [1, 7],
              "A silent piano grand staff counts one measure once, alongside a separate seven-bar flute rest")
        for band in generatedPlan {
            do { try review.setCropEdges(for: band.id, top: 1, bottom: 799); check(false, "Generated anchor must not become a crop") }
            catch { check(true, "Review crop editor rejects generated silence") }
            do { try review.resetCropEdges(for: band.id); check(false, "Generated anchor has no source crop to reset") }
            catch { check(true, "Review crop reset rejects generated silence") }
        }
        var initial = ProjectData.empty; initial.pageCount = 2
        let document = PartsmithDocument(project: initial, sourcePDFData: sourceData)
        let undo = UndoManager(); undo.groupsByEvent = false; document.undoManager = undo
        edit(undo) { check(document.addScoreParts(from: review) == 6, "Apply accepts all real crops and generated silences atomically") }
        let applied = document.project
        for (planned, stored) in zip(plan.bands, applied.bands) {
            check(stored.barNumberMode == .manual && stored.barNumberValue == planned.startBarNumber,
                  "Adding parts preserves the entered start number on every music and silence item")
        }
        let withoutNumbers = PartsmithDocument(sourcePDFData: sourceData)
        var unnumberedReview = review
        unnumberedReview.overrides = [unnumbered]; unnumberedReview.replan()
        check(withoutNumbers.addScoreParts(from: unnumberedReview) == 6
              && withoutNumbers.project.bands.allSatisfy { $0.barNumberMode == .hidden && $0.barNumberValue == nil },
              "A blank starting measure preserves existing hidden-number output")
        for margin in [48.0, 12.0, 0.0] {
            var numbered = applied
            numbered.projectSettings.margins.leading = margin
            numbered.projectSettings.margins.trailing = margin
            for part in numbered.parts {
                let layout = try PartLayoutEngine.makePlan(project: numbered,
                    pageBoundsProvider: { _ in CGRect(x: 0, y: 0, width: 600, height: 800) }, partID: part.id)
                for outputPage in layout.pages {
                    for placement in outputPage.placements where placement.generatedRest == nil {
                        guard let number = placement.barNumberRect else { fatalError("Missing safe measure label position") }
                        check(CGRect(origin: .zero, size: layout.pageSize).contains(number), "Measure labels stay on the paper at every margin")
                        check(outputPage.placements.allSatisfy { !$0.destinationRect.intersects(number)
                            && $0.sourceMarkings.allSatisfy { !$0.destinationRect.intersects(number) } },
                              "Measure labels cannot paint over any retained music or copied direction")
                        if let title = layout.titleBlockRect, outputPage.index == 0 {
                            check(!title.intersects(number), "Narrow-margin number rows remain below the title")
                        }
                    }
                }
            }
        }
        var shortCrops = applied
        let music = applied.bands.first { $0.generatedRest == nil }!
        shortCrops.bands = (1...20).map { index in
            var band = music
            band.id = UUID(); band.barNumberValue = index
            band.bottomFraction = band.topFraction + 0.001
            return band
        }
        shortCrops.parts = applied.parts.filter { $0.id == music.partID }
        shortCrops.parts[0].layoutSettings.interSystemGap = 4
        let shortLayout = try PartLayoutEngine.makePlan(project: shortCrops,
            pageBoundsProvider: { _ in CGRect(x: 0, y: 0, width: 600, height: 800) }, partID: music.partID)
        for page in shortLayout.pages {
            let numbers = page.placements.compactMap(\.barNumberRect)
            check(numbers.count == page.placements.count, "Short crops retain their numbers")
            for (i, rect) in numbers.enumerated() {
                check(!numbers.dropFirst(i + 1).contains { $0.intersects(rect) },
                      "Short crop numbers do not overlap subsequent numbers")
            }
        }
        let generated = applied.bands.filter { $0.generatedRest != nil }
        check(generated.count == 2 && generated.allSatisfy { $0.restReplacement == nil && $0.exclusions.isEmpty },
              "Generated silence persists separately from reversible source replacements")
        check(generated.map { $0.generatedRest!.sourceSystemIndex } == [0, 1]
              && generated.map { $0.generatedRest!.startBarNumber } == [21, 22],
              "Source system identity and starting measure survive application")
        check(document.savedScoreProfile == profile, "Variable-system setup persists with its profile")
        let stored = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(applied))
        check(stored == applied, "Generated rests and setup round trip exactly")
        let reopened = PartsmithDocument(project: stored, sourcePDFData: sourceData)
        check(reopened.savedScoreProfile?.requiresSystemAssignment == true, "Reopening retains explicit system-assignment mode")
        undo.undo(); check(document.project == initial, "One Undo removes all applied crops and silence items")
        undo.redo(); check(document.project == applied, "Redo restores generated silence without creating surrogate source music")

        let single = generated.first { $0.generatedRest?.barCount == 1 }!
        let seven = generated.first { $0.generatedRest?.barCount == 7 }!
        let untouched = document.band(withID: single.id)!
        undo.removeAllActions()
        for bad in [Int.min, -1, 0, 1000, Int.max] {
            check(!document.updateBandGeneratedRestCount(single.id, barCount: bad), "Invalid generated count rejected")
        }
        check(!document.updateBandRestReplacement(single.id, barCount: nil)
              && !document.updateBandRestReplacement(single.id, barCount: 9),
              "Generated silence cannot be restored to unrelated source music or reinterpreted as source replacement")
        document.updateBand(single.id, topFraction: 0, bottomFraction: 1)
        check(!document.expandBandCrop(single.id, by: 20), "Generated anchor cannot be expanded as a source crop")
        document.nudgeBandTop(single.id, delta: 0.02)
        document.nudgeBandBottom(single.id, delta: 0.02)
        document.updateBandExclusions(single.id, exclusions: [BandExclusion(topFraction: 0, bottomFraction: 1, leftFraction: 0, rightFraction: 0)])
        document.updateBandBarNumberMode(single.id, mode: .automatic)
        document.refreshBarNumber(for: single.id)
        check(document.band(withID: single.id) == untouched && !undo.canUndo,
              "Crop, whiteout, OCR and invalid rest requests preserve the generated item and undo history")
        edit(undo) { check(document.updateBandGeneratedRestCount(single.id, barCount: 5), "Dedicated generated count edit works") }
        check(document.band(withID: single.id)?.generatedRest?.endBarNumber == 25, "Generated duration updates its displayed final measure")
        undo.undo(); check(document.band(withID: single.id) == untouched, "Generated count is independently undoable")
        edit(undo) { document.updateBandBarNumberValue(single.id, value: 30) }
        check(document.band(withID: single.id)?.generatedRest?.startBarNumber == 30,
              "Manual start measure remains synchronized with generated provenance")
        undo.undo()
        let otherMusic = document.project.bands.first { $0.generatedRest == nil }!
        edit(undo) {
            document.updateBand(otherMusic.id, topFraction: otherMusic.topFraction - 0.001, bottomFraction: otherMusic.bottomFraction)
        }
        document.project.pageRectifications = [.default(pageIndex: 0)]
        document.sourcePDFData = source(red: false)
        check(document.band(withID: single.id)?.generatedRest == single.generatedRest
              && document.band(withID: seven.id)?.generatedRest == seven.generatedRest,
              "Unrelated crop edits, source correction and source replacement cannot reveal surrogate music")

        // Entirely different colored page contents must produce exactly the
        // same generated-only PDF pixels. This proves the anchor is never drawn.
        for band in generated {
            var isolated = applied
            isolated.bands = [band]
            isolated.projectSettings.showTitleBlock = false
            isolated.projectSettings.showPartNameInHeader = false
            isolated.projectSettings.margins.bottom = 0
            isolated.bands[0].barNumberMode = .hidden
            let a = try PartPDFExporter.pdfData(for: band.partID, project: isolated, sourcePDFData: sourceData)
            let b = try PartPDFExporter.pdfData(for: band.partID, project: isolated, sourcePDFData: source(red: false))
            check(pixels(a) == pixels(b), "Generated output contains no pixels from its colored source-system anchor")
            var sourceControl = isolated
            sourceControl.bands[0].generatedRest = nil
            let redControl = try PartPDFExporter.pdfData(for: band.partID, project: sourceControl, sourcePDFData: sourceData)
            let blueControl = try PartPDFExporter.pdfData(for: band.partID, project: sourceControl, sourcePDFData: source(red: false))
            check(pixels(redControl) != pixels(blueControl),
                  "The independent pixel comparison observes real source-color changes when a source crop is drawn")
            let layout = try PartLayoutEngine.makePlan(project: isolated,
                pageBoundsProvider: { _ in CGRect(x: 0, y: 0, width: 600, height: 800) }, partID: band.partID)
            let placement = layout.pages.flatMap(\.placements).first!
            check(placement.generatedRest == band.generatedRest && placement.restReplacement == nil
                  && placement.restSourcePlacement == nil && placement.restBarCount == band.generatedRest!.barCount,
                  "Layout retains dedicated generated provenance without source-context restoration")
            if band.generatedRest!.barCount == 1 {
                check(!(PDFDocument(data: a)?.string ?? "").contains("1"), "Single silent measure draws an ordinary whole-bar rest without a multibar numeral")
                let out = URL(fileURLWithPath: ".build/generated-rest-review")
                try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
                try a.write(to: out.appendingPathComponent("single-bar-generated.pdf"))
            }
        }
        for invalid in [BandGeneratedRest(barCount: 0, startBarNumber: 1, sourceSystemIndex: 0),
                        BandGeneratedRest(barCount: 3, startBarNumber: Int.max, sourceSystemIndex: 0),
                        BandGeneratedRest(barCount: 1, startBarNumber: 1, sourceSystemIndex: -1)] {
            var bad = applied; bad.bands = [single]; bad.bands[0].generatedRest = invalid
            do { _ = try PartPDFExporter.pdfData(for: single.partID, project: bad, sourcePDFData: sourceData)
                check(false, "Malformed generated silence must not draw its source anchor")
            } catch PartLayoutError.invalidGeneratedRest { check(true, "Malformed generated metadata blocks export") }
        }
        var automatic: RestAutoResult?
        let onlyGenerated = PartsmithDocument(project: applied, sourcePDFData: sourceData)
        onlyGenerated.project.bands = generated
        onlyGenerated.autoDetectRestReplacements(recognizer: { _,_,_,_ in fatalError("Generated anchor must never reach source rest recognition") }) { automatic = $0 }
        check(automatic == .completed(replacedBands: 0, totalBars: 0, examinedBands: 0), "Find Rests skips generated omissions")
        onlyGenerated.currentPageIndex = 0
        onlyGenerated.copyCurrentPageBandsToNextPage()
        check(onlyGenerated.project.bands == generated, "Copy Bands cannot invent the same silence on another source page")
        var copyProject = applied
        var confirmedDestination = single
        confirmedDestination.id = UUID(); confirmedDestination.pageIndex = 1
        copyProject.bands.append(confirmedDestination)
        let copier = PartsmithDocument(project: copyProject, sourcePDFData: sourceData)
        copier.currentPageIndex = 0
        copier.copyCurrentPageBandsToNextPage()
        check(copier.project.bands.filter { $0.pageIndex == 1 && $0.partID == single.partID } == [confirmedDestination],
              "Copying crop templates preserves a destination part's confirmed silence without adding unrelated source strips")
        try realMozart()
        print("\(checks) generated-rest workflow checks passed")
    }

    static func realMozart() throws {
        let source = try Data(contentsOf: URL(fileURLWithPath: "Tests/extraction/sources/mozart-k488-page-17.pdf"))
        check(SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
              == "9e7a091795bbc85fc8da0794afd791c8540ec3268a1e516204a08aa82244f121", "Reviewed Mozart excerpt bytes are unchanged")
        let names = ["Flute", "Clarinet", "Bassoon", "Horn", "Piano", "Violin I", "Violin II", "Viola", "Cello and Bass"]
        let profile = ScoreExtractionProfile(parts: names.map {
            ScorePartDefinition(id: $0, name: $0, staffCount: $0 == "Piano" ? 2 : 1)
        }, cropMode: "compact", requiresSystemAssignment: true)
        let document = PartsmithDocument(sourcePDFData: source); document.project.pageCount = 1
        var result: ScoreDetectionReview?; var completed = false
        document.detectScore(profile: profile) { result = $0; completed = true }
        wait { completed }
        var review = result!
        let analysis = review.analyses[0]
        check(analysis.staves.count == 18 && !review.plan.canApply, "Native Mozart analysis requires actual system identities rather than a false fixed cadence")
        var correction: ScorePageOverride?
        for (system, ids, present, start, count) in [
            (0, Array(0...5), Set(names.dropFirst(4)), 144, 6),
            (1, [6, 7], Set(["Piano"]), 150, 3),
            (2, Array(8...17), Set(names), 153, 4)
        ] {
            correction = try ScoreSystemAssignment.assign(page: analysis, profile: profile,
                pagePlan: review.plan.pages.first, existingOverride: correction, systemIndex: system,
                candidateIDs: ids, presentPartIDs: present, startBarNumber: start, barCount: count)
        }
        review.overrides = [correction!]; review.replan()
        check(review.plan.canApply && document.addScoreParts(from: review) == 27,
              "Real Mozart variable systems produce every part across all three systems")
        check(document.project.bands.allSatisfy { $0.barNumberMode == .manual }
              && document.project.parts.allSatisfy { part in
                  document.project.bands.filter { $0.partID == part.id }.map(\.barNumberValue) == [144, 150, 153]
              }, "All nine real Mozart parts keep reviewed starting measures, including all-piano music")
        let rests = document.project.bands.filter { $0.generatedRest != nil }
        check(rests.count == 12 && rests.filter { $0.generatedRest?.barCount == 6 }.count == 4
              && rests.filter { $0.generatedRest?.barCount == 3 }.count == 8,
              "Four omitted winds retain bars144–149; eight non-piano parts retain bars150–152")
        check(document.project.bands.filter { $0.partID == document.project.parts.first { $0.name == "Piano" }!.id }
            .allSatisfy { $0.generatedRest == nil }, "Printed piano music remains real source across all three systems")
        let reopened = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(document.project))
        check(reopened == document.project && document.sourcePDFData == source, "Real omission rests preserve editable project and original PDF bytes")
        document.project.projectSettings.defaultTitleText = "Mozart K. 488 — excerpt"
        document.project.projectSettings.defaultComposerText = "Source page 17 · Bars 144–156"
        let out = URL(fileURLWithPath: ".build/generated-rest-review/mozart-page17")
        try PartPDFExporter.exportAll(document: document, to: out)
        for part in document.project.parts {
            let layout = try PartLayoutEngine.makePlan(project: document.project,
                pageBoundsProvider: { document.pdfDocument?.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
            check(layout.pages.flatMap(\.placements).count == 3, "\(part.name) retains three systems in correct order")
            check(layout.pages.flatMap(\.placements).compactMap(\.generatedRest).map(\.sourceSystemIndex)
                  == (part.name == "Piano" ? [] : names.prefix(4).contains(part.name) ? [0, 1] : [1]),
                  "\(part.name) generated silence remains at its reviewed source system")
            let pdf = PDFDocument(url: out.appendingPathComponent(part.name.replacingOccurrences(of: "/", with: "-") + ".pdf"))
            check(["144", "150", "153"].allSatisfy { (pdf?.string ?? "").contains($0) },
                  "\(part.name) PDF contains every reviewed system start")
        }
        struct Envelope: Encodable { var project: ProjectData }
        let package = out.appendingPathComponent("Mozart K488 source page17 excerpt.partsmithproject")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Envelope(project: document.project)).write(to: package.appendingPathComponent("project.json"))
        try source.write(to: package.appendingPathComponent("source.pdf"))
    }
}
