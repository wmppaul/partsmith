import Combine
import Foundation
import PDFKit

/// Only values used by this part's renderer participate in preview identity.
/// Selection changes, other parts, and save timestamps do not rebuild a PDF.
struct PartPreviewSnapshot: Equatable {
    let partID: UUID
    let project: ProjectData
    let sourcePDFData: Data

    init(partID: UUID, project: ProjectData, sourcePDFData: Data) {
        self.partID = partID
        self.sourcePDFData = sourcePDFData
        var snapshot = project
        snapshot.modifiedAt = snapshot.createdAt
        snapshot.parts = project.parts.filter { $0.id == partID }
        // Excluded bands remain ordering barriers for optional rest joining.
        snapshot.bands = project.bands.filter { $0.partID == partID }
        var pages = Set(snapshot.bands.map(\.pageIndex))
        if let header = snapshot.projectSettings.headerSelection { pages.insert(header.pageIndex) }
        snapshot.pageRectifications = project.pageRectifications.filter { pages.contains($0.pageIndex) }
        self.project = snapshot
    }
}

/// Main-thread observable state with a serial, worker-owned export pipeline.
/// Superseded renders are cancelled and can never replace the newest preview.
final class PartPreviewRenderer: ObservableObject {
    private struct PublishedPreview {
        let pdfDocument: PDFDocument
        let renderPlan: PartRenderPlan
        let snapshot: PartPreviewSnapshot
    }
    // One publication prevents a new PDF from being paired with old drag
    // geometry or a different source snapshot by an observation callback.
    @Published private var preview: PublishedPreview?
    var pdfDocument: PDFDocument? { preview?.pdfDocument }
    var renderPlan: PartRenderPlan? { preview?.renderPlan }
    var renderedSnapshot: PartPreviewSnapshot? { preview?.snapshot }
    @Published private(set) var isRendering = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var scaleInfo: PartRenderScaleInfo?
    private var requestedSnapshot: PartPreviewSnapshot?
    private var operation: BlockOperation?
    private var generation = UUID()
    // Used only on the serial worker queue. The exporter validates source
    // identity before reusing lightweight row bounds across slider commits.
    private let horizontalContentCache = SourceHorizontalContentCache()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func update(_ snapshot: PartPreviewSnapshot) {
        guard requestedSnapshot != snapshot else { return }
        operation?.cancel()
        queue.cancelAllOperations()
        if renderedSnapshot?.partID != snapshot.partID || renderedSnapshot?.sourcePDFData != snapshot.sourcePDFData {
            preview = nil
        }
        requestedSnapshot = snapshot
        errorMessage = nil
        scaleInfo = nil
        isRendering = true
        let token = UUID()
        generation = token
        let operation = BlockOperation()
        self.operation = operation
        let horizontalContentCache = self.horizontalContentCache
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            let result = Result { try autoreleasepool {
                try PartPDFExporter.renderResult(for: snapshot.partID, project: snapshot.project,
                    sourcePDFData: snapshot.sourcePDFData, horizontalContentCache: horizontalContentCache,
                    isCancelled: { operation.isCancelled })
            } }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == token, !operation.isCancelled else { return }
                self.operation = nil
                defer { self.isRendering = false }
                switch result {
                case .success(let result):
                    guard let pdf = PDFDocument(data: result.data) else {
                        self.errorMessage = "The preview PDF could not be generated."
                        return
                    }
                    self.scaleInfo = result.scaleInfo
                    self.preview = PublishedPreview(pdfDocument: pdf, renderPlan: result.renderPlan, snapshot: snapshot)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        queue.addOperation(operation)
    }

    func cancel(clearPreview: Bool = false) {
        operation?.cancel()
        queue.cancelAllOperations()
        operation = nil
        generation = UUID()
        requestedSnapshot = nil
        isRendering = false
        scaleInfo = nil
        if clearPreview {
            preview = nil
            errorMessage = nil
        }
    }

    deinit { queue.cancelAllOperations() }
}

/// Converts a drag on the rendered music strip to the corresponding source
/// edges. Output PDF coordinates increase upward; source fractions go downward.
enum PartPreviewCropGeometry {
    enum Edge { case top, bottom }
    struct CropEdges: Equatable {
        var topFraction: Double
        var bottomFraction: Double
    }

    static func cropEdges(for band: BandModel, placement: BandPlacement,
                          sourcePageBounds: CGRect, edge: Edge,
                          outputDeltaY: CGFloat) -> CropEdges? {
        func valid(_ rect: CGRect) -> Bool {
            [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
                && rect.size.width > 0 && rect.size.height > 0
                && rect.maxX.isFinite && rect.maxY.isFinite
        }
        guard band.id == placement.bandID, band.pageIndex == placement.sourcePageIndex,
              !band.excluded, band.generatedRest == nil, band.restReplacement == nil,
              placement.generatedRest == nil, placement.restReplacement == nil,
              placement.restSourcePlacement == nil,
              placement.sourceBandIDs.isEmpty || placement.sourceBandIDs == [band.id],
              [band.topFraction, band.bottomFraction, band.leftFraction, band.rightFraction].allSatisfy(\.isFinite),
              outputDeltaY.isFinite, valid(sourcePageBounds),
              valid(placement.sourceRect), valid(placement.destinationRect) else { return nil }
        let normalized = band.normalized()
        let expected = normalized.cropRect(in: sourcePageBounds)
        // A drag must use the same vertical crop as the published snapshot.
        // Horizontal whitespace trimming may legitimately differ from the band.
        guard abs(placement.sourceRect.minY - expected.minY) < 0.0001,
              abs(placement.sourceRect.height - expected.height) < 0.0001 else { return nil }
        let scale = placement.destinationRect.height / placement.sourceRect.height
        guard scale.isFinite, scale > 0 else { return nil }
        let fractionDelta = Double(outputDeltaY / scale / sourcePageBounds.height)
        guard fractionDelta.isFinite else { return nil }
        var result = CropEdges(topFraction: normalized.topFraction, bottomFraction: normalized.bottomFraction)
        // Preserve the opposite edge and the same 0.002 minimum used by
        // BandModel.normalized(), even when a handle crosses the other handle.
        switch edge {
        case .top:
            result.topFraction = max(0, min(result.bottomFraction - 0.002, result.topFraction - fractionDelta))
        case .bottom:
            result.bottomFraction = min(1, max(result.topFraction + 0.002, result.bottomFraction - fractionDelta))
        }
        return result
    }
}
