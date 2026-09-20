// Native export regression. Compile with the Core Swift sources (excluding App/Features), then run.
// Optional argument: a generated .partsmithproject package to verify and re-export its masks too.
import AppKit
import Foundation
import PDFKit

@main
struct ExclusionRegressionTests {
    struct Envelope: Codable { var project: ProjectData }
    static var checks = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }

    static func sourcePDF() -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data as CFMutableData)!, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(box)
        context.setFillColor(NSColor.black.cgColor)
        // One intrusion to mask; three surrounding target marks must remain unchanged.
        for rect in [CGRect(x: 125, y: 530, width: 50, height: 60),
                     CGRect(x: 215, y: 530, width: 50, height: 60),
                     CGRect(x: 130, y: 610, width: 40, height: 20),
                     CGRect(x: 130, y: 490, width: 40, height: 20),
                     // A target mark just above the initial crop, recoverable by outward expansion.
                     CGRect(x: 300, y: 650, width: 40, height: 8)] {
            context.fill(rect)
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    static func raster(_ pdf: PDFDocument, pageIndex: Int = 0) -> NSBitmapImageRep {
        let page = pdf.page(at: pageIndex)!
        let bounds = page.bounds(for: .mediaBox)
        let context = CGContext(data: nil, width: Int(bounds.width * 2), height: Int(bounds.height * 2),
                                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width * 2, height: bounds.height * 2))
        context.scaleBy(x: 2, y: 2)
        context.drawPDFPage(page.pageRef!)
        return NSBitmapImageRep(cgImage: context.makeImage()!)
    }

    static func luma(_ bitmap: NSBitmapImageRep, point: CGPoint) -> Double {
        let x = min(bitmap.pixelsWide - 1, max(0, Int(point.x * 2)))
        let y = min(bitmap.pixelsHigh - 1, max(0, bitmap.pixelsHigh - 1 - Int(point.y * 2)))
        let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        return (color.redComponent + color.greenComponent + color.blueComponent) / 3
    }

    static func normalizedText(_ string: String) -> String {
        string.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func containsWordsInOrder(_ expected: String, in extracted: String) -> Bool {
        // PDFKit retains text outside source clips and interleaves it with new labels.
        // Require every label word in order without requiring those unrelated tokens to disappear.
        let words = normalizedText(expected).split(separator: " ")
        var cursor = 0
        for word in normalizedText(extracted).split(separator: " ") {
            if cursor < words.count, word == words[cursor] { cursor += 1 }
        }
        return cursor == words.count
    }

    static func assertMasksRender(_ document: PartsmithDocument, output: URL) throws {
        var originalProject = document.project
        for index in originalProject.bands.indices { originalProject.bands[index].exclusions = [] }
        let originalDocument = PartsmithDocument(project: originalProject, sourcePDFData: document.sourcePDFData)
        for part in document.project.parts where document.bandCount(for: part.id) > 0 {
            let plan = try PartLayoutEngine.makePlan(project: document.project,
                pageBoundsProvider: { document.pdfDocument?.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
            let pdf = try PartPDFExporter.previewDocument(for: part.id, in: document)
            let originalPDF = try PartPDFExporter.previewDocument(for: part.id, in: originalDocument)
            check(pdf.pageCount == plan.pages.count, "Native re-export page count agrees with layout")
            for page in plan.pages {
                let pageText = normalizedText(pdf.page(at: page.index)?.string ?? "")
                for placement in page.placements where !placement.editorialLabel.isEmpty {
                    check(containsWordsInOrder(placement.editorialLabel, in: pageText),
                          "Native PDF contains every word in order for editorial label '\(placement.editorialLabel)' on page \(page.index + 1)")
                }
                let bitmap = raster(pdf, pageIndex: page.index)
                let originalBitmap = raster(originalPDF, pageIndex: page.index)
                let masks = page.placements.flatMap(\.exclusionRects)
                for mask in masks {
                    // Check an interior 3x3 grid; any original ink surviving here reveals a failed transform/paint.
                    for x in [0.2, 0.5, 0.8] {
                        for y in [0.2, 0.5, 0.8] {
                            check(luma(bitmap, point: CGPoint(x: mask.minX + mask.width * x,
                                                             y: mask.minY + mask.height * y)) > 0.99,
                                  "Every exclusion must render white in native preview and re-export")
                        }
                    }
                }
                // All changes must remain in the reviewed masks (plus the documented edge bleed).
                // This compares every other pixel, including target clefs, slurs, chords and accidentals.
                let pixels = bitmap.bitmapData!, originals = originalBitmap.bitmapData!
                check(bitmap.bytesPerRow == originalBitmap.bytesPerRow && bitmap.samplesPerPixel == originalBitmap.samplesPerPixel,
                      "Reference and masked exports use the same raster format")
                var changedOutside = 0
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        let offset = y * bitmap.bytesPerRow + x * bitmap.samplesPerPixel
                        if (0..<3).contains(where: { abs(Int(pixels[offset + $0]) - Int(originals[offset + $0])) > 1 }) {
                            let point = CGPoint(x: (Double(x) + 0.5) / 2,
                                                y: (Double(bitmap.pixelsHigh - y) - 0.5) / 2)
                            if !masks.contains(where: { $0.insetBy(dx: -1, dy: -1).contains(point) }) {
                                changedOutside += 1
                            }
                        }
                    }
                }
                check(changedOutside == 0, "All notation outside mask regions remains pixel-identical to native unmasked export")
            }
            let filename = part.name.replacingOccurrences(of: "/", with: "-") + ".pdf"
            try PartPDFExporter.export(partID: part.id, document: document, to: output.appendingPathComponent(filename))
        }
    }

    static func main() throws {
        let output = URL(fileURLWithPath: "/tmp/partsmith-exclusion-tests")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var project = ProjectData.empty
        let part = PartModel(id: UUID(), name: "Mask regression", color: ColorData(red: 0, green: 0, blue: 1),
                             layoutSettings: .default, createdAt: .now)
        project.parts = [part]
        project.pageCount = 1
        project.projectSettings.showTitleBlock = false
        let band = BandModel(id: UUID(), pageIndex: 0, partID: part.id, topFraction: 0.2, bottomFraction: 0.4,
                             leftFraction: 0.1, rightFraction: 0.1, excluded: false, createdAt: .now, barNumberMode: .hidden)
        project.bands = [band]
        let source = sourcePDF()
        let document = PartsmithDocument(project: project, sourcePDFData: source)
        let undo = UndoManager()
        undo.groupsByEvent = false
        document.undoManager = undo
        let exclusion = BandExclusion(topFraction: 0.25, bottomFraction: 0.35, leftFraction: 0.2, rightFraction: 0.7)
        undo.beginUndoGrouping()
        document.updateBandExclusions(band.id, exclusions: [exclusion])
        undo.endUndoGrouping()
        check(document.band(withID: band.id)?.exclusions == [exclusion], "Mask edit applies")
        undo.undo()
        check(document.band(withID: band.id)?.exclusions.isEmpty == true, "Undo restores original engraving")
        undo.redo()
        check(document.band(withID: band.id)?.exclusions == [exclusion], "Redo restores exact mask geometry")
        check(document.sourcePDFData == source, "Mask edits leave embedded source immutable")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedData = try encoder.encode(Envelope(project: document.project))
        let reopened = try decoder.decode(Envelope.self, from: savedData).project
        let reopenedDocument = PartsmithDocument(project: reopened, sourcePDFData: source)
        check(reopened.bands[0].exclusions == [exclusion], "Project reopen retains masks")
        try assertMasksRender(reopenedDocument, output: output)

        let plan = try PartLayoutEngine.makePlan(project: reopened,
                                                pageBoundsProvider: { _ in CGRect(x: 0, y: 0, width: 600, height: 800) }, partID: part.id)
        let placement = plan.pages[0].placements[0]
        let scale = placement.destinationRect.width / placement.sourceRect.width
        func mapped(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: placement.destinationRect.minX + (x - placement.sourceRect.minX) * scale,
                    y: placement.destinationRect.minY + (y - placement.sourceRect.minY) * scale)
        }
        let bitmap = raster(try PartPDFExporter.previewDocument(for: part.id, in: reopenedDocument))
        check(luma(bitmap, point: mapped(150, 560)) > 0.99, "Intruding source mark is removed")
        for point in [mapped(240, 560), mapped(150, 620), mapped(150, 500)] {
            check(luma(bitmap, point: point) < 0.01, "Notation beside, above and below mask survives")
        }
        undo.undo()
        let restoredBitmap = raster(try PartPDFExporter.previewDocument(for: part.id, in: document))
        check(luma(restoredBitmap, point: mapped(150, 560)) < 0.01, "Undo restores source ink in actual PDF renderer")

        let contextDocument = PartsmithDocument(project: reopened, sourcePDFData: source)
        let contextUndo = UndoManager()
        contextUndo.groupsByEvent = false
        contextDocument.undoManager = contextUndo
        let beforeExpansion = contextDocument.project
        for invalidAmount in [0.0, -6, .infinity, .nan] {
            check(!contextDocument.expandBandCrop(band.id, by: invalidAmount), "Invalid expansion never shrinks or corrupts a crop")
        }
        check(contextDocument.project == beforeExpansion && !contextUndo.canUndo,
              "Rejected expansion leaves the project and undo history untouched")
        contextUndo.beginUndoGrouping()
        check(contextDocument.expandBandCrop(band.id, by: 20), "Context expansion succeeds")
        contextUndo.endUndoGrouping()
        let afterExpansion = contextDocument.project
        let expandedBand = contextDocument.band(withID: band.id)!
        let expandedPlan = try PartLayoutEngine.makePlan(project: afterExpansion,
            pageBoundsProvider: { _ in CGRect(x: 0, y: 0, width: 600, height: 800) }, partID: part.id)
        let expandedPlacement = expandedPlan.pages[0].placements[0]
        check(expandedPlacement.sourceRect.contains(placement.sourceRect), "Expansion retains every previously included source point")
        let expectedRect = placement.sourceRect.insetBy(dx: -20, dy: -20)
        check(abs(expandedPlacement.sourceRect.minX - expectedRect.minX) < 0.000001 &&
              abs(expandedPlacement.sourceRect.minY - expectedRect.minY) < 0.000001 &&
              abs(expandedPlacement.sourceRect.width - expectedRect.width) < 0.000001 &&
              abs(expandedPlacement.sourceRect.height - expectedRect.height) < 0.000001,
              "Expansion adds the requested source points on all four sides")
        check(expandedBand.exclusions == [exclusion] && expandedBand.exclusions.allSatisfy { $0.isValid(in: expandedBand) },
              "Existing whiteout coordinates remain exact and valid after expansion")
        check(contextDocument.sourcePDFData == source, "Expansion leaves embedded source immutable")
        let recoveredMark = CGPoint(x: 320, y: 654)
        check(!placement.sourceRect.contains(recoveredMark) && expandedPlacement.sourceRect.contains(recoveredMark),
              "Previously cropped target mark is now included")
        let expandedScale = expandedPlacement.destinationRect.width / expandedPlacement.sourceRect.width
        let recoveredDestination = CGPoint(
            x: expandedPlacement.destinationRect.minX + (recoveredMark.x - expandedPlacement.sourceRect.minX) * expandedScale,
            y: expandedPlacement.destinationRect.minY + (recoveredMark.y - expandedPlacement.sourceRect.minY) * expandedScale)
        let expandedBitmap = raster(try PartPDFExporter.previewDocument(for: part.id, in: contextDocument))
        check(luma(expandedBitmap, point: recoveredDestination) < 0.01, "Native export restores the target mark beyond the old crop")
        contextUndo.undo()
        check(contextDocument.project == beforeExpansion, "One undo restores all original crop edges")
        contextUndo.redo()
        check(contextDocument.project == afterExpansion, "Redo restores exact expanded geometry")
        let savedExpansion = try decoder.decode(Envelope.self,
            from: encoder.encode(Envelope(project: contextDocument.project))).project
        check(savedExpansion.bands == afterExpansion.bands, "Expanded geometry persists without a schema change")
        contextUndo.beginUndoGrouping()
        check(contextDocument.expandBandCrop(band.id, by: .greatestFiniteMagnitude), "Large expansion reaches page edges")
        contextUndo.endUndoGrouping()
        let fullPageBand = contextDocument.band(withID: band.id)!
        check(fullPageBand.topFraction == 0 && fullPageBand.bottomFraction == 1 &&
              fullPageBand.leftFraction == 0 && fullPageBand.rightFraction == 0,
              "Outward expansion clamps to all four source page edges")
        check(!contextDocument.expandBandCrop(band.id, by: 6), "Expansion at all page edges is a no-op")
        contextUndo.undo()
        check(contextDocument.project == afterExpansion, "No-op expansion adds no undo step")
        check(!contextDocument.expandBandCrop(UUID(), by: 6), "Missing band cannot be expanded")
        let sourceMissingDocument = PartsmithDocument(project: reopened, sourcePDFData: nil)
        check(!sourceMissingDocument.expandBandCrop(band.id, by: 6), "Missing source cannot guess point geometry")

        var labeledProject = project
        var secondBand = band
        secondBand.id = UUID()
        secondBand.topFraction = 0.5
        secondBand.bottomFraction = 0.7
        labeledProject.bands.append(secondBand)
        let labelDocument = PartsmithDocument(project: labeledProject, sourcePDFData: source)
        let labelUndo = UndoManager()
        labelUndo.groupsByEvent = false
        labelDocument.undoManager = labelUndo
        let longLabel = "Tempo primo. " + String(repeating: "Keep the full direction without clipping. ", count: 10) + "FINALWORD"
        labelUndo.beginUndoGrouping()
        labelDocument.updateBandEditorialLabel(band.id, label: longLabel)
        labelDocument.updateBandEditorialLabel(secondBand.id, label: "Source page 2 - Allegretto")
        labelDocument.updateBandPageBreakBefore(secondBand.id, pageBreakBefore: true)
        labelUndo.endUndoGrouping()
        labelUndo.undo()
        check(labelDocument.project.bands.allSatisfy { $0.editorialLabel.isEmpty && !$0.pageBreakBefore },
              "Undo restores editorial labels and page-break settings")
        labelUndo.redo()
        check(labelDocument.project.bands[0].editorialLabel == longLabel && labelDocument.project.bands[1].pageBreakBefore,
              "Redo restores exact label text and explicit page break")
        let reopenedLabels = try decoder.decode(Envelope.self, from: encoder.encode(Envelope(project: labelDocument.project))).project
        let labeledDoc = PartsmithDocument(project: reopenedLabels, sourcePDFData: source)
        let labeledPDF = try PartPDFExporter.previewDocument(for: part.id, in: labeledDoc)
        check(labeledPDF.pageCount == 2, "Saved explicit page break is honored by native PDF export")
        try assertMasksRender(labeledDoc, output: output)

        if CommandLine.arguments.count > 1 {
            let package = URL(fileURLWithPath: CommandLine.arguments[1])
            let imported = try decoder.decode(Envelope.self, from: Data(contentsOf: package.appendingPathComponent("project.json"))).project
            let importedSource = try Data(contentsOf: package.appendingPathComponent("source.pdf"))
            check(imported.bands.contains { !$0.exclusions.isEmpty }, "Imported skill project contains expected masks")
            let importedPlan = try PartLayoutEngine.makePlan(project: imported,
                pageBoundsProvider: { PDFDocument(data: importedSource)?.page(at: $0)?.bounds(for: .mediaBox) },
                partID: imported.parts[0].id)
            let firstBands = Set(importedPlan.pages.compactMap { $0.placements.first?.bandID })
            for importedBand in imported.bands where importedBand.pageBreakBefore {
                check(firstBands.contains(importedBand.id), "Every imported explicit break begins a native output page")
            }
            if imported.projectName == "Notte e giorno" {
                check(importedPlan.pages.map { $0.placements.count } == [5, 5, 5, 5],
                      "Reviewed Piano project retains its four source page divisions")
            }
            try assertMasksRender(PartsmithDocument(project: imported, sourcePDFData: importedSource), output: output)
        }
        print("PASS: \(checks) native crop and export checks, including persisted geometry, undo/redo and rasterized notation")
    }
}
