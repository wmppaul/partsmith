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
                            Text("This preview is generated from the same renderer used for PDF export.")
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
                            PDFPreviewRepresentable(pdfDocument: pdf)
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

    func makeNSView(context: Context) -> PDFPreviewContainerView {
        PDFPreviewContainerView()
    }

    func updateNSView(_ nsView: PDFPreviewContainerView, context: Context) {
        nsView.update(pdfDocument: pdfDocument)
    }
}

final class PDFPreviewContainerView: NSView {
    private let pdfView = PDFView()
    private var refreshGeneration = 0
    private var lastLayoutSize: CGSize = .zero
    private var pendingPageIndex: Int?

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
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(pdfDocument: PDFDocument) {
        guard pdfView.document !== pdfDocument else { return }
        let currentIndex = pdfView.currentPage.flatMap { pdfView.document?.index(for: $0) } ?? 0
        pendingPageIndex = min(max(0, currentIndex), max(0, pdfDocument.pageCount - 1))
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        guard bounds.size != .zero else { return }
        refreshGeneration &+= 1
        refreshPDFView(generation: refreshGeneration)
    }

    override func layout() {
        super.layout()
        guard bounds.size != .zero, bounds.size != lastLayoutSize else { return }
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
            if let index = self.pendingPageIndex, let page = self.pdfView.document?.page(at: index) {
                self.pdfView.go(to: page)
            }
            self.pendingPageIndex = nil
            self.forceScrollViewRefresh()
        }
    }

    private func forceScrollViewRefresh() {
        guard let clipView = pdfView.documentView?.enclosingScrollView?.contentView else { return }
        clipView.scroll(to: clipView.bounds.origin)
        clipView.enclosingScrollView?.reflectScrolledClipView(clipView)
        pdfView.documentView?.needsDisplay = true
        clipView.needsDisplay = true
    }
}
