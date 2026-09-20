import AppKit
import Foundation
import PDFKit

@main
enum RestDocumentTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }
    static func edit(_ undo: UndoManager, _ action: () throws -> Void) rethrows {
        undo.beginUndoGrouping()
        defer { undo.endUndoGrouping() }
        try action()
    }
    static func sourcePDF(mark: Double = 0) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &mediaBox, nil)!
        for page in 0..<3 {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 1, alpha: 1); context.fill(mediaBox)
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 100 + mark, y: 500 + Double(page), width: 120, height: 2))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
    static func main() throws {
        let source = sourcePDF()
        let firstPart = UUID(), secondPart = UUID()
        let a = UUID(), b = UUID(), c = UUID()
        var project = ProjectData.empty
        project.sourceFilename = "rest-model-fixture.pdf"
        project.pageCount = 3
        project.parts = [firstPart, secondPart].enumerated().map {
            PartModel(id: $0.element, name: "Part \($0.offset + 1)", color: ColorData(nsColor: .systemBlue),
                      layoutSettings: .default, createdAt: .now)
        }
        project.bands = [(a, 0, firstPart, 8), (b, 1, firstPart, 16), (c, 0, secondPart, 4)].map {
            BandModel(id: $0.0, pageIndex: $0.1, partID: $0.2, topFraction: 0.10, bottomFraction: 0.20,
                leftFraction: 0.05, rightFraction: 0.05, excluded: false, createdAt: .now,
                barNumberMode: .manual, barNumberValue: 7,
                restReplacement: BandRestReplacement(barCount: $0.3, joinWithPrevious: true))
        }
        func make() -> (PartsmithDocument, UndoManager) {
            let document = PartsmithDocument(project: project, sourcePDFData: source)
            let undo = UndoManager(); undo.groupsByEvent = false; document.undoManager = undo
            return (document, undo)
        }
        func band(_ document: PartsmithDocument, _ id: UUID = a) -> BandModel { document.band(withID: id)! }
        func rest(_ document: PartsmithDocument, _ id: UUID = a) -> BandRestReplacement? { band(document, id).restReplacement }

        let (document, undo) = make()
        check(rest(document)?.barCount == 8 && rest(document)?.joinWithPrevious == true,
              "Opening a project preserves saved replacement counts and explicit join choices")
        let originalBand = band(document)
        for invalid in [Int.min, -1, 0, 1, 1000, Int.max] {
            check(!document.updateBandRestReplacement(a, barCount: invalid), "Invalid count \(invalid) is rejected")
        }
        check(band(document) == originalBand && !undo.canUndo, "Invalid rest edits change neither source metadata nor undo history")
        check(!document.updateBandRestReplacement(UUID(), barCount: 8), "Unknown bands cannot receive replacements")
        check(document.updateBandRestReplacement(a, barCount: 8, joinWithPrevious: true), "Repeating a replacement is accepted")
        check(!undo.canUndo, "Repeating an unchanged replacement does not create an undo step")
        edit(undo) { document.updateBandRestReplacement(a, barCount: 2) }
        var expected = originalBand; expected.restReplacement = BandRestReplacement(barCount: 2)
        check(band(document) == expected && document.sourcePDFData == source, "Replacing changes only explicit rest output metadata")
        undo.undo()
        check(band(document) == originalBand, "One Undo restores count and join flag together")
        undo.redo()
        check(band(document) == expected, "Redo restores the complete replacement choice")
        edit(undo) { document.updateBandRestReplacement(a, barCount: 999, joinWithPrevious: true) }
        check(rest(document)?.barCount == 999 && rest(document)?.joinWithPrevious == true, "Maximum supported count retains explicit joining")
        edit(undo) { document.updateBandRestReplacement(a, barCount: nil) }
        check(rest(document) == nil && band(document).topFraction == originalBand.topFraction,
              "Restore Source Music removes the replacement without losing its original crop")
        undo.undo()
        check(rest(document)?.barCount == 999, "Restoring source music is itself undoable")

        let (cosmetic, cosmeticUndo) = make()
        edit(cosmeticUndo) {
            cosmetic.updatePartScale(firstPart, scale: 1.25)
            cosmetic.updatePartGap(firstPart, gap: 32)
            cosmetic.updatePartName(firstPart, name: "Clarinet")
            cosmetic.updatePartColor(firstPart, color: .systemRed)
            cosmetic.updatePartTitleText(firstPart, titleText: "Title")
            cosmetic.updatePartComposerText(firstPart, composerText: "Composer")
            cosmetic.updateHeaderSelection(pageIndex: 0, topFraction: 0, bottomFraction: 0.05, leftFraction: 0, rightFraction: 0)
            cosmetic.updateBandBarNumberValue(a, value: 12)
            cosmetic.updateBandEditorialLabel(a, label: "New movement")
            cosmetic.updateBandPageBreakBefore(a, pageBreakBefore: true)
            cosmetic.toggleBandExclusion(a, excluded: true)
        }
        check(cosmetic.project.bands.allSatisfy { $0.restReplacement != nil },
              "Scale, spacing, names, titles, header, bar numbers, labels, page breaks and visibility preserve replacements")

        let cropEdits: [(String, (PartsmithDocument) -> Void)] = [
            ("resize", { $0.updateBand(a, topFraction: 0.09, bottomFraction: 0.21) }),
            ("expand", { _ = $0.expandBandCrop(a, by: 6) }),
            ("top nudge", { $0.nudgeBandTop(a, delta: -0.01) }),
            ("bottom nudge", { $0.nudgeBandBottom(a, delta: 0.01) }),
            ("whiteout", { $0.updateBandExclusions(a, exclusions: [BandExclusion(topFraction: 0.12, bottomFraction: 0.14, leftFraction: 0.10, rightFraction: 0.70)]) }),
            ("shared score marking", { $0.updateBandSourceMarkings(a, markings: [BandSourceMarking(topFraction: 0.06, bottomFraction: 0.08, leftFraction: 0.10, rightFraction: 0.70)]) })
        ]
        for (name, action) in cropEdits {
            let (changed, changesUndo) = make()
            edit(changesUndo) { action(changed) }
            check(rest(changed) == nil && rest(changed, b) != nil && rest(changed, c) != nil,
                  "A \(name) clears only the affected source replacement")
            changesUndo.undo()
            check(changed.project.bands == project.bands, "Undoing a \(name) restores both the source and original rest choice")
            changesUndo.redo()
            check(rest(changed) == nil, "Redoing a \(name) clears the stale replacement again")
        }
        let (unchanged, unchangedUndo) = make()
        edit(unchangedUndo) { unchanged.updateBand(a, topFraction: 0.10, bottomFraction: 0.20) }
        check(rest(unchanged) != nil, "Unchanged crop coordinates do not discard a valid replacement")

        let (rectified, rectificationUndo) = make()
        edit(rectificationUndo) { rectified.updatePageRectification(.default(pageIndex: 0)) }
        check(rest(rectified) == nil && rest(rectified, c) == nil && rest(rectified, b) != nil,
              "Page alignment invalidates every affected part on that page, preserving other pages")
        rectificationUndo.undo()
        check(rectified.project.bands == project.bands, "Undoing rectification restores all previous replacement choices")
        rectificationUndo.redo()
        edit(rectificationUndo) { rectified.updateBandRestReplacement(a, barCount: 8) }
        edit(rectificationUndo) { rectified.updatePageRectification(.default(pageIndex: 0)) }
        check(rest(rectified) != nil, "Reapplying unchanged alignment preserves a new deliberate replacement")
        rectified.currentPageIndex = 0
        edit(rectificationUndo) { rectified.clearCurrentPageRectification() }
        check(rest(rectified) == nil, "Removing a page correction changes the crop source and invalidates its replacement")
        rectificationUndo.undo()
        check(rest(rectified)?.barCount == 8, "Undoing correction removal restores the replacement in its corrected geometry")

        let (copied, copyUndo) = make()
        copied.selectedPartID = firstPart; copied.currentPageIndex = 0
        edit(copyUndo) { copied.copySelectedPartBandsToNextPage() }
        let copies = copied.project.bands.filter { $0.partID == firstPart && $0.pageIndex == 1 }
        check(copies.count == 1 && copies[0].restReplacement == nil && rest(copied)?.barCount == 8,
              "Copied crops on another source page never inherit a rest count; originals remain intact")
        copyUndo.undo()
        check(copied.project.bands == project.bands, "Undoing a band copy restores the destination's original replacement")

        for property in ["top", "bottom", "left", "right", "page", "part"] {
            let (direct, _) = make()
            switch property {
            case "top": direct.project.bands[0].topFraction -= 0.01
            case "bottom": direct.project.bands[0].bottomFraction += 0.01
            case "left": direct.project.bands[0].leftFraction = 0
            case "right": direct.project.bands[0].rightFraction = 0
            case "page": direct.project.bands[0].pageIndex = 2
            default: direct.project.bands[0].partID = secondPart
            }
            check(rest(direct) == nil, "Direct \(property) changes also invalidate source-bound replacement metadata")
        }
        let (directAlignment, _) = make()
        directAlignment.project.pageRectifications = [.default(pageIndex: 0)]
        check(rest(directAlignment) == nil && rest(directAlignment, b) != nil,
              "Direct correction changes invalidate only their source page")
        let (changedSource, _) = make()
        changedSource.sourcePDFData = source
        check(changedSource.project.bands.allSatisfy { $0.restReplacement != nil }, "Unchanged source bytes preserve replacements")
        changedSource.sourcePDFData = sourcePDF(mark: 20)
        check(changedSource.project.bands.allSatisfy { $0.restReplacement == nil }, "Replacing source bytes invalidates all existing rest claims")

        let (imported, importUndo) = make()
        let importURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("partsmith-rest-import-\(UUID()).pdf")
        try sourcePDF(mark: 40).write(to: importURL)
        defer { try? FileManager.default.removeItem(at: importURL) }
        try edit(importUndo) { try imported.importSourcePDF(from: importURL) }
        check(imported.project.bands.isEmpty, "Importing another score leaves no prior source-rest claims")
        importUndo.undo()
        check(imported.project.bands == project.bands && imported.sourcePDFData == source,
              "Undoing a source import restores its exact original score and rest metadata together")
        print("\(checks) rest-document checks passed.")
    }
}
