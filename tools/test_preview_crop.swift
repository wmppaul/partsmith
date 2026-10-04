import AppKit
import Combine
import Foundation
import PDFKit

@main enum PreviewCropTests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        precondition(value(), message)
    }
    static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000001 }
    static func wait(_ condition: () -> Bool) {
        let until = Date().addingTimeInterval(30)
        while !condition() && Date() < until { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(condition(), "The asynchronous preview completes")
    }
    static func sourcePDF(_ bounds: CGRect) -> Data {
        var media = bounds
        let data = NSMutableData()
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor); context.fill(bounds)
        context.setFillColor(NSColor.black.cgColor)
        for y in stride(from: bounds.minY + 30, to: bounds.maxY - 30, by: 10) {
            context.fill(CGRect(x: bounds.minX + 80, y: y, width: bounds.width - 160, height: 1))
        }
        context.endPDFPage(); context.closePDF()
        return data as Data
    }
    static func main() throws {
        let bounds = CGRect(x: 40, y: -80, width: 600, height: 1000)
        var project = ProjectData.empty
        project.projectSettings.showTitleBlock = false
        project.projectSettings.showPartNameInHeader = false
        project.projectSettings.margins.bottom = 0
        var part = PartModel(id: UUID(), name: "Violin", color: ColorData(nsColor: .systemBlue), layoutSettings: .default, createdAt: .now)
        part.layoutSettings.balancePages = false
        project.parts = [part]; project.pageCount = 1
        let band = BandModel(id: UUID(), pageIndex: 0, partID: part.id, topFraction: 0.2, bottomFraction: 0.4,
                             leftFraction: 0.1, rightFraction: 0.1, excluded: false, createdAt: .now, barNumberMode: .hidden)
        project.bands = [band]
        let placement = BandPlacement(bandID: band.id, sourcePageIndex: 0, sourceRect: band.cropRect(in: bounds),
            destinationRect: CGRect(x: -30, y: 175, width: 500, height: 400), exclusionRects: [], editorialLabel: "", editorialLabelRect: nil)
        func edges(_ edge: PartPreviewCropGeometry.Edge, _ delta: CGFloat, _ b: BandModel = band,
                   _ p: BandPlacement? = nil, _ source: CGRect = bounds) -> PartPreviewCropGeometry.CropEdges? {
            PartPreviewCropGeometry.cropEdges(for: b, placement: p ?? placement, sourcePageBounds: source, edge: edge, outputDeltaY: delta)
        }
        let top = edges(.top, 40)!
        check(close(top.topFraction, 0.18) && top.bottomFraction == 0.4, "Upward top drag reveals source at actual2x vertical scale despite different horizontal scale")
        let bottom = edges(.bottom, 40)!
        check(bottom.topFraction == 0.2 && close(bottom.bottomFraction, 0.38), "Upward bottom drag removes source while preserving top")
        check(close(edges(.top, -40)!.topFraction, 0.22), "Downward top drag crops inward")
        check(close(edges(.bottom, -40)!.bottomFraction, 0.42), "Downward bottom drag reveals source")
        check(edges(.top, 10000)!.topFraction == 0, "Top clamps to source page start")
        check(edges(.bottom, -10000)!.bottomFraction == 1, "Bottom clamps to source page end")
        check(close(edges(.top, -10000)!.topFraction, 0.398) && edges(.top, -10000)!.bottomFraction == 0.4,
              "Crossing top preserves opposite edge and model minimum height")
        check(close(edges(.bottom, 10000)!.bottomFraction, 0.202) && edges(.bottom, 10000)!.topFraction == 0.2,
              "Crossing bottom preserves opposite edge and model minimum height")
        var shifted = placement
        shifted.sourceRect = shifted.sourceRect.offsetBy(dx: -40, dy: 80)
        shifted.destinationRect = shifted.destinationRect.offsetBy(dx: 200, dy: -300)
        check(edges(.top, 40, band, shifted, CGRect(x: 0, y: 0, width: 600, height: 1000)) == top,
              "Nonzero source and output PDF origins do not change a delta conversion")
        shifted = placement; shifted.destinationRect.size.height = 100
        check(close(edges(.top, 40, band, shifted)!.topFraction, 0.12), "Actual reduced placement scale is used")
        shifted = placement; shifted.sourceRect = shifted.sourceRect.insetBy(dx: 20, dy: 0)
        check(edges(.top, 40, band, shifted) == top, "Source-side horizontal whitespace trimming remains editable")
        var normalizedBand = band; normalizedBand.topFraction = -0.1
        shifted = placement; shifted.sourceRect = normalizedBand.cropRect(in: bounds)
        shifted.destinationRect.size.height = shifted.sourceRect.height * 2
        check(close(edges(.bottom, 40, normalizedBand, shifted)!.topFraction, 0), "Saved fractions use the model's normalization")
        check(edges(.top, .nan) == nil && edges(.top, .infinity) == nil, "Nonfinite drag distances are rejected")
        shifted = placement; shifted.destinationRect.size.height = 0
        check(edges(.top, 40, band, shifted) == nil, "Degenerate placement scale is rejected")
        shifted = placement; shifted.sourceRect.origin.y += 2
        check(edges(.top, 40, band, shifted) == nil, "A stale placement from another crop cannot commit")
        shifted = placement; shifted.bandID = UUID()
        check(edges(.top, 40, band, shifted) == nil, "Another band's placement cannot commit")
        var disabled = band; disabled.generatedRest = BandGeneratedRest(barCount: 4, startBarNumber: 1, sourceSystemIndex: 0)
        check(edges(.top, 40, disabled) == nil, "Generated silent rows have no editable source crop")
        disabled = band; disabled.restReplacement = BandRestReplacement(barCount: 4)
        check(edges(.top, 40, disabled) == nil, "Compressed replacements are not editable music strips")
        shifted = placement; shifted.restReplacement = BandRestReplacement(barCount: 4)
        check(edges(.top, 40, band, shifted) == nil, "A stale rendered rest cannot edit an ordinary band")
        shifted = placement; shifted.sourceBandIDs = [band.id, UUID()]
        check(edges(.top, 40, band, shifted) == nil, "A joined source row cannot be interpreted as one band's crop")
        disabled = band; disabled.topFraction = .nan
        check(edges(.top, 40, disabled) == nil, "Nonfinite model bounds are rejected before normalization")
        check(edges(.top, 40, band, nil, CGRect(x: 0, y: 0, width: 600, height: 0)) == nil,
              "Missing source page geometry is rejected")

        let source = sourcePDF(bounds)
        let result = try PartPDFExporter.renderResult(for: part.id, project: project, sourcePDFData: source)
        let pdf = PDFDocument(data: result.data)!
        check(result.renderPlan.pages.count == pdf.pageCount && result.renderPlan.part.id == part.id,
              "Exporter returns the plan for the actual PDF it drew")
        check(result.scaleInfo == result.renderPlan.scaleInfo, "Scale information comes from the same returned plan")
        let actual = result.renderPlan.pages.flatMap(\.placements)[0]
        let actualEdges = PartPreviewCropGeometry.cropEdges(for: band, placement: actual, sourcePageBounds: bounds,
            edge: .top, outputDeltaY: actual.destinationRect.height / actual.sourceRect.height * 10)!
        check(close(actualEdges.topFraction, 0.19), "Actual exported placement maps ten source points correctly")

        // Real document edits keep whiteout coordinates fixed in the source
        // and clip/drop them atomically when the music crop moves inward.
        let partial = BandExclusion(topFraction: 0.22, bottomFraction: 0.27, leftFraction: 0.2, rightFraction: 0.7)
        let inside = BandExclusion(topFraction: 0.29, bottomFraction: 0.31, leftFraction: 0.3, rightFraction: 0.5)
        let outside = BandExclusion(topFraction: 0.36, bottomFraction: 0.39, leftFraction: 0.2, rightFraction: 0.7)
        var whiteoutProject = project
        whiteoutProject.bands[0].exclusions = [partial, inside, outside]
        let document = PartsmithDocument(project: whiteoutProject, sourcePDFData: source)
        let undo = UndoManager(); undo.groupsByEvent = false; document.undoManager = undo
        let initialProject = document.project
        undo.beginUndoGrouping()
        document.updateBand(band.id, topFraction: 0.25, bottomFraction: 0.35)
        undo.endUndoGrouping()
        let resized = document.band(withID: band.id)!
        var clipped = partial; clipped.topFraction = 0.25
        check(resized.exclusions == [clipped, inside], "Resize clips a partial whiteout in place, keeps an interior one, and drops an exterior one")
        check(resized.exclusions.allSatisfy { $0.isValid(in: resized) }, "All retained whiteouts satisfy actual layout validation")
        check(resized.exclusions[0].id == partial.id && resized.exclusions[0].leftFraction == partial.leftFraction,
              "Clipping retains source identity and horizontal position")
        check(document.sourcePDFData == source, "Crop and whiteout edits do not change original PDF bytes")
        undo.undo()
        check(document.project == initialProject, "One Undo restores both crop and complete original whiteouts")
        undo.redo()
        check(document.band(withID: band.id) == resized, "One Redo restores the exact clipped state")
        let beforeInvalid = document.project
        document.updateBand(band.id, topFraction: .nan, bottomFraction: .infinity)
        check(document.project == beforeInvalid, "Nonfinite public crop edits cannot corrupt the saved document")
        struct Envelope: Codable { var project: ProjectData }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let folder = URL(fileURLWithPath: ".build/preview-crop-tests/resize.partsmithproject")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try encoder.encode(Envelope(project: document.project)).write(to: folder.appendingPathComponent("project.json"))
        try source.write(to: folder.appendingPathComponent("source.pdf"))
        let reopened = try decoder.decode(Envelope.self, from: Data(contentsOf: folder.appendingPathComponent("project.json"))).project
        check(reopened.bands[0].exclusions == [clipped, inside] && reopened.bands[0].topFraction == 0.25,
              "Saved project roundtrip retains clipped source coordinates and new crop")
        let savedSource = try Data(contentsOf: folder.appendingPathComponent("source.pdf"))
        check(savedSource == source, "Saved source is byte-identical")
        let exported = try PartPDFExporter.renderResult(for: part.id, project: reopened, sourcePDFData: savedSource)
        try exported.data.write(to: folder.deletingLastPathComponent().appendingPathComponent("resized.pdf"))
        let renderedStrip = exported.renderPlan.pages.flatMap(\.placements)[0]
        check(PDFDocument(data: exported.data)!.pageCount == exported.renderPlan.pages.count && renderedStrip.exclusionRects.count == 2,
              "Resized and reopened whiteouts export through the actual layout and PDF renderer")
        let maskRect = renderedStrip.exclusionRects[0]
        let printedScale = renderedStrip.destinationRect.height / renderedStrip.sourceRect.height
        let restoredMask = CGRect(x: renderedStrip.sourceRect.minX + (maskRect.minX - renderedStrip.destinationRect.minX) / printedScale,
            y: renderedStrip.sourceRect.minY + (maskRect.minY - renderedStrip.destinationRect.minY) / printedScale,
            width: maskRect.width / printedScale, height: maskRect.height / printedScale)
        check(close(restoredMask.minX, bounds.minX + 0.2 * bounds.width)
              && close(restoredMask.maxY, bounds.maxY - 0.25 * bounds.height)
              && close(restoredMask.minY, bounds.maxY - 0.27 * bounds.height),
              "Printed clipped whiteout maps back to the precise original source intersection")

        let renderer = PartPreviewRenderer()
        var observations = 0
        let observation = renderer.objectWillChange.sink {
            observations += 1
            if let visible = renderer.pdfDocument {
                guard let plan = renderer.renderPlan, let snapshot = renderer.renderedSnapshot else { preconditionFailure("Incomplete preview publication") }
                check(visible.pageCount == plan.pages.count && plan.part.id == snapshot.partID,
                      "Every synchronous observation has matching PDF, plan and snapshot")
                check(plan.part.layoutSettings == snapshot.project.parts[0].layoutSettings,
                      "Published plan retains the rendered layout settings")
                let byID = Dictionary(uniqueKeysWithValues: snapshot.project.bands.map { ($0.id, $0) })
                check(plan.pages.flatMap(\.placements).allSatisfy { p in
                    guard let b = byID[p.bandID] else { return false }
                    return close(p.sourceRect.minY, b.cropRect(in: bounds).minY) && close(p.sourceRect.height, b.cropRect(in: bounds).height)
                }, "Published source rectangles belong to the same snapshot")
            } else {
                check(renderer.renderPlan == nil && renderer.renderedSnapshot == nil, "An empty preview has no orphan geometry")
            }
        }
        let first = PartPreviewSnapshot(partID: part.id, project: project, sourcePDFData: source)
        renderer.update(first); wait { !renderer.isRendering }
        check(renderer.errorMessage == nil && renderer.renderedSnapshot == first && renderer.renderPlan != nil,
              "First preview publishes its exact render plan")
        let originalPDF = renderer.pdfDocument!
        var edited = project
        edited.parts[0].layoutSettings.scale = 1.4
        edited.bands[0].topFraction = 0.18
        let second = PartPreviewSnapshot(partID: part.id, project: edited, sourcePDFData: source)
        renderer.update(second)
        check(renderer.pdfDocument === originalPDF && renderer.renderedSnapshot == first,
              "Pending render keeps old PDF and old crop geometry together")
        edited.parts[0].layoutSettings.scale = 0.8
        edited.bands[0].bottomFraction = 0.45
        let latest = PartPreviewSnapshot(partID: part.id, project: edited, sourcePDFData: source)
        renderer.update(latest); wait { !renderer.isRendering }
        check(renderer.renderedSnapshot == latest && renderer.renderPlan!.part.layoutSettings.scale == 0.8,
              "Superseded render cannot publish stale crop geometry")
        let finalPDF = renderer.pdfDocument!
        renderer.update(first); renderer.cancel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        check(renderer.pdfDocument === finalPDF && renderer.renderedSnapshot == latest && renderer.renderPlan!.part.layoutSettings.scale == 0.8,
              "Cancelled refresh preserves the complete last publication")
        renderer.update(PartPreviewSnapshot(partID: part.id, project: project, sourcePDFData: Data("invalid".utf8)))
        check(renderer.pdfDocument == nil && renderer.renderPlan == nil && renderer.renderedSnapshot == nil,
              "Changing source clears PDF, plan and snapshot together")
        wait { !renderer.isRendering }
        check(renderer.errorMessage != nil && renderer.renderPlan == nil, "Failed source cannot publish a mismatched plan")
        renderer.cancel(clearPreview: true)
        check(renderer.pdfDocument == nil && renderer.renderPlan == nil && renderer.renderedSnapshot == nil,
              "Clear cancellation removes the entire publication")
        check(observations > 5, "Atomic publication was observed during actual asynchronous renders")
        withExtendedLifetime(observation) {}
        print("PASS: \(checks) preview crop geometry/publication checks")
    }
}
