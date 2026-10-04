import PDFKit
import SwiftUI

struct PartPreviewView: View {
    @ObservedObject var document: PartsmithDocument
    var onExportRequested: () -> Void
    @StateObject private var renderer = PartPreviewRenderer()

    private var snapshot: PartPreviewSnapshot? {
        guard let part = document.selectedPart, let source = document.sourcePDFData else { return nil }
        return PartPreviewSnapshot(partID: part.id, project: document.project, sourcePDFData: source)
    }

    var body: some View {
        Group {
            if let selectedPart = document.selectedPart {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Previewing \(selectedPart.name)").font(.headline)
                            Text("Click a system, then drag its top or bottom edge to crop. Changes also appear in the score and exported PDF.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            RestAutoStatusView(document: document)
                        }
                        Spacer()
                        Button("Export PDF", systemImage: "square.and.arrow.up", action: onExportRequested)
                            .disabled(renderer.isRendering || renderer.pdfDocument == nil || renderer.errorMessage != nil)
                    }
                    .padding(16)
                    Divider()
                    ZStack(alignment: .topTrailing) {
                        if document.sourcePDFData == nil {
                            ContentUnavailableView("Source PDF Needed", systemImage: "doc",
                                description: Text("Import a score PDF to preview this part."))
                        } else if let error = renderer.errorMessage {
                            ContentUnavailableView {
                                Label("Preview Unavailable", systemImage: "exclamationmark.triangle")
                            } description: { Text(error) }
                        } else if let pdf = renderer.pdfDocument {
                            PDFPreviewRepresentable(pdfDocument: pdf, plan: renderer.renderPlan,
                                project: renderer.renderedSnapshot?.project,
                                selectedBandID: document.selectedBandID,
                                canEdit: !renderer.isRendering && renderer.renderedSnapshot == snapshot,
                                sourceBounds: { document.pdfDocument?.page(at: $0)?.bounds(for: .mediaBox) },
                                onSelect: { id in
                                    if let id, let band = document.band(withID: id), document.currentPageIndex != band.pageIndex {
                                        document.setCurrentPage(band.pageIndex)
                                    }
                                    document.selectBand(id)
                                },
                                onCrop: { original, edges in
                                    guard renderer.renderedSnapshot == snapshot,
                                          document.band(withID: original.id) == original else { return }
                                    document.updateBand(original.id, topFraction: edges.topFraction,
                                        bottomFraction: edges.bottomFraction)
                                })
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        if renderer.isRendering {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(renderer.pdfDocument == nil ? "Preparing preview…" : "Updating preview…")
                            }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding(12)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Select a Part", systemImage: "sidebar.left")
                } description: {
                    Text("Choose a part in the sidebar to preview the extracted output layout.")
                }
            }
        }
        .onAppear(perform: updatePreview)
        .onChange(of: snapshot) { updatePreview() }
        .onChange(of: renderer.scaleInfo) { document.previewScaleInfo = renderer.scaleInfo }
        .onDisappear { renderer.cancel(); document.previewScaleInfo = nil }
    }

    private func updatePreview() {
        if let snapshot { renderer.update(snapshot) }
        else { renderer.cancel(clearPreview: true) }
    }
}

private struct PDFPreviewRepresentable: NSViewRepresentable {
    var pdfDocument: PDFDocument
    var plan: PartRenderPlan?
    var project: ProjectData?
    var selectedBandID: UUID?
    var canEdit: Bool
    var sourceBounds: (Int) -> CGRect?
    var onSelect: (UUID?) -> Void
    var onCrop: (BandModel, PartPreviewCropGeometry.CropEdges) -> Void

    func makeNSView(context: Context) -> PDFPreviewContainerView {
        PDFPreviewContainerView()
    }

    func updateNSView(_ nsView: PDFPreviewContainerView, context: Context) {
        nsView.update(pdfDocument: pdfDocument, plan: plan, project: project,
            selectedBandID: selectedBandID, canEdit: canEdit, sourceBounds: sourceBounds,
            onSelect: onSelect, onCrop: onCrop)
    }
}

final class PDFPreviewContainerView: NSView {
    private let pdfView = PDFView()
    private let cropOverlay = PreviewCropOverlayView()
    private var overlayObservers: [NSObjectProtocol] = []
    private var refreshGeneration = 0
    private var lastLayoutSize: CGSize = .zero
    private var pendingPageIndex: Int?
    private var pendingCropAnchor: (bandID: UUID, offsetAbove: CGFloat)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.displaysPageBreaks = true

        addSubview(pdfView)
        cropOverlay.pdfView = pdfView
        cropOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cropOverlay)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cropOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            cropOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            cropOverlay.topAnchor.constraint(equalTo: topAnchor),
            cropOverlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { overlayObservers.forEach(NotificationCenter.default.removeObserver) }

    func update(pdfDocument: PDFDocument, plan: PartRenderPlan? = nil, project: ProjectData? = nil,
                selectedBandID: UUID? = nil, canEdit: Bool = false,
                sourceBounds: @escaping (Int) -> CGRect? = { _ in nil },
                onSelect: @escaping (UUID?) -> Void = { _ in },
                onCrop: @escaping (BandModel, PartPreviewCropGeometry.CropEdges) -> Void = { _, _ in }) {
        let changed = pdfView.document !== pdfDocument
        if changed { pendingCropAnchor = cropOverlay.viewportAnchor() }
        cropOverlay.update(plan: plan, project: project, selectedBandID: selectedBandID,
            canEdit: canEdit, sourceBounds: sourceBounds, onSelect: onSelect, onCrop: onCrop,
            documentChanged: changed)
        guard changed else { return }
        let currentIndex = pdfView.currentPage.flatMap { pdfView.document?.index(for: $0) } ?? 0
        pendingPageIndex = min(max(0, currentIndex), max(0, pdfDocument.pageCount - 1))
        let wasAutoScaled = pdfView.autoScales
        let scale = pdfView.scaleFactor
        pdfView.document = pdfDocument
        pdfView.autoScales = wasAutoScaled
        if !wasAutoScaled { pdfView.scaleFactor = scale }
        guard bounds.size != .zero else { return }
        refreshGeneration &+= 1
        refreshPDFView(generation: refreshGeneration)
    }

    override func layout() {
        super.layout()
        cropOverlay.needsDisplay = true
        guard bounds.size != .zero, bounds.size != lastLayoutSize else { return }
        cropOverlay.cancelDrag()
        lastLayoutSize = bounds.size
        refreshGeneration &+= 1
        refreshPDFView(generation: refreshGeneration)
    }

    private func refreshPDFView(generation: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }
            self.pdfView.layoutDocumentView()
            self.pdfView.documentView?.needsLayout = true
            self.pdfView.documentView?.layoutSubtreeIfNeeded()
            self.pdfView.documentView?.needsDisplay = true
            self.pdfView.needsDisplay = true
            if let anchor = self.pendingCropAnchor, self.cropOverlay.restoreViewportAnchor(anchor) {
                // Keep the edited system in view even if it moves to another output page.
            } else if let index = self.pendingPageIndex, let page = self.pdfView.document?.page(at: index) {
                self.pdfView.go(to: page)
            }
            self.pendingCropAnchor = nil
            self.pendingPageIndex = nil
            self.forceScrollViewRefresh()
            self.configureOverlayObservers()
            self.cropOverlay.needsDisplay = true
        }
    }

    private func forceScrollViewRefresh() {
        guard let clipView = pdfView.documentView?.enclosingScrollView?.contentView else { return }
        clipView.scroll(to: clipView.bounds.origin)
        clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
        pdfView.documentView?.needsDisplay = true
        clipView.needsDisplay = true
    }

    private func configureOverlayObservers() {
        overlayObservers.forEach(NotificationCenter.default.removeObserver)
        overlayObservers.removeAll()
        for name in [Notification.Name.PDFViewScaleChanged, .PDFViewPageChanged, .PDFViewVisiblePagesChanged] {
            overlayObservers.append(NotificationCenter.default.addObserver(forName: name, object: pdfView,
                queue: .main) { [weak self] _ in self?.cropOverlay.cancelDrag() })
        }
        if let clip = pdfView.documentView?.enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            overlayObservers.append(NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                object: clip, queue: .main) { [weak self] _ in self?.cropOverlay.cancelDrag() })
        }
    }
}

/// Editing adornments live outside the PDF. Dragging never regenerates pages;
/// one source-band mutation on mouse-up drives the ordinary preview/export path.
private final class PreviewCropOverlayView: NSView {
    typealias Edge = PartPreviewCropGeometry.Edge
    typealias Edges = PartPreviewCropGeometry.CropEdges
    struct Entry { var pageIndex: Int; var placement: BandPlacement; var band: BandModel }
    struct Drag {
        var entry: Entry
        var edge: Edge
        var startPDFY: CGFloat
        var sourceBounds: CGRect
        var draft: Edges
    }
    weak var pdfView: PDFView?
    private var entries: [UUID: Entry] = [:]
    private var selectedID: UUID?
    private var hoveredID: UUID?
    private var canEdit = false
    private var drag: Drag?
    private var tracking: NSTrackingArea?
    private var sourceBounds: (Int) -> CGRect? = { _ in nil }
    private var onSelect: (UUID?) -> Void = { _ in }
    private var onCrop: (BandModel, Edges) -> Void = { _, _ in }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func update(plan: PartRenderPlan?, project: ProjectData?, selectedBandID: UUID?, canEdit: Bool,
                sourceBounds: @escaping (Int) -> CGRect?, onSelect: @escaping (UUID?) -> Void,
                onCrop: @escaping (BandModel, Edges) -> Void, documentChanged: Bool) {
        if documentChanged || !canEdit || selectedID != selectedBandID { cancelDrag() }
        let bands = Dictionary(uniqueKeysWithValues: (project?.bands ?? []).map { ($0.id, $0) })
        var next: [UUID: Entry] = [:]
        for page in plan?.pages ?? [] {
            for placement in page.placements {
                guard placement.restBarCount == nil, let band = bands[placement.bandID],
                      band.generatedRest == nil, band.restReplacement == nil, !band.excluded else { continue }
                next[band.id] = Entry(pageIndex: page.index, placement: placement, band: band)
            }
        }
        entries = next
        selectedID = selectedBandID
        self.canEdit = canEdit
        self.sourceBounds = sourceBounds
        self.onSelect = onSelect
        self.onCrop = onCrop
        if let drag, entries[drag.entry.band.id]?.band != drag.entry.band { cancelDrag() }
        needsDisplay = true
    }

    private func page(for entry: Entry) -> PDFPage? { pdfView?.document?.page(at: entry.pageIndex) }
    private func frame(for entry: Entry, edges: Edges? = nil) -> CGRect? {
        guard let pdfView, let page = page(for: entry) else { return nil }
        var rect = entry.placement.destinationRect
        if let edges, let source = sourceBounds(entry.band.pageIndex) {
            let scale = rect.height / entry.placement.sourceRect.height
            let topDelta = CGFloat(entry.band.topFraction - edges.topFraction) * source.height * scale
            let bottomDelta = CGFloat(entry.band.bottomFraction - edges.bottomFraction) * source.height * scale
            rect = CGRect(x: rect.minX, y: rect.minY + bottomDelta, width: rect.width,
                height: rect.height + topDelta - bottomDelta)
        }
        return convert(pdfView.convert(rect, from: page), from: pdfView)
    }

    private func pointOnPage(_ point: CGPoint, entry: Entry) -> CGPoint? {
        guard let pdfView, let page = page(for: entry) else { return nil }
        return pdfView.convert(pdfView.convert(point, from: self), to: page)
    }

    private func edge(at point: CGPoint, rect: CGRect) -> Edge? {
        guard point.x >= rect.minX - 6, point.x <= rect.maxX + 6 else { return nil }
        let top = abs(point.y - rect.minY), bottom = abs(point.y - rect.maxY)
        if min(top, bottom) <= 9 { return top <= bottom ? .top : .bottom }
        return nil
    }

    private func hit(at point: CGPoint) -> Entry? {
        guard canEdit, let pdfView else { return nil }
        if let id = selectedID, let entry = entries[id], let rect = frame(for: entry),
           edge(at: point, rect: rect) != nil { return entry }
        let pdfPoint = pdfView.convert(point, from: self)
        guard let page = pdfView.page(for: pdfPoint, nearest: false), let index = pdfView.document?.index(for: page) else { return nil }
        return entries.values.first { $0.pageIndex == index && frame(for: $0)?.contains(point) == true }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return hit(at: local) == nil ? nil : self
    }

    override func draw(_ dirtyRect: NSRect) {
        guard canEdit else { return }
        if let id = hoveredID, id != selectedID, let entry = entries[id], let rect = frame(for: entry) {
            NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke()
            NSBezierPath(rect: rect).stroke()
        }
        guard let id = selectedID, let entry = entries[id], let original = frame(for: entry),
              let rect = frame(for: entry, edges: drag?.draft), rect.intersects(bounds) else { return }
        if drag != nil {
            NSColor.white.withAlphaComponent(0.65).setFill()
            if rect.minY > original.minY {
                NSRect(x: original.minX, y: original.minY, width: original.width,
                    height: min(rect.minY, original.maxY) - original.minY).fill()
            }
            if rect.maxY < original.maxY {
                NSRect(x: original.minX, y: max(rect.maxY, original.minY), width: original.width,
                    height: original.maxY - max(rect.maxY, original.minY)).fill()
            }
        }
        NSColor.controlAccentColor.setStroke()
        let outline = NSBezierPath(rect: rect); outline.lineWidth = 1.5; outline.stroke()
        for y in [rect.minY, rect.maxY] {
            let handle = NSRect(x: rect.midX - 24, y: y - 4, width: 48, height: 8)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: handle, xRadius: 4, yRadius: 4).fill()
            NSColor.white.setStroke()
            let grip = NSBezierPath(); grip.move(to: CGPoint(x: handle.minX + 12, y: y))
            grip.line(to: CGPoint(x: handle.maxX - 12, y: y)); grip.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let entry = hit(at: point), let rect = frame(for: entry) else { return }
        window?.makeFirstResponder(self)
        let clickedEdge = edge(at: point, rect: rect)
        selectedID = entry.band.id
        onSelect(entry.band.id)
        if let clickedEdge, let source = sourceBounds(entry.band.pageIndex),
           let pagePoint = pointOnPage(point, entry: entry) {
            drag = Drag(entry: entry, edge: clickedEdge, startPDFY: pagePoint.y, sourceBounds: source,
                draft: Edges(topFraction: entry.band.topFraction, bottomFraction: entry.band.bottomFraction))
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard canEdit, var drag, let point = pointOnPage(convert(event.locationInWindow, from: nil), entry: drag.entry),
              let edges = PartPreviewCropGeometry.cropEdges(for: drag.entry.band, placement: drag.entry.placement,
                sourcePageBounds: drag.sourceBounds, edge: drag.edge, outputDeltaY: point.y - drag.startPDFY) else { return }
        drag.draft = edges
        self.drag = drag
        NSCursor.resizeUpDown.set()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let pending = drag else { return }
        mouseDragged(with: event)
        let edges = drag?.draft ?? pending.draft
        cancelDrag()
        if canEdit, entries[pending.entry.band.id]?.band == pending.entry.band,
           edges.topFraction != pending.entry.band.topFraction || edges.bottomFraction != pending.entry.band.bottomFraction {
            onCrop(pending.entry.band, edges)
        }
    }

    func cancelDrag() { drag = nil; needsDisplay = true }
    override func cancelOperation(_ sender: Any?) { cancelDrag() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancelDrag() } else { super.keyDown(with: event) }
    }
    override func scrollWheel(with event: NSEvent) {
        cancelDrag()
        pdfView?.documentView?.enclosingScrollView?.scrollWheel(with: event)
    }
    override func magnify(with event: NSEvent) {
        cancelDrag()
        guard let pdfView else { return }
        pdfView.autoScales = false
        pdfView.scaleFactor = min(pdfView.maxScaleFactor,
            max(pdfView.minScaleFactor, pdfView.scaleFactor * (1 + event.magnification)))
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate], owner: self)
        addTrackingArea(area); tracking = area
        super.updateTrackingAreas()
    }
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil), entry = hit(at: convert(event.locationInWindow, from: nil))
        hoveredID = entry?.band.id
        if let entry, let rect = frame(for: entry), edge(at: point, rect: rect) != nil { NSCursor.resizeUpDown.set() }
        else if entry != nil { NSCursor.pointingHand.set() }
        else { NSCursor.arrow.set() }
        needsDisplay = true
    }
    override func cursorUpdate(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseExited(with event: NSEvent) { hoveredID = nil; NSCursor.arrow.set(); needsDisplay = true }

    func viewportAnchor() -> (bandID: UUID, offsetAbove: CGFloat)? {
        guard let id = selectedID, let entry = entries[id], let rect = frame(for: entry), rect.intersects(bounds),
              let point = pointOnPage(CGPoint(x: rect.midX, y: bounds.minY), entry: entry) else { return nil }
        return (id, point.y - entry.placement.destinationRect.maxY)
    }

    func restoreViewportAnchor(_ anchor: (bandID: UUID, offsetAbove: CGFloat)) -> Bool {
        guard let pdfView, let entry = entries[anchor.bandID], let page = page(for: entry) else { return false }
        pdfView.go(to: PDFDestination(page: page, at: CGPoint(x: page.bounds(for: .mediaBox).minX,
            y: entry.placement.destinationRect.maxY + anchor.offsetAbove)))
        return true
    }
}
