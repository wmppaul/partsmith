import AppKit
import SwiftUI

struct DocumentRootView: View {
    @ObservedObject var document: PartsmithDocument
    @Environment(\.undoManager) private var undoManager

    @State private var presentedError: PresentedError?
    @State private var showingAddPartSheet = false

    var body: some View {
        NavigationSplitView {
            PartsSidebarView(
                document: document,
                onNewPartRequested: { showingAddPartSheet = true }
            )
        } detail: {
            HSplitView {
                Group {
                    switch document.canvasMode {
                    case .source:
                        SourceCanvasView(
                            document: document,
                            onImportRequested: importPDF,
                            onImportDropped: importPDF(from:),
                            onNewPartRequested: { showingAddPartSheet = true }
                        )
                    case .preview:
                        PartPreviewView(document: document)
                    }
                }
                .frame(minWidth: 760, maxWidth: .infinity, maxHeight: .infinity)

                InspectorView(document: document)
                    .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Import PDF", systemImage: "doc.badge.plus") {
                    importPDF()
                }

                if document.canvasMode == .source, document.project.pageCount > 0 {
                    Button {
                        document.previousPage()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(document.currentPageIndex == 0)

                    Text("Page \(document.currentPageIndex + 1) of \(document.project.pageCount)")
                        .monospacedDigit()

                    Button {
                        document.nextPage()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(document.currentPageIndex + 1 >= document.project.pageCount)

                    Button("Copy To Next Page", systemImage: "doc.on.doc") {
                        document.copyCurrentPageBandsToNextPage()
                    }
                    .disabled(document.canCopyCurrentPageBandsToNextPage == false)

                    Button(document.zoomMode == .fitWidth ? "Fit Width" : "Fit Width") {
                        document.zoomMode = .fitWidth
                    }

                    Button(document.zoomMode == .fitPage ? "Fit Page" : "Fit Page") {
                        document.zoomMode = .fitPage
                    }
                }

                Button("Export PDF", systemImage: "square.and.arrow.up") {
                    exportSelectedPart()
                }
                .disabled(exportDisabled)

                Picker(
                    "Mode",
                    selection: Binding(
                        get: { document.canvasMode },
                        set: { document.canvasMode = $0 }
                    )
                ) {
                    ForEach(CanvasMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .disabled(document.pdfDocument == nil)
            }
        }
        .onAppear {
            document.undoManager = undoManager
        }
        .onChange(of: undoManager) { _, newValue in
            document.undoManager = newValue
        }
        .sheet(isPresented: $showingAddPartSheet) {
            AddPartSheet(document: document, isPresented: $showingAddPartSheet)
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var exportDisabled: Bool {
        guard let selectedPartID = document.selectedPartID else { return true }
        guard document.pdfDocument != nil else { return true }
        return document.project.bands.contains(where: { $0.partID == selectedPartID && !$0.excluded }) == false
    }

    private func importPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose the full-score PDF to embed in this Partsmith project."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        importPDF(from: url)
    }

    private func importPDF(from url: URL) {
        do {
            try document.importSourcePDF(from: url)
        } catch {
            presentedError = PresentedError(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func exportSelectedPart() {
        guard let part = document.selectedPart else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(sanitizedFilename(part.name)).pdf"
        panel.message = "Export the assembled part preview as a PDF."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try PartPDFExporter.export(partID: part.id, document: document, to: url)
        } catch {
            presentedError = PresentedError(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func sanitizedFilename(_ string: String) -> String {
        string
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
