import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let partsmithProject = UTType(exportedAs: "com.partsmith.project", conformingTo: .package)
}

private struct StoredProjectEnvelope: Codable {
    var project: ProjectData
}

struct DocumentStateSnapshot {
    var project: ProjectData
    var sourcePDFData: Data?
}

final class PartsmithDocument: ReferenceFileDocument, ObservableObject {
    static var readableContentTypes: [UTType] { [.partsmithProject] }
    private static let defaultPartPalette: [NSColor] = [
        .systemBlue,
        .systemRed,
        .systemGreen,
        .systemOrange,
        .systemPurple,
        .systemTeal,
        .systemPink,
        .systemIndigo
    ]

    @Published var project: ProjectData
    @Published var sourcePDFData: Data?
    @Published var selectedPartID: UUID?
    @Published var selectedBandID: UUID?
    @Published var currentPageIndex: Int
    @Published var canvasMode: CanvasMode
    @Published var zoomMode: ZoomMode
    @Published var isEditingHeaderSelection: Bool

    weak var undoManager: UndoManager?

    private var cachedPDFDocument: PDFDocument?
    private var bandTemplateHalfHeight: Double?

    init(project: ProjectData = .empty, sourcePDFData: Data? = nil) {
        self.project = project
        self.sourcePDFData = sourcePDFData
        self.selectedPartID = project.parts.first?.id
        self.selectedBandID = nil
        self.currentPageIndex = 0
        self.canvasMode = .source
        self.zoomMode = .fitWidth
        self.isEditingHeaderSelection = false
        self.bandTemplateHalfHeight = project.bands.max(by: { $0.createdAt < $1.createdAt }).map { band in
            Self.bandHalfHeight(for: band)
        }
        rebuildPDFCache()
    }

    required init(configuration: ReadConfiguration) throws {
        let loadedProject: ProjectData
        let loadedSourcePDFData: Data?

        if let wrappers = configuration.file.fileWrappers, let projectWrapper = wrappers["project.json"]?.regularFileContents {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(StoredProjectEnvelope.self, from: projectWrapper)
            loadedProject = envelope.project
            loadedSourcePDFData = wrappers["source.pdf"]?.regularFileContents
        } else if let regularContents = configuration.file.regularFileContents {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(StoredProjectEnvelope.self, from: regularContents)
            loadedProject = envelope.project
            loadedSourcePDFData = nil
        } else {
            loadedProject = .empty
            loadedSourcePDFData = nil
        }

        self.project = loadedProject
        self.sourcePDFData = loadedSourcePDFData
        self.selectedPartID = loadedProject.parts.first?.id
        self.selectedBandID = nil
        self.currentPageIndex = 0
        self.canvasMode = .source
        self.zoomMode = .fitWidth
        self.isEditingHeaderSelection = false
        self.bandTemplateHalfHeight = loadedProject.bands.max(by: { $0.createdAt < $1.createdAt }).map { band in
            Self.bandHalfHeight(for: band)
        }
        rebuildPDFCache()
        clampSelectionsToCurrentState()
    }

    func snapshot(contentType: UTType) throws -> DocumentStateSnapshot {
        currentState()
    }

    func fileWrapper(snapshot: DocumentStateSnapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonWrapper = FileWrapper(regularFileWithContents: try encoder.encode(StoredProjectEnvelope(project: snapshot.project)))
        jsonWrapper.preferredFilename = "project.json"

        var wrappers: [String: FileWrapper] = ["project.json": jsonWrapper]

        if let sourcePDFData = snapshot.sourcePDFData {
            let pdfWrapper = FileWrapper(regularFileWithContents: sourcePDFData)
            pdfWrapper.preferredFilename = "source.pdf"
            wrappers["source.pdf"] = pdfWrapper
        }

        let directoryWrapper = FileWrapper(directoryWithFileWrappers: wrappers)
        directoryWrapper.preferredFilename = "\(snapshot.project.projectName).partsmithproject"
        return directoryWrapper
    }

    var pdfDocument: PDFDocument? {
        if cachedPDFDocument == nil, let sourcePDFData {
            cachedPDFDocument = PDFDocument(data: sourcePDFData)
        }
        return cachedPDFDocument
    }

    var selectedPart: PartModel? {
        guard let selectedPartID else { return nil }
        return project.parts.first(where: { $0.id == selectedPartID })
    }

    var selectedBand: BandModel? {
        guard let selectedBandID else { return nil }
        return project.bands.first(where: { $0.id == selectedBandID })
    }

    func part(withID partID: UUID) -> PartModel? {
        project.parts.first(where: { $0.id == partID })
    }

    func bands(on pageIndex: Int) -> [BandModel] {
        project.bands(on: pageIndex)
    }

    func bandCount(for partID: UUID) -> Int {
        project.bands.filter { $0.partID == partID && !$0.excluded }.count
    }

    func colorMap() -> [UUID: NSColor] {
        Dictionary(uniqueKeysWithValues: project.parts.map { ($0.id, $0.nsColor) })
    }

    var suggestedNewPartColor: NSColor {
        Self.defaultPartPalette[project.parts.count % Self.defaultPartPalette.count]
    }

    var canCopyCurrentPageBandsToNextPage: Bool {
        currentPageIndex + 1 < project.pageCount && project.bands.contains(where: { $0.pageIndex == currentPageIndex })
    }

    var headerSelection: SourceHeaderSelection? {
        project.projectSettings.headerSelection
    }

    var headerSelectionOnCurrentPage: SourceHeaderSelection? {
        guard let headerSelection, headerSelection.pageIndex == currentPageIndex else { return nil }
        return headerSelection
    }

    func selectPart(_ partID: UUID?) {
        selectedPartID = partID
        guard let partID else {
            selectedBandID = nil
            return
        }

        if let selectedBandID,
           let selectedBand = project.bands.first(where: { $0.id == selectedBandID }),
           selectedBand.partID != partID
        {
            self.selectedBandID = nil
        }
    }

    func selectBand(_ bandID: UUID?) {
        selectedBandID = bandID
        guard let bandID,
              let band = project.bands.first(where: { $0.id == bandID })
        else { return }

        selectedPartID = band.partID
    }

    func nextPage() {
        guard currentPageIndex + 1 < project.pageCount else { return }
        currentPageIndex += 1
        selectedBandID = nil
    }

    func previousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
        selectedBandID = nil
    }

    func setCurrentPage(_ pageIndex: Int) {
        currentPageIndex = max(0, min(pageIndex, max(0, project.pageCount - 1)))
        selectedBandID = nil
    }

    func importSourcePDF(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let pdfDocument = PDFDocument(data: data) else {
            throw NSError(domain: "Partsmith", code: 1001, userInfo: [NSLocalizedDescriptionKey: "The selected file could not be opened as a PDF."])
        }

        commit(actionName: "Import PDF") { project, sourceData in
            sourceData = data
            project.sourceFilename = url.lastPathComponent
            project.pageCount = pdfDocument.pageCount
            project.projectSettings.headerSelection = nil
            project.bands.removeAll()
        }

        currentPageIndex = 0
        selectedBandID = nil
        canvasMode = .source
        isEditingHeaderSelection = false
    }

    func createPart(name: String, color: NSColor) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let part = PartModel(
            id: UUID(),
            name: trimmedName.isEmpty ? "Part \(project.parts.count + 1)" : trimmedName,
            color: ColorData(nsColor: color),
            layoutSettings: defaultPartLayoutSettings(),
            createdAt: .now
        )

        commit(actionName: "Create Part") { project, _ in
            project.parts.append(part)
        }

        selectedPartID = part.id
        selectedBandID = nil
    }

    func deletePart(_ partID: UUID) {
        commit(actionName: "Delete Part") { project, _ in
            project.parts.removeAll { $0.id == partID }
            project.bands.removeAll { $0.partID == partID }
        }

        if selectedPartID == partID {
            selectedPartID = project.parts.first?.id
        }
        selectedBandID = nil
    }

    func updatePartName(_ partID: UUID, name: String) {
        updatePart(partID: partID, actionName: "Rename Part") { part in
            part.name = name.isEmpty ? part.name : name
        }
    }

    func updatePartColor(_ partID: UUID, color: NSColor) {
        updatePart(partID: partID, actionName: "Change Part Color") { part in
            part.color = ColorData(nsColor: color)
        }
    }

    func updateShowTitle(_ partID: UUID, showTitle: Bool) {
        updatePart(partID: partID, actionName: "Toggle Title") { part in
            part.layoutSettings.showTitle = showTitle
        }
    }

    func updatePartScale(_ partID: UUID, scale: Double) {
        updatePart(partID: partID, actionName: "Change Scale") { part in
            part.layoutSettings.scale = max(0.6, min(scale, 1.4))
        }
    }

    func updatePartGap(_ partID: UUID, gap: Double) {
        updatePart(partID: partID, actionName: "Change System Gap") { part in
            part.layoutSettings.interSystemGap = max(4, min(gap, 48))
        }
    }

    func updatePartTitleText(_ partID: UUID, titleText: String) {
        updatePart(partID: partID, actionName: "Edit Title") { part in
            part.layoutSettings.titleText = titleText
        }
    }

    func updatePartComposerText(_ partID: UUID, composerText: String) {
        updatePart(partID: partID, actionName: "Edit Composer") { part in
            part.layoutSettings.composerText = composerText
        }
    }

    func updateProjectTitleText(_ titleText: String) {
        commit(actionName: "Edit Project Title") { project, _ in
            project.projectSettings.defaultTitleText = titleText
        }
    }

    func updateProjectComposerText(_ composerText: String) {
        commit(actionName: "Edit Project Subtitle") { project, _ in
            project.projectSettings.defaultComposerText = composerText
        }
    }

    func updateProjectHeaderDisplayMode(_ mode: HeaderDisplayMode) {
        commit(actionName: "Change Header Mode") { project, _ in
            project.projectSettings.headerDisplayMode = mode
        }

        if mode == .sourceSelection {
            canvasMode = .source
        } else {
            isEditingHeaderSelection = false
        }
    }

    func setHeaderSelectionEditing(_ isEditing: Bool) {
        isEditingHeaderSelection = isEditing
        if isEditing {
            canvasMode = .source
            selectedBandID = nil
        }
    }

    func updateHeaderSelection(
        pageIndex: Int,
        topFraction: Double,
        bottomFraction: Double,
        leftFraction: Double,
        rightFraction: Double
    ) {
        let selection = SourceHeaderSelection(
            pageIndex: pageIndex,
            topFraction: topFraction,
            bottomFraction: bottomFraction,
            leftFraction: leftFraction,
            rightFraction: rightFraction
        ).normalized()

        commit(actionName: "Select Source Header") { project, _ in
            project.projectSettings.headerDisplayMode = .sourceSelection
            project.projectSettings.headerSelection = selection
        }

        isEditingHeaderSelection = false
    }

    func clearHeaderSelection() {
        commit(actionName: "Clear Source Header") { project, _ in
            project.projectSettings.headerSelection = nil
        }

        isEditingHeaderSelection = false
    }

    func updateShowPartNameLabel(_ partID: UUID, showPartNameLabel: Bool) {
        updatePart(partID: partID, actionName: "Toggle Part Name Label") { part in
            part.layoutSettings.showPartNameLabel = showPartNameLabel
        }
    }

    func createBand(on pageIndex: Int, centerFraction: Double, partID: UUID) {
        let halfHeight = preferredHalfHeight()
        let band = BandModel(
            id: UUID(),
            pageIndex: pageIndex,
            partID: partID,
            topFraction: max(0, centerFraction - halfHeight),
            bottomFraction: min(1, centerFraction + halfHeight),
            leftFraction: 0,
            rightFraction: 0,
            excluded: false,
            createdAt: .now
        ).normalized()

        commit(actionName: "Create Band") { project, _ in
            project.bands.append(band)
        }

        bandTemplateHalfHeight = halfHeight
        selectedBandID = band.id
        selectedPartID = partID
    }

    func updateBand(_ bandID: UUID, topFraction: Double, bottomFraction: Double) {
        commit(actionName: "Resize Band") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].topFraction = topFraction
            project.bands[index].bottomFraction = bottomFraction
            project.bands[index] = project.bands[index].normalized()
        }

        if let updatedBand = project.bands.first(where: { $0.id == bandID }) {
            bandTemplateHalfHeight = Self.bandHalfHeight(for: updatedBand)
        }
    }

    func copyCurrentPageBandsToNextPage() {
        guard canCopyCurrentPageBandsToNextPage else { return }

        let sourcePageIndex = currentPageIndex
        let destinationPageIndex = currentPageIndex + 1
        let sourceBands = project.bands
            .filter { $0.pageIndex == sourcePageIndex }
            .sorted {
                if $0.partID != $1.partID {
                    return $0.partID.uuidString < $1.partID.uuidString
                }
                return $0.createdAt < $1.createdAt
            }

        guard sourceBands.isEmpty == false else { return }

        let copyStartDate = Date()
        let copiedBands = sourceBands.enumerated().map { offset, band in
            var copy = band
            copy.id = UUID()
            copy.pageIndex = destinationPageIndex
            copy.createdAt = copyStartDate.addingTimeInterval(Double(offset) * 0.001)
            return copy
        }

        commit(actionName: "Copy Bands To Next Page") { project, _ in
            project.bands.removeAll { $0.pageIndex == destinationPageIndex }
            project.bands.append(contentsOf: copiedBands)
        }

        currentPageIndex = destinationPageIndex
        selectedBandID = nil
    }

    func nudgeBandTop(_ bandID: UUID, delta: Double) {
        guard let band = project.bands.first(where: { $0.id == bandID }) else { return }
        updateBand(bandID, topFraction: band.topFraction + delta, bottomFraction: band.bottomFraction)
    }

    func nudgeBandBottom(_ bandID: UUID, delta: Double) {
        guard let band = project.bands.first(where: { $0.id == bandID }) else { return }
        updateBand(bandID, topFraction: band.topFraction, bottomFraction: band.bottomFraction + delta)
    }

    func toggleBandExclusion(_ bandID: UUID, excluded: Bool) {
        commit(actionName: excluded ? "Exclude Band" : "Include Band") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].excluded = excluded
        }
    }

    func deleteBand(_ bandID: UUID) {
        commit(actionName: "Delete Band") { project, _ in
            project.bands.removeAll { $0.id == bandID }
        }
        if selectedBandID == bandID {
            selectedBandID = nil
        }
    }

    private func updatePart(partID: UUID, actionName: String, mutation: (inout PartModel) -> Void) {
        commit(actionName: actionName) { project, _ in
            guard let index = project.parts.firstIndex(where: { $0.id == partID }) else { return }
            mutation(&project.parts[index])
        }
    }

    private func defaultPartLayoutSettings() -> PartLayoutSettings {
        PartLayoutSettings(
            showTitle: true,
            titleText: "",
            composerText: "",
            scale: max(0.6, min(project.projectSettings.defaultScale, 1.4)),
            interSystemGap: max(4, min(project.projectSettings.interSystemGap, 48)),
            showPartNameLabel: false
        )
    }

    private func preferredHalfHeight() -> Double {
        if let selectedBandID,
           let selectedBand = project.bands.first(where: { $0.id == selectedBandID })
        {
            return Self.bandHalfHeight(for: selectedBand)
        }

        if let bandTemplateHalfHeight {
            return bandTemplateHalfHeight
        }

        if let mostRecentBand = project.bands.max(by: { $0.createdAt < $1.createdAt }) {
            return Self.bandHalfHeight(for: mostRecentBand)
        }

        return 0.055
    }

    private static func bandHalfHeight(for band: BandModel) -> Double {
        let normalizedBand = band.normalized()
        let rawHalfHeight = (normalizedBand.bottomFraction - normalizedBand.topFraction) / 2
        return max(0.01, min(rawHalfHeight, 0.49))
    }

    private func currentState() -> DocumentStateSnapshot {
        DocumentStateSnapshot(project: project, sourcePDFData: sourcePDFData)
    }

    private func commit(actionName: String, mutation: (inout ProjectData, inout Data?) -> Void) {
        let previousState = currentState()
        var projectCopy = previousState.project
        var sourceCopy = previousState.sourcePDFData

        mutation(&projectCopy, &sourceCopy)
        projectCopy.modifiedAt = .now

        applyState(DocumentStateSnapshot(project: projectCopy, sourcePDFData: sourceCopy))

        undoManager?.registerUndo(withTarget: self) { target in
            target.restore(previousState, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }

    private func restore(_ snapshot: DocumentStateSnapshot, actionName: String) {
        let redoSnapshot = currentState()
        applyState(snapshot)

        undoManager?.registerUndo(withTarget: self) { target in
            target.restore(redoSnapshot, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }

    private func applyState(_ snapshot: DocumentStateSnapshot) {
        let sourceChanged = sourcePDFData != snapshot.sourcePDFData
        project = snapshot.project
        sourcePDFData = snapshot.sourcePDFData
        if sourceChanged {
            rebuildPDFCache()
        }
        clampSelectionsToCurrentState()
    }

    private func rebuildPDFCache() {
        if let sourcePDFData {
            cachedPDFDocument = PDFDocument(data: sourcePDFData)
        } else {
            cachedPDFDocument = nil
        }
    }

    private func clampSelectionsToCurrentState() {
        if let selectedPartID, project.parts.contains(where: { $0.id == selectedPartID }) == false {
            self.selectedPartID = project.parts.first?.id
        }

        if let selectedBandID, project.bands.contains(where: { $0.id == selectedBandID }) == false {
            self.selectedBandID = nil
        }

        if let headerSelection = project.projectSettings.headerSelection,
           headerSelection.pageIndex < 0 || headerSelection.pageIndex >= project.pageCount
        {
            project.projectSettings.headerSelection = nil
        }

        currentPageIndex = max(0, min(currentPageIndex, max(0, project.pageCount - 1)))
    }
}
