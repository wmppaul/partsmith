import AppKit
import SwiftUI

struct DocumentExportCommands {
    var exportSelectedPart: () -> Void
    var exportAllParts: () -> Void
    var canExportSelectedPart: Bool
    var canExportAllParts: Bool
}

struct DocumentBandCommands {
    var deleteSelectedBand: () -> Void
    var canDeleteSelectedBand: Bool
}

private struct DocumentExportCommandsKey: FocusedValueKey {
    typealias Value = DocumentExportCommands
}

private struct DocumentBandCommandsKey: FocusedValueKey {
    typealias Value = DocumentBandCommands
}

extension FocusedValues {
    var documentExportCommands: DocumentExportCommands? {
        get { self[DocumentExportCommandsKey.self] }
        set { self[DocumentExportCommandsKey.self] = newValue }
    }

    var documentBandCommands: DocumentBandCommands? {
        get { self[DocumentBandCommandsKey.self] }
        set { self[DocumentBandCommandsKey.self] = newValue }
    }
}

struct DocumentRootView: View {
    @ObservedObject var document: PartsmithDocument
    @Environment(\.undoManager) private var undoManager

    @State private var presentedError: PresentedError?
    @State private var showingAddPartSheet = false
    @State private var showingStaffDetectionSheet = false
    @StateObject private var scoreExtractionWindow = ScoreExtractionWindowController()

    var body: some View {
        NavigationSplitView {
            PartsSidebarView(
                document: document,
                onNewPartRequested: {
                    document.setHeaderSelectionEditing(false)
                    document.setPageRectificationEditing(false)
                    showingAddPartSheet = true
                }
            )
        } detail: {
            VStack(spacing: 0) {
                HSplitView {
                    Group {
                        switch document.canvasMode {
                        case .source:
                            SourceCanvasView(
                                document: document,
                                onImportRequested: importPDF,
                                onImportDropped: importPDF(from:),
                                onNewPartRequested: {
                                    document.setHeaderSelectionEditing(false)
                                    document.setPageRectificationEditing(false)
                                    showingAddPartSheet = true
                                },
                                onAutoExtractRequested: showAutoExtract
                            )
                        case .preview:
                            PartPreviewView(
                                document: document,
                                onExportRequested: exportSelectedPart
                            )
                        }
                    }
                    .frame(minWidth: 760, maxWidth: .infinity, maxHeight: .infinity)

                    InspectorView(document: document)
                        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, maxHeight: .infinity)
                }

                if let progress = document.rectificationAutoProgress {
                    RectificationStatusBar(progress: progress)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(
            \.documentExportCommands,
            DocumentExportCommands(
                exportSelectedPart: exportSelectedPart,
                exportAllParts: exportAllParts,
                canExportSelectedPart: exportSelectedDisabled == false,
                canExportAllParts: exportAllDisabled == false
            )
        )
        .focusedSceneValue(
            \.documentBandCommands,
            DocumentBandCommands(
                deleteSelectedBand: deleteSelectedBand,
                canDeleteSelectedBand: document.selectedBandID != nil
            )
        )
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Import PDF", systemImage: "doc.badge.plus") {
                    importPDF()
                }

                if document.canvasMode == .source, document.project.pageCount > 0 {
                    Button("Auto Extract", systemImage: "wand.and.stars", action: showAutoExtract)
                        .labelStyle(.titleAndIcon)
                        .disabled(document.isAutoEstimatingPageRectifications && !scoreExtractionWindow.isPresented)
                        .help("Start here: optionally align scanned pages, choose instruments, and extract parts offline.")

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

                    Button("Find Staves", systemImage: "music.note.list") {
                        document.setHeaderSelectionEditing(false)
                        document.setPageRectificationEditing(false)
                        showingStaffDetectionSheet = true
                    }
                    .disabled(document.project.parts.isEmpty || document.isAutoEstimatingPageRectifications)
                    .help("Find editable staff bands on this page using offline image analysis. Create a part first.")



                    Menu("Copy Bands") {
                        Button("All Parts to Next Page") {
                            document.copyCurrentPageBandsToNextPage()
                        }
                        .disabled(document.canCopyCurrentPageBandsToNextPage == false)

                        Button("Selected Part to Next Page") {
                            document.copySelectedPartBandsToNextPage()
                        }
                        .disabled(document.canCopySelectedPartBandsToNextPage == false)

                        Divider()

                        Button("All Parts to Remaining Pages") {
                            document.copyCurrentPageBandsToRemainingPages()
                        }
                        .disabled(document.canCopyCurrentPageBandsToRemainingPages == false)

                        Button("Selected Part to Remaining Pages") {
                            document.copySelectedPartBandsToRemainingPages()
                        }
                        .disabled(document.canCopySelectedPartBandsToRemainingPages == false)
                    }
                    .disabled(
                        document.canCopyCurrentPageBandsToNextPage == false &&
                        document.canCopySelectedPartBandsToNextPage == false &&
                        document.canCopyCurrentPageBandsToRemainingPages == false &&
                        document.canCopySelectedPartBandsToRemainingPages == false
                    )

                    Button(document.zoomMode == .fitWidth ? "Fit Width" : "Fit Width") {
                        document.zoomMode = .fitWidth
                    }

                    Button(document.zoomMode == .fitPage ? "Fit Page" : "Fit Page") {
                        document.zoomMode = .fitPage
                    }
                }

                Button(primaryExportTitle, systemImage: "square.and.arrow.up") {
                    performPrimaryExport()
                }
                .disabled(primaryExportDisabled)
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Picker(
                    "View",
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
        .sheet(isPresented: $showingStaffDetectionSheet) {
            StaffDetectionView(document: document)
        }
        .background(ScoreExtractionWindowAnchor(controller: scoreExtractionWindow).frame(width: 0, height: 0))
        .onDisappear { scoreExtractionWindow.close() }
        .onDeleteCommand(perform: deleteSelectedBand)
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func showAutoExtract() {
        document.setHeaderSelectionEditing(false)
        document.setPageRectificationEditing(false)
        scoreExtractionWindow.show(document: document)
    }

    private var exportableParts: [PartModel] {
        document.project.parts.filter { part in
            document.project.bands.contains { $0.partID == part.id && !$0.excluded }
        }
    }

    private var exportSelectedDisabled: Bool {
        guard let selectedPartID = document.selectedPartID else { return true }
        guard document.pdfDocument != nil else { return true }
        return document.project.bands.contains(where: { $0.partID == selectedPartID && !$0.excluded }) == false
    }

    private var exportAllDisabled: Bool {
        guard document.pdfDocument != nil else { return true }
        return exportableParts.isEmpty
    }

    private var primaryExportTitle: String {
        document.canvasMode == .source ? "Export All" : "Export PDF"
    }

    private var primaryExportDisabled: Bool {
        document.canvasMode == .source ? exportAllDisabled : exportSelectedDisabled
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

    private func exportAllParts() {
        guard exportAllDisabled == false else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        let folderName = sanitizedFilename(document.project.projectName, fallback: "Partsmith Export")
        panel.message = "Choose where to create the \"\(folderName)\" export folder."
        panel.prompt = "Export All"

        guard panel.runModal() == .OK, let parentURL = panel.url else { return }

        let exportFolderURL = uniqueExportFolderURL(named: folderName, inside: parentURL)

        do {
            try PartPDFExporter.exportAll(document: document, to: exportFolderURL)
        } catch {
            presentedError = PresentedError(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func performPrimaryExport() {
        if document.canvasMode == .source {
            exportAllParts()
        } else {
            exportSelectedPart()
        }
    }

    private func deleteSelectedBand() {
        guard let selectedBandID = document.selectedBandID else { return }
        document.deleteBand(selectedBandID)
    }

    private func uniqueExportFolderURL(named folderName: String, inside parentURL: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = parentURL.appendingPathComponent(folderName, isDirectory: true)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = parentURL.appendingPathComponent("\(folderName) \(suffix)", isDirectory: true)
            suffix += 1
        }

        return candidate
    }

    private func sanitizedFilename(_ string: String, fallback: String = "Part") -> String {
        let sanitized = string
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }
}

private struct RectificationStatusBar: View {
    var progress: RectificationAutoProgress

    var body: some View {
        HStack(spacing: 12) {
            Text("Deskew")
                .font(.subheadline.weight(.semibold))

            ProgressView(value: progress.fractionComplete)
                .progressViewStyle(.linear)
                .frame(width: 220)

            Text("\(progress.completedPageCount)/\(progress.totalPageCount)")
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Text("\(progress.estimatedPageCount) found")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
