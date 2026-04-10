import PDFKit
import SwiftUI

struct PartPreviewView: View {
    @ObservedObject var document: PartsmithDocument

    var body: some View {
        if let selectedPart = document.selectedPart {
            Group {
                if let previewDocument = try? PartPDFExporter.previewDocument(for: selectedPart.id, in: document) {
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
                        }
                        .padding(16)

                        Divider()

                        PDFPreviewRepresentable(pdfDocument: previewDocument)
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Preview Yet", systemImage: "music.note")
                    } description: {
                        Text("Create bands for the selected part to generate its stacked part preview.")
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

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.displaysPageBreaks = true
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== pdfDocument {
            nsView.document = pdfDocument
        }
        nsView.autoScales = true
    }
}
