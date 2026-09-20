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
    @Published private(set) var pdfDocument: PDFDocument?
    @Published private(set) var isRendering = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var scaleInfo: PartRenderScaleInfo?
    private(set) var renderedSnapshot: PartPreviewSnapshot?
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
            pdfDocument = nil
            renderedSnapshot = nil
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
                self.isRendering = false
                switch result {
                case .success(let result):
                    guard let pdf = PDFDocument(data: result.data) else {
                        self.errorMessage = "The preview PDF could not be generated."
                        return
                    }
                    self.pdfDocument = pdf
                    self.scaleInfo = result.scaleInfo
                    self.renderedSnapshot = snapshot
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
            pdfDocument = nil
            renderedSnapshot = nil
            errorMessage = nil
        }
    }

    deinit { queue.cancelAllOperations() }
}
