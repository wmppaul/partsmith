import AppKit
import CoreGraphics
import PDFKit

struct PartRenderPlan {
    var pageSize: CGSize
    var part: PartModel
    var resolvedTitle: String
    var resolvedSubtitle: String
    var showsPartNameInHeader: Bool
    var titleBlockRect: CGRect?
    var partNameRect: CGRect?
    var headerPlacement: HeaderPlacement?
    var pages: [PartRenderPage]
}

struct PartRenderPage: Identifiable {
    var id: Int { index }
    var index: Int
    var drawsTitle: Bool
    var placements: [BandPlacement]
}

struct BandPlacement {
    var bandID: UUID
    var sourcePageIndex: Int
    var sourceRect: CGRect
    var destinationRect: CGRect
    var exclusionRects: [CGRect]
    var editorialLabel: String
    var editorialLabelRect: CGRect?
    var sourceMarkings: [SourceMarkingPlacement] = []
    /// Joined rest strips still identify every original source band.
    var sourceBandIDs: [UUID] = []
    var restReplacement: BandRestReplacement? = nil
}

struct SourceMarkingPlacement {
    var sourceRect: CGRect
    var destinationRect: CGRect
}

struct HeaderPlacement {
    var sourcePageIndex: Int
    var sourceRect: CGRect
    var destinationRect: CGRect
}

enum PartLayoutError: LocalizedError {
    case missingPDF
    case missingPart
    case noBands
    case missingSourcePage(Int)
    case invalidBand(Int)
    case invalidExclusion(Int)
    case invalidHeader
    case invalidLayoutSettings
    case editorialLabelDoesNotFit(Int)
    case invalidSourceMarking(Int)
    case overlappingSourceMarkings(Int)
    case failedRectification(Int)
    case invalidRestReplacement(Int)

    var errorDescription: String? {
        switch self {
        case .missingPDF:
            return "Import a source PDF before previewing or exporting a part."
        case .missingPart:
            return "Select a part before previewing or exporting."
        case .noBands:
            return "The selected part does not have any included bands yet."
        case .missingSourcePage(let pageIndex):
            return "Source page \(pageIndex + 1) is missing or has invalid dimensions. Restore the source PDF before exporting."
        case .invalidBand(let pageIndex):
            return "A crop on source page \(pageIndex + 1) has invalid boundaries. Adjust or remove it before exporting."
        case .invalidExclusion(let pageIndex):
            return "A whiteout area on source page \(pageIndex + 1) extends outside its crop or has invalid boundaries. Adjust or remove it before exporting."
        case .invalidHeader:
            return "The source header has invalid boundaries. Adjust the header selection before exporting."
        case .invalidLayoutSettings:
            return "The output margins, scale, or spacing leave no usable space. Adjust the layout settings before exporting."
        case .editorialLabelDoesNotFit(let pageIndex):
            return "The editorial label for a crop on source page \(pageIndex + 1) is too long to fit with its music. Shorten the label or adjust the output margins before exporting."
        case .invalidSourceMarking(let pageIndex):
            return "A shared source marking on page \(pageIndex + 1) has invalid bounds or extends outside its band's horizontal crop. Widen the crop or review the marking."
        case .overlappingSourceMarkings(let pageIndex):
            return "Shared source markings on page \(pageIndex + 1) overlap in the annotation row. Combine them into one source selection or remove the overlap before exporting."
        case .invalidRestReplacement(let pageIndex):
            return "The multi-bar rest on source page \(pageIndex + 1) needs a verified count between 2 and 999 bars. Restore the source crop or correct the count before exporting."
        case .failedRectification(let pageIndex):
            return "The correction for source page \(pageIndex + 1) could not be rendered. Adjust its correction points, or reset the correction and review that page's crops before previewing or exporting."
        }
    }
}

// Layout and drawing must use the same font, wrapping and leading, or a measured label can clip.
enum BandEditorialLabelStyle {
    static var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        return [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.black, .paragraphStyle: paragraph]
    }

    static let drawingOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    static func height(for text: String, width: CGFloat) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: drawingOptions, attributes: attributes
        )
        return max(14, ceil(bounds.height) + 2)
    }
}

enum PartLayoutEngine {
    /// Source-point height shared with the generated-rest renderer. Scaling the
    /// strip uses the same page-width factor as its surrounding music.
    static let restStripHeight: Double = 48
    private struct PreparedBand {
        var band: BandModel
        var pageBounds: CGRect
        var sourceRect: CGRect
        var label: String
        var labelHeight: Double
        var scale: Double
        var markingRects: [CGRect] = []
        var sourceBandIDs: [UUID]
        var lastSourceOrder: Int
        var restReplacement: BandRestReplacement?
        var restStartNumber: Int?
        var renderedSourceHeight: Double {
            restReplacement == nil ? sourceRect.height : min(PartLayoutEngine.restStripHeight, max(32, sourceRect.height))
        }
        var markingSourceHeight: Double { Double(markingRects.map(\.height).max() ?? 0) }
        var markingGap: Double { markingRects.isEmpty ? 0 : 4 }
        var height: Double { labelHeight + (renderedSourceHeight + markingSourceHeight) * scale + markingGap }
    }

    /// Minimize pages first, then uneven fill and solitary systems. A requested
    /// musical break is a hard boundary; source-page boundaries have no effect.
    private static func paginate(_ bands: [PreparedBand], firstCapacity: Double,
                                 continuationCapacity: Double, gap: Double, balanced: Bool) -> [Range<Int>] {
        let count = bands.count
        guard count > 0 else { return [] }
        var pageCounts = Array(repeating: Int.max, count: count + 1)
        var costs = Array(repeating: Double.infinity, count: count + 1)
        var next = Array(repeating: count, count: count)
        pageCounts[count] = 0
        costs[count] = 0
        for start in stride(from: count - 1, through: 0, by: -1) {
            let capacity = start == 0 ? firstCapacity : continuationCapacity
            var used = 0.0
            for end in start..<count {
                if end > start && bands[end].band.pageBreakBefore { break }
                used += bands[end].height + (end > start ? gap : 0)
                if used > capacity + 0.000001 && end > start { break }
                let occupied = min(used, capacity)
                let pages = 1 + pageCounts[end + 1]
                let emptyFraction = max(0, 1 - occupied / capacity)
                let orphanPenalty = end == start && count > 1 ? 0.35 : 0
                let cost = costs[end + 1] + (balanced ? emptyFraction * emptyFraction + orphanPenalty : 0)
                if pages < pageCounts[start] || (pages == pageCounts[start] && cost <= costs[start]) {
                    pageCounts[start] = pages
                    costs[start] = cost
                    next[start] = end + 1
                }
                if used > capacity { break }
            }
        }
        var ranges: [Range<Int>] = []
        var start = 0
        while start < count {
            ranges.append(start..<next[start])
            start = next[start]
        }
        return ranges
    }

    private static func restStartNumbersAgree(_ start: Int?, count: Int, next: Int?) -> Bool {
        guard let start, let next else { return true }
        let (expected, overflow) = start.addingReportingOverflow(count)
        return !overflow && next == expected
    }

    static func makePlan(
        project: ProjectData,
        pageBoundsProvider: (Int) -> CGRect?,
        partID: UUID
    ) throws -> PartRenderPlan {
        guard let part = project.parts.first(where: { $0.id == partID }) else {
            throw PartLayoutError.missingPart
        }

        let sourceBands = project.sortedBands(for: partID)
        let includedBands = sourceBands.filter { !$0.excluded }

        guard includedBands.isEmpty == false else {
            throw PartLayoutError.noBands
        }

        let pageSize = project.projectSettings.outputPageSize.pointsSize
        let margins = project.projectSettings.margins
        let marginValues = [margins.top, margins.leading, margins.bottom, margins.trailing]
        guard marginValues.allSatisfy({ $0.isFinite && $0 >= 0 }),
              margins.leading + margins.trailing < pageSize.width,
              margins.top + margins.bottom < pageSize.height,
              part.layoutSettings.scale.isFinite, part.layoutSettings.scale > 0,
              part.layoutSettings.interSystemGap.isFinite, part.layoutSettings.interSystemGap >= 0
        else {
            throw PartLayoutError.invalidLayoutSettings
        }
        let contentRect = CGRect(
            x: margins.leading,
            y: margins.bottom,
            width: pageSize.width - margins.leading - margins.trailing,
            height: pageSize.height - margins.top - margins.bottom
        )
        let partScale = max(0.6, min(part.layoutSettings.scale, 1.4))
        let interSystemGap = max(4, part.layoutSettings.interSystemGap)
        let nameHeight = project.projectSettings.showPartNameInHeader ? 24.0 : 0.0
        let partNameRect = nameHeight > 0 ? CGRect(
            x: contentRect.minX, y: contentRect.maxY - 18, width: contentRect.width, height: 18
        ) : nil
        let pageMusicTop = contentRect.maxY - nameHeight
        guard pageMusicTop > contentRect.minY else {
            throw PartLayoutError.invalidLayoutSettings
        }
        let headerPlacement = try sourceHeaderPlacement(
            project: project,
            pageBoundsProvider: pageBoundsProvider,
            contentRect: contentRect,
            top: pageMusicTop
        )
        let headerBlockHeight: Double
        if project.projectSettings.showTitleBlock == false {
            headerBlockHeight = 0
        } else if let headerPlacement {
            headerBlockHeight = headerPlacement.destinationRect.height + 18
        } else {
            headerBlockHeight = 60
        }
        guard pageMusicTop - headerBlockHeight > contentRect.minY else {
            throw PartLayoutError.invalidLayoutSettings
        }
        let titleBlockRect = project.projectSettings.showTitleBlock && headerPlacement == nil ? CGRect(
            x: contentRect.minX, y: pageMusicTop - 60, width: contentRect.width, height: 60
        ) : nil

        var prepared: [PreparedBand] = []
        for (sourceOrder, band) in sourceBands.enumerated() where !band.excluded {
            if let replacement = band.restReplacement, !replacement.isValid {
                throw PartLayoutError.invalidRestReplacement(band.pageIndex)
            }
            guard validCrop(top: band.topFraction, bottom: band.bottomFraction,
                            left: band.leftFraction, right: band.rightFraction) else {
                throw PartLayoutError.invalidBand(band.pageIndex)
            }
            let bounds = try sourcePageBounds(at: band.pageIndex, provider: pageBoundsProvider)
            let sourceRect = cropRect(top: band.topFraction, bottom: band.bottomFraction,
                                      left: band.leftFraction, right: band.rightFraction, in: bounds)
            guard band.exclusions.allSatisfy({ $0.isValid(in: band) }) else {
                throw PartLayoutError.invalidExclusion(band.pageIndex)
            }
            guard band.sourceMarkings.allSatisfy({ $0.isValid(in: band) }) else {
                throw PartLayoutError.invalidSourceMarking(band.pageIndex)
            }
            let label = band.editorialLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let labelHeight = label.isEmpty ? 0 : BandEditorialLabelStyle.height(for: label, width: contentRect.width)
            let capacity = pageMusicTop - contentRect.minY - (prepared.isEmpty ? headerBlockHeight : 0)
            guard labelHeight.isFinite, labelHeight < capacity else {
                throw PartLayoutError.editorialLabelDoesNotFit(band.pageIndex)
            }
            let markingRects = band.sourceMarkings.map {
                cropRect(top: $0.topFraction, bottom: $0.bottomFraction,
                         left: $0.leftFraction, right: $0.rightFraction, in: bounds)
            }
            // Every fragment shares the row's top edge, so overlapping source
            // x spans would overpaint each other even at different source y positions.
            for (index, rect) in markingRects.enumerated() {
                guard markingRects.prefix(index).allSatisfy({
                    min(rect.maxX, $0.maxX) - max(rect.minX, $0.minX) <= 0.0000001
                }) else {
                    throw PartLayoutError.overlappingSourceMarkings(band.pageIndex)
                }
            }
            guard labelHeight + (markingRects.isEmpty ? 0 : 4) < capacity else {
                throw PartLayoutError.editorialLabelDoesNotFit(band.pageIndex)
            }
            prepared.append(PreparedBand(band: band, pageBounds: bounds, sourceRect: sourceRect,
                                         label: label, labelHeight: labelHeight, scale: 1, markingRects: markingRects,
                                         sourceBandIDs: [band.id], lastSourceOrder: sourceOrder,
                                         restReplacement: band.restReplacement, restStartNumber: band.barNumberValue))
        }
        let maximumSourceWidth = prepared.map { $0.sourceRect.width }.max() ?? contentRect.width
        var joined: [PreparedBand] = []
        for item in prepared {
            if let current = item.restReplacement, current.joinWithPrevious,
               let previous = joined.last, let previousRest = previous.restReplacement,
               previous.lastSourceOrder + 1 == item.lastSourceOrder,
               !item.band.pageBreakBefore,
               previous.label.isEmpty, item.label.isEmpty,
               previous.markingRects.isEmpty, item.markingRects.isEmpty,
               previousRest.barCount + current.barCount <= 999,
               restStartNumbersAgree(previous.restStartNumber, count: previousRest.barCount,
                                     next: item.restStartNumber) {
                joined[joined.count - 1].restReplacement = BandRestReplacement(barCount: previousRest.barCount + current.barCount)
                joined[joined.count - 1].sourceBandIDs.append(contentsOf: item.sourceBandIDs)
                joined[joined.count - 1].lastSourceOrder = item.lastSourceOrder
                if previous.restStartNumber == nil, let currentStart = item.restStartNumber {
                    let (derivedStart, overflow) = currentStart.subtractingReportingOverflow(previousRest.barCount)
                    if !overflow { joined[joined.count - 1].restStartNumber = derivedStart }
                }
            } else {
                var separate = item
                if let rest = separate.restReplacement {
                    separate.restReplacement = BandRestReplacement(barCount: rest.barCount)
                }
                joined.append(separate)
            }
        }
        prepared = joined
        for index in prepared.indices {
            let width = part.layoutSettings.useConsistentScale ? maximumSourceWidth : prepared[index].sourceRect.width
            prepared[index].scale = contentRect.width / width * min(partScale, 1)
        }
        let firstCapacity = pageMusicTop - headerBlockHeight - contentRect.minY
        let continuationCapacity = pageMusicTop - contentRect.minY
        var actualGap = interSystemGap
        var ranges = paginate(prepared, firstCapacity: firstCapacity, continuationCapacity: continuationCapacity,
                              gap: actualGap, balanced: part.layoutSettings.balancePages)
        if part.layoutSettings.balancePages, interSystemGap > 4 {
            let compact = paginate(prepared, firstCapacity: firstCapacity, continuationCapacity: continuationCapacity,
                                   gap: 4, balanced: true)
            if compact.count < ranges.count {
                // Page count is monotonic in the gap. Keep the widest spacing that
                // reaches the minimum page count, without changing crops or scale.
                var lower = 4.0
                var upper = interSystemGap
                for _ in 0..<28 {
                    let candidate = (lower + upper) / 2
                    let candidateRanges = paginate(prepared, firstCapacity: firstCapacity,
                        continuationCapacity: continuationCapacity, gap: candidate, balanced: true)
                    if candidateRanges.count == compact.count { lower = candidate } else { upper = candidate }
                }
                actualGap = lower
                ranges = paginate(prepared, firstCapacity: firstCapacity,
                    continuationCapacity: continuationCapacity, gap: actualGap, balanced: true)
            }
        }
        var pages: [PartRenderPage] = []
        for (pageIndex, range) in ranges.enumerated() {
            var cursorTop = pageMusicTop - (pageIndex == 0 ? headerBlockHeight : 0)
            var placements: [BandPlacement] = []
            for index in range {
                let item = prepared[index]
                let band = item.band
                let labelRect = item.label.isEmpty ? nil : CGRect(
                    x: contentRect.minX, y: cursorTop - item.labelHeight,
                    width: contentRect.width, height: item.labelHeight)
                let markingsTop = cursorTop - item.labelHeight
                // Only an individually oversized crop is fitted to one page. Page balancing
                // itself never reduces music scale or removes any source notation.
                let renderScale = min(item.scale, (markingsTop - contentRect.minY - item.markingGap) /
                                      (item.renderedSourceHeight + item.markingSourceHeight))
                let bandTop = markingsTop - item.markingSourceHeight * renderScale - item.markingGap
                let targetWidth = item.sourceRect.width * renderScale
                let destinationRect = CGRect(x: contentRect.minX + (contentRect.width - targetWidth) / 2,
                    y: bandTop - item.renderedSourceHeight * renderScale,
                    width: targetWidth, height: item.renderedSourceHeight * renderScale)
                let exclusionRects = (item.restReplacement == nil ? band.exclusions : []).map { exclusion in
                    let rect = cropRect(top: exclusion.topFraction, bottom: exclusion.bottomFraction,
                                        left: exclusion.leftFraction, right: exclusion.rightFraction, in: item.pageBounds)
                    return CGRect(x: destinationRect.minX + (rect.minX - item.sourceRect.minX) * renderScale,
                                  y: destinationRect.minY + (rect.minY - item.sourceRect.minY) * renderScale,
                                  width: rect.width * renderScale, height: rect.height * renderScale)
                }
                placements.append(BandPlacement(bandID: band.id, sourcePageIndex: band.pageIndex,
                    sourceRect: item.sourceRect, destinationRect: destinationRect, exclusionRects: exclusionRects,
                    editorialLabel: item.label, editorialLabelRect: labelRect,
                    sourceMarkings: item.markingRects.map { rect in
                        SourceMarkingPlacement(sourceRect: rect, destinationRect: CGRect(
                            x: destinationRect.minX + (rect.minX - item.sourceRect.minX) * renderScale,
                            y: markingsTop - rect.height * renderScale,
                            width: rect.width * renderScale, height: rect.height * renderScale))
                    }, sourceBandIDs: item.sourceBandIDs, restReplacement: item.restReplacement))
                cursorTop = destinationRect.minY - actualGap
            }
            pages.append(PartRenderPage(index: pageIndex,
                drawsTitle: pageIndex == 0 && project.projectSettings.showTitleBlock, placements: placements))
        }

        return PartRenderPlan(
            pageSize: pageSize,
            part: part,
            resolvedTitle: resolvedTitle(for: part, project: project),
            resolvedSubtitle: resolvedSubtitle(for: part, project: project),
            showsPartNameInHeader: project.projectSettings.showPartNameInHeader,
            titleBlockRect: titleBlockRect,
            partNameRect: partNameRect,
            headerPlacement: headerPlacement,
            pages: pages
        )
    }

    private static func sourceHeaderPlacement(
        project: ProjectData,
        pageBoundsProvider: (Int) -> CGRect?,
        contentRect: CGRect,
        top: CGFloat
    ) throws -> HeaderPlacement? {
        guard project.projectSettings.showTitleBlock,
              project.projectSettings.headerDisplayMode == .sourceSelection,
              let headerSelection = project.projectSettings.headerSelection
        else {
            return nil
        }

        guard validCrop(top: headerSelection.topFraction, bottom: headerSelection.bottomFraction,
                        left: headerSelection.leftFraction, right: headerSelection.rightFraction) else {
            throw PartLayoutError.invalidHeader
        }
        let pageBounds = try sourcePageBounds(at: headerSelection.pageIndex, provider: pageBoundsProvider)
        let sourceRect = cropRect(top: headerSelection.topFraction, bottom: headerSelection.bottomFraction,
                                  left: headerSelection.leftFraction, right: headerSelection.rightFraction, in: pageBounds)
        // Keep even an oversized header selection intact while reserving most of the page for music.
        let renderScale = min(contentRect.width / sourceRect.width, (top - contentRect.minY) * 0.35 / sourceRect.height)
        let targetHeight = sourceRect.height * renderScale
        let targetWidth = sourceRect.width * renderScale
        let destinationRect = CGRect(
            x: contentRect.minX + (contentRect.width - targetWidth) / 2,
            y: top - targetHeight,
            width: targetWidth,
            height: targetHeight
        )

        return HeaderPlacement(
            sourcePageIndex: headerSelection.pageIndex,
            sourceRect: sourceRect,
            destinationRect: destinationRect
        )
    }

    private static func sourcePageBounds(at pageIndex: Int, provider: (Int) -> CGRect?) throws -> CGRect {
        guard pageIndex >= 0, let bounds = provider(pageIndex),
              [bounds.minX, bounds.minY, bounds.width, bounds.height].allSatisfy({ $0.isFinite }),
              bounds.width > 0, bounds.height > 0 else {
            throw PartLayoutError.missingSourcePage(pageIndex)
        }
        return bounds
    }

    private static func validCrop(top: Double, bottom: Double, left: Double, right: Double) -> Bool {
        [top, bottom, left, right].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
            && bottom > top && left + right < 1
    }

    private static func cropRect(top: Double, bottom: Double, left: Double, right: Double, in bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX + bounds.width * left,
               y: bounds.maxY - bounds.height * bottom,
               width: bounds.width * (1 - left - right),
               height: bounds.height * (bottom - top))
    }

    private static func resolvedTitle(for part: PartModel, project: ProjectData) -> String {
        let partTitle = part.layoutSettings.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if partTitle.isEmpty == false {
            return partTitle
        }

        let projectTitle = project.projectSettings.defaultTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if projectTitle.isEmpty == false {
            return projectTitle
        }

        return part.name
    }

    private static func resolvedSubtitle(for part: PartModel, project: ProjectData) -> String {
        let partSubtitle = part.layoutSettings.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if partSubtitle.isEmpty == false {
            return partSubtitle
        }

        let projectSubtitle = project.projectSettings.defaultComposerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if projectSubtitle.isEmpty == false {
            return projectSubtitle
        }

        return project.sourceFilename ?? ""
    }
}
