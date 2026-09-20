import AppKit
import Foundation
import PDFKit

@main
enum PreviewPerformanceTests {
    struct Envelope: Decodable { var project: ProjectData }
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }
    static func waitFor(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(90)
        while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(condition(), "Preview background work completes within the real-score timeout")
    }
    static func pixels(_ page: PDFPage) -> Data {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width), height = Int(bounds.height)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.drawPDFPage(page.pageRef!)
        return Data(bytes: context.data!, count: width * height * 4)
    }

    static func main() throws {
        let path = CommandLine.arguments.dropFirst().first
            ?? "output/pdf/brahms-trio-medium/Brahms Clarinet Trio Op. 114.partsmithproject"
        let package = URL(fileURLWithPath: path)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var project = try decoder.decode(Envelope.self,
            from: Data(contentsOf: package.appendingPathComponent("project.json"))).project
        let source = try Data(contentsOf: package.appendingPathComponent("source.pdf"))
        let partID = project.parts[0].id
        let original = PartPreviewSnapshot(partID: partID, project: project, sourcePDFData: source)
        check(original.project.bands.count > 100, "Performance fixture contains a complete large part")
        var unrelated = project
        unrelated.modifiedAt = Date().addingTimeInterval(300)
        if unrelated.parts.count > 1 { unrelated.parts[1].layoutSettings.interSystemGap = 38 }
        check(PartPreviewSnapshot(partID: partID, project: unrelated, sourcePDFData: source) == original,
              "Save timestamps and another part's edits do not rebuild the selected part")

        let renderer = PartPreviewRenderer()
        let start = Date()
        renderer.update(original)
        let enqueueTime = Date().timeIntervalSince(start)
        check(enqueueTime < 0.25 && renderer.isRendering,
              "Starting a full-score preview returns promptly with background progress")
        // Supersede an in-flight render with changes to BOTH slow sliders.
        project.parts[0].layoutSettings.interSystemGap = 48
        project.parts[0].layoutSettings.scale = 1.4
        let intermediate = PartPreviewSnapshot(partID: partID, project: project, sourcePDFData: source)
        renderer.update(intermediate)
        project.parts[0].layoutSettings.interSystemGap = 10
        project.parts[0].layoutSettings.scale = 0.8
        let final = PartPreviewSnapshot(partID: partID, project: project, sourcePDFData: source)
        renderer.update(final)
        var mainQueueHeartbeat = false
        DispatchQueue.main.async { mainQueueHeartbeat = true }
        waitFor { mainQueueHeartbeat }
        check(renderer.isRendering || renderer.renderedSnapshot == final,
              "The main queue remains available while the final preview is rendered")
        waitFor { !renderer.isRendering }
        check(renderer.errorMessage == nil && renderer.renderedSnapshot == final,
              "Only the latest scale and gap snapshot becomes the visible preview")
        let preview = renderer.pdfDocument!
        let identity = ObjectIdentifier(preview)
        renderer.update(final)
        check(!renderer.isRendering && ObjectIdentifier(renderer.pdfDocument!) == identity,
              "An unchanged view update reuses its PDF instead of exporting it again")

        let document = PartsmithDocument(project: project, sourcePDFData: source)
        let exported = try PartPDFExporter.previewDocument(for: partID, in: document)
        check(preview.pageCount == exported.pageCount,
              "Background preview and ordinary export paginate the complete part identically")
        for index in Set([0, preview.pageCount / 2, preview.pageCount - 1]).sorted() {
            check(pixels(preview.page(at: index)!) == pixels(exported.page(at: index)!),
                  "Background and export pixels match on output page \(index + 1)")
        }

        // These counts are synthetic model fixtures, not musical assertions
        // about the source score. An excluded band remains a join boundary.
        var barrierProject = project
        barrierProject.parts = project.parts.filter { $0.id == partID }
        barrierProject.bands = Array(project.sortedBands(for: partID).prefix(3))
        check(barrierProject.bands.count == 3, "The join-boundary fixture has three source bands")
        for index in barrierProject.bands.indices {
            barrierProject.bands[index].excluded = index == 1
            barrierProject.bands[index].editorialLabel = ""
            barrierProject.bands[index].sourceMarkings = []
            barrierProject.bands[index].pageBreakBefore = false
            barrierProject.bands[index].barNumberValue = nil
            barrierProject.bands[index].restReplacement = nil
        }
        barrierProject.bands[0].restReplacement = BandRestReplacement(barCount: 4)
        barrierProject.bands[2].restReplacement = BandRestReplacement(barCount: 5, joinWithPrevious: true)
        let barrierSnapshot = PartPreviewSnapshot(partID: partID, project: barrierProject, sourcePDFData: source)
        check(barrierSnapshot.project.bands.count == 3 && barrierSnapshot.project.bands[1].excluded,
              "Preview identity retains excluded source bands that prevent joining rest strips")
        let sourcePDF = PDFDocument(data: source)!
        let exportBarrierPlan = try PartLayoutEngine.makePlan(project: barrierProject,
            pageBoundsProvider: { sourcePDF.page(at: $0)?.bounds(for: .mediaBox) }, partID: partID)
        let previewBarrierPlan = try PartLayoutEngine.makePlan(project: barrierSnapshot.project,
            pageBoundsProvider: { sourcePDF.page(at: $0)?.bounds(for: .mediaBox) }, partID: partID)
        let exportBarrierBands = exportBarrierPlan.pages.flatMap(\.placements)
        let previewBarrierBands = previewBarrierPlan.pages.flatMap(\.placements)
        check(exportBarrierBands.compactMap { $0.restReplacement?.barCount } == [4, 5]
              && previewBarrierBands.compactMap { $0.restReplacement?.barCount } == [4, 5],
              "Preview and export both retain separate four- and five-bar rests across an excluded band")
        check(previewBarrierBands.map(\.sourceBandIDs) == exportBarrierBands.map(\.sourceBandIDs),
              "Preview and export account for the same source bands across a rest-join boundary")
        let barrierData = try PartPDFExporter.pdfData(for: partID, project: barrierSnapshot.project, sourcePDFData: source)
        let barrierPreview = PDFDocument(data: barrierData)!
        let barrierDocument = PartsmithDocument(project: barrierProject, sourcePDFData: source)
        let barrierExport = try PartPDFExporter.previewDocument(for: partID, in: barrierDocument)
        check(barrierPreview.pageCount == barrierExport.pageCount
              && pixels(barrierPreview.page(at: 0)!) == pixels(barrierExport.page(at: 0)!),
              "The actual preview and export PDFs match for rests separated by an excluded source band")

        renderer.update(original)
        check(renderer.pdfDocument === preview && renderer.isRendering,
              "A layout refresh retains the last complete preview while new pages render")
        renderer.cancel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.10))
        check(!renderer.isRendering && renderer.renderedSnapshot == final && renderer.pdfDocument === preview,
              "Closing or superseding a preview cannot publish its cancelled render")

        do {
            _ = try PartPDFExporter.pdfData(for: partID, project: project, sourcePDFData: source, isCancelled: { true })
            fatalError("Cancelled snapshot export should stop")
        } catch is CancellationError { checks += 1 }
        let corrupt = PartPreviewSnapshot(partID: partID, project: project, sourcePDFData: Data("invalid PDF".utf8))
        renderer.update(corrupt)
        check(renderer.pdfDocument == nil, "A different source never shows an old-source preview")
        waitFor { !renderer.isRendering }
        check(renderer.errorMessage != nil, "A failed background source reports a preview error")
        renderer.cancel(clearPreview: true)
        check(renderer.pdfDocument == nil && renderer.renderedSnapshot == nil && renderer.errorMessage == nil,
              "Removing the selected source clears its old preview and error state")
        print("\(checks) preview checks passed; full-score enqueue \(String(format: "%.2f", enqueueTime * 1000)) ms, \(preview.pageCount) final pages.")
    }
}
