import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct SourceCanvasView: View {
    @ObservedObject var document: PartsmithDocument
    var onImportRequested: () -> Void
    var onImportDropped: (URL) -> Void
    var onNewPartRequested: () -> Void

    @State private var isImportDropTargeted = false

    var body: some View {
        if let pdfDocument = document.pdfDocument {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.sourceInstruction.title)
                            .font(.headline)
                        Text(document.sourceInstruction.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if document.selectedPartID == nil {
                        Button("New Part", systemImage: "plus") {
                            onNewPartRequested()
                        }
                    }
                }
                .padding(16)

                Divider()

                PDFBandEditorRepresentable(
                    pdfDocument: pdfDocument,
                    pageIndex: document.currentPageIndex,
                    bands: document.bands(on: document.currentPageIndex),
                    headerSelection: document.headerSelectionOnCurrentPage,
                    isEditingHeaderSelection: document.isEditingHeaderSelection,
                    selectedPartID: document.selectedPartID,
                    selectedBandID: document.selectedBandID,
                    partColors: document.colorMap(),
                    zoomMode: document.zoomMode,
                    canCreateBands: document.selectedPartID != nil && document.isEditingHeaderSelection == false,
                    onSelectBand: document.selectBand(_:),
                    onCreateBand: { centerFraction in
                        guard let selectedPartID = document.selectedPartID else { return }
                        document.createBand(on: document.currentPageIndex, centerFraction: centerFraction, partID: selectedPartID)
                    },
                    onUpdateBand: { bandID, topFraction, bottomFraction in
                        document.updateBand(bandID, topFraction: topFraction, bottomFraction: bottomFraction)
                    },
                    onUpdateHeaderSelection: { pageIndex, topFraction, bottomFraction, leftFraction, rightFraction in
                        document.updateHeaderSelection(
                            pageIndex: pageIndex,
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
    var sourceInstruction: (title: String, body: String) {
        if isEditingHeaderSelection {
            return (
                title: "Selecting a shared source header",
                body: "Drag a rectangle over the engraved score header, or adjust its corner handles. Click Save in the inspector, or just click elsewhere to finish."
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
            onSelectBand: onSelectBand,
            onCreateBand: onCreateBand,
            onUpdateBand: onUpdateBand,
            onUpdateHeaderSelection: onUpdateHeaderSelection,
            onFinishHeaderSelection: onFinishHeaderSelection
        )
    }
}

final class PDFBandEditorContainerView: NSView {
    private let pdfView = PDFView()
    private let overlayView = BandOverlayView()

    private var currentZoomMode: ZoomMode = .fitWidth
    private var displayedPageIndex: Int?
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
            onSelectBand: onSelectBand,
            onCreateBand: onCreateBand,
            onUpdateBand: onUpdateBand,
            onUpdateHeaderSelection: onUpdateHeaderSelection,
            onFinishHeaderSelection: onFinishHeaderSelection
        )

        if documentChanged || pageChanged || zoomModeChanged {
            applyZoomMode()
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
        case bandCreate
        case bandMove
        case bandResize
        case headerCreate
        case headerMove
        case headerResize(HeaderCorner)
    }

    weak var pdfView: PDFView?

    private var pageIndex = 0
    private var page: PDFPage?
    private var bands: [BandModel] = []
    private var headerSelection: SourceHeaderSelection?
    private var isEditingHeaderSelection = false
    private var selectedPartID: UUID?
    private var selectedBandID: UUID?
    private var partColors: [UUID: NSColor] = [:]
    private var canCreateBands = false
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
        onSelectBand: @escaping (UUID?) -> Void,
        onCreateBand: @escaping (Double) -> Void,
        onUpdateBand: @escaping (UUID, Double, Double) -> Void,
        onUpdateHeaderSelection: @escaping (Int, Double, Double, Double, Double) -> Void,
        onFinishHeaderSelection: @escaping () -> Void
    ) {
        self.pageIndex = pageIndex
        self.page = page
        self.bands = bands
        self.headerSelection = headerSelection
        self.isEditingHeaderSelection = isEditingHeaderSelection
        self.selectedPartID = selectedPartID
        self.selectedBandID = selectedBandID
        self.partColors = partColors
        self.canCreateBands = canCreateBands
        self.onSelectBand = onSelectBand
        self.onCreateBand = onCreateBand
        self.onUpdateBand = onUpdateBand
        self.onUpdateHeaderSelection = onUpdateHeaderSelection
        self.onFinishHeaderSelection = onFinishHeaderSelection
        if isEditingHeaderSelection == false {
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

    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)

        guard let page, let pageFrame = pageFrameInView() else { return }

        if isEditingHeaderSelection {
            let target = hoverTarget(at: point)
            let existingHeaderSelection = displayedHeaderSelection

            guard pageFrame.contains(point) else {
                onFinishHeaderSelection?()
                updateCursor(for: point)
                needsDisplay = true
                return
            }

            let fractionPoint = headerFractionPointFromViewPoint(point, in: page)
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
                    startPointerFraction: fractionFromViewPoint(point, in: page),
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
                    startPointerFraction: fractionFromViewPoint(point, in: page),
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
                    startPointerFraction: fractionFromViewPoint(point, in: page),
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
        let centerFraction = fractionFromViewPoint(point, in: page)
        onCreateBand?(centerFraction)
        updateCursor(for: point)
    }

    override func mouseDragged(with event: NSEvent) {
        if var headerDragState, let page {
            let point = convert(event.locationInWindow, from: nil)
            headerDragState.currentPoint = headerFractionPointFromViewPoint(point, in: page)
            self.headerDragState = headerDragState
            headerDraft = headerSelection(from: headerDragState)
            updateCursor(for: point)
            needsDisplay = true
            return
        }

        guard let page, var dragState else { return }
        let point = convert(event.locationInWindow, from: nil)
        let fraction = fractionFromViewPoint(point, in: page)

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
        if let headerDragState {
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
            updateCursor(for: convert(event.locationInWindow, from: nil))
            needsDisplay = true
            return
        }

        guard let dragState else { return }

        if let band = bands.first(where: { $0.id == dragState.bandID }) {
            let topChanged = abs(band.topFraction - dragState.topFraction) > 0.0001
            let bottomChanged = abs(band.bottomFraction - dragState.bottomFraction) > 0.0001
            if topChanged || bottomChanged {
                onUpdateBand?(dragState.bandID, dragState.topFraction, dragState.bottomFraction)
            }
        }

        self.dragState = nil
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

    private func fractionFromViewPoint(_ point: CGPoint, in page: PDFPage) -> Double {
        guard let pdfView else { return 0.5 }
        let pagePoint = pdfView.convert(point, to: page)
        let pageBounds = page.bounds(for: .mediaBox)
        let normalizedY = (pagePoint.y - pageBounds.minY) / pageBounds.height
        return max(0.0, min(1.0, 1.0 - normalizedY))
    }

    private func headerFractionPointFromViewPoint(_ point: CGPoint, in page: PDFPage) -> CGPoint {
        guard let pdfView else { return CGPoint(x: 0.5, y: 0.5) }
        let pagePoint = pdfView.convert(point, to: page)
        let pageBounds = page.bounds(for: .mediaBox)
        let normalizedX = (pagePoint.x - pageBounds.minX) / pageBounds.width
        let normalizedY = (pagePoint.y - pageBounds.minY) / pageBounds.height
        return CGPoint(
            x: max(0.0, min(1.0, normalizedX)),
            y: max(0.0, min(1.0, 1.0 - normalizedY))
        )
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
