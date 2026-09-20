import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct SourceCanvasView: View {
    @ObservedObject var document: PartsmithDocument
    var onImportRequested: () -> Void
    var onImportDropped: (URL) -> Void
    var onNewPartRequested: () -> Void
    var onAutoExtractRequested: () -> Void

    @State private var isImportDropTargeted = false

    var body: some View {
        if let pdfDocument = document.pdfDocument {
            let rectifiedDisplayImage = document.sourceDisplayImageForCurrentPage()
            let sourceEditorDocument = document.sourceDisplayDocumentForCurrentPage() ?? pdfDocument
            let sourceEditorPageIndex = document.usesRectifiedDisplayForCurrentPage ? document.sourceDisplayPageIndex : document.currentPageIndex

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.sourceInstruction.title)
                            .font(.headline)
                        Text(document.sourceInstruction.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if document.isPickingInstrumentNames {
                            if document.isRecognizingInstrumentName {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("Reading the instrument name…")
                                }
                                .font(.subheadline)
                            } else if let message = document.instrumentNamePickMessage {
                                Text(message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else if let pick = document.instrumentNamePick {
                                Text("Recognized: \(pick.name). Click the next instrument name, or choose Done.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    if document.isPickingInstrumentNames {
                        Button("Done", action: document.cancelInstrumentNamePicking)
                    } else {
                        if document.project.bands.isEmpty && !document.isEditingHeaderSelection && !document.isEditingPageRectification {
                            Button("Auto Extract", systemImage: "wand.and.stars", action: onAutoExtractRequested)
                                .buttonStyle(.borderedProminent)
                                .disabled(document.isAutoEstimatingPageRectifications)
                        }
                        if document.selectedPartID == nil {
                            Button("New Part", systemImage: "plus") {
                                onNewPartRequested()
                            }
                        }
                    }
                }
                .padding(16)

                Divider()

                Group {
                    if document.isEditingPageRectification && !document.isPickingInstrumentNames {
                        PDFPageRectificationEditorRepresentable(
                            pdfDocument: pdfDocument,
                            pageIndex: document.currentPageIndex,
                            rectification: document.currentPageRectification,
                            zoomMode: document.zoomMode,
                            onUpdateRectification: { document.updatePageRectification($0) }
                        )
                        .id(document.rectificationEditorIdentity)
                    } else if document.usesRectifiedDisplayForCurrentPage,
                              let rectifiedDisplayImage,
                              let pageBounds = document.sourceDisplayPageBoundsForCurrentPage()
                    {
                        RectifiedBandEditorRepresentable(
                            image: rectifiedDisplayImage,
                            pageBounds: pageBounds,
                            pageIndex: document.currentPageIndex,
                            bands: document.bands(on: document.currentPageIndex),
                            headerSelection: document.headerSelectionOnCurrentPage,
                            isEditingHeaderSelection: document.isEditingHeaderSelection,
                            selectedPartID: document.selectedPartID,
                            selectedBandID: document.selectedBandID,
                            partColors: document.colorMap(),
                            zoomMode: document.zoomMode,
                            canCreateBands: document.selectedPartID != nil && document.isEditingHeaderSelection == false,
                            isPickingInstrumentNames: document.isPickingInstrumentNames,
                            instrumentNameHighlights: document.instrumentNameHighlights,
                            renderIdentity: document.bandEditorIdentity,
                            onPickInstrumentName: { point in
                                guard !document.isRecognizingInstrumentName else { return }
                                document.pickInstrumentName(at: point, pageIndex: document.currentPageIndex)
                            },
                            onSelectBand: document.selectBand(_:),
                            onCreateBand: { centerFraction in
                                guard let selectedPartID = document.selectedPartID else { return }
                                document.createBand(on: document.currentPageIndex, centerFraction: centerFraction, partID: selectedPartID)
                            },
                            onUpdateBand: { bandID, topFraction, bottomFraction in
                                document.updateBand(bandID, topFraction: topFraction, bottomFraction: bottomFraction)
                            },
                            onUpdateHeaderSelection: { _, topFraction, bottomFraction, leftFraction, rightFraction in
                                document.updateHeaderSelection(
                                    pageIndex: document.currentPageIndex,
                                    topFraction: topFraction,
                                    bottomFraction: bottomFraction,
                                    leftFraction: leftFraction,
                                    rightFraction: rightFraction
                                )
                            },
                            onFinishHeaderSelection: {
                                document.setHeaderSelectionEditing(false)
                            }
                        )
                        .id(document.bandEditorIdentity)
                    } else {
                        PDFBandEditorRepresentable(
                            pdfDocument: sourceEditorDocument,
                            pageIndex: sourceEditorPageIndex,
                            bands: document.bands(on: document.currentPageIndex),
                            headerSelection: document.headerSelectionOnCurrentPage,
                            isEditingHeaderSelection: document.isEditingHeaderSelection,
                            selectedPartID: document.selectedPartID,
                            selectedBandID: document.selectedBandID,
                            partColors: document.colorMap(),
                            zoomMode: document.zoomMode,
                            canCreateBands: document.selectedPartID != nil && document.isEditingHeaderSelection == false,
                            isPickingInstrumentNames: document.isPickingInstrumentNames,
                            instrumentNameHighlights: document.instrumentNameHighlights,
                            onPickInstrumentName: { point in
                                guard !document.isRecognizingInstrumentName else { return }
                                document.pickInstrumentName(at: point, pageIndex: document.currentPageIndex)
                            },
                            onSelectBand: document.selectBand(_:),
                            onCreateBand: { centerFraction in
                                guard let selectedPartID = document.selectedPartID else { return }
                                document.createBand(on: document.currentPageIndex, centerFraction: centerFraction, partID: selectedPartID)
                            },
                            onUpdateBand: { bandID, topFraction, bottomFraction in
                                document.updateBand(bandID, topFraction: topFraction, bottomFraction: bottomFraction)
                            },
                            onUpdateHeaderSelection: { _, topFraction, bottomFraction, leftFraction, rightFraction in
                                document.updateHeaderSelection(
                                    pageIndex: document.currentPageIndex,
                                    topFraction: topFraction,
                                    bottomFraction: bottomFraction,
                                    leftFraction: leftFraction,
                                    rightFraction: rightFraction
                                )
                            },
                            onFinishHeaderSelection: {
                                document.setHeaderSelectionEditing(false)
                            }
                        )
                        .id(document.bandEditorIdentity)
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        } else {
            VStack {
                VStack(spacing: 18) {
                    ContentUnavailableView {
                        Label("Import a Full Score PDF", systemImage: "doc.richtext")
                    } description: {
                        Text("Start by importing a PDF score. Partsmith will keep that source immutable and store your part geometry separately.")
                    } actions: {
                        Button("Import PDF", action: onImportRequested)
                    }

                    Text("You can also drag a PDF anywhere in this area from Finder.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(36)
                .frame(maxWidth: 560)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            Color.secondary.opacity(0.14),
                            lineWidth: 1
                        )
                }
                .scaleEffect(isImportDropTargeted ? 1.01 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isImportDropTargeted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(
                Group {
                    if isImportDropTargeted {
                        Color.accentColor.opacity(0.06)
                    } else {
                        Color(nsColor: .windowBackgroundColor)
                    }
                }
            )
            .overlay {
                if isImportDropTargeted {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, dash: [10, 8])
                        )
                        .padding(24)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: isImportDropTargeted)
            .onDrop(
                of: [UTType.fileURL.identifier],
                isTargeted: $isImportDropTargeted,
                perform: handleImportDrop(providers:)
            )
        }
    }

    private func handleImportDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let url = droppedFileURL(from: item) else { return }
            DispatchQueue.main.async {
                onImportDropped(url)
            }
        }

        return true
    }

    private func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let url = item as? NSURL {
            return url as URL
        }

        if let data = item as? Data {
            return NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL?
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }
}

private extension PartsmithDocument {
    var rectificationEditorIdentity: String {
        "rectify-\(currentPageIndex)-\(zoomMode.rawValue)"
    }

    var bandEditorIdentity: String {
        let rectificationKey: String
        if usesRectifiedDisplayForCurrentPage {
            rectificationKey = currentPageRectification?.renderIdentity ?? "none"
        } else {
            rectificationKey = "raw"
        }

        return "bands-\(currentPageIndex)-\(zoomMode.rawValue)-\(rectificationKey)-header-\(isEditingHeaderSelection)"
    }

    var sourceInstruction: (title: String, body: String) {
        if isPickingInstrumentNames {
            return (
                title: "Pick instrument names",
                body: "Click instrument names from top to bottom. Return to Auto Extract to review the setup."
            )
        }

        if isEditingPageRectification {
            return (
                title: "Rectifying page \(currentPageIndex + 1)",
                body: "Drag the four orange corner handles onto the staff field you want to square up. Saving keeps the same page size and switches band editing to the rectified page."
            )
        }

        if isEditingHeaderSelection {
            return (
                title: "Selecting a shared source header",
                body: "Drag a rectangle over the engraved score header, or adjust its corner handles. Click Save in the inspector, or just click elsewhere to finish."
            )
        }

        if project.bands.isEmpty {
            return (
                title: "Start with Auto Extract",
                body: "Use the magic wand to straighten scans if needed, set the instrument order, and extract parts throughout the score."
            )
        }

        if let part = selectedPart {
            return (
                title: "Creating bands for \(part.name)",
                body: "Click inside the page to create a horizontal crop band. Drag the visible top and bottom handles to refine it, or drag inside a band to move it."
            )
        }

        if project.parts.isEmpty {
            return (
                title: "Create a part to begin",
                body: "Bands belong to a part. Click New Part first, then click inside the page to place crop bands."
            )
        }

        return (
            title: "Select a part before creating bands",
            body: "Choose a part in the sidebar, then click inside the page to create a horizontal crop band."
        )
    }
}

private extension PageRectification {
    var renderIdentity: String {
        [
            pageIndex.description,
            String(format: "%.5f", topLeft.x),
            String(format: "%.5f", topLeft.y),
            String(format: "%.5f", topRight.x),
            String(format: "%.5f", topRight.y),
            String(format: "%.5f", bottomRight.x),
            String(format: "%.5f", bottomRight.y),
            String(format: "%.5f", bottomLeft.x),
            String(format: "%.5f", bottomLeft.y)
        ].joined(separator: "-")
    }
}

struct PDFBandEditorRepresentable: NSViewRepresentable {
    var pdfDocument: PDFDocument
    var pageIndex: Int
    var bands: [BandModel]
    var headerSelection: SourceHeaderSelection?
    var isEditingHeaderSelection: Bool
    var selectedPartID: UUID?
    var selectedBandID: UUID?
    var partColors: [UUID: NSColor]
    var zoomMode: ZoomMode
    var canCreateBands: Bool
    var isPickingInstrumentNames: Bool
    var instrumentNameHighlights: [ScoreInstrumentNamePick]
    var onPickInstrumentName: (CGPoint) -> Void
    var onSelectBand: (UUID?) -> Void
    var onCreateBand: (Double) -> Void
    var onUpdateBand: (UUID, Double, Double) -> Void
    var onUpdateHeaderSelection: (Int, Double, Double, Double, Double) -> Void
    var onFinishHeaderSelection: () -> Void

    func makeNSView(context: Context) -> PDFBandEditorContainerView {
        PDFBandEditorContainerView()
    }

    func updateNSView(_ nsView: PDFBandEditorContainerView, context: Context) {
        nsView.update(
            pdfDocument: pdfDocument,
            pageIndex: pageIndex,
            bands: bands,
            headerSelection: headerSelection,
            isEditingHeaderSelection: isEditingHeaderSelection,
            selectedPartID: selectedPartID,
            selectedBandID: selectedBandID,
            partColors: partColors,
            zoomMode: zoomMode,
            canCreateBands: canCreateBands,
            isPickingInstrumentNames: isPickingInstrumentNames,
            instrumentNameHighlights: instrumentNameHighlights,
            onPickInstrumentName: onPickInstrumentName,
            onSelectBand: onSelectBand,
            onCreateBand: onCreateBand,
            onUpdateBand: onUpdateBand,
            onUpdateHeaderSelection: onUpdateHeaderSelection,
            onFinishHeaderSelection: onFinishHeaderSelection
        )
    }
}

struct RectifiedBandEditorRepresentable: NSViewRepresentable {
    var image: CGImage
    var pageBounds: CGRect
    var pageIndex: Int
    var bands: [BandModel]
    var headerSelection: SourceHeaderSelection?
    var isEditingHeaderSelection: Bool
    var selectedPartID: UUID?
    var selectedBandID: UUID?
    var partColors: [UUID: NSColor]
    var zoomMode: ZoomMode
    var canCreateBands: Bool
    var isPickingInstrumentNames: Bool
    var instrumentNameHighlights: [ScoreInstrumentNamePick]
    var renderIdentity: String
    var onPickInstrumentName: (CGPoint) -> Void
    var onSelectBand: (UUID?) -> Void
    var onCreateBand: (Double) -> Void
    var onUpdateBand: (UUID, Double, Double) -> Void
    var onUpdateHeaderSelection: (Int, Double, Double, Double, Double) -> Void
    var onFinishHeaderSelection: () -> Void

    func makeNSView(context: Context) -> RectifiedBandEditorContainerView {
        RectifiedBandEditorContainerView()
    }

    func updateNSView(_ nsView: RectifiedBandEditorContainerView, context: Context) {
        nsView.update(
            image: image,
            pageBounds: pageBounds,
            pageIndex: pageIndex,
            bands: bands,
            headerSelection: headerSelection,
            isEditingHeaderSelection: isEditingHeaderSelection,
            selectedPartID: selectedPartID,
            selectedBandID: selectedBandID,
            partColors: partColors,
            zoomMode: zoomMode,
            canCreateBands: canCreateBands,
            isPickingInstrumentNames: isPickingInstrumentNames,
            instrumentNameHighlights: instrumentNameHighlights,
            renderIdentity: renderIdentity,
            onPickInstrumentName: onPickInstrumentName,
            onSelectBand: onSelectBand,
            onCreateBand: onCreateBand,
            onUpdateBand: onUpdateBand,
            onUpdateHeaderSelection: onUpdateHeaderSelection,
            onFinishHeaderSelection: onFinishHeaderSelection
        )
    }
}

struct PDFPageRectificationEditorRepresentable: NSViewRepresentable {
    var pdfDocument: PDFDocument
    var pageIndex: Int
    var rectification: PageRectification?
    var zoomMode: ZoomMode
    var onUpdateRectification: (PageRectification) -> Void

    func makeNSView(context: Context) -> PDFPageRectificationEditorContainerView {
        PDFPageRectificationEditorContainerView()
    }

    func updateNSView(_ nsView: PDFPageRectificationEditorContainerView, context: Context) {
        nsView.update(
            pdfDocument: pdfDocument,
            pageIndex: pageIndex,
            rectification: rectification,
            zoomMode: zoomMode,
            onUpdateRectification: onUpdateRectification
        )
    }
}

final class RectifiedBandEditorContainerView: NSView {
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private let imageView = NSImageView()
    private let overlayView = BandOverlayView()

    private var currentZoomMode: ZoomMode = .fitWidth
    private var currentRenderIdentity: String?
    private var currentPageBounds: CGRect = .zero
    private var lastAppliedViewportSize: CGSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = documentView

        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleAxesIndependently

        overlayView.viewportClipView = scrollView.contentView

        documentView.addSubview(imageView)
        documentView.addSubview(overlayView)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let viewportSize = bounds.size
        guard viewportSize != .zero else { return }

        if lastAppliedViewportSize != viewportSize {
            lastAppliedViewportSize = viewportSize
            applyZoomMode(resetToTop: false)
        } else {
            overlayView.needsDisplay = true
        }
    }

    func update(
        image: CGImage,
        pageBounds: CGRect,
        pageIndex: Int,
        bands: [BandModel],
        headerSelection: SourceHeaderSelection?,
        isEditingHeaderSelection: Bool,
        selectedPartID: UUID?,
        selectedBandID: UUID?,
        partColors: [UUID: NSColor],
        zoomMode: ZoomMode,
        canCreateBands: Bool,
        isPickingInstrumentNames: Bool,
        instrumentNameHighlights: [ScoreInstrumentNamePick],
        renderIdentity: String,
        onPickInstrumentName: @escaping (CGPoint) -> Void,
        onSelectBand: @escaping (UUID?) -> Void,
        onCreateBand: @escaping (Double) -> Void,
        onUpdateBand: @escaping (UUID, Double, Double) -> Void,
        onUpdateHeaderSelection: @escaping (Int, Double, Double, Double, Double) -> Void,
        onFinishHeaderSelection: @escaping () -> Void
    ) {
        let renderChanged = currentRenderIdentity != renderIdentity
        let zoomModeChanged = currentZoomMode != zoomMode
        let preservedViewportOrigin = (renderChanged == false && zoomModeChanged == false) ? currentViewportOrigin() : nil

        if renderChanged {
            currentRenderIdentity = renderIdentity
            currentPageBounds = pageBounds
            imageView.image = NSImage(
                cgImage: image,
                size: NSSize(width: pageBounds.width, height: pageBounds.height)
            )
        }

        currentZoomMode = zoomMode

        if renderChanged || zoomModeChanged {
            applyZoomMode(resetToTop: renderChanged && preservedViewportOrigin == nil)
        } else {
            overlayView.fixedPageFrame = imageView.frame
            restoreViewportOrigin(preservedViewportOrigin)
        }

        overlayView.update(
            pageIndex: pageIndex,
            page: nil,
            bands: bands,
            headerSelection: headerSelection,
            isEditingHeaderSelection: isEditingHeaderSelection,
            selectedPartID: selectedPartID,
            selectedBandID: selectedBandID,
            partColors: partColors,
            canCreateBands: canCreateBands,
            isPickingInstrumentNames: isPickingInstrumentNames,
            instrumentNameHighlights: instrumentNameHighlights,
            onPickInstrumentName: onPickInstrumentName,
            onSelectBand: onSelectBand,
            onCreateBand: onCreateBand,
            onUpdateBand: onUpdateBand,
            onUpdateHeaderSelection: onUpdateHeaderSelection,
            onFinishHeaderSelection: onFinishHeaderSelection
        )

        if renderChanged == false && zoomModeChanged == false {
            restoreViewportOrigin(preservedViewportOrigin)
        }
    }

    private func applyZoomMode(resetToTop: Bool) {
        guard currentPageBounds.width > 0, currentPageBounds.height > 0 else { return }

        let horizontalInset: CGFloat = 48
        let verticalInset: CGFloat = 24
        let viewportWidth = max(200, bounds.width)
        let viewportHeight = max(200, bounds.height)

        let scale: CGFloat
        switch currentZoomMode {
        case .fitWidth:
            scale = max(0.01, (viewportWidth - horizontalInset) / currentPageBounds.width)
        case .fitPage:
            let widthScale = max(0.01, (viewportWidth - horizontalInset) / currentPageBounds.width)
            let heightScale = max(0.01, (viewportHeight - verticalInset * 2) / currentPageBounds.height)
            scale = min(widthScale, heightScale)
        }

        let displaySize = CGSize(
            width: currentPageBounds.width * scale,
            height: currentPageBounds.height * scale
        )
        let contentSize = CGSize(
            width: max(viewportWidth, displaySize.width + horizontalInset),
            height: max(viewportHeight, displaySize.height + verticalInset * 2)
        )

        documentView.frame = CGRect(origin: .zero, size: contentSize)
        let imageFrame = CGRect(
            x: (contentSize.width - displaySize.width) / 2,
            y: contentSize.height - displaySize.height - verticalInset,
            width: displaySize.width,
            height: displaySize.height
        )
        imageView.frame = imageFrame
        overlayView.frame = documentView.bounds
        overlayView.fixedPageFrame = imageFrame

        documentView.needsLayout = true
        documentView.layoutSubtreeIfNeeded()
        documentView.needsDisplay = true
        imageView.needsDisplay = true
        overlayView.needsDisplay = true
        scrollView.needsDisplay = true
        scrollView.displayIfNeeded()

        if resetToTop {
            scrollToTop()
        }
    }

    private func scrollToTop() {
        let clipView = scrollView.contentView
        let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
        let origin = CGPoint(x: 0, y: maxY)
        clipView.scroll(to: origin)
        scrollView.reflectScrolledClipView(clipView)
        overlayView.needsDisplay = true
    }

    private func currentViewportOrigin() -> CGPoint? {
        scrollView.contentView.bounds.origin
    }

    private func restoreViewportOrigin(_ origin: CGPoint?) {
        guard let origin else { return }
        let clipView = scrollView.contentView
        let maxX = max(0, documentView.bounds.width - clipView.bounds.width)
        let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
        let clampedOrigin = CGPoint(
            x: min(max(0, origin.x), maxX),
            y: min(max(0, origin.y), maxY)
        )
        clipView.scroll(to: clampedOrigin)
        scrollView.reflectScrolledClipView(clipView)
        overlayView.needsDisplay = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let clipView = self.scrollView.contentView
            clipView.scroll(to: clampedOrigin)
            self.scrollView.reflectScrolledClipView(clipView)
            self.overlayView.needsDisplay = true
        }
    }
}

final class PDFPageRectificationEditorContainerView: NSView {
    private let pdfView = PDFView()
    private let overlayView = PageRectificationOverlayView()

    private var currentZoomMode: ZoomMode = .fitWidth
    private var displayedPageIndex: Int?
    private var refreshGeneration: Int = 0
    private var lastAppliedViewportSize: CGSize = .zero
    private var overlayRedrawObservers: [NSObjectProtocol] = []
    private weak var observedClipView: NSClipView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = false
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 8.0

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.pdfView = pdfView

        addSubview(pdfView)
        addSubview(overlayView)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        tearDownOverlayObservers()
    }

    override func layout() {
        super.layout()
        let viewportSize = bounds.size
        guard viewportSize != .zero else { return }

        if lastAppliedViewportSize != viewportSize {
            lastAppliedViewportSize = viewportSize
            applyZoomMode()
            if let displayedPageIndex {
                refreshGeneration &+= 1
                refreshPDFView(pageIndex: displayedPageIndex, generation: refreshGeneration)
            } else {
                overlayView.needsDisplay = true
            }
        } else {
            overlayView.needsDisplay = true
        }
    }

    func update(
        pdfDocument: PDFDocument,
        pageIndex: Int,
        rectification: PageRectification?,
        zoomMode: ZoomMode,
        onUpdateRectification: @escaping (PageRectification) -> Void
    ) {
        let documentChanged = pdfView.document !== pdfDocument
        if documentChanged {
            pdfView.document = pdfDocument
            displayedPageIndex = nil
            lastAppliedViewportSize = .zero
            configureOverlayObservers()
        }

        let pageChanged = displayedPageIndex != pageIndex
        if pageChanged, let page = pdfDocument.page(at: pageIndex) {
            pdfView.go(to: page)
            displayedPageIndex = pageIndex
        }

        let zoomModeChanged = currentZoomMode != zoomMode
        currentZoomMode = zoomMode

        overlayView.update(
            pageIndex: pageIndex,
            page: pdfDocument.page(at: pageIndex),
            rectification: rectification,
            onUpdateRectification: onUpdateRectification
        )

        if documentChanged || pageChanged || zoomModeChanged {
            guard bounds.size != .zero else {
                overlayView.needsDisplay = true
                return
            }

            refreshGeneration &+= 1
            applyZoomMode()
            refreshPDFView(pageIndex: pageIndex, generation: refreshGeneration)
        } else {
            overlayView.needsDisplay = true
        }
    }

    private func applyZoomMode() {
        guard let page = pdfView.currentPage else { return }
        switch currentZoomMode {
        case .fitWidth:
            pdfView.autoScales = false
            let pageBounds = page.bounds(for: .mediaBox)
            let horizontalInset: CGFloat = 48
            let width = max(200, pdfView.bounds.width - horizontalInset)
            let scale = width / pageBounds.width
            pdfView.scaleFactor = min(pdfView.maxScaleFactor, max(pdfView.minScaleFactor, scale))
        case .fitPage:
            pdfView.autoScales = true
        }

        overlayView.needsDisplay = true
    }

    private func refreshPDFView(pageIndex: Int, generation: Int) {
        guard generation == refreshGeneration else { return }
        let targetPage = pdfView.document?.page(at: pageIndex) ?? pdfView.currentPage
        pdfView.layoutDocumentView()
        pdfView.documentView?.needsLayout = true
        pdfView.documentView?.layoutSubtreeIfNeeded()
        pdfView.documentView?.needsDisplay = true
        pdfView.needsDisplay = true
        pdfView.displayIfNeeded()
        if let targetPage {
            pdfView.go(to: targetPage)
        }
        let targetOrigin = pdfView.documentView?.enclosingScrollView?.contentView.bounds.origin
        forceScrollViewRefresh(origin: targetOrigin)

        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }
            let targetPage = self.pdfView.document?.page(at: pageIndex) ?? self.pdfView.currentPage
            self.pdfView.layoutDocumentView()
            self.pdfView.documentView?.needsLayout = true
            self.pdfView.documentView?.layoutSubtreeIfNeeded()
            self.pdfView.documentView?.needsDisplay = true
            self.pdfView.needsDisplay = true
            self.pdfView.displayIfNeeded()
            if let targetPage {
                self.pdfView.go(to: targetPage)
            }
            let targetOrigin = self.pdfView.documentView?.enclosingScrollView?.contentView.bounds.origin
            self.forceScrollViewRefresh(origin: targetOrigin)
            self.overlayView.needsDisplay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }
            let targetPage = self.pdfView.document?.page(at: pageIndex) ?? self.pdfView.currentPage
            self.pdfView.layoutDocumentView()
            self.pdfView.documentView?.needsLayout = true
            self.pdfView.documentView?.layoutSubtreeIfNeeded()
            self.pdfView.documentView?.needsDisplay = true
            self.pdfView.needsDisplay = true
            self.pdfView.displayIfNeeded()
            if let targetPage {
                self.pdfView.go(to: targetPage)
            }
            let targetOrigin = self.pdfView.documentView?.enclosingScrollView?.contentView.bounds.origin
            self.forceScrollViewRefresh(origin: targetOrigin)
            self.overlayView.needsDisplay = true
        }
    }

    private func forceScrollViewRefresh(origin: CGPoint?) {
        guard let clipView = pdfView.documentView?.enclosingScrollView?.contentView else { return }
        clipView.scroll(to: origin ?? clipView.bounds.origin)
        clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
        pdfView.documentView?.needsDisplay = true
        clipView.needsDisplay = true
    }

    private func configureOverlayObservers() {
        tearDownOverlayObservers()

        let center = NotificationCenter.default

        overlayRedrawObservers.append(
            center.addObserver(
                forName: Notification.Name.PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.overlayView.needsDisplay = true
            }
        )

        overlayRedrawObservers.append(
            center.addObserver(
                forName: Notification.Name.PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.overlayView.needsDisplay = true
            }
        )

        overlayRedrawObservers.append(
            center.addObserver(
                forName: Notification.Name.PDFViewVisiblePagesChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.overlayView.needsDisplay = true
            }
        )

        if let clipView = pdfView.documentView?.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            observedClipView = clipView

            overlayRedrawObservers.append(
                center.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: clipView,
                    queue: .main
                ) { [weak self] _ in
                    self?.overlayView.needsDisplay = true
                }
            )
        }
    }

    private func tearDownOverlayObservers() {
        let center = NotificationCenter.default
        overlayRedrawObservers.forEach(center.removeObserver)
        overlayRedrawObservers.removeAll()
        observedClipView?.postsBoundsChangedNotifications = false
        observedClipView = nil
    }
}

private final class PageRectificationOverlayView: NSView {
    private enum RectificationCorner: CaseIterable {
        case topLeft
        case topRight
        case bottomRight
        case bottomLeft
    }

    weak var pdfView: PDFView?
    weak var viewportClipView: NSClipView?
    var fixedPageFrame: CGRect?

    private var pageIndex = 0
    private var page: PDFPage?
    private var rectification: PageRectification?
    private var draftRectification: PageRectification?
    private var activeCorner: RectificationCorner?
    private var trackingArea: NSTrackingArea?
    private var onUpdateRectification: ((PageRectification) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    func update(
        pageIndex: Int,
        page: PDFPage?,
        rectification: PageRectification?,
        onUpdateRectification: @escaping (PageRectification) -> Void
    ) {
        self.pageIndex = pageIndex
        self.page = page
        self.rectification = rectification?.normalized()
        self.onUpdateRectification = onUpdateRectification

        if activeCorner == nil {
            draftRectification = nil
        }

        window?.invalidateCursorRects(for: self)
        updateCursorFromCurrentMouseLocation()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let pageFrame = pageFrameInView() else { return }

        let displayedRectification = displayedRectification()
        let path = quadPath(for: displayedRectification, in: pageFrame)

        NSColor.systemOrange.withAlphaComponent(0.1).setFill()
        path.fill()

        drawGrid(for: displayedRectification, in: pageFrame)

        NSColor.systemOrange.setStroke()
        path.lineWidth = 3
        path.stroke()

        for corner in RectificationCorner.allCases {
            let handleRect = handleRect(for: corner, rectification: displayedRectification, in: pageFrame)
            NSColor.systemOrange.setFill()
            NSBezierPath(roundedRect: handleRect, xRadius: 5, yRadius: 5).fill()

            NSColor.white.withAlphaComponent(0.95).setStroke()
            let border = NSBezierPath(roundedRect: handleRect.insetBy(dx: 1.2, dy: 1.2), xRadius: 4, yRadius: 4)
            border.lineWidth = 1.2
            border.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        guard let pageFrame = pageFrameInView() else { return }

        let displayedRectification = displayedRectification()
        for corner in RectificationCorner.allCases {
            if handleHitRect(for: corner, rectification: displayedRectification, in: pageFrame).contains(point) {
                activeCorner = corner
                draftRectification = displayedRectification
                updateCursor(for: point)
                needsDisplay = true
                return
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let activeCorner, var draftRectification, let page else { return }
        let point = convert(event.locationInWindow, from: nil)
        let fractionPoint = fractionPointFromViewPoint(point, in: page)

        switch activeCorner {
        case .topLeft:
            draftRectification.topLeft = fractionPoint
        case .topRight:
            draftRectification.topRight = fractionPoint
        case .bottomRight:
            draftRectification.bottomRight = fractionPoint
        case .bottomLeft:
            draftRectification.bottomLeft = fractionPoint
        }

        self.draftRectification = draftRectification.normalized()
        updateCursor(for: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let draftRectification {
            onUpdateRectification?(draftRectification.normalized())
        }

        activeCorner = nil
        draftRectification = nil
        updateCursor(for: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    private func displayedRectification() -> PageRectification {
        draftRectification?.normalized()
            ?? rectification?.normalized()
            ?? PageRectification.default(pageIndex: pageIndex)
    }

    private func pageFrameInView() -> CGRect? {
        guard let pdfView, let page else { return nil }
        return pdfView.convert(page.bounds(for: .mediaBox), from: page)
    }

    private func fractionPointFromViewPoint(_ point: CGPoint, in page: PDFPage) -> FractionPoint {
        guard let pdfView else { return FractionPoint(x: 0.5, y: 0.5) }
        let pagePoint = pdfView.convert(point, to: page)
        let pageBounds = page.bounds(for: .mediaBox)
        let normalizedX = (pagePoint.x - pageBounds.minX) / pageBounds.width
        let normalizedY = (pagePoint.y - pageBounds.minY) / pageBounds.height

        return FractionPoint(
            x: Double(max(0.0, min(1.0, normalizedX))),
            y: Double(max(0.0, min(1.0, 1.0 - normalizedY)))
        )
    }

    private func point(for point: FractionPoint, in pageFrame: CGRect) -> CGPoint {
        CGPoint(
            x: pageFrame.minX + pageFrame.width * point.x,
            y: pageFrame.maxY - pageFrame.height * point.y
        )
    }

    private func quadPath(for rectification: PageRectification, in pageFrame: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: point(for: rectification.topLeft, in: pageFrame))
        path.line(to: point(for: rectification.topRight, in: pageFrame))
        path.line(to: point(for: rectification.bottomRight, in: pageFrame))
        path.line(to: point(for: rectification.bottomLeft, in: pageFrame))
        path.close()
        return path
    }

    private func handleRect(
        for corner: RectificationCorner,
        rectification: PageRectification,
        in pageFrame: CGRect
    ) -> CGRect {
        let size: CGFloat = 16
        let center: CGPoint

        switch corner {
        case .topLeft:
            center = point(for: rectification.topLeft, in: pageFrame)
        case .topRight:
            center = point(for: rectification.topRight, in: pageFrame)
        case .bottomRight:
            center = point(for: rectification.bottomRight, in: pageFrame)
        case .bottomLeft:
            center = point(for: rectification.bottomLeft, in: pageFrame)
        }

        return CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    }

    private func handleHitRect(
        for corner: RectificationCorner,
        rectification: PageRectification,
        in pageFrame: CGRect
    ) -> CGRect {
        handleRect(for: corner, rectification: rectification, in: pageFrame).insetBy(dx: -8, dy: -8)
    }

    private func drawGrid(for rectification: PageRectification, in pageFrame: CGRect) {
        NSColor.systemOrange.withAlphaComponent(0.28).setStroke()

        for step in 1...3 {
            let t = CGFloat(step) / 4
            let left = interpolate(
                from: point(for: rectification.topLeft, in: pageFrame),
                to: point(for: rectification.bottomLeft, in: pageFrame),
                t: t
            )
            let right = interpolate(
                from: point(for: rectification.topRight, in: pageFrame),
                to: point(for: rectification.bottomRight, in: pageFrame),
                t: t
            )

            let horizontal = NSBezierPath()
            horizontal.move(to: left)
            horizontal.line(to: right)
            horizontal.lineWidth = 1
            horizontal.stroke()
        }

        for step in 1...3 {
            let t = CGFloat(step) / 4
            let top = interpolate(
                from: point(for: rectification.topLeft, in: pageFrame),
                to: point(for: rectification.topRight, in: pageFrame),
                t: t
            )
            let bottom = interpolate(
                from: point(for: rectification.bottomLeft, in: pageFrame),
                to: point(for: rectification.bottomRight, in: pageFrame),
                t: t
            )

            let vertical = NSBezierPath()
            vertical.move(to: top)
            vertical.line(to: bottom)
            vertical.lineWidth = 1
            vertical.stroke()
        }
    }

    private func interpolate(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }

    private func updateCursor(for point: CGPoint) {
        guard let pageFrame = pageFrameInView() else {
            NSCursor.arrow.set()
            return
        }

        let rectification = displayedRectification()
        let isOverHandle = RectificationCorner.allCases.contains {
            handleHitRect(for: $0, rectification: rectification, in: pageFrame).contains(point)
        }

        (isOverHandle ? NSCursor.crosshair : NSCursor.arrow).set()
    }

    private func updateCursorFromCurrentMouseLocation() {
        guard let window else { return }
        updateCursor(for: convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }
}

final class PDFBandEditorContainerView: NSView {
    private let pdfView = PDFView()
    private let overlayView = BandOverlayView()

    private var currentZoomMode: ZoomMode = .fitWidth
    private var displayedPageIndex: Int?
    private var refreshGeneration: Int = 0
    private var lastAppliedViewportSize: CGSize = .zero
    private var overlayRedrawObservers: [NSObjectProtocol] = []
    private weak var observedClipView: NSClipView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = false
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 8.0

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.pdfView = pdfView

        addSubview(pdfView)
        addSubview(overlayView)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        tearDownOverlayObservers()
    }

    override func layout() {
        super.layout()
        let viewportSize = bounds.size
        guard viewportSize != .zero else { return }

        if lastAppliedViewportSize != viewportSize {
            lastAppliedViewportSize = viewportSize
            applyZoomMode()
            if let displayedPageIndex {
                refreshGeneration &+= 1
                refreshPDFView(pageIndex: displayedPageIndex, generation: refreshGeneration)
            } else {
                overlayView.needsDisplay = true
            }
        } else {
            overlayView.needsDisplay = true
        }
    }

    func update(
        pdfDocument: PDFDocument,
        pageIndex: Int,
        bands: [BandModel],
        headerSelection: SourceHeaderSelection?,
        isEditingHeaderSelection: Bool,
        selectedPartID: UUID?,
        selectedBandID: UUID?,
        partColors: [UUID: NSColor],
        zoomMode: ZoomMode,
        canCreateBands: Bool,
        isPickingInstrumentNames: Bool,
        instrumentNameHighlights: [ScoreInstrumentNamePick],
        onPickInstrumentName: @escaping (CGPoint) -> Void,
        onSelectBand: @escaping (UUID?) -> Void,
        onCreateBand: @escaping (Double) -> Void,
        onUpdateBand: @escaping (UUID, Double, Double) -> Void,
        onUpdateHeaderSelection: @escaping (Int, Double, Double, Double, Double) -> Void,
        onFinishHeaderSelection: @escaping () -> Void
    ) {
        let documentChanged = pdfView.document !== pdfDocument
        if documentChanged {
            pdfView.document = pdfDocument
            displayedPageIndex = nil
            lastAppliedViewportSize = .zero
            configureOverlayObservers()
        }

        let pageChanged = displayedPageIndex != pageIndex
        if pageChanged, let page = pdfDocument.page(at: pageIndex) {
            pdfView.go(to: page)
            displayedPageIndex = pageIndex
        }

        let zoomModeChanged = currentZoomMode != zoomMode
        let preservedViewportOrigin = shouldPreserveViewportOrigin(
            documentChanged: documentChanged,
            pageChanged: pageChanged,
            zoomModeChanged: zoomModeChanged
        ) ? currentViewportOrigin() : nil

        currentZoomMode = zoomMode
        overlayView.update(
            pageIndex: pageIndex,
            page: pdfDocument.page(at: pageIndex),
            bands: bands,
            headerSelection: headerSelection,
            isEditingHeaderSelection: isEditingHeaderSelection,
            selectedPartID: selectedPartID,
            selectedBandID: selectedBandID,
            partColors: partColors,
            canCreateBands: canCreateBands,
            isPickingInstrumentNames: isPickingInstrumentNames,
            instrumentNameHighlights: instrumentNameHighlights,
            onPickInstrumentName: onPickInstrumentName,
            onSelectBand: onSelectBand,
            onCreateBand: onCreateBand,
            onUpdateBand: onUpdateBand,
            onUpdateHeaderSelection: onUpdateHeaderSelection,
            onFinishHeaderSelection: onFinishHeaderSelection
        )

        if documentChanged || pageChanged || zoomModeChanged {
            guard bounds.size != .zero else {
                overlayView.needsDisplay = true
                return
            }

            refreshGeneration &+= 1
            applyZoomMode()
            refreshPDFView(pageIndex: pageIndex, generation: refreshGeneration)
        } else {
            restoreViewportOrigin(preservedViewportOrigin)
            overlayView.needsDisplay = true
        }
    }

    private func applyZoomMode() {
        guard let page = pdfView.currentPage else { return }
        switch currentZoomMode {
        case .fitWidth:
            pdfView.autoScales = false
            let pageBounds = page.bounds(for: .mediaBox)
            let horizontalInset: CGFloat = 48
            let width = max(200, pdfView.bounds.width - horizontalInset)
            let scale = width / pageBounds.width
            pdfView.scaleFactor = min(pdfView.maxScaleFactor, max(pdfView.minScaleFactor, scale))
        case .fitPage:
            pdfView.autoScales = true
        }

        overlayView.needsDisplay = true
    }

    private func refreshPDFView(pageIndex: Int, generation: Int) {
        guard generation == refreshGeneration else { return }
        let targetPage = pdfView.document?.page(at: pageIndex) ?? pdfView.currentPage
        pdfView.layoutDocumentView()
        pdfView.documentView?.needsLayout = true
        pdfView.documentView?.layoutSubtreeIfNeeded()
        pdfView.documentView?.needsDisplay = true
        pdfView.needsDisplay = true
        pdfView.displayIfNeeded()
        if let targetPage {
            pdfView.go(to: targetPage)
        }
        let targetOrigin = pdfView.documentView?.enclosingScrollView?.contentView.bounds.origin
        forceScrollViewRefresh(origin: targetOrigin)

        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }
            let targetPage = self.pdfView.document?.page(at: pageIndex) ?? self.pdfView.currentPage
            self.pdfView.layoutDocumentView()
            self.pdfView.documentView?.needsLayout = true
            self.pdfView.documentView?.layoutSubtreeIfNeeded()
            self.pdfView.documentView?.needsDisplay = true
            self.pdfView.needsDisplay = true
            self.pdfView.displayIfNeeded()
            if let targetPage {
                self.pdfView.go(to: targetPage)
            }
            let targetOrigin = self.pdfView.documentView?.enclosingScrollView?.contentView.bounds.origin
            self.forceScrollViewRefresh(origin: targetOrigin)
            self.overlayView.needsDisplay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }
            let targetPage = self.pdfView.document?.page(at: pageIndex) ?? self.pdfView.currentPage
            self.pdfView.layoutDocumentView()
            self.pdfView.documentView?.needsLayout = true
            self.pdfView.documentView?.layoutSubtreeIfNeeded()
            self.pdfView.documentView?.needsDisplay = true
            self.pdfView.needsDisplay = true
            self.pdfView.displayIfNeeded()
            if let targetPage {
                self.pdfView.go(to: targetPage)
            }
            let targetOrigin = self.pdfView.documentView?.enclosingScrollView?.contentView.bounds.origin
            self.forceScrollViewRefresh(origin: targetOrigin)
            self.overlayView.needsDisplay = true
        }
    }

    private func forceScrollViewRefresh(origin: CGPoint?) {
        guard let clipView = pdfView.documentView?.enclosingScrollView?.contentView else { return }
        clipView.scroll(to: origin ?? clipView.bounds.origin)
        clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
        pdfView.documentView?.needsDisplay = true
        clipView.needsDisplay = true
    }

    private func configureOverlayObservers() {
        tearDownOverlayObservers()

        let center = NotificationCenter.default

        overlayRedrawObservers.append(
            center.addObserver(
                forName: Notification.Name.PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.overlayView.needsDisplay = true
            }
        )

        overlayRedrawObservers.append(
            center.addObserver(
                forName: Notification.Name.PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.overlayView.needsDisplay = true
            }
        )

        overlayRedrawObservers.append(
            center.addObserver(
                forName: Notification.Name.PDFViewVisiblePagesChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.overlayView.needsDisplay = true
            }
        )

        if let clipView = pdfView.documentView?.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            observedClipView = clipView

            overlayRedrawObservers.append(
                center.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: clipView,
                    queue: .main
                ) { [weak self] _ in
                    self?.overlayView.needsDisplay = true
                }
            )
        }
    }

    private func tearDownOverlayObservers() {
        let center = NotificationCenter.default
        overlayRedrawObservers.forEach(center.removeObserver)
        overlayRedrawObservers.removeAll()
        observedClipView?.postsBoundsChangedNotifications = false
        observedClipView = nil
    }

    private func shouldPreserveViewportOrigin(
        documentChanged: Bool,
        pageChanged: Bool,
        zoomModeChanged: Bool
    ) -> Bool {
        documentChanged == false && pageChanged == false && zoomModeChanged == false
    }

    private func currentViewportOrigin() -> CGPoint? {
        pdfView.documentView?.enclosingScrollView?.contentView.bounds.origin
    }

    private func restoreViewportOrigin(_ origin: CGPoint?) {
        guard let origin,
              let clipView = pdfView.documentView?.enclosingScrollView?.contentView
        else { return }

        clipView.scroll(to: origin)
        clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
        overlayView.needsDisplay = true

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let clipView = self.pdfView.documentView?.enclosingScrollView?.contentView
            else { return }

            clipView.scroll(to: origin)
            clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
            self.overlayView.needsDisplay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  let clipView = self.pdfView.documentView?.enclosingScrollView?.contentView
            else { return }

            clipView.scroll(to: origin)
            clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
            self.overlayView.needsDisplay = true
        }
    }
}

private final class BandOverlayView: NSView {
    enum DragMode {
        case top
        case bottom
        case move
    }

    enum HeaderCorner: CaseIterable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    enum HeaderDragMode {
        case create
        case move(initialSelection: SourceHeaderSelection)
        case resize(corner: HeaderCorner, initialSelection: SourceHeaderSelection)
    }

    struct DragState {
        var bandID: UUID
        var mode: DragMode
        var startPointerFraction: Double
        var topFraction: Double
        var bottomFraction: Double
    }

    struct HeaderSelectionDragState {
        var pageIndex: Int
        var mode: HeaderDragMode
        var startPoint: CGPoint
        var currentPoint: CGPoint
    }

    private enum HoverTarget: Equatable {
        case none
        case instrumentName
        case bandCreate
        case bandMove
        case bandResize
        case headerCreate
        case headerMove
        case headerResize(HeaderCorner)
    }

    weak var pdfView: PDFView?
    weak var viewportClipView: NSClipView?
    var fixedPageFrame: CGRect?

    private var pageIndex = 0
    private var page: PDFPage?
    private var bands: [BandModel] = []
    private var headerSelection: SourceHeaderSelection?
    private var isEditingHeaderSelection = false
    private var selectedPartID: UUID?
    private var selectedBandID: UUID?
    private var partColors: [UUID: NSColor] = [:]
    private var canCreateBands = false
    private var isPickingInstrumentNames = false
    private var instrumentNameHighlights: [ScoreInstrumentNamePick] = []
    private var onPickInstrumentName: ((CGPoint) -> Void)?
    private var instrumentNameMouseDownPoint: CGPoint?
    private var onSelectBand: ((UUID?) -> Void)?
    private var onCreateBand: ((Double) -> Void)?
    private var onUpdateBand: ((UUID, Double, Double) -> Void)?
    private var onUpdateHeaderSelection: ((Int, Double, Double, Double, Double) -> Void)?
    private var onFinishHeaderSelection: (() -> Void)?
    private var dragState: DragState?
    private var headerDragState: HeaderSelectionDragState?
    private var headerDraft: SourceHeaderSelection?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        isPickingInstrumentNames || super.acceptsFirstMouse(for: event)
    }

    private static let addBandCursor: NSCursor = {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ringRect = CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)

        NSColor.white.withAlphaComponent(0.95).setStroke()
        let haloRing = NSBezierPath(ovalIn: ringRect)
        haloRing.lineWidth = 4
        haloRing.stroke()

        NSColor.controlAccentColor.setStroke()
        let ring = NSBezierPath(ovalIn: ringRect)
        ring.lineWidth = 1.6
        ring.stroke()

        let halo = NSBezierPath()
        halo.lineCapStyle = .round
        halo.lineWidth = 4
        halo.move(to: CGPoint(x: center.x - 4.5, y: center.y))
        halo.line(to: CGPoint(x: center.x + 4.5, y: center.y))
        halo.move(to: CGPoint(x: center.x, y: center.y - 4.5))
        halo.line(to: CGPoint(x: center.x, y: center.y + 4.5))
        NSColor.white.withAlphaComponent(0.95).setStroke()
        halo.stroke()

        let plus = NSBezierPath()
        plus.lineCapStyle = .round
        plus.lineWidth = 2
        plus.move(to: CGPoint(x: center.x - 4.5, y: center.y))
        plus.line(to: CGPoint(x: center.x + 4.5, y: center.y))
        plus.move(to: CGPoint(x: center.x, y: center.y - 4.5))
        plus.line(to: CGPoint(x: center.x, y: center.y + 4.5))
        NSColor.controlAccentColor.setStroke()
        plus.stroke()

        return NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: center.y))
    }()

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    func update(
        pageIndex: Int,
        page: PDFPage?,
        bands: [BandModel],
        headerSelection: SourceHeaderSelection?,
        isEditingHeaderSelection: Bool,
        selectedPartID: UUID?,
        selectedBandID: UUID?,
        partColors: [UUID: NSColor],
        canCreateBands: Bool,
        isPickingInstrumentNames: Bool,
        instrumentNameHighlights: [ScoreInstrumentNamePick],
        onPickInstrumentName: @escaping (CGPoint) -> Void,
        onSelectBand: @escaping (UUID?) -> Void,
        onCreateBand: @escaping (Double) -> Void,
        onUpdateBand: @escaping (UUID, Double, Double) -> Void,
        onUpdateHeaderSelection: @escaping (Int, Double, Double, Double, Double) -> Void,
        onFinishHeaderSelection: @escaping () -> Void
    ) {
        if self.isPickingInstrumentNames != isPickingInstrumentNames || self.pageIndex != pageIndex {
            instrumentNameMouseDownPoint = nil
        }
        self.pageIndex = pageIndex
        self.page = page
        self.bands = bands
        self.headerSelection = headerSelection
        self.isEditingHeaderSelection = isEditingHeaderSelection
        self.selectedPartID = selectedPartID
        self.selectedBandID = selectedBandID
        self.partColors = partColors
        self.canCreateBands = canCreateBands
        self.isPickingInstrumentNames = isPickingInstrumentNames
        self.instrumentNameHighlights = instrumentNameHighlights
        self.onPickInstrumentName = onPickInstrumentName
        self.onSelectBand = onSelectBand
        self.onCreateBand = onCreateBand
        self.onUpdateBand = onUpdateBand
        self.onUpdateHeaderSelection = onUpdateHeaderSelection
        self.onFinishHeaderSelection = onFinishHeaderSelection
        if isPickingInstrumentNames {
            dragState = nil
            headerDragState = nil
            headerDraft = nil
        } else if isEditingHeaderSelection == false {
            headerDragState = nil
            headerDraft = nil
        }
        window?.invalidateCursorRects(for: self)
        updateCursorFromCurrentMouseLocation()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for band in orderedBandsForDisplay {
            let color = partColors[band.partID] ?? .systemBlue
            let isSelectedBand = selectedBandID == band.id
            let isSelectedPartBand = selectedPartID == band.partID
            let fillAlpha: CGFloat
            let strokeAlpha: CGFloat
            let borderWidth: CGFloat

            if isSelectedBand {
                fillAlpha = 0.32
                strokeAlpha = 1.0
                borderWidth = 3
            } else if isSelectedPartBand {
                fillAlpha = 0.12
                strokeAlpha = 0.68
                borderWidth = 1.5
            } else {
                fillAlpha = 0.05
                strokeAlpha = 0.32
                borderWidth = 1
            }

            let displayTop: Double
            let displayBottom: Double
            if let dragState, dragState.bandID == band.id {
                displayTop = dragState.topFraction
                displayBottom = dragState.bottomFraction
            } else {
                displayTop = band.topFraction
                displayBottom = band.bottomFraction
            }

            let bandRect = bandFrame(topFraction: displayTop, bottomFraction: displayBottom)
            guard let bandRect else { continue }

            if isSelectedBand {
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowBlurRadius = 12
                shadow.shadowOffset = .zero
                shadow.shadowColor = color.withAlphaComponent(0.28)
                shadow.set()
            }

            let fillColor = color.withAlphaComponent(fillAlpha)
            fillColor.setFill()
            NSBezierPath(roundedRect: bandRect, xRadius: 6, yRadius: 6).fill()

            let strokeColor = color.withAlphaComponent(strokeAlpha)
            strokeColor.setStroke()
            let border = NSBezierPath(roundedRect: bandRect, xRadius: 6, yRadius: 6)
            border.lineWidth = borderWidth
            border.stroke()

            drawBarNumberBadge(for: band, in: bandRect, color: color)

            if isSelectedBand {
                drawEdgeGuide(
                    rect: edgeGuideRect(for: bandRect, edge: .bottom),
                    color: strokeColor,
                    emphasized: true
                )
                drawEdgeGuide(
                    rect: edgeGuideRect(for: bandRect, edge: .top),
                    color: strokeColor,
                    emphasized: true
                )

                drawHandle(rect: visibleHandleRect(for: bandRect, edge: .bottom), color: color)
                drawHandle(rect: visibleHandleRect(for: bandRect, edge: .top), color: color)
            }

            if isSelectedBand {
                let label = "P\(band.pageIndex + 1)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ]
                label.draw(at: CGPoint(x: bandRect.minX + 8, y: bandRect.maxY + 6), withAttributes: attributes)
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        if let headerSelection = displayedHeaderSelection,
           let headerRect = headerFrame(for: headerSelection)
        {
            let headerColor = NSColor.systemOrange
            let strokeColor = headerColor.withAlphaComponent(isEditingHeaderSelection ? 1.0 : 0.78)
            let fillColor = headerColor.withAlphaComponent(isEditingHeaderSelection ? 0.16 : 0.08)

            fillColor.setFill()
            NSBezierPath(roundedRect: headerRect, xRadius: 8, yRadius: 8).fill()

            strokeColor.setStroke()
            let border = NSBezierPath(roundedRect: headerRect, xRadius: 8, yRadius: 8)
            border.lineWidth = isEditingHeaderSelection ? 3 : 2
            border.stroke()

            if isEditingHeaderSelection {
                for corner in HeaderCorner.allCases {
                    drawHeaderHandle(
                        rect: headerHandleRect(for: headerRect, corner: corner),
                        color: headerColor
                    )
                }
            }

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
            "Header".draw(
                at: CGPoint(x: headerRect.minX + 8, y: headerRect.maxY + 6),
                withAttributes: labelAttributes
            )
        }

        drawInstrumentNameHighlights()
    }

    /// These annotations live only in the picking overlay, never in the score
    /// geometry or export. Convert from the same displayed page used for OCR.
    private func drawInstrumentNameHighlights() {
        guard isPickingInstrumentNames, let pageFrame = pageFrameInView(),
              pageFrame.width > 0, pageFrame.height > 0 else { return }
        let color = NSColor.systemGreen
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let textAttributes = labelAttributes.merging([.paragraphStyle: paragraphStyle]) { _, new in new }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: pageFrame).addClip()
        for pick in instrumentNameHighlights where pick.pageIndex == pageIndex {
            let box = CGRect(x: pageFrame.minX + pick.bounds.minX * pageFrame.width,
                y: pageFrame.maxY - pick.bounds.maxY * pageFrame.height,
                width: pick.bounds.width * pageFrame.width,
                height: pick.bounds.height * pageFrame.height).insetBy(dx: -3, dy: -3)
            guard box.intersects(visibleRect) else { continue }
            let outline = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
            color.withAlphaComponent(0.20).setFill()
            outline.fill()
            color.setStroke()
            outline.lineWidth = 2
            outline.stroke()

            // Show the actual recognized spelling beside the ink, large enough
            // to read even when the whole source page is fitted to the window.
            let label = "✓ \(pick.name)" as NSString
            let textSize = label.size(withAttributes: labelAttributes)
            let size = NSSize(width: min(textSize.width + 14, pageFrame.width - 8), height: textSize.height + 6)
            let x = max(pageFrame.minX + 4, min(box.minX, pageFrame.maxX - size.width - 4))
            let y = box.maxY + size.height + 4 <= pageFrame.maxY
                ? box.maxY + 4 : max(pageFrame.minY + 4, box.minY - size.height - 4)
            let badge = CGRect(origin: CGPoint(x: x, y: y), size: size)
            NSColor(calibratedRed: 0.10, green: 0.38, blue: 0.20, alpha: 0.97).setFill()
            NSBezierPath(roundedRect: badge, xRadius: 5, yRadius: 5).fill()
            label.draw(in: badge.insetBy(dx: 7, dy: 3), withAttributes: textAttributes)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)

        guard let pageFrame = pageFrameInView() else { return }

        if isPickingInstrumentNames {
            instrumentNameMouseDownPoint = event.clickCount == 1 && pageFrame.contains(point) ? point : nil
            updateCursor(for: point)
            return
        }

        if isEditingHeaderSelection {
            let target = hoverTarget(at: point)
            let existingHeaderSelection = displayedHeaderSelection

            guard pageFrame.contains(point) else {
                onFinishHeaderSelection?()
                updateCursor(for: point)
                needsDisplay = true
                return
            }

            let fractionPoint = headerFractionPointFromViewPoint(point)
            let dragMode: HeaderDragMode
            switch target {
            case .headerResize(let corner):
                guard let existingHeaderSelection else { return }
                dragMode = .resize(corner: corner, initialSelection: existingHeaderSelection)
            case .headerMove:
                guard let existingHeaderSelection else { return }
                dragMode = .move(initialSelection: existingHeaderSelection)
            case .headerCreate:
                if existingHeaderSelection == nil {
                    dragMode = .create
                } else {
                    onFinishHeaderSelection?()
                    updateCursor(for: point)
                    needsDisplay = true
                    return
                }
            default:
                onFinishHeaderSelection?()
                updateCursor(for: point)
                needsDisplay = true
                return
            }

            let dragState = HeaderSelectionDragState(
                pageIndex: pageIndex,
                mode: dragMode,
                startPoint: fractionPoint,
                currentPoint: fractionPoint
            )
            headerDragState = dragState
            headerDraft = headerSelection(from: dragState)
            updateCursor(for: point)
            needsDisplay = true
            return
        }

        for band in orderedBandsForDisplay.reversed() {
            guard let bandRect = bandFrame(for: band) else { continue }
            if edgeHitRect(for: bandRect, edge: .top).contains(point) {
                selectedBandID = band.id
                onSelectBand?(band.id)
                dragState = DragState(
                    bandID: band.id,
                    mode: .top,
                    startPointerFraction: fractionFromViewPoint(point),
                    topFraction: band.topFraction,
                    bottomFraction: band.bottomFraction
                )
                needsDisplay = true
                updateCursor(for: point)
                return
            }

            if edgeHitRect(for: bandRect, edge: .bottom).contains(point) {
                selectedBandID = band.id
                onSelectBand?(band.id)
                dragState = DragState(
                    bandID: band.id,
                    mode: .bottom,
                    startPointerFraction: fractionFromViewPoint(point),
                    topFraction: band.topFraction,
                    bottomFraction: band.bottomFraction
                )
                needsDisplay = true
                updateCursor(for: point)
                return
            }

            if bandRect.contains(point) {
                selectedBandID = band.id
                onSelectBand?(band.id)
                dragState = DragState(
                    bandID: band.id,
                    mode: .move,
                    startPointerFraction: fractionFromViewPoint(point),
                    topFraction: band.topFraction,
                    bottomFraction: band.bottomFraction
                )
                needsDisplay = true
                updateCursor(for: point)
                return
            }
        }

        selectedBandID = nil
        onSelectBand?(nil)
        needsDisplay = true

        guard canCreateBands, pageFrame.contains(point) else { return }
        let centerFraction = fractionFromViewPoint(point)
        onCreateBand?(centerFraction)
        updateCursor(for: point)
    }

    override func mouseDragged(with event: NSEvent) {
        if isPickingInstrumentNames {
            let point = convert(event.locationInWindow, from: nil)
            if let start = instrumentNameMouseDownPoint, hypot(point.x - start.x, point.y - start.y) > 4 {
                instrumentNameMouseDownPoint = nil
            }
            return
        }

        if var headerDragState {
            let point = convert(event.locationInWindow, from: nil)
            headerDragState.currentPoint = headerFractionPointFromViewPoint(point)
            self.headerDragState = headerDragState
            headerDraft = headerSelection(from: headerDragState)
            updateCursor(for: point)
            needsDisplay = true
            return
        }

        guard var dragState else { return }
        let point = convert(event.locationInWindow, from: nil)
        let fraction = fractionFromViewPoint(point)

        switch dragState.mode {
        case .top:
            dragState.topFraction = min(max(0.0, fraction), dragState.bottomFraction - 0.02)
        case .bottom:
            dragState.bottomFraction = max(min(1.0, fraction), dragState.topFraction + 0.02)
        case .move:
            let height = dragState.bottomFraction - dragState.topFraction
            let delta = fraction - dragState.startPointerFraction
            let proposedTop = dragState.topFraction + delta
            let proposedBottom = dragState.bottomFraction + delta

            if proposedTop < 0 {
                dragState.topFraction = 0
                dragState.bottomFraction = height
            } else if proposedBottom > 1 {
                dragState.bottomFraction = 1
                dragState.topFraction = 1 - height
            } else {
                dragState.topFraction = proposedTop
                dragState.bottomFraction = proposedBottom
            }

            dragState.startPointerFraction = fraction
        }

        self.dragState = dragState
        updateCursor(for: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isPickingInstrumentNames {
            let point = convert(event.locationInWindow, from: nil)
            let start = instrumentNameMouseDownPoint
            instrumentNameMouseDownPoint = nil
            guard event.clickCount == 1, let start,
                  hypot(point.x - start.x, point.y - start.y) <= 4,
                  let pageFrame = pageFrameInView(), pageFrame.contains(point)
            else { return }
            onPickInstrumentName?(headerFractionPointFromViewPoint(point))
            updateCursor(for: point)
            return
        }

        if let headerDragState {
            let preservedViewportOrigin = currentViewportOrigin()
            let selection = headerSelection(from: headerDragState)
            let widthFraction = 1 - selection.leftFraction - selection.rightFraction
            let heightFraction = selection.bottomFraction - selection.topFraction
            if widthFraction >= 0.02, heightFraction >= 0.02 {
                onUpdateHeaderSelection?(
                    selection.pageIndex,
                    selection.topFraction,
                    selection.bottomFraction,
                    selection.leftFraction,
                    selection.rightFraction
                )
            }
            self.headerDragState = nil
            headerDraft = nil
            restoreViewportOrigin(preservedViewportOrigin)
            updateCursor(for: convert(event.locationInWindow, from: nil))
            needsDisplay = true
            return
        }

        guard let dragState else { return }
        let preservedViewportOrigin = currentViewportOrigin()

        if let band = bands.first(where: { $0.id == dragState.bandID }) {
            let topChanged = abs(band.topFraction - dragState.topFraction) > 0.0001
            let bottomChanged = abs(band.bottomFraction - dragState.bottomFraction) > 0.0001
            if topChanged || bottomChanged {
                onUpdateBand?(dragState.bandID, dragState.topFraction, dragState.bottomFraction)
            }
        }

        self.dragState = nil
        restoreViewportOrigin(preservedViewportOrigin)
        updateCursor(for: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    private func drawEdgeGuide(rect: CGRect, color: NSColor, emphasized: Bool) {
        let fillColor = color.withAlphaComponent(emphasized ? 0.35 : 0.22)
        fillColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
    }

    private func drawHandle(rect: CGRect, color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()

        NSColor.white.withAlphaComponent(0.8).setStroke()
        let grip = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 4, yRadius: 4)
        grip.lineWidth = 1
        grip.stroke()
    }

    private func drawHeaderHandle(rect: CGRect, color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

        NSColor.white.withAlphaComponent(0.92).setStroke()
        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1.25, dy: 1.25), xRadius: 3, yRadius: 3)
        border.lineWidth = 1.2
        border.stroke()
    }

    private func drawBarNumberBadge(for band: BandModel, in bandRect: CGRect, color: NSColor) {
        guard let barNumber = band.displayedBarNumber else { return }

        let label = "\(barNumber)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: band.barNumberMode == .manual ? NSColor.white : NSColor.labelColor
        ]
        let labelSize = label.size(withAttributes: attributes)
        let badgeRect = CGRect(
            x: bandRect.minX + 8,
            y: bandRect.maxY - labelSize.height - 12,
            width: labelSize.width + 16,
            height: labelSize.height + 8
        )

        let fillColor: NSColor
        let strokeColor: NSColor
        switch band.barNumberMode {
        case .automatic:
            fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94)
            strokeColor = color.withAlphaComponent(0.68)
        case .manual:
            fillColor = color.withAlphaComponent(0.96)
            strokeColor = color.withAlphaComponent(1.0)
        case .hidden:
            return
        }

        fillColor.setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 8, yRadius: 8).fill()

        strokeColor.setStroke()
        let border = NSBezierPath(roundedRect: badgeRect, xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()

        label.draw(
            at: CGPoint(
                x: badgeRect.minX + (badgeRect.width - labelSize.width) / 2,
                y: badgeRect.minY + (badgeRect.height - labelSize.height) / 2
            ),
            withAttributes: attributes
        )
    }

    private func visibleHandleRect(for bandRect: CGRect, edge: DragMode) -> CGRect {
        let handleSize = CGSize(width: min(96, max(56, bandRect.width * 0.24)), height: 12)
        let y = edge == .top ? bandRect.maxY : bandRect.minY
        return CGRect(
            x: bandRect.minX + (bandRect.width - handleSize.width) / 2,
            y: y - handleSize.height / 2,
            width: handleSize.width,
            height: handleSize.height
        )
    }

    private func edgeGuideRect(for bandRect: CGRect, edge: DragMode) -> CGRect {
        let y = edge == .top ? bandRect.maxY : bandRect.minY
        return CGRect(
            x: bandRect.minX + 10,
            y: y - 2,
            width: max(40, bandRect.width - 20),
            height: 4
        )
    }

    private func edgeHitRect(for bandRect: CGRect, edge: DragMode) -> CGRect {
        let y = edge == .top ? bandRect.maxY : bandRect.minY
        return CGRect(
            x: bandRect.minX + 4,
            y: y - 14,
            width: max(40, bandRect.width - 8),
            height: 28
        )
    }

    private func currentViewportOrigin() -> CGPoint? {
        viewportClipView?.bounds.origin ?? pdfView?.documentView?.enclosingScrollView?.contentView.bounds.origin
    }

    private func restoreViewportOrigin(_ origin: CGPoint?) {
        guard let origin,
              let clipView = currentClipView()
        else { return }

        clipView.scroll(to: origin)
        clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
        needsDisplay = true

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let clipView = self.currentClipView()
            else { return }

            clipView.scroll(to: origin)
            clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
            self.needsDisplay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  let clipView = self.currentClipView()
            else { return }

            clipView.scroll(to: origin)
            clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
            self.needsDisplay = true
        }
    }

    private func headerHandleRect(for headerRect: CGRect, corner: HeaderCorner) -> CGRect {
        let size: CGFloat = 14
        let center: CGPoint

        switch corner {
        case .topLeft:
            center = CGPoint(x: headerRect.minX, y: headerRect.maxY)
        case .topRight:
            center = CGPoint(x: headerRect.maxX, y: headerRect.maxY)
        case .bottomLeft:
            center = CGPoint(x: headerRect.minX, y: headerRect.minY)
        case .bottomRight:
            center = CGPoint(x: headerRect.maxX, y: headerRect.minY)
        }

        return CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
    }

    private func headerHandleHitRect(for headerRect: CGRect, corner: HeaderCorner) -> CGRect {
        headerHandleRect(for: headerRect, corner: corner).insetBy(dx: -6, dy: -6)
    }

    private func pageFrameInView() -> CGRect? {
        if let fixedPageFrame {
            return fixedPageFrame
        }
        guard let pdfView, let page else { return nil }
        return pdfView.convert(page.bounds(for: .mediaBox), from: page)
    }

    private func bandFrame(for band: BandModel) -> CGRect? {
        bandFrame(topFraction: band.topFraction, bottomFraction: band.bottomFraction)
    }

    private func headerFrame(for headerSelection: SourceHeaderSelection) -> CGRect? {
        guard let pageFrame = pageFrameInView() else { return nil }
        let topY = pageFrame.maxY - pageFrame.height * headerSelection.topFraction
        let bottomY = pageFrame.maxY - pageFrame.height * headerSelection.bottomFraction
        let minX = pageFrame.minX + pageFrame.width * headerSelection.leftFraction
        let maxX = pageFrame.maxX - pageFrame.width * headerSelection.rightFraction
        return CGRect(
            x: minX,
            y: bottomY,
            width: max(1, maxX - minX),
            height: max(1, topY - bottomY)
        )
    }

    private func bandFrame(topFraction: Double, bottomFraction: Double) -> CGRect? {
        guard let pageFrame = pageFrameInView() else { return nil }
        let topY = pageFrame.maxY - pageFrame.height * topFraction
        let bottomY = pageFrame.maxY - pageFrame.height * bottomFraction
        return CGRect(
            x: pageFrame.minX,
            y: bottomY,
            width: pageFrame.width,
            height: topY - bottomY
        )
    }

    private func fractionFromViewPoint(_ point: CGPoint) -> Double {
        guard let pageFrame = pageFrameInView(), pageFrame.height > 0 else { return 0.5 }
        let normalizedY = (point.y - pageFrame.minY) / pageFrame.height
        return max(0.0, min(1.0, 1.0 - normalizedY))
    }

    private func headerFractionPointFromViewPoint(_ point: CGPoint) -> CGPoint {
        guard let pageFrame = pageFrameInView(),
              pageFrame.width > 0,
              pageFrame.height > 0
        else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let normalizedX = (point.x - pageFrame.minX) / pageFrame.width
        let normalizedY = (point.y - pageFrame.minY) / pageFrame.height
        return CGPoint(
            x: max(0.0, min(1.0, normalizedX)),
            y: max(0.0, min(1.0, 1.0 - normalizedY))
        )
    }

    private func currentClipView() -> NSClipView? {
        viewportClipView ?? pdfView?.documentView?.enclosingScrollView?.contentView
    }

    private func headerSelection(from dragState: HeaderSelectionDragState) -> SourceHeaderSelection {
        let minX: CGFloat
        let maxX: CGFloat
        let top: CGFloat
        let bottom: CGFloat

        switch dragState.mode {
        case .create:
            minX = min(dragState.startPoint.x, dragState.currentPoint.x)
            maxX = max(dragState.startPoint.x, dragState.currentPoint.x)
            top = min(dragState.startPoint.y, dragState.currentPoint.y)
            bottom = max(dragState.startPoint.y, dragState.currentPoint.y)
        case .move(let initialSelection):
            let initialMinX = initialSelection.leftFraction
            let initialMaxX = 1 - initialSelection.rightFraction
            let deltaX = dragState.currentPoint.x - dragState.startPoint.x
            let deltaY = dragState.currentPoint.y - dragState.startPoint.y
            let width = initialMaxX - initialMinX
            let height = initialSelection.bottomFraction - initialSelection.topFraction

            let clampedMinX = max(0, min(initialMinX + deltaX, 1 - width))
            let clampedTop = max(0, min(initialSelection.topFraction + deltaY, 1 - height))
            minX = clampedMinX
            maxX = clampedMinX + width
            top = clampedTop
            bottom = clampedTop + height
        case .resize(let corner, let initialSelection):
            let anchorPoint: CGPoint
            switch corner {
            case .topLeft:
                anchorPoint = CGPoint(x: 1 - initialSelection.rightFraction, y: initialSelection.bottomFraction)
            case .topRight:
                anchorPoint = CGPoint(x: initialSelection.leftFraction, y: initialSelection.bottomFraction)
            case .bottomLeft:
                anchorPoint = CGPoint(x: 1 - initialSelection.rightFraction, y: initialSelection.topFraction)
            case .bottomRight:
                anchorPoint = CGPoint(x: initialSelection.leftFraction, y: initialSelection.topFraction)
            }

            minX = min(anchorPoint.x, dragState.currentPoint.x)
            maxX = max(anchorPoint.x, dragState.currentPoint.x)
            top = min(anchorPoint.y, dragState.currentPoint.y)
            bottom = max(anchorPoint.y, dragState.currentPoint.y)
        }

        return SourceHeaderSelection(
            pageIndex: dragState.pageIndex,
            topFraction: Double(top),
            bottomFraction: Double(bottom),
            leftFraction: Double(minX),
            rightFraction: Double(1 - maxX)
        ).normalized()
    }

    private func hoverTarget(at point: CGPoint) -> HoverTarget {
        guard let pageFrame = pageFrameInView() else { return .none }

        if isPickingInstrumentNames {
            return pageFrame.contains(point) ? .instrumentName : .none
        }

        if isEditingHeaderSelection {
            if let headerSelection = displayedHeaderSelection,
               let headerRect = headerFrame(for: headerSelection)
            {
                for corner in HeaderCorner.allCases {
                    if headerHandleHitRect(for: headerRect, corner: corner).contains(point) {
                        return .headerResize(corner)
                    }
                }

                if headerRect.insetBy(dx: -4, dy: -4).contains(point) {
                    return .headerMove
                }
            }

            return pageFrame.contains(point) ? .headerCreate : .none
        }

        for band in orderedBandsForDisplay.reversed() {
            guard let bandRect = bandFrame(for: band) else { continue }
            if edgeHitRect(for: bandRect, edge: .top).contains(point) ||
                edgeHitRect(for: bandRect, edge: .bottom).contains(point)
            {
                return .bandResize
            }

            if bandRect.contains(point) {
                return .bandMove
            }
        }

        return canCreateBands && pageFrame.contains(point) ? .bandCreate : .none
    }

    private func updateCursor(for point: CGPoint) {
        cursor(for: hoverTarget(at: point)).set()
    }

    private func updateCursorFromCurrentMouseLocation() {
        guard let window else { return }
        updateCursor(for: convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    private func cursor(for hoverTarget: HoverTarget) -> NSCursor {
        switch hoverTarget {
        case .none:
            return .arrow
        case .instrumentName:
            return .crosshair
        case .bandCreate, .headerCreate:
            return Self.addBandCursor
        case .bandResize:
            return .resizeUpDown
        case .bandMove:
            return dragState?.mode == .move ? .closedHand : .openHand
        case .headerMove:
            if let headerDragState, case .move = headerDragState.mode {
                return .closedHand
            }
            return .openHand
        case .headerResize:
            return .crosshair
        }
    }

    private var orderedBandsForDisplay: [BandModel] {
        let backgroundBands = bands.filter { band in
            band.id != selectedBandID && band.partID != selectedPartID
        }
        let selectedPartBands = bands.filter { band in
            band.id != selectedBandID && band.partID == selectedPartID
        }
        let selectedBand = bands.first(where: { $0.id == selectedBandID })

        return backgroundBands + selectedPartBands + (selectedBand.map { [$0] } ?? [])
    }

    private var displayedHeaderSelection: SourceHeaderSelection? {
        if let headerDraft {
            return headerDraft
        }

        return headerSelection
    }
}
