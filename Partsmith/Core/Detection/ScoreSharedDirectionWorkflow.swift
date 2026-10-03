import CoreGraphics
import Foundation
import PDFKit

enum ScoreDirectionPhase: String, CaseIterable {
    case headings, navigation, references, destinations, endings

    var title: String {
        switch self {
        case .headings: return "Finding tempo headings"
        case .navigation: return "Finding repeat instructions"
        case .references: return "Reading printed repeat symbols"
        case .destinations: return "Finding linked repeat symbols"
        case .endings: return "Finding paired endings"
        }
    }
}

struct ScoreDirectionProgress {
    var phase: ScoreDirectionPhase
    var completedPages: Int
    var totalPages: Int
}

struct ScoreDirectionIssue: Equatable, Identifiable {
    /// -1 denotes information about the selected score as a whole.
    var pageIndex: Int
    var message: String
    var id: String { "\(pageIndex):\(message)" }
}

struct ScoreDirectionReference {
    var pageIndex: Int
    var match: ScoreSharedDestinationDetector.Match
}

struct ScoreSharedDirectionResult {
    var analyses: [ScorePageAnalysis]
    var issues: [ScoreDirectionIssue]
    var references: [ScoreDirectionReference] = []
}

typealias ScoreSharedDirectionRunner = (PDFDocument, [ScorePageAnalysis], ScoreExtractionProfile,
    [PageRectification], (ScoreDirectionProgress) -> Void, () -> Bool) -> ScoreSharedDirectionResult

/// Recognition dependencies permit deterministic sequencing/failure tests
/// without changing the app's worker or requiring Vision in every test.
struct ScoreSharedDirectionServices {
    var headings: (CGImage, ScorePageAnalysis, ScoreExtractionProfile, () -> Bool) throws -> [ScoreSharedHeading]
    var navigation: (CGImage, ScorePageAnalysis, ScoreExtractionProfile, () -> Bool) throws -> [ScoreSharedNavigation]
    var references: (CGImage, ScorePageAnalysis, ScoreExtractionProfile, () -> Bool) -> [ScoreSharedDestinationDetector.Template]
    var destinations: (CGImage, ScorePageAnalysis, ScoreExtractionProfile,
        [ScoreSharedDestinationDetector.Template], () -> Bool) -> ([ScoreSharedNavigation], [ScoreSharedDestinationDetector.Match])

    var endings: ((CGImage, ScorePageAnalysis, ScoreExtractionProfile, () -> Bool) throws -> ScoreSharedEndingDetector.PageResult)? = nil
    var pairEndings: ([ScoreSharedEndingDetector.PageResult], () -> Bool) -> [ScoreSharedEndingDetector.Pair] = {
        ScoreSharedEndingDetector.pairs(in: $0, isCancelled: $1)
    }

    static var native: Self {
        Self(headings: { image, page, profile, cancelled in
            var failure: Error?
            let headings = ScoreSharedHeadingDetector.detect(in: image, page: page, profile: profile,
                observedFailure: { _, error in failure = error }, isCancelled: cancelled)
            if let failure { throw failure }
            return headings
        }, navigation: { image, page, profile, cancelled in
            var failure: Error?
            let navigation = ScoreSharedNavigationDetector.detect(in: image, page: page, profile: profile,
                observedFailure: { _, error in failure = error }, isCancelled: cancelled)
            if let failure { throw failure }
            return navigation
        }, references: { image, page, profile, cancelled in
            ScoreSharedDestinationDetector.templates(in: image, page: page, profile: profile, isCancelled: cancelled)
        }, destinations: { image, page, profile, templates, cancelled in
            var matches: [ScoreSharedDestinationDetector.Match] = []
            let symbols = ScoreSharedDestinationDetector.detect(in: image, page: page, profile: profile,
                templates: templates, observedMatches: { matches = $0 }, isCancelled: cancelled)
            return (symbols, matches)
        }, endings: { image, page, profile, cancelled in
            var failure: Error?
            let result = ScoreSharedEndingDetector.analyze(in: image, page: page, profile: profile,
                observedFailure: { failure = $0 }, isCancelled: cancelled)
            if let failure { throw failure }
            return result
        })
    }
}

enum ScoreSharedDirectionWorkflow {
    /// Called on the document's serial worker with its private PDFDocument.
    static func run(pdf: PDFDocument, analyses: [ScorePageAnalysis], profile: ScoreExtractionProfile,
                    rectifications: [PageRectification], progress: (ScoreDirectionProgress) -> Void,
                    isCancelled: () -> Bool) -> ScoreSharedDirectionResult {
        analyze(analyses: analyses, profile: profile, render: { analysis, phase in
            guard let page = pdf.page(at: analysis.pageIndex) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { return nil }
            let width = phase == .headings ? 2200 : 2400
            let height = phase == .headings ? 3200 : 3500
            if let correction = rectifications.first(where: { $0.pageIndex == analysis.pageIndex }) {
                // Use the saved display transformation, never a new estimate or
                // an uncorrected fallback with corrected staff coordinates.
                return SourcePageRenderCache(pdfDocument: pdf,
                    rasterScale: min(CGFloat(width) / bounds.width, CGFloat(height) / bounds.height))
                    .rectifiedDisplayImage(for: analysis.pageIndex, rectification: correction)
            }
            return NativeScorePageAnalyzer.render(page, maximumWidth: width, maximumHeight: height)
        }, progress: progress, isCancelled: isCancelled)
    }

    static func analyze(analyses: [ScorePageAnalysis], profile: ScoreExtractionProfile,
                        render: (ScorePageAnalysis, ScoreDirectionPhase) -> CGImage?,
                        services: ScoreSharedDirectionServices = .native,
                        progress: (ScoreDirectionProgress) -> Void,
                        isCancelled: () -> Bool) -> ScoreSharedDirectionResult {
        let cancelledResult = ScoreSharedDirectionResult(analyses: analyses, issues: [])
        var result = ScoreSharedDirectionResult(analyses: analyses, issues: [])
        var eligible: [Int] = []
        for index in result.analyses.indices {
            guard !isCancelled() else { return cancelledResult }
            // A fresh scan replaces recognition metadata; it cannot seed itself
            // with copies left by an earlier run.
            result.analyses[index].sharedHeadings = nil
            result.analyses[index].sharedNavigation = nil
            result.analyses[index].sharedEndings = nil
            let page = result.analyses[index]
            if page.staves.isEmpty { continue }
            let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile, isCancelled: isCancelled)
            if plan.canApply, profile.requiresSystemAssignment != true {
                eligible.append(index)
            } else {
                result.issues.append(.init(pageIndex: page.pageIndex,
                    message: "Directions were not scanned because this page's staff layout needs assignment."))
            }
        }
        for phase in [ScoreDirectionPhase.headings, .navigation] {
            progress(.init(phase: phase, completedPages: 0, totalPages: eligible.count))
            for (offset, index) in eligible.enumerated() {
                guard !isCancelled() else { return cancelledResult }
                autoreleasepool {
                    let page = result.analyses[index]
                    guard let image = render(page, phase) else {
                        result.issues.append(.init(pageIndex: page.pageIndex,
                            message: "\(phase.title) could not render this page. Its ordinary music crops are retained."))
                        return
                    }
                    do {
                        if phase == .headings {
                            result.analyses[index].sharedHeadings = try services.headings(image, page, profile, isCancelled)
                        } else {
                            result.analyses[index].sharedNavigation = try services.navigation(image, page, profile, isCancelled)
                        }
                    } catch {
                        // Partial OCR from this module is discarded, but this
                        // optional pass must not block accepting valid music.
                        result.issues.append(.init(pageIndex: page.pageIndex,
                            message: "\(phase.title) failed: \(error.localizedDescription)"))
                    }
                }
                guard !isCancelled() else { return cancelledResult }
                progress(.init(phase: phase, completedPages: offset + 1, totalPages: eligible.count))
            }
        }
        // Instructions can follow their destinations. Collect references across
        // the entire input selection before searching any destination page.
        var templates: [ScoreSharedDestinationDetector.Template] = []
        let referencedPages = eligible.filter {
            result.analyses[$0].sharedNavigation?.contains { !$0.recognizedText.isEmpty } == true
        }
        progress(.init(phase: .references, completedPages: 0, totalPages: referencedPages.count))
        for (offset, index) in referencedPages.enumerated() {
            guard !isCancelled() else { return cancelledResult }
            autoreleasepool {
                let page = result.analyses[index]
                guard let image = render(page, .references) else {
                    result.issues.append(.init(pageIndex: page.pageIndex,
                        message: "The printed repeat-symbol reference could not be rendered."))
                    return
                }
                templates += services.references(image, page, profile, isCancelled)
            }
            guard !isCancelled() else { return cancelledResult }
            progress(.init(phase: .references, completedPages: offset + 1, totalPages: referencedPages.count))
        }
        if !referencedPages.isEmpty, templates.isEmpty {
            result.issues.append(.init(pageIndex: -1,
                message: "No supported printed repeat-symbol reference was found in the selected pages. Check the repeat destinations in the source."))
        }
        if !templates.isEmpty {
            progress(.init(phase: .destinations, completedPages: 0, totalPages: eligible.count))
            for (offset, index) in eligible.enumerated() {
                guard !isCancelled() else { return cancelledResult }
                autoreleasepool {
                    let page = result.analyses[index]
                    // Failed instruction recognition leaves this page's inline
                    // symbols unclassified, so do not treat them as destinations.
                    guard page.sharedNavigation != nil else { return }
                    guard let image = render(page, .destinations) else {
                        result.issues.append(.init(pageIndex: page.pageIndex,
                            message: "Linked repeat symbols could not be scanned on this page."))
                        return
                    }
                    let (symbols, matches) = services.destinations(image, page, profile, templates, isCancelled)
                    result.analyses[index].sharedNavigation = (page.sharedNavigation ?? []) + symbols
                    result.references += matches.map { .init(pageIndex: page.pageIndex, match: $0) }
                }
                guard !isCancelled() else { return cancelledResult }
                progress(.init(phase: .destinations, completedPages: offset + 1, totalPages: eligible.count))
            }
        }
        if let recognizeEndings = services.endings {
            // Keep an entry for every selected physical page. Failed/unresolved
            // pages are barriers; missing indices remain gaps in the pairer.
            var endingPages = result.analyses.map { page in
                ScoreSharedEndingDetector.PageResult(pageIndex: page.pageIndex, ownershipVerified: false,
                    systemIndices: [], geometryProposalCount: 0, mergedProposalCount: 0, candidates: [])
            }
            let eligibleSet = Set(eligible)
            progress(.init(phase: .endings, completedPages: 0, totalPages: result.analyses.count))
            for index in result.analyses.indices {
                guard !isCancelled() else { return cancelledResult }
                autoreleasepool {
                    let page = result.analyses[index]
                    guard eligibleSet.contains(index) || page.staves.isEmpty else { return }
                    guard let image = render(page, .endings) else {
                        result.issues.append(.init(pageIndex: page.pageIndex,
                            message: "Paired endings could not render this page. Ending pairing will not cross it; ordinary music crops are retained."))
                        return
                    }
                    if page.staves.isEmpty {
                        // No detected staffs is not proof of a blank page. Only
                        // a completely white render supplies an affirmed blank.
                        if page.pageWidth.isFinite, page.pageWidth > 0, page.pageHeight.isFinite, page.pageHeight > 0,
                           let raster = ScoreSharedEndingDetector.Raster(image: image),
                           raster.pixels.allSatisfy({ $0 == 255 }) {
                            endingPages[index].ownershipVerified = true
                        }
                        return
                    }
                    do {
                        let observed = try recognizeEndings(image, page, profile, isCancelled)
                        guard observed.pageIndex == page.pageIndex, observed.ownershipVerified else {
                            result.issues.append(.init(pageIndex: page.pageIndex,
                                message: "Paired-ending staff ownership could not be verified. Ordinary music crops are retained."))
                            return
                        }
                        endingPages[index] = observed
                    } catch {
                        result.issues.append(.init(pageIndex: page.pageIndex,
                            message: "Finding paired endings failed: \(error.localizedDescription)"))
                    }
                }
                guard !isCancelled() else { return cancelledResult }
                progress(.init(phase: .endings, completedPages: index + 1, totalPages: result.analyses.count))
            }
            guard !isCancelled() else { return cancelledResult }
            let pairs = services.pairEndings(endingPages, isCancelled)
            guard !isCancelled() else { return cancelledResult }
            let metadata = ScoreSharedEndingMetadata.make(pairs: pairs, pages: result.analyses, isCancelled: isCancelled)
            guard !isCancelled() else { return cancelledResult }
            for index in result.analyses.indices where endingPages[index].ownershipVerified {
                result.analyses[index].sharedEndings = metadata[result.analyses[index].pageIndex] ?? []
            }
        }
        return isCancelled() ? cancelledResult : result
    }
}
