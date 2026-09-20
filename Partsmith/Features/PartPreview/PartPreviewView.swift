import PDFKit
import SwiftUI

struct PartPreviewView: View {
    @ObservedObject var document: PartsmithDocument
    var onExportRequested: () -> Void

    var body: some View {
        if let selectedPart = document.selectedPart {
            Group {
                switch Result(catching: { try PartPDFExporter.previewDocument(for: selectedPart.id, in: document) }) {
                case .success(let previewDocument):
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Previewing \(selectedPart.name)")
                                    .font(.headline)
                                Text("This preview is generated from the same renderer used for PDF export.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Export PDF", systemImage: "square.and.arrow.up") {
                                onExportRequested()
                            }
                        }
                        .padding(16)

                        Divider()

                        PDFPreviewRepresentable(pdfDocument: previewDocument)
                    }
                case .failure(let error):
                    ContentUnavailableView {
                        Label("Preview Unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
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
        let documentChanged = pdfView.document !== pdfDocument
        if documentChanged {
            pdfView.document = pdfDocument
        }

        pdfView.autoScales = true
        guard bounds.size != .zero else { return }

        refreshGeneration &+= 1
        refreshPDFView(generation: refreshGeneration)
    }

    override func layout() {
        super.layout()
        guard bounds.size != .zero else { return }
        refreshGeneration &+= 1
        refreshPDFView(generation: refreshGeneration)
    }

    private func refreshPDFView(generation: Int) {
        guard generation == refreshGeneration else { return }

        let firstPage = pdfView.document?.page(at: 0)
        pdfView.layoutDocumentView()
        pdfView.documentView?.needsLayout = true
        pdfView.documentView?.layoutSubtreeIfNeeded()
        pdfView.documentView?.needsDisplay = true
        pdfView.needsDisplay = true
        pdfView.displayIfNeeded()
        if let firstPage {
            pdfView.go(to: firstPage)
        }
        forceScrollViewRefresh()

        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.refreshGeneration else { return }
            let firstPage = self.pdfView.document?.page(at: 0)
            self.pdfView.layoutDocumentView()
            self.pdfView.documentView?.needsLayout = true
            self.pdfView.documentView?.layoutSubtreeIfNeeded()
            self.pdfView.documentView?.needsDisplay = true
            self.pdfView.needsDisplay = true
            self.pdfView.displayIfNeeded()
            if let firstPage {
                self.pdfView.go(to: firstPage)
            }
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
