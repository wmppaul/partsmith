import AppKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import OSLog
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

struct RectificationAutoProgress {
    var completedPageCount: Int
    var totalPageCount: Int
    var estimatedPageCount: Int

    var fractionComplete: Double {
        guard totalPageCount > 0 else { return 0 }
        return Double(completedPageCount) / Double(totalPageCount)
    }
}

enum RectificationAutoResult: Equatable {
    case completed(appliedPageCount: Int)
    case cancelled
    /// The source PDF or its coordinate-bound edits changed while estimating.
    case sourceChanged
    case unavailable
}

struct StaffDetectionPage {
    var pageIndex: Int
    var image: CGImage
    var result: StaffDetectionResult
    var sourcePDFData: Data
    var rectification: PageRectification?
}

struct ScoreDetectionProgress {
    var completedPages: Int
    var totalPages: Int
}

struct ScoreDetectionReview {
    var profile: ScoreExtractionProfile
    var analyses: [ScorePageAnalysis]
    var plan: ScoreExtractionPlan
    var overrides: [ScorePageOverride] = []
    var excludedPageReasons: [Int: String] = [:]
    var suggestedSourceHeader: SourceHeaderSelection? = nil
    var sourcePDFData: Data
    var rectifications: [PageRectification]

    mutating func replan() {
        plan = ScoreExtractionPlanner.plan(pages: analyses.filter { excludedPageReasons[$0.pageIndex] == nil },
                                           profile: profile, overrides: overrides.filter { excludedPageReasons[$0.pageIndex] == nil })
    }

    func nextPageNeedingReview(after pageIndex: Int) -> Int? {
        let unresolved = plan.pages.filter { !$0.unresolvedReasons.isEmpty }.map(\.pageIndex).sorted()
        return unresolved.first { $0 > pageIndex } ?? unresolved.first
    }

    enum PageExclusionError: LocalizedError {
        case unavailablePage, missingReason
        var errorDescription: String? {
            switch self {
            case .unavailablePage: return "This source page is no longer available. Run Auto again."
            case .missingReason: return "Enter why this page has no score music, such as a blank page or publisher catalogue."
            }
        }
    }

    /// No-staff detection alone never excludes a page. This records the user's
    /// explicit source review and returns a useful next page to inspect.
    @discardableResult
    mutating func excludePageAsNonMusic(_ pageIndex: Int, reason: String) throws -> Int? {
        guard analyses.contains(where: { $0.pageIndex == pageIndex }) else { throw PageExclusionError.unavailablePage }
        let reviewedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reviewedReason.isEmpty else { throw PageExclusionError.missingReason }
        excludedPageReasons[pageIndex] = reviewedReason
        replan()
        return nextPageNeedingReview(after: pageIndex)
            ?? plan.pages.first(where: { !$0.assignments.isEmpty })?.pageIndex
    }

    enum CropEditError: LocalizedError {
        case unavailableBand, invalidEdges, incompletePage
        var errorDescription: String? {
            switch self {
            case .unavailableBand: return "This crop is no longer available. Review the current page assignments first."
            case .invalidEdges: return "Keep the crop inside the source page, with Top above Bottom and every assigned staff line, including its tilted ends, inside it."
            case .incompletePage: return "Resolve this page's staff assignments before changing crop edges."
            }
        }
    }

    /// Edits only the proposal. Applying the complete review remains one undoable edit.
    mutating func setCropEdges(for bandID: String, top: Double, bottom: Double) throws {
        guard let band = plan.bands.first(where: { $0.id == bandID }),
              let page = analyses.first(where: { $0.pageIndex == band.pageIndex }) else {
            throw CropEditError.unavailableBand
        }
        let staves = page.staves.filter { band.candidateIDs.contains($0.id) }
        let skewReach = abs(tan(page.analysisSkewDegrees * .pi / 180)) * page.pageWidth / 2
        guard top.isFinite, bottom.isFinite, top >= 0, top < bottom, bottom <= page.pageHeight,
              skewReach.isFinite,
              staves.allSatisfy({
                  max(0, ($0.staffLineFractions.first ?? -1) * page.pageHeight - skewReach) >= top
                      && min(page.pageHeight, ($0.staffLineFractions.last ?? 2) * page.pageHeight + skewReach) <= bottom
              }) else { throw CropEditError.invalidEdges }
        try setCrop(for: band, rect: [band.leftFraction * page.pageWidth, top,
                                      (1 - band.rightFraction) * page.pageWidth, bottom])
    }

    mutating func resetCropEdges(for bandID: String) throws {
        guard let band = plan.bands.first(where: { $0.id == bandID }) else { throw CropEditError.unavailableBand }
        try setCrop(for: band, rect: nil)
    }

    private mutating func setCrop(for band: ScorePlannedBand, rect: [Double]?) throws {
        guard let page = analyses.first(where: { $0.pageIndex == band.pageIndex }),
              let pagePlan = plan.pages.first(where: { $0.pageIndex == band.pageIndex }),
              pagePlan.unresolvedReasons.isEmpty, excludedPageReasons[band.pageIndex] == nil else {
            throw CropEditError.incompletePage
        }
        // Existing overrides carry omission reasons, movement headings, cues and
        // shared markings. Preserve them verbatim when changing a single edge.
        var correction = overrides.first(where: { $0.pageIndex == band.pageIndex })
            ?? ScorePageOverride(pageIndex: band.pageIndex, reason: "Crop edges reviewed in Auto Extract.",
                systems: Set(pagePlan.assignments.map(\.systemIndex)).sorted().map { system in
                    ScoreSystemOverride(systemIndex: system, label: nil, movementLabel: nil,
                        bands: pagePlan.assignments.filter { $0.systemIndex == system }.map { item in
                            ScoreBandOverride(partID: item.partID, candidateIDs: item.candidateIDs,
                                rect: nil, label: item.editorialLabel, kind: item.kind,
                                pageBreakBefore: item.pageBreakBefore, sourceMarkings: item.sourceMarkings.map {
                                    [$0.leftFraction * page.pageWidth, $0.topFraction * page.pageHeight,
                                     (1 - $0.rightFraction) * page.pageWidth, $0.bottomFraction * page.pageHeight]
                                })
                        }, omittedParts: nil)
                })
        guard let systemIndex = correction.systems.firstIndex(where: { $0.systemIndex == band.systemIndex }),
              let bandIndex = correction.systems[systemIndex].bands.firstIndex(where: { $0.partID == band.partID }) else {
            throw CropEditError.unavailableBand
        }
        correction.systems[systemIndex].bands[bandIndex].rect = rect
        var proposal = self
        proposal.overrides.removeAll { $0.pageIndex == band.pageIndex }
        proposal.overrides.append(correction)
        proposal.replan()
        guard proposal.plan.pages.first(where: { $0.pageIndex == band.pageIndex })?.unresolvedReasons.isEmpty == true else {
            throw CropEditError.incompletePage
        }
        self = proposal
    }
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
    private static let rectificationLogger = Logger(subsystem: "Partsmith", category: "Rectification")
    private static let barNumberLogger = Logger(subsystem: "Partsmith", category: "BarNumbers")

    @Published var project: ProjectData {
        didSet {
            if project.pageRectifications != oldValue.pageRectifications {
                invalidateInstrumentNameHighlights()
            }
        }
    }
    @Published var sourcePDFData: Data? {
        didSet {
            if sourcePDFData != oldValue { invalidateInstrumentNameHighlights() }
        }
    }
    @Published var selectedPartID: UUID?
    @Published var selectedBandID: UUID?
    @Published var currentPageIndex: Int
    @Published var canvasMode: CanvasMode
    @Published var zoomMode: ZoomMode
    @Published var isEditingHeaderSelection: Bool
    @Published var isEditingPageRectification: Bool
    @Published private(set) var rectificationAutoProgress: RectificationAutoProgress?
    @Published private(set) var scoreDetectionProgress: ScoreDetectionProgress?
    @Published var isPickingInstrumentNames = false
    @Published private(set) var instrumentNamePick: ScoreInstrumentNamePick?
    @Published private(set) var instrumentNameHighlights: [ScoreInstrumentNamePick] = []
    @Published private(set) var instrumentNamePickMessage: String?
    @Published private(set) var isRecognizingInstrumentName = false

    weak var undoManager: UndoManager?

    private var cachedPDFDocument: PDFDocument?
    private var sourcePageRenderCache: SourcePageRenderCache?
    private var bandTemplateHalfHeight: Double?
    private var rectificationAutoRunID: UUID?
    private var rectificationAutoOperation: BlockOperation?
    private var rectificationAutoCompletion: ((RectificationAutoResult) -> Void)?
    private let barNumberDetectionQueue = DispatchQueue(label: "Partsmith.BarNumberDetection", qos: .userInitiated)
    private var staffDetectionOperation: BlockOperation?
    private var scoreDetectionOperation: BlockOperation?
    private var instrumentNameOperation: BlockOperation?
    private let instrumentNameQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Partsmith.InstrumentNameRecognition"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let staffDetectionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Partsmith.StaffDetection"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private enum BandCopyScope {
        case allParts
        case selectedPart(UUID)
    }

    init(project: ProjectData = .empty, sourcePDFData: Data? = nil) {
        self.project = project
        self.sourcePDFData = sourcePDFData
        self.selectedPartID = project.parts.first?.id
        self.selectedBandID = nil
        self.currentPageIndex = 0
        self.canvasMode = .source
        self.zoomMode = .fitWidth
        self.isEditingHeaderSelection = false
        self.isEditingPageRectification = false
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
        self.isEditingPageRectification = false
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
            if let cachedPDFDocument {
                sourcePageRenderCache = SourcePageRenderCache(pdfDocument: cachedPDFDocument)
            }
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

    func band(withID bandID: UUID) -> BandModel? {
        project.bands.first(where: { $0.id == bandID })
    }

    func bands(on pageIndex: Int) -> [BandModel] {
        project.bands(on: pageIndex)
    }

    func bandCount(for partID: UUID) -> Int {
        project.bands.filter { $0.partID == partID && !$0.excluded }.count
    }

    func outputBands(for partID: UUID) -> [BandModel] {
        project.sortedBands(for: partID).filter { !$0.excluded }
    }

    func colorMap() -> [UUID: NSColor] {
        Dictionary(uniqueKeysWithValues: project.parts.map { ($0.id, $0.nsColor) })
    }

    var suggestedNewPartColor: NSColor {
        Self.defaultPartPalette[project.parts.count % Self.defaultPartPalette.count]
    }

    var canCopyCurrentPageBandsToNextPage: Bool {
        canCopyBands(from: currentPageIndex, to: [currentPageIndex + 1], scope: .allParts)
    }

    var canCopySelectedPartBandsToNextPage: Bool {
        guard let selectedPartID else { return false }
        return canCopyBands(from: currentPageIndex, to: [currentPageIndex + 1], scope: .selectedPart(selectedPartID))
    }

    var canCopyCurrentPageBandsToRemainingPages: Bool {
        canCopyBands(from: currentPageIndex, to: remainingPageIndices(after: currentPageIndex), scope: .allParts)
    }

    var canCopySelectedPartBandsToRemainingPages: Bool {
        guard let selectedPartID else { return false }
        return canCopyBands(
            from: currentPageIndex,
            to: remainingPageIndices(after: currentPageIndex),
            scope: .selectedPart(selectedPartID)
        )
    }

    var headerSelection: SourceHeaderSelection? {
        project.projectSettings.headerSelection
    }

    var headerSelectionOnCurrentPage: SourceHeaderSelection? {
        guard let headerSelection, headerSelection.pageIndex == currentPageIndex else { return nil }
        return headerSelection
    }

    var currentPageRectification: PageRectification? {
        project.pageRectifications.first(where: { $0.pageIndex == currentPageIndex })
    }

    var isAutoEstimatingPageRectifications: Bool {
        rectificationAutoProgress != nil
    }

    var canAutoEstimateCurrentPageRectification: Bool {
        isEditingPageRectification == false &&
        isAutoEstimatingPageRectifications == false &&
        pdfDocument?.page(at: currentPageIndex) != nil
    }

    var canAutoEstimateAllPageRectifications: Bool {
        isEditingPageRectification == false &&
        isAutoEstimatingPageRectifications == false &&
        (pdfDocument?.pageCount ?? 0) > 0
    }

    var usesRectifiedDisplayForCurrentPage: Bool {
        isEditingPageRectification == false && currentPageRectification != nil
    }

    var sourceDisplayPageIndex: Int {
        usesRectifiedDisplayForCurrentPage ? 0 : currentPageIndex
    }

    func sourceDisplayDocumentForCurrentPage() -> PDFDocument? {
        guard let pdfDocument else { return nil }
        guard usesRectifiedDisplayForCurrentPage else { return pdfDocument }
        guard let currentPageRectification else { return pdfDocument }
        return sourcePageRenderCache?.rectifiedDisplayDocument(for: currentPageIndex, rectification: currentPageRectification) ?? pdfDocument
    }

    func sourceDisplayImageForCurrentPage() -> CGImage? {
        guard usesRectifiedDisplayForCurrentPage else { return nil }
        guard let currentPageRectification else { return nil }
        return sourcePageRenderCache?.rectifiedDisplayImage(
            for: currentPageIndex,
            rectification: currentPageRectification
        )
    }

    func sourceDisplayPageBoundsForCurrentPage() -> CGRect? {
        guard let pdfDocument else { return nil }
        if usesRectifiedDisplayForCurrentPage {
            return sourcePageRenderCache?.pageBounds(for: currentPageIndex)
        }
        return pdfDocument.page(at: currentPageIndex)?.bounds(for: .mediaBox)
    }

    func detectStaffBands(completion: @escaping (StaffDetectionPage?) -> Void) {
        cancelStaffDetection()
        guard let sourcePDFData else { completion(nil); return }
        let pageIndex = currentPageIndex
        let rectification = currentPageRectification
        let operation = BlockOperation()
        staffDetectionOperation = operation
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            // Each worker owns its PDFKit document and render cache. No mutable
            // PDFKit/AppKit state crosses from the editor into this queue.
            let backgroundPDF = PDFDocument(data: sourcePDFData)
            let bounds = backgroundPDF?.page(at: pageIndex)?.bounds(for: .mediaBox)
            let cache = backgroundPDF.map {
                SourcePageRenderCache(pdfDocument: $0, rasterScale: 1800 / max(bounds?.width ?? 612, 1))
            }
            let detectionImage: CGImage?
            if let rectification {
                // Never detect in original coordinates after a failed
                // rectification: the editor's bands refer to corrected space.
                detectionImage = cache?.rectifiedDisplayImage(for: pageIndex, rectification: rectification)
            } else {
                detectionImage = cache?.imageForDetection(pageIndex: pageIndex, rectification: nil)?.image
            }
            guard !operation.isCancelled else { return }
            let review = detectionImage.map {
                StaffDetectionPage(
                    pageIndex: pageIndex, image: $0,
                    result: StaffBandDetector.detect(in: $0, isCancelled: { operation.isCancelled }),
                    sourcePDFData: sourcePDFData, rectification: rectification
                )
            }
            DispatchQueue.main.async { [weak self, weak operation] in
                guard let self, let operation,
                      self.staffDetectionOperation === operation, !operation.isCancelled else { return }
                self.staffDetectionOperation = nil
                guard let review, self.isStaffDetectionCurrent(review) else { completion(nil); return }
                completion(review)
            }
        }
        staffDetectionQueue.addOperation(operation)
    }

    func cancelStaffDetection() {
        staffDetectionOperation?.cancel()
        staffDetectionOperation = nil
    }

    /// Analyze every source page with an explicitly supplied instrument order.
    /// Each worker owns its PDFKit objects; only small geometric results return to the UI.
    func detectScore(profile: ScoreExtractionProfile, findSourceHeader: Bool = false,
                     completion: @escaping (ScoreDetectionReview?) -> Void) {
        cancelScoreDetection()
        cancelStaffDetection()
        guard let data = sourcePDFData, let pageCount = pdfDocument?.pageCount, pageCount > 0 else {
            completion(nil); return
        }
        let rectifications = project.pageRectifications
        let operation = BlockOperation()
        scoreDetectionOperation = operation
        scoreDetectionProgress = ScoreDetectionProgress(completedPages: 0, totalPages: pageCount)
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled, let pdf = PDFDocument(data: data) else { return }
            var analyses: [ScorePageAnalysis] = []
            var suggestedSourceHeader: SourceHeaderSelection?
            var triedSourceHeader = false
            for pageIndex in 0..<pdf.pageCount {
                guard !operation.isCancelled else { return }
                let analysis: ScorePageAnalysis = autoreleasepool {
                    let page = pdf.page(at: pageIndex)
                    let bounds = page?.bounds(for: .mediaBox) ?? .zero
                    let image: CGImage?
                    if let rectification = rectifications.first(where: { $0.pageIndex == pageIndex }) {
                        // Release each corrected raster after analysis rather than
                        // retaining an entire scanned score in a render cache.
                        let cache = SourcePageRenderCache(pdfDocument: pdf, rasterScale: 2.5)
                        image = cache.rectifiedDisplayImage(for: pageIndex, rectification: rectification)
                    } else {
                        image = page.flatMap { NativeScorePageAnalyzer.render($0) }
                    }
                    guard let image else {
                        return ScorePageAnalysis(pageIndex: pageIndex, pageWidth: bounds.width, pageHeight: bounds.height,
                            imageWidth: 0, imageHeight: 0, staves: [], warnings: ["Page could not be rendered; review or restore the source."])
                    }
                    let analysis = NativeScorePageAnalyzer.analyze(pageIndex: pageIndex, image: image,
                        pageWidth: bounds.width, pageHeight: bounds.height, isCancelled: { operation.isCancelled })
                    if findSourceHeader, !triedSourceHeader, !analysis.staves.isEmpty {
                        triedSourceHeader = true
                        suggestedSourceHeader = ScoreSourceHeaderDetector.detect(in: image, pageIndex: pageIndex,
                            staves: analysis.staves, isCancelled: { operation.isCancelled })?.selection
                    }
                    return analysis
                }
                analyses.append(analysis)
                DispatchQueue.main.async { [weak self, weak operation] in
                    guard let self, let operation, self.scoreDetectionOperation === operation, !operation.isCancelled else { return }
                    self.scoreDetectionProgress = ScoreDetectionProgress(completedPages: pageIndex + 1, totalPages: pageCount)
                }
            }
            let plan = ScoreExtractionPlanner.plan(pages: analyses, profile: profile, isCancelled: { operation.isCancelled })
            let review = ScoreDetectionReview(profile: profile, analyses: analyses, plan: plan,
                                               suggestedSourceHeader: suggestedSourceHeader,
                                               sourcePDFData: data, rectifications: rectifications)
            DispatchQueue.main.async { [weak self, weak operation] in
                guard let self, let operation, self.scoreDetectionOperation === operation, !operation.isCancelled else { return }
                self.scoreDetectionOperation = nil
                self.scoreDetectionProgress = nil
                completion(self.isScoreDetectionCurrent(review) ? review : nil)
            }
        }
        staffDetectionQueue.addOperation(operation)
    }

    func cancelScoreDetection() {
        scoreDetectionOperation?.cancel()
        scoreDetectionOperation = nil
        scoreDetectionProgress = nil
    }

    var savedScoreProfile: ScoreExtractionProfile? {
        guard let setup = project.projectSettings.instrumentationSetup else { return nil }
        return ScoreExtractionProfile(parts: setup.instruments.map {
            ScorePartDefinition(id: $0.id, name: $0.name, staffCount: $0.staffCount,
                topPaddingStaffSpaces: $0.topPaddingStaffSpaces, bottomPaddingStaffSpaces: $0.bottomPaddingStaffSpaces, hasLyrics: $0.hasLyrics)
        }, topPaddingStaffSpaces: setup.topPaddingStaffSpaces, bottomPaddingStaffSpaces: setup.bottomPaddingStaffSpaces,
           leftTrimPoints: setup.leftTrimPoints, rightTrimPoints: setup.rightTrimPoints, cropMode: setup.cropMode)
    }

    private static func instrumentationSetup(for profile: ScoreExtractionProfile) -> ScoreInstrumentationSetup {
        ScoreInstrumentationSetup(instruments: profile.parts.map {
            ScoreInstrumentationSetup.Instrument(id: $0.id, name: $0.name, staffCount: $0.staffCount,
                topPaddingStaffSpaces: $0.topPaddingStaffSpaces, bottomPaddingStaffSpaces: $0.bottomPaddingStaffSpaces, hasLyrics: $0.hasLyrics)
        }, topPaddingStaffSpaces: profile.topPaddingStaffSpaces, bottomPaddingStaffSpaces: profile.bottomPaddingStaffSpaces,
           leftTrimPoints: profile.leftTrimPoints, rightTrimPoints: profile.rightTrimPoints, cropMode: profile.cropMode)
    }

    func saveScoreProfile(_ profile: ScoreExtractionProfile) {
        let setup = Self.instrumentationSetup(for: profile)
        guard project.projectSettings.instrumentationSetup != setup else { return }
        commit(actionName: "Save Instrumentation Setup") { project, _ in
            project.projectSettings.instrumentationSetup = setup
        }
    }

    func isScoreDetectionCurrent(_ review: ScoreDetectionReview) -> Bool {
        review.sourcePDFData == sourcePDFData && review.rectifications == project.pageRectifications &&
            review.analyses.map(\.pageIndex) == Array(0..<(pdfDocument?.pageCount ?? 0))
    }

    func scoreReviewImage(pageIndex: Int) -> CGImage? {
        guard let page = pdfDocument?.page(at: pageIndex) else { return nil }
        if let rectification = project.pageRectifications.first(where: { $0.pageIndex == pageIndex }) {
            return sourcePageRenderCache?.rectifiedDisplayImage(for: pageIndex, rectification: rectification)
        }
        return NativeScorePageAnalyzer.render(page)
    }

    /// The point is normalized in the currently displayed page, top to bottom.
    /// No project data changes until the user accepts the instrument setup.
    func pickInstrumentName(at point: CGPoint, pageIndex: Int) {
        instrumentNameOperation?.cancel()
        instrumentNameOperation = nil
        instrumentNamePick = nil
        instrumentNamePickMessage = nil
        isRecognizingInstrumentName = false
        guard isPickingInstrumentNames else { return }
        guard pageIndex == currentPageIndex, !isEditingPageRectification,
              point.x.isFinite, point.y.isFinite, (0...1).contains(point.x), (0...1).contains(point.y),
              let data = sourcePDFData, let image = scoreReviewImage(pageIndex: pageIndex) else {
            instrumentNamePickMessage = "Show a score page, then click a printed instrument name."
            return
        }
        let rectification = currentPageRectification
        let operation = BlockOperation()
        instrumentNameOperation = operation
        isRecognizingInstrumentName = true
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            let candidate = ScoreInstrumentNameDetector.recognize(in: image, at: point,
                                                                  isCancelled: { operation.isCancelled })
            DispatchQueue.main.async { [weak self, weak operation] in
                guard let self, let operation, self.instrumentNameOperation === operation,
                      !operation.isCancelled else { return }
                self.instrumentNameOperation = nil
                self.isRecognizingInstrumentName = false
                guard self.isPickingInstrumentNames else { return }
                guard self.sourcePDFData == data, self.currentPageIndex == pageIndex,
                      self.currentPageRectification == rectification, !self.isEditingPageRectification else {
                    self.instrumentNamePickMessage = "The displayed page changed. Click its instrument name again."
                    return
                }
                guard let candidate else {
                    self.instrumentNamePickMessage = "Couldn’t read a name there. Click the printed letters, or type the name in the list."
                    return
                }
                let pick = ScoreInstrumentNamePick(id: UUID(), name: candidate.text,
                    suggestedStaffCount: ScoreInstrumentNameDetector.suggestedStaffCount(for: candidate.text),
                    pageIndex: pageIndex, bounds: candidate.bounds)
                // A repeat click updates its existing label; it never leaves
                // stacked highlights over the same printed word.
                if let index = self.instrumentNameHighlights.firstIndex(where: { previous in
                    guard previous.pageIndex == pick.pageIndex else { return false }
                    let intersection = previous.bounds.intersection(pick.bounds)
                    let smallerArea = min(previous.bounds.width * previous.bounds.height,
                                          pick.bounds.width * pick.bounds.height)
                    return !intersection.isNull && smallerArea > 0
                        && intersection.width * intersection.height >= smallerArea * 0.5
                }) {
                    self.instrumentNameHighlights[index] = pick
                } else {
                    self.instrumentNameHighlights.append(pick)
                }
                self.instrumentNamePick = pick
            }
        }
        instrumentNameQueue.addOperation(operation)
    }

    func cancelInstrumentNamePicking() {
        isPickingInstrumentNames = false
        instrumentNameOperation?.cancel()
        instrumentNameOperation = nil
        instrumentNamePick = nil
        instrumentNameHighlights = []
        instrumentNamePickMessage = nil
        isRecognizingInstrumentName = false
    }

    /// Rectification, source import, and undo can replace the displayed page
    /// while the picker stays open. Never retain boxes from the old geometry.
    private func invalidateInstrumentNameHighlights() {
        guard isPickingInstrumentNames || !instrumentNameHighlights.isEmpty || instrumentNameOperation != nil else { return }
        instrumentNameOperation?.cancel()
        instrumentNameOperation = nil
        instrumentNamePick = nil
        instrumentNameHighlights = []
        isRecognizingInstrumentName = false
        instrumentNamePickMessage = isPickingInstrumentNames
            ? "The displayed page changed. Click its instrument name again." : nil
    }

    /// Add every reviewed part atomically. Existing populated parts of the same
    /// name are rejected, so re-running Auto cannot silently duplicate their music.
    @discardableResult
    func addScoreParts(from review: ScoreDetectionReview, sourceHeader: SourceHeaderSelection? = nil) -> Int? {
        guard isScoreDetectionCurrent(review), review.plan.canApply, !review.plan.bands.isEmpty,
              review.excludedPageReasons.values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(review.plan.pages.map(\.pageIndex)) == Set(review.analyses.map(\.pageIndex)).subtracting(review.excludedPageReasons.keys),
              review.plan.parts == review.profile.parts,
              Set(review.profile.parts.map { $0.name.lowercased() }).count == review.profile.parts.count else { return nil }
        if let sourceHeader {
            guard project.projectSettings.headerSelection == nil,
                  sourceHeader.pageIndex >= 0, sourceHeader.pageIndex < project.pageCount,
                  review.analyses.contains(where: { $0.pageIndex == sourceHeader.pageIndex }),
                  review.excludedPageReasons[sourceHeader.pageIndex] == nil,
                  [sourceHeader.topFraction, sourceHeader.bottomFraction, sourceHeader.leftFraction, sourceHeader.rightFraction]
                    .allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
                  sourceHeader.topFraction < sourceHeader.bottomFraction,
                  sourceHeader.leftFraction + sourceHeader.rightFraction < 1 else { return nil }
        }
        let now = Date()
        var parts: [PartModel] = []
        var partIDs: [String: UUID] = [:]
        for definition in review.profile.parts {
            let existing = project.parts.filter { $0.name.caseInsensitiveCompare(definition.name) == .orderedSame }
            guard existing.count <= 1 else { return nil }
            if let part = existing.first {
                guard !project.bands.contains(where: { $0.partID == part.id }) else { return nil }
                partIDs[definition.id] = part.id
            } else {
                let id = UUID()
                partIDs[definition.id] = id
                parts.append(PartModel(id: id, name: definition.name,
                    color: ColorData(nsColor: Self.defaultPartPalette[(project.parts.count + parts.count) % Self.defaultPartPalette.count]),
                    layoutSettings: defaultPartLayoutSettings(), createdAt: now))
            }
        }
        var bands: [BandModel] = []
        for planned in review.plan.bands {
            guard let partID = partIDs[planned.partID], planned.pageIndex >= 0, planned.pageIndex < review.analyses.count,
                  [planned.topFraction, planned.bottomFraction, planned.leftFraction, planned.rightFraction].allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
                  planned.topFraction < planned.bottomFraction, planned.leftFraction + planned.rightFraction < 1 else { return nil }
            let band = BandModel(id: UUID(), pageIndex: planned.pageIndex, partID: partID,
                topFraction: planned.topFraction, bottomFraction: planned.bottomFraction,
                leftFraction: planned.leftFraction, rightFraction: planned.rightFraction,
                excluded: false, createdAt: now, barNumberMode: .hidden,
                editorialLabel: planned.editorialLabel, pageBreakBefore: planned.pageBreakBefore,
                sourceMarkings: planned.sourceMarkings.map { BandSourceMarking(topFraction: $0.topFraction,
                    bottomFraction: $0.bottomFraction, leftFraction: $0.leftFraction, rightFraction: $0.rightFraction) })
            guard band.sourceMarkings.allSatisfy({ $0.isValid(in: band) }) else { return nil }
            bands.append(band)
        }
        commit(actionName: "Auto Extract Reviewed Parts") { project, _ in
            project.parts.append(contentsOf: parts)
            project.bands.append(contentsOf: bands)
            project.projectSettings.showPartNameInHeader = true
            project.projectSettings.instrumentationSetup = Self.instrumentationSetup(for: review.profile)
            if let sourceHeader {
                project.projectSettings.headerSelection = sourceHeader.normalized()
                project.projectSettings.headerDisplayMode = .sourceSelection
                project.projectSettings.showTitleBlock = true
            }
        }
        selectedPartID = review.profile.parts.first.flatMap { partIDs[$0.id] }
        selectedBandID = bands.first?.id
        currentPageIndex = bands.first?.pageIndex ?? 0
        canvasMode = .source
        return bands.count
    }

    func isStaffDetectionCurrent(_ review: StaffDetectionPage) -> Bool {
        review.pageIndex == currentPageIndex && review.sourcePDFData == sourcePDFData
            && review.rectification == currentPageRectification
    }

    /// Applies explicitly reviewed consecutive groups as one undoable edit.
    /// Returns nil for a stale/invalid review and skips existing overlapping bands.
    @discardableResult
    func addStaffBands(from review: StaffDetectionPage, groups: [[Int]], partID: UUID) -> Int? {
        guard isStaffDetectionCurrent(review), project.parts.contains(where: { $0.id == partID }) else { return nil }
        let candidates = review.result.candidates
        var usedIDs = Set<Int>()
        var additions: [BandModel] = []
        for group in groups {
            let ids = group.sorted()
            guard !ids.isEmpty, ids.allSatisfy({ candidates.indices.contains($0) && usedIDs.insert($0).inserted }),
                  zip(ids, ids.dropFirst()).allSatisfy({ $1 == $0 + 1 }) else { return nil }
            let selected = ids.map { candidates[$0] }
            guard let top = selected.map(\.topFraction).min(),
                  let bottom = selected.map(\.bottomFraction).max(),
                  top.isFinite, bottom.isFinite, top >= 0, bottom <= 1, bottom > top else { return nil }
            let overlapsExisting = project.bands.contains { band in
                guard band.partID == partID, band.pageIndex == review.pageIndex else { return false }
                return selected.contains { candidate in
                    let center = candidate.staffLineFractions.reduce(0, +) / 5
                    return center >= band.topFraction && center <= band.bottomFraction
                }
            }
            if overlapsExisting { continue }
            additions.append(BandModel(
                id: UUID(), pageIndex: review.pageIndex, partID: partID,
                topFraction: top, bottomFraction: bottom, leftFraction: 0, rightFraction: 0,
                excluded: false, createdAt: .now
            ).normalized())
        }
        guard !additions.isEmpty else { return 0 }
        commit(actionName: "Add Detected Staff Bands") { project, _ in
            project.bands.append(contentsOf: additions)
        }
        selectedPartID = partID
        selectedBandID = additions.first?.id
        canvasMode = .source
        isEditingHeaderSelection = false
        isEditingPageRectification = false
        return additions.count
    }

    func selectPart(_ partID: UUID?) {
        if partID != nil {
            isEditingHeaderSelection = false
            isEditingPageRectification = false
        }
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
        if bandID != nil {
            isEditingHeaderSelection = false
            isEditingPageRectification = false
        }
        selectedBandID = bandID
        guard let bandID,
              let band = project.bands.first(where: { $0.id == bandID })
        else { return }

        selectedPartID = band.partID
    }

    func revealBand(_ bandID: UUID) {
        guard let band = project.bands.first(where: { $0.id == bandID }) else { return }
        canvasMode = .source
        setCurrentPage(band.pageIndex)
        selectBand(bandID)
    }

    func nextPage() {
        guard currentPageIndex + 1 < project.pageCount else { return }
        currentPageIndex += 1
        selectedBandID = nil
        isEditingPageRectification = false
    }

    func previousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
        selectedBandID = nil
        isEditingPageRectification = false
    }

    func setCurrentPage(_ pageIndex: Int) {
        currentPageIndex = max(0, min(pageIndex, max(0, project.pageCount - 1)))
        selectedBandID = nil
        isEditingPageRectification = false
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
            project.pageRectifications.removeAll()
        }

        currentPageIndex = 0
        selectedBandID = nil
        canvasMode = .source
        isEditingHeaderSelection = false
        isEditingPageRectification = false
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
        isEditingHeaderSelection = false
        isEditingPageRectification = false
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

    func updateProjectShowTitleBlock(_ showTitleBlock: Bool) {
        commit(actionName: "Toggle Title Block") { project, _ in
            project.projectSettings.showTitleBlock = showTitleBlock
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

    func updatePartBalancedPages(_ partID: UUID, enabled: Bool) {
        updatePart(partID: partID, actionName: "Balance Part Pages") { part in
            part.layoutSettings.balancePages = enabled
        }
    }

    func updatePartConsistentScale(_ partID: UUID, enabled: Bool) {
        updatePart(partID: partID, actionName: "Change Part Scaling") { part in
            part.layoutSettings.useConsistentScale = enabled
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

    func updateProjectShowPartNameInHeader(_ showPartNameInHeader: Bool) {
        commit(actionName: "Toggle Part Name Header") { project, _ in
            project.projectSettings.showPartNameInHeader = showPartNameInHeader
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
            isEditingPageRectification = false
            if let headerSelection = project.projectSettings.headerSelection {
                currentPageIndex = max(0, min(headerSelection.pageIndex, max(0, project.pageCount - 1)))
            }
        }
    }

    func setPageRectificationEditing(_ isEditing: Bool) {
        guard isAutoEstimatingPageRectifications == false else { return }
        isEditingPageRectification = isEditing
        if isEditing {
            canvasMode = .source
            selectedBandID = nil
            isEditingHeaderSelection = false
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
    }

    func clearHeaderSelection() {
        commit(actionName: "Clear Source Header") { project, _ in
            project.projectSettings.headerSelection = nil
        }

        isEditingHeaderSelection = false
    }

    func updatePageRectification(_ rectification: PageRectification) {
        let rectification = rectification.normalized()
        commit(actionName: "Rectify Page") { project, _ in
            project.pageRectifications.removeAll { $0.pageIndex == rectification.pageIndex }
            project.pageRectifications.append(rectification)
        }
    }

    func clearCurrentPageRectification() {
        guard isAutoEstimatingPageRectifications == false else { return }
        let pageIndex = currentPageIndex
        commit(actionName: "Clear Page Rectification") { project, _ in
            project.pageRectifications.removeAll { $0.pageIndex == pageIndex }
        }
        isEditingPageRectification = false
    }

    func autoEstimateCurrentPageRectification() {
        guard isAutoEstimatingPageRectifications == false else { return }
        guard let estimate = estimatedRectification(for: currentPageIndex) else { return }

        updatePageRectification(estimate)
        isEditingPageRectification = false
    }

    /// Returns an ownership token so a temporary workflow can cancel its own run
    /// without interrupting an estimate started elsewhere in the document.
    @discardableResult
    func autoEstimateAllPageRectifications(
        onlyUnrectified: Bool = false,
        completion: ((RectificationAutoResult) -> Void)? = nil
    ) -> UUID? {
        guard isAutoEstimatingPageRectifications == false, let sourcePDFData else {
            completion?(.unavailable)
            return nil
        }
        let totalPageCount = pdfDocument?.pageCount ?? 0
        guard totalPageCount > 0 else {
            completion?(.unavailable)
            return nil
        }

        let runID = UUID()
        let startingRectifications = project.pageRectifications
        let excludedPageIndices = onlyUnrectified ? Set(startingRectifications.map(\.pageIndex)) : []
        let operation = BlockOperation()
        rectificationAutoRunID = runID
        rectificationAutoOperation = operation
        rectificationAutoCompletion = completion
        rectificationAutoProgress = RectificationAutoProgress(
            completedPageCount: 0,
            totalPageCount: totalPageCount,
            estimatedPageCount: 0
        )
        isEditingPageRectification = false
        Self.rectificationLogger.notice("Auto All started for \(totalPageCount, privacy: .public) pages")

        operation.addExecutionBlock { [weak self, weak operation, sourcePDFData] in
            guard let operation, !operation.isCancelled else { return }
            guard let backgroundDocument = PDFDocument(data: sourcePDFData) else {
                Self.rectificationLogger.error("Auto All failed to open background PDF document")
                DispatchQueue.main.async { [weak self] in
                    self?.finishAutoEstimateAllPageRectifications(
                        [],
                        sourcePDFData: sourcePDFData,
                        startingRectifications: startingRectifications,
                        runID: runID,
                        preserveExistingCrops: onlyUnrectified,
                        failed: true
                    )
                }
                return
            }

            var estimatedRectifications: [PageRectification] = []
            estimatedRectifications.reserveCapacity(backgroundDocument.pageCount)

            for pageIndex in 0..<backgroundDocument.pageCount {
                guard !operation.isCancelled else { return }
                if !excludedPageIndices.contains(pageIndex) {
                    let estimate = autoreleasepool {
                        Self.estimatedRectification(for: pageIndex, in: backgroundDocument)
                    }
                    if let estimate { estimatedRectifications.append(estimate) }
                }
                guard !operation.isCancelled else { return }

                let progress = RectificationAutoProgress(
                    completedPageCount: pageIndex + 1,
                    totalPageCount: totalPageCount,
                    estimatedPageCount: estimatedRectifications.count
                )
                if progress.completedPageCount == totalPageCount || progress.completedPageCount.isMultiple(of: 8) {
                    Self.rectificationLogger.debug(
                        "Auto All progress \(progress.completedPageCount, privacy: .public)/\(progress.totalPageCount, privacy: .public), estimates \(progress.estimatedPageCount, privacy: .public)"
                    )
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.rectificationAutoRunID == runID else { return }
                    self.rectificationAutoProgress = progress
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.finishAutoEstimateAllPageRectifications(
                    estimatedRectifications,
                    sourcePDFData: sourcePDFData,
                    startingRectifications: startingRectifications,
                    runID: runID,
                    preserveExistingCrops: onlyUnrectified
                )
            }
        }
        DispatchQueue.global(qos: .userInitiated).async { operation.start() }
        return runID
    }

    @discardableResult
    func cancelAutoEstimateAllPageRectifications(runID: UUID? = nil) -> Bool {
        guard let activeRunID = rectificationAutoRunID,
              runID == nil || runID == activeRunID else { return false }
        rectificationAutoOperation?.cancel()
        let completion = rectificationAutoCompletion
        rectificationAutoRunID = nil
        rectificationAutoOperation = nil
        rectificationAutoCompletion = nil
        rectificationAutoProgress = nil
        completion?(.cancelled)
        return true
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
        refreshBarNumber(for: band.id)
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
            if updatedBand.barNumberMode == .automatic {
                refreshBarNumber(for: bandID)
            }
        }
    }

    /// Adds source context without moving any crop edge inward or changing whiteout areas.
    @discardableResult
    func expandBandCrop(_ bandID: UUID, by points: Double) -> Bool {
        guard points.isFinite, points > 0,
              let band = project.bands.first(where: { $0.id == bandID }), band.pageIndex >= 0,
              let bounds = pdfDocument?.page(at: band.pageIndex)?.bounds(for: .mediaBox),
              bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0,
              [band.topFraction, band.bottomFraction, band.leftFraction, band.rightFraction]
                .allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
              band.topFraction < band.bottomFraction, band.leftFraction + band.rightFraction < 1
        else { return false }

        var expanded = band
        expanded.topFraction = max(0, band.topFraction - points / bounds.height)
        expanded.bottomFraction = min(1, band.bottomFraction + points / bounds.height)
        expanded.leftFraction = max(0, band.leftFraction - points / bounds.width)
        expanded.rightFraction = max(0, band.rightFraction - points / bounds.width)
        guard expanded != band else { return false }

        commit(actionName: "Expand Band Crop") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index] = expanded
        }
        bandTemplateHalfHeight = Self.bandHalfHeight(for: expanded)
        return true
    }

    func updateBandExclusions(_ bandID: UUID, exclusions: [BandExclusion]) {
        guard project.bands.contains(where: { $0.id == bandID }) else { return }
        commit(actionName: "Edit Band Exclusions") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].exclusions = exclusions
        }
    }

    func updateBandEditorialLabel(_ bandID: UUID, label: String) {
        guard project.bands.contains(where: { $0.id == bandID }) else { return }
        commit(actionName: "Edit Band Label") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].editorialLabel = label
        }
    }

    func updateBandSourceMarkings(_ bandID: UUID, markings: [BandSourceMarking]) {
        guard project.bands.contains(where: { $0.id == bandID }) else { return }
        commit(actionName: "Edit Shared Score Markings") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].sourceMarkings = markings
        }
    }

    func updateBandPageBreakBefore(_ bandID: UUID, pageBreakBefore: Bool) {
        guard project.bands.contains(where: { $0.id == bandID }) else { return }
        commit(actionName: "Change Band Page Break") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].pageBreakBefore = pageBreakBefore
        }
    }

    func copyCurrentPageBandsToNextPage() {
        copyBands(
            from: currentPageIndex,
            to: [currentPageIndex + 1],
            scope: .allParts,
            actionName: "Copy Bands To Next Page",
            advanceToFirstDestination: true
        )
    }

    func copySelectedPartBandsToNextPage() {
        guard let selectedPartID else { return }
        copyBands(
            from: currentPageIndex,
            to: [currentPageIndex + 1],
            scope: .selectedPart(selectedPartID),
            actionName: "Copy Selected Part To Next Page",
            advanceToFirstDestination: true
        )
    }

    func copyCurrentPageBandsToRemainingPages() {
        copyBands(
            from: currentPageIndex,
            to: remainingPageIndices(after: currentPageIndex),
            scope: .allParts,
            actionName: "Copy Bands To Remaining Pages",
            advanceToFirstDestination: false
        )
    }

    func copySelectedPartBandsToRemainingPages() {
        guard let selectedPartID else { return }
        copyBands(
            from: currentPageIndex,
            to: remainingPageIndices(after: currentPageIndex),
            scope: .selectedPart(selectedPartID),
            actionName: "Copy Selected Part To Remaining Pages",
            advanceToFirstDestination: false
        )
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

    func updateBandBarNumberMode(_ bandID: UUID, mode: BarNumberMode) {
        commit(actionName: "Change Bar Number Mode") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].barNumberMode = mode

            switch mode {
            case .automatic:
                project.bands[index].barNumberValue = nil
                project.bands[index].barNumberConfidence = nil
                project.bands[index].barNumberDetectionMethod = nil
            case .manual:
                if project.bands[index].barNumberValue == nil {
                    project.bands[index].barNumberValue = 1
                }
                project.bands[index].barNumberConfidence = nil
                project.bands[index].barNumberDetectionMethod = nil
            case .hidden:
                break
            }
        }

        if mode == .automatic {
            refreshBarNumber(for: bandID)
        }
    }

    func updateBandBarNumberValue(_ bandID: UUID, value: Int) {
        let clampedValue = max(1, min(value, 999))
        commit(actionName: "Edit Bar Number") { project, _ in
            guard let index = project.bands.firstIndex(where: { $0.id == bandID }) else { return }
            project.bands[index].barNumberMode = .manual
            project.bands[index].barNumberValue = clampedValue
            project.bands[index].barNumberConfidence = nil
            project.bands[index].barNumberDetectionMethod = nil
        }
    }

    func refreshBarNumber(for bandID: UUID) {
        guard let band = band(withID: bandID) else { return }
        guard band.barNumberMode == .automatic else { return }
        guard let sourcePDFData else { return }

        let bandSnapshot = band
        let systemBandsSnapshot = scoreSystemBands(containing: bandSnapshot)
        let pageRectification = project.pageRectifications.first(where: { $0.pageIndex == band.pageIndex })
        Self.barNumberLogger.debug("Refreshing bar number for band \(bandID.uuidString, privacy: .public)")

        barNumberDetectionQueue.async { [weak self, sourcePDFData] in
            guard let self else { return }
            guard let pdfDocument = PDFDocument(data: sourcePDFData) else { return }

            let renderCache = SourcePageRenderCache(pdfDocument: pdfDocument)
            let detection = BarNumberDetector.detect(
                band: bandSnapshot,
                systemBands: systemBandsSnapshot,
                pdfDocument: pdfDocument,
                rectification: pageRectification,
                sourcePageCache: renderCache
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.sourcePDFData == sourcePDFData else { return }
                guard let currentBand = self.band(withID: bandID) else { return }
                guard currentBand.barNumberMode == .automatic else { return }
                guard Self.matchesDetectionSnapshot(currentBand, snapshot: bandSnapshot) else { return }
                let resolvedDetection = detection ?? self.inferredBarNumberFromNearbyBands(for: currentBand)
                self.applyAutomaticBarNumberDetection(resolvedDetection, toSystemContaining: currentBand)
            }
        }
    }

    func refreshAutomaticBarNumbers(for partID: UUID) {
        project.sortedBands(for: partID)
            .filter { $0.excluded == false && $0.barNumberMode == .automatic }
            .forEach { refreshBarNumber(for: $0.id) }
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

    private func remainingPageIndices(after pageIndex: Int) -> [Int] {
        guard pageIndex + 1 < project.pageCount else { return [] }
        return Array((pageIndex + 1)..<project.pageCount)
    }

    private func canCopyBands(from sourcePageIndex: Int, to destinationPageIndices: [Int], scope: BandCopyScope) -> Bool {
        guard destinationPageIndices.isEmpty == false else { return false }
        return sourceBandsForCopy(on: sourcePageIndex, scope: scope).isEmpty == false
    }

    private func sourceBandsForCopy(on pageIndex: Int, scope: BandCopyScope) -> [BandModel] {
        project.bands(on: pageIndex).filter { band in
            switch scope {
            case .allParts:
                return true
            case .selectedPart(let partID):
                return band.partID == partID
            }
        }
    }

    private func copyBands(
        from sourcePageIndex: Int,
        to destinationPageIndices: [Int],
        scope: BandCopyScope,
        actionName: String,
        advanceToFirstDestination: Bool
    ) {
        let destinationPageIndices = destinationPageIndices.filter { $0 >= 0 && $0 < project.pageCount && $0 != sourcePageIndex }
        guard destinationPageIndices.isEmpty == false else { return }

        let sourceBands = sourceBandsForCopy(on: sourcePageIndex, scope: scope)
        guard sourceBands.isEmpty == false else { return }

        let copyStartDate = Date()
        var copyIndex = 0
        var copiedBands: [BandModel] = []
        copiedBands.reserveCapacity(sourceBands.count * destinationPageIndices.count)

        for destinationPageIndex in destinationPageIndices {
            for band in sourceBands {
                var copy = band
                copy.id = UUID()
                copy.pageIndex = destinationPageIndex
                copy.createdAt = copyStartDate.addingTimeInterval(Double(copyIndex) * 0.001)
                copy.barNumberMode = .automatic
                copy.barNumberValue = nil
                copy.barNumberConfidence = nil
                copy.barNumberDetectionMethod = nil
                copiedBands.append(copy)
                copyIndex += 1
            }
        }

        commit(actionName: actionName) { project, _ in
            for destinationPageIndex in destinationPageIndices {
                switch scope {
                case .allParts:
                    project.bands.removeAll { $0.pageIndex == destinationPageIndex }
                case .selectedPart(let partID):
                    project.bands.removeAll { $0.pageIndex == destinationPageIndex && $0.partID == partID }
                }
            }
            project.bands.append(contentsOf: copiedBands)
        }

        if advanceToFirstDestination, let firstDestination = destinationPageIndices.first {
            currentPageIndex = firstDestination
        }
        selectedBandID = nil

        copiedBands.forEach { copy in
            refreshBarNumber(for: copy.id)
        }
    }

    private func currentState() -> DocumentStateSnapshot {
        DocumentStateSnapshot(project: project, sourcePDFData: sourcePDFData)
    }

    private func estimatedRectification(for pageIndex: Int) -> PageRectification? {
        guard let pdfDocument, let page = pdfDocument.page(at: pageIndex) else { return nil }
        return PageRectificationEstimator.estimate(for: page, pageIndex: pageIndex)?.rectification.normalized()
    }

    private static func estimatedRectification(for pageIndex: Int, in pdfDocument: PDFDocument) -> PageRectification? {
        guard let page = pdfDocument.page(at: pageIndex) else { return nil }
        return PageRectificationEstimator.estimate(for: page, pageIndex: pageIndex)?.rectification.normalized()
    }

    private func finishAutoEstimateAllPageRectifications(
        _ estimatedRectifications: [PageRectification],
        sourcePDFData: Data,
        startingRectifications: [PageRectification],
        runID: UUID,
        preserveExistingCrops: Bool,
        failed: Bool = false
    ) {
        guard rectificationAutoRunID == runID else { return }
        let completion = rectificationAutoCompletion
        rectificationAutoRunID = nil
        rectificationAutoOperation = nil
        rectificationAutoCompletion = nil
        rectificationAutoProgress = nil
        var result = RectificationAutoResult.unavailable
        defer { completion?(result) }

        guard self.sourcePDFData == sourcePDFData, project.pageRectifications == startingRectifications else {
            Self.rectificationLogger.notice("Auto All ignored because the source PDF or corrections changed during processing")
            result = .sourceChanged
            return
        }
        guard !failed else { return }
        let estimatedPageIndices = Set(estimatedRectifications.map(\.pageIndex))
        let affectsBands = project.bands.contains { estimatedPageIndices.contains($0.pageIndex) }
        let affectsHeader = project.projectSettings.headerSelection.map {
            estimatedPageIndices.contains($0.pageIndex)
        } ?? false
        guard !preserveExistingCrops || (!affectsBands && !affectsHeader) else {
            Self.rectificationLogger.notice("Auto All ignored because an affected page now has crops or a selected header")
            result = .sourceChanged
            return
        }
        result = .completed(appliedPageCount: estimatedRectifications.count)
        guard estimatedRectifications.isEmpty == false else {
            Self.rectificationLogger.notice("Auto All finished with no estimated rectifications")
            return
        }

        commit(actionName: "Auto Rectify All Pages") { project, _ in
            project.pageRectifications.removeAll { estimatedPageIndices.contains($0.pageIndex) }
            project.pageRectifications.append(contentsOf: estimatedRectifications)
        }
        Self.rectificationLogger.notice(
            "Auto All finished with \(estimatedRectifications.count, privacy: .public) rectified pages"
        )
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

    private func applyDerivedProjectMutation(_ mutation: (inout ProjectData) -> Void) {
        var projectCopy = project
        mutation(&projectCopy)
        projectCopy.modifiedAt = .now
        project = projectCopy
        clampSelectionsToCurrentState()
    }

    private func applyAutomaticBarNumberDetection(_ detection: BarNumberDetector.Detection?, toSystemContaining band: BandModel) {
        let targetIDs: Set<UUID>
        if detection == nil {
            targetIDs = [band.id]
        } else {
            targetIDs = Set(scoreSystemBands(containing: band).map(\.id))
        }

        applyDerivedProjectMutation { project in
            for targetID in targetIDs {
                guard let index = project.bands.firstIndex(where: { $0.id == targetID }) else { continue }
                guard project.bands[index].barNumberMode == .automatic else { continue }
                project.bands[index].barNumberValue = detection?.value
                project.bands[index].barNumberConfidence = detection?.confidence
                project.bands[index].barNumberDetectionMethod = detection?.method
            }
        }
    }

    private func scoreSystemBands(containing band: BandModel) -> [BandModel] {
        let pageBands = project.bands(on: band.pageIndex)
        guard let seedIndex = pageBands.firstIndex(where: { $0.id == band.id }) else { return [band] }

        var lowerBound = seedIndex
        while lowerBound > 0, likelySharesScoreSystem(pageBands[lowerBound], pageBands[lowerBound - 1]) {
            lowerBound -= 1
        }

        var upperBound = seedIndex
        while upperBound + 1 < pageBands.count, likelySharesScoreSystem(pageBands[upperBound], pageBands[upperBound + 1]) {
            upperBound += 1
        }

        return Array(pageBands[lowerBound...upperBound])
    }

    private func inferredBarNumberFromNearbyBands(for band: BandModel) -> BarNumberDetector.Detection? {
        let candidateBands = scoreSystemBands(containing: band)
            .filter { otherBand in
                otherBand.id != band.id && otherBand.displayedBarNumber != nil
            }
            .sorted { lhs, rhs in
                let lhsPriority = barNumberInferencePriority(for: lhs)
                let rhsPriority = barNumberInferencePriority(for: rhs)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }

                let lhsConfidence = lhs.barNumberConfidence ?? (lhs.barNumberMode == .manual ? 1.0 : 0.5)
                let rhsConfidence = rhs.barNumberConfidence ?? (rhs.barNumberMode == .manual ? 1.0 : 0.5)
                if lhsConfidence != rhsConfidence {
                    return lhsConfidence > rhsConfidence
                }

                let lhsGap = systemGapDistance(between: band, and: lhs)
                let rhsGap = systemGapDistance(between: band, and: rhs)
                if lhsGap != rhsGap {
                    return lhsGap < rhsGap
                }

                return lhs.normalized().topFraction < rhs.normalized().topFraction
            }

        guard let sourceBand = candidateBands.first,
              let value = sourceBand.displayedBarNumber
        else {
            return nil
        }

        let inheritedConfidence = min(0.95, max(0.55, (sourceBand.barNumberConfidence ?? 0.78) * 0.9))
        return BarNumberDetector.Detection(
            value: value,
            confidence: inheritedConfidence,
            method: .nearbyBand
        )
    }

    private func barNumberInferencePriority(for band: BandModel) -> Int {
        switch band.barNumberMode {
        case .manual:
            return 0
        case .automatic:
            if band.barNumberDetectionMethod == .nearbyBand {
                return 2
            }
            return 1
        case .hidden:
            return 3
        }
    }

    private func likelySharesScoreSystem(_ lhs: BandModel, _ rhs: BandModel) -> Bool {
        systemGapDistance(between: lhs, and: rhs) <= systemAdjacencyThreshold(between: lhs, and: rhs)
    }

    private func systemGapDistance(between lhs: BandModel, and rhs: BandModel) -> Double {
        let lhsNormalized = lhs.normalized()
        let rhsNormalized = rhs.normalized()

        if lhsNormalized.bottomFraction < rhsNormalized.topFraction {
            return rhsNormalized.topFraction - lhsNormalized.bottomFraction
        }

        if rhsNormalized.bottomFraction < lhsNormalized.topFraction {
            return lhsNormalized.topFraction - rhsNormalized.bottomFraction
        }

        return 0
    }

    private func systemAdjacencyThreshold(between lhs: BandModel, and rhs: BandModel) -> Double {
        let lhsHeight = lhs.normalized().bottomFraction - lhs.normalized().topFraction
        let rhsHeight = rhs.normalized().bottomFraction - rhs.normalized().topFraction
        return max(0.01, min(0.035, (lhsHeight + rhsHeight) * 0.45))
    }

    private static func matchesDetectionSnapshot(_ lhs: BandModel, snapshot rhs: BandModel) -> Bool {
        lhs.pageIndex == rhs.pageIndex &&
        abs(lhs.topFraction - rhs.topFraction) < 0.0001 &&
        abs(lhs.bottomFraction - rhs.bottomFraction) < 0.0001 &&
        abs(lhs.leftFraction - rhs.leftFraction) < 0.0001 &&
        abs(lhs.rightFraction - rhs.rightFraction) < 0.0001
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
            if let cachedPDFDocument {
                sourcePageRenderCache = SourcePageRenderCache(pdfDocument: cachedPDFDocument)
            } else {
                sourcePageRenderCache = nil
            }
        } else {
            cachedPDFDocument = nil
            sourcePageRenderCache = nil
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

        project.pageRectifications.removeAll { rectification in
            rectification.pageIndex < 0 || rectification.pageIndex >= project.pageCount
        }

        currentPageIndex = max(0, min(currentPageIndex, max(0, project.pageCount - 1)))
    }
}

final class SourcePageRenderCache {
    private struct CachedRectifiedPage {
        var rectification: PageRectification
        var pageBounds: CGRect
        var image: CGImage
        var displayDocument: PDFDocument
    }

    private static let ciContext = CIContext(options: nil)

    private let pdfDocument: PDFDocument
    private let rasterScale: CGFloat
    private var rectifiedPages: [Int: CachedRectifiedPage] = [:]

    init(pdfDocument: PDFDocument, rasterScale: CGFloat = 300.0 / 72.0) {
        self.pdfDocument = pdfDocument
        self.rasterScale = rasterScale
    }

    func rectifiedDisplayDocument(for pageIndex: Int, rectification: PageRectification?) -> PDFDocument? {
        rectifiedPage(for: pageIndex, rectification: rectification)?.displayDocument
    }

    func rectifiedDisplayImage(for pageIndex: Int, rectification: PageRectification?) -> CGImage? {
        rectifiedPage(for: pageIndex, rectification: rectification)?.image
    }

    func pageBounds(for pageIndex: Int) -> CGRect? {
        pdfDocument.page(at: pageIndex)?.bounds(for: .mediaBox)
    }

    func imageForDetection(pageIndex: Int, rectification: PageRectification?) -> (image: CGImage, pageBounds: CGRect)? {
        if let rectifiedPage = rectifiedPage(for: pageIndex, rectification: rectification) {
            return (rectifiedPage.image, rectifiedPage.pageBounds)
        }

        guard let pdfPage = pdfDocument.page(at: pageIndex) else { return nil }
        guard let pageBounds = pageBounds(for: pageIndex) else { return nil }
        guard let image = rasterizedImage(for: pdfPage, pageBounds: pageBounds, scale: rasterScale) else { return nil }
        return (image, pageBounds)
    }

    func draw(
        pageIndex: Int,
        rectification: PageRectification?,
        sourceRect: CGRect,
        destinationRect: CGRect,
        in context: CGContext
    ) throws {
        guard let pdfPage = pdfDocument.page(at: pageIndex) else { throw PartLayoutError.missingSourcePage(pageIndex) }

        if let rectification {
            // Bands refer to corrected coordinates. Drawing the original page
            // after a correction failure would silently substitute different music.
            guard let rectifiedPage = rectifiedPage(for: pageIndex, rectification: rectification) else {
                throw PartLayoutError.failedRectification(pageIndex)
            }
            draw(
                image: rectifiedPage.image,
                pageBounds: rectifiedPage.pageBounds,
                sourceRect: sourceRect,
                destinationRect: destinationRect,
                in: context
            )
        } else {
            draw(
                pdfPage: pdfPage,
                sourceRect: sourceRect,
                destinationRect: destinationRect,
                in: context
            )
        }
    }

    private func rectifiedPage(for pageIndex: Int, rectification: PageRectification?) -> CachedRectifiedPage? {
        guard let rectification else { return nil }
        guard let pdfPage = pdfDocument.page(at: pageIndex) else { return nil }

        let normalizedRectification = rectification.normalized()
        if let cached = rectifiedPages[pageIndex], cached.rectification == normalizedRectification {
            return cached
        }

        let pageBounds = pdfPage.bounds(for: .mediaBox)
        guard let rasterizedImage = rasterizedImage(
            for: pdfPage,
            pageBounds: pageBounds,
            scale: rasterScale
        ) else {
            return nil
        }

        guard let correctedImage = rectifiedImage(
            from: rasterizedImage,
            rectification: normalizedRectification
        ) else {
            return nil
        }

        guard let displayDocument = makeDisplayDocument(
            from: correctedImage,
            pageBounds: pageBounds
        ) else {
            return nil
        }

        let cachedPage = CachedRectifiedPage(
            rectification: normalizedRectification,
            pageBounds: pageBounds,
            image: correctedImage,
            displayDocument: displayDocument
        )
        rectifiedPages[pageIndex] = cachedPage
        return cachedPage
    }

    private func rasterizedImage(
        for page: PDFPage,
        pageBounds: CGRect,
        scale: CGFloat
    ) -> CGImage? {
        let pixelWidth = max(1, Int((pageBounds.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((pageBounds.height * scale).rounded(.up)))

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    private func rectifiedImage(from image: CGImage, rectification: PageRectification) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let sourceExtent = ciImage.extent
        let sourceQuad = sourceQuadPoints(for: rectification, in: sourceExtent)
        let targetRect = targetRectForRectification(rectification: rectification, sourceExtent: sourceExtent)
        let targetQuad = targetQuadPoints(for: targetRect)

        guard let homography = solveHomography(from: sourceQuad, to: targetQuad) else {
            return nil
        }

        let pageCorners = [
            CGPoint(x: sourceExtent.minX, y: sourceExtent.maxY),
            CGPoint(x: sourceExtent.maxX, y: sourceExtent.maxY),
            CGPoint(x: sourceExtent.maxX, y: sourceExtent.minY),
            CGPoint(x: sourceExtent.minX, y: sourceExtent.minY)
        ]
        let transformedCorners = pageCorners.map { applyingHomography($0, coefficients: homography) }

        let filter = CIFilter.perspectiveTransform()
        filter.inputImage = ciImage
        filter.topLeft = transformedCorners[0]
        filter.topRight = transformedCorners[1]
        filter.bottomRight = transformedCorners[2]
        filter.bottomLeft = transformedCorners[3]

        guard let outputImage = filter.outputImage else { return nil }

        let whiteBackground = CIImage(color: CIColor.white).cropped(to: sourceExtent)
        let compositedImage = outputImage
            .composited(over: whiteBackground)
            .cropped(to: sourceExtent)
        return Self.ciContext.createCGImage(compositedImage, from: sourceExtent)
    }

    private func sourceQuadPoints(for rectification: PageRectification, in sourceExtent: CGRect) -> [CGPoint] {
        [
            CGPoint(
                x: sourceExtent.minX + rectification.topLeft.x * sourceExtent.width,
                y: sourceExtent.maxY - rectification.topLeft.y * sourceExtent.height
            ),
            CGPoint(
                x: sourceExtent.minX + rectification.topRight.x * sourceExtent.width,
                y: sourceExtent.maxY - rectification.topRight.y * sourceExtent.height
            ),
            CGPoint(
                x: sourceExtent.minX + rectification.bottomRight.x * sourceExtent.width,
                y: sourceExtent.maxY - rectification.bottomRight.y * sourceExtent.height
            ),
            CGPoint(
                x: sourceExtent.minX + rectification.bottomLeft.x * sourceExtent.width,
                y: sourceExtent.maxY - rectification.bottomLeft.y * sourceExtent.height
            )
        ]
    }

    private func targetRectForRectification(
        rectification: PageRectification,
        sourceExtent: CGRect
    ) -> CGRect {
        let quad = sourceQuadPoints(for: rectification, in: sourceExtent)
        let topLeft = quad[0]
        let topRight = quad[1]
        let bottomRight = quad[2]
        let bottomLeft = quad[3]

        let center = CGPoint(
            x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4,
            y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4
        )

        let averageHorizontal = (distance(from: topLeft, to: topRight) + distance(from: bottomLeft, to: bottomRight)) / 2
        let averageVertical = (distance(from: topLeft, to: bottomLeft) + distance(from: topRight, to: bottomRight)) / 2
        let width = min(max(averageHorizontal, 1), sourceExtent.width)
        let height = min(max(averageVertical, 1), sourceExtent.height)
        var rect = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )

        if rect.minX < sourceExtent.minX {
            rect.origin.x = sourceExtent.minX
        }
        if rect.maxX > sourceExtent.maxX {
            rect.origin.x = sourceExtent.maxX - rect.width
        }
        if rect.minY < sourceExtent.minY {
            rect.origin.y = sourceExtent.minY
        }
        if rect.maxY > sourceExtent.maxY {
            rect.origin.y = sourceExtent.maxY - rect.height
        }

        return rect
    }

    private func targetQuadPoints(for rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.minY)
        ]
    }

    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    private func solveHomography(from source: [CGPoint], to destination: [CGPoint]) -> [Double]? {
        guard source.count == 4, destination.count == 4 else { return nil }

        var matrix = Array(
            repeating: Array(repeating: 0.0, count: 9),
            count: 8
        )

        for index in 0..<4 {
            let sourcePoint = source[index]
            let destinationPoint = destination[index]
            let x = Double(sourcePoint.x)
            let y = Double(sourcePoint.y)
            let u = Double(destinationPoint.x)
            let v = Double(destinationPoint.y)

            matrix[index * 2] = [x, y, 1, 0, 0, 0, -x * u, -y * u, u]
            matrix[index * 2 + 1] = [0, 0, 0, x, y, 1, -x * v, -y * v, v]
        }

        guard gaussianEliminationSolve(&matrix) else { return nil }

        return matrix.enumerated().map { rowIndex, row in
            row[row.count - 1]
        } + [1.0]
    }

    private func gaussianEliminationSolve(_ matrix: inout [[Double]]) -> Bool {
        let rowCount = matrix.count
        let columnCount = matrix.first?.count ?? 0
        guard rowCount == 8, columnCount == 9 else { return false }

        for pivotIndex in 0..<rowCount {
            var bestRow = pivotIndex
            var bestValue = abs(matrix[pivotIndex][pivotIndex])

            for candidateRow in (pivotIndex + 1)..<rowCount {
                let candidateValue = abs(matrix[candidateRow][pivotIndex])
                if candidateValue > bestValue {
                    bestValue = candidateValue
                    bestRow = candidateRow
                }
            }

            guard bestValue > 1e-9 else { return false }

            if bestRow != pivotIndex {
                matrix.swapAt(bestRow, pivotIndex)
            }

            let pivot = matrix[pivotIndex][pivotIndex]
            for columnIndex in pivotIndex..<columnCount {
                matrix[pivotIndex][columnIndex] /= pivot
            }

            for rowIndex in 0..<rowCount where rowIndex != pivotIndex {
                let factor = matrix[rowIndex][pivotIndex]
                guard factor != 0 else { continue }
                for columnIndex in pivotIndex..<columnCount {
                    matrix[rowIndex][columnIndex] -= factor * matrix[pivotIndex][columnIndex]
                }
            }
        }

        return true
    }

    private func applyingHomography(_ point: CGPoint, coefficients: [Double]) -> CGPoint {
        let x = Double(point.x)
        let y = Double(point.y)
        let denominator = coefficients[6] * x + coefficients[7] * y + coefficients[8]
        guard abs(denominator) > 1e-9 else { return point }

        let mappedX = (coefficients[0] * x + coefficients[1] * y + coefficients[2]) / denominator
        let mappedY = (coefficients[3] * x + coefficients[4] * y + coefficients[5]) / denominator
        return CGPoint(x: mappedX, y: mappedY)
    }

    private func makeDisplayDocument(from image: CGImage, pageBounds: CGRect) -> PDFDocument? {
        let mutableData = NSMutableData()
        var mediaBox = pageBounds

        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPDFPage(nil as CFDictionary?)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(pageBounds)
        context.draw(image, in: pageBounds)
        context.endPDFPage()
        context.closePDF()

        return PDFDocument(data: mutableData as Data)
    }

    private func draw(
        pdfPage: PDFPage,
        sourceRect: CGRect,
        destinationRect: CGRect,
        in context: CGContext
    ) {
        context.saveGState()
        context.clip(to: destinationRect)

        let xScale = destinationRect.width / sourceRect.width
        let yScale = destinationRect.height / sourceRect.height

        context.translateBy(
            x: destinationRect.minX - sourceRect.minX * xScale,
            y: destinationRect.minY - sourceRect.minY * yScale
        )
        context.scaleBy(x: xScale, y: yScale)
        pdfPage.draw(with: .mediaBox, to: context)

        context.restoreGState()
    }

    private func draw(
        image: CGImage,
        pageBounds: CGRect,
        sourceRect: CGRect,
        destinationRect: CGRect,
        in context: CGContext
    ) {
        context.saveGState()
        context.clip(to: destinationRect)

        let xScale = destinationRect.width / sourceRect.width
        let yScale = destinationRect.height / sourceRect.height

        context.translateBy(
            x: destinationRect.minX - sourceRect.minX * xScale,
            y: destinationRect.minY - sourceRect.minY * yScale
        )
        context.scaleBy(x: xScale, y: yScale)
        context.draw(image, in: pageBounds)

        context.restoreGState()
    }
}
