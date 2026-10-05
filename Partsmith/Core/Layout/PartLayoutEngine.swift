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
    var scaleInfo: PartRenderScaleInfo
}

/// Multipliers relative to the original crop's fit-to-width scale. With
/// independent system scaling, the least enlarged system is reported.
struct PartRenderScaleInfo: Equatable {
    var requestedScale: Double
    /// Horizontal enlargement before the exceptional vertical fitting of a
    /// crop taller than an output page; this is not a universal printed size.
    var appliedScale: Double
    /// Largest multiplier that keeps retained source ink within output margins.
    /// This is guidance, not a clamp: the user may deliberately exceed it.
    var maximumSafeScale: Double
    var exceedsContentWidth: Bool { requestedScale > maximumSafeScale + 0.0001 }
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
    var restSourcePlacement: RestSourcePlacement? = nil
    var generatedRest: BandGeneratedRest? = nil
    /// Ordinary music numbers sit outside the source crop, never over its ink.
    var barNumberRect: CGRect? = nil

    var restBarCount: Int? { generatedRest?.barCount ?? restReplacement?.barCount }
}

struct RestSourcePlacement {
    var fragments: [SourceMarkingPlacement]
    var staffLines: [[CGPoint]]
    var staffSpace: CGFloat
    var restCenter: CGPoint
    var restSpan: CGFloat
    var additionalRestCenters: [CGPoint] = []
}

struct SourceMarkingPlacement {
    var sourceRect: CGRect
    var destinationRect: CGRect
    var isBelow: Bool = false
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
    case invalidGeneratedRest(Int)

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
        case .invalidGeneratedRest(let pageIndex):
            return "A silent part on source page \(pageIndex + 1) needs a confirmed count between 1 and 999 bars and a valid source system. Review its silence count before exporting."
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
        var barNumberHeight: Double
        var scale: Double
        var originalSourceRect: CGRect
        var originalSourceWidth: Double { originalSourceRect.width }
        var markingRects: [CGRect] = []
        var belowMarkingIndices: Set<Int> = []
        var sourceBandIDs: [UUID]
        var lastSourceOrder: Int
        var restReplacement: BandRestReplacement?
        var restStartNumber: Int?
        var hasFlexibleRestWidth: Bool {
            (band.generatedRest != nil || (restReplacement != nil && restReplacement?.sourceContext == nil))
                && markingRects.isEmpty
        }
        var renderedSourceHeight: Double {
            if band.generatedRest != nil { return PartLayoutEngine.restStripHeight }
            guard let replacement = restReplacement else { return sourceRect.height }
            if let context = replacement.sourceContext {
                let space = (context.staffLineFractions[4] - context.staffLineFractions[0]) * pageBounds.height / 4
                let slope = tan(context.skewDegrees * .pi / 180)
                let top = pageBounds.maxY - context.staffLineFractions[0] * pageBounds.height
                    + abs(slope) * sourceRect.width / 2
                let barLabelRoom = band.displayedBarNumber == nil ? 0 : 4 * space
                return sourceRect.height + max(barLabelRoom, top + 4 * space - sourceRect.maxY)
            }
            return min(PartLayoutEngine.restStripHeight, max(32, sourceRect.height))
        }
        var aboveMarkingHeight: Double {
            markingRects.enumerated().filter { !belowMarkingIndices.contains($0.offset) }.map { Double($0.element.height) }.max() ?? 0
        }
        var belowMarkingHeight: Double {
            markingRects.enumerated().filter { belowMarkingIndices.contains($0.offset) }.map { Double($0.element.height) }.max() ?? 0
        }
        var markingSourceHeight: Double { aboveMarkingHeight + belowMarkingHeight }
        var aboveMarkingGap: Double { aboveMarkingHeight > 0 ? 4 : 0 }
        var belowMarkingGap: Double { belowMarkingHeight > 0 ? 4 : 0 }
        var markingGap: Double { aboveMarkingGap + belowMarkingGap }
        var height: Double { labelHeight + barNumberHeight + (renderedSourceHeight + markingSourceHeight) * scale + markingGap }
        var barNumberWidth: Double { Double(String(band.displayedBarNumber ?? 0).count) * 7 + 2 }
        var hasOutsideBarNumber: Bool {
            band.displayedBarNumber != nil && band.generatedRest == nil && restReplacement == nil
        }
    }

    /// One horizontal source frame keeps aligned staves aligned even when a
    /// page number, instrument label or speck changes an individual ink trim.
    /// Page-box origins are PDF coordinates, not musical offsets.
    private static func horizontalFrame(_ bands: [PreparedBand], original: Bool) -> CGRect {
        bands.reduce(CGRect.null) { frame, band in
            let rect = original ? band.originalSourceRect : band.sourceRect
            return frame.union(CGRect(x: rect.minX - band.pageBounds.minX,
                                      y: 0, width: rect.width, height: 1))
        }
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
        guard let start else { return next.map { $0 > count } ?? true }
        let (expected, overflow) = start.addingReportingOverflow(count)
        return !overflow && (next == nil || next == expected)
    }

    private static func consecutiveRestSources(_ previous: BandModel, _ next: BandModel,
                                                lastSystemByPage: [Int: Int]) -> Bool {
        let previousSystem = previous.sourceSystemIndex ?? previous.generatedRest?.sourceSystemIndex
        let nextSystem = next.sourceSystemIndex ?? next.generatedRest?.sourceSystemIndex
        if next.pageIndex == previous.pageIndex {
            if let previousSystem, let nextSystem {
                return previousSystem >= 0 && previousSystem < Int.max && nextSystem == previousSystem + 1
            }
            return next.topFraction > previous.topFraction
        }
        if let previousSystem, let last = lastSystemByPage[previous.pageIndex], previousSystem < last { return false }
        return next.pageIndex == previous.pageIndex + 1 && (nextSystem == nil || nextSystem == 0)
    }

    static func makePlan(
        project: ProjectData,
        pageBoundsProvider: (Int) -> CGRect?,
        partID: UUID,
        horizontalContentBoundsProvider: ((BandModel, CGRect) -> CGRect?)? = nil
    ) throws -> PartRenderPlan {
        guard var part = project.parts.first(where: { $0.id == partID }) else {
            throw PartLayoutError.missingPart
        }
        part.layoutSettings = part.layoutSettings.resolved(in: project.projectSettings)

        let sourceBands = project.sortedBands(for: partID)
        let includedBands = sourceBands.filter { !$0.excluded }
        var lastSystemByPage: [Int: Int] = [:]
        for band in project.bands {
            if let index = band.sourceSystemIndex ?? band.generatedRest?.sourceSystemIndex, index >= 0 {
                lastSystemByPage[band.pageIndex] = max(lastSystemByPage[band.pageIndex] ?? 0, index)
            }
        }

        guard includedBands.isEmpty == false else {
            throw PartLayoutError.noBands
        }

        let pageSize = project.projectSettings.outputPageSize.pointsSize
        let margins = part.layoutSettings.outputMargins(in: project.projectSettings)
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
            if let generated = band.generatedRest,
               !generated.isValid || band.restReplacement != nil || !band.exclusions.isEmpty {
                throw PartLayoutError.invalidGeneratedRest(band.pageIndex)
            }
            if let replacement = band.restReplacement, !replacement.isValid {
                throw PartLayoutError.invalidRestReplacement(band.pageIndex)
            }
            if let context = band.restReplacement?.sourceContext, !context.isValid(in: band) {
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
            let hasMusicNumber = band.displayedBarNumber != nil && band.generatedRest == nil && band.restReplacement == nil
            let numberWidth = Double(String(band.displayedBarNumber ?? 0).count) * 7 + 2
            // Prefer the page margin. With narrow margins, reserve a separate
            // row so numbers cannot cover clefs, notes or copied directions.
            let numberHeight = hasMusicNumber && contentRect.minX < numberWidth + 4 ? 16.0 : 0
            let capacity = pageMusicTop - contentRect.minY - (prepared.isEmpty ? headerBlockHeight : 0)
            guard labelHeight.isFinite, labelHeight + numberHeight < capacity else {
                throw PartLayoutError.editorialLabelDoesNotFit(band.pageIndex)
            }
            let markingRects = band.sourceMarkings.map {
                cropRect(top: $0.topFraction, bottom: $0.bottomFraction,
                         left: $0.leftFraction, right: $0.rightFraction, in: bounds)
            }
            let belowMarkingIndices = Set(band.sourceMarkings.indices.filter { band.sourceMarkings[$0].isBelow == true })
            // Fragments on the same side share a row. Opposite sides can retain
            // the same bar position without painting over one another.
            for (index, rect) in markingRects.enumerated() {
                guard markingRects.prefix(index).enumerated().allSatisfy({ previous, other in
                    belowMarkingIndices.contains(index) != belowMarkingIndices.contains(previous)
                        || min(rect.maxX, other.maxX) - max(rect.minX, other.minX) <= 0.0000001
                }) else {
                    throw PartLayoutError.overlappingSourceMarkings(band.pageIndex)
                }
            }
            let markingGaps = (belowMarkingIndices.isEmpty ? 0 : 4)
                + (belowMarkingIndices.count < markingRects.count ? 4 : 0)
            guard labelHeight + numberHeight + Double(markingGaps) < capacity else {
                throw PartLayoutError.editorialLabelDoesNotFit(band.pageIndex)
            }
            var renderedSourceRect = sourceRect
            // At the historical range (<= 1), preserve source geometry exactly.
            // Above it, only independently verified blank horizontal edges can go.
            if partScale > 1, band.generatedRest == nil,
               band.restReplacement == nil || band.restReplacement?.sourceContext != nil,
               let ink = horizontalContentBoundsProvider?(band, sourceRect),
               [ink.minX, ink.minY, ink.width, ink.height].allSatisfy({ $0.isFinite }),
               !ink.isEmpty, sourceRect.insetBy(dx: -0.000001, dy: -0.000001).contains(ink) {
                var left = max(sourceRect.minX, ink.minX)
                var right = min(sourceRect.maxX, ink.maxX)
                var preservedRects = markingRects
                if let context = band.restReplacement?.sourceContext {
                    preservedRects += ([context.prefix] + (context.suffix.map { [$0] } ?? [])).map {
                        cropRect(top: $0.topFraction, bottom: $0.bottomFraction,
                                 left: $0.leftFraction, right: $0.rightFraction, in: bounds)
                    }
                    left = min(left, bounds.minX + context.staffLeftFraction * bounds.width)
                    right = max(right, bounds.minX + context.staffRightFraction * bounds.width)
                }
                for rect in preservedRects { left = min(left, rect.minX); right = max(right, rect.maxX) }
                renderedSourceRect = CGRect(x: max(sourceRect.minX, left), y: sourceRect.minY,
                    width: min(sourceRect.maxX, right) - max(sourceRect.minX, left), height: sourceRect.height)
            }
            prepared.append(PreparedBand(band: band, pageBounds: bounds, sourceRect: renderedSourceRect,
                                         label: label, labelHeight: labelHeight, barNumberHeight: numberHeight, scale: 1,
                                         originalSourceRect: sourceRect, markingRects: markingRects,
                                         belowMarkingIndices: belowMarkingIndices,
                                         sourceBandIDs: [band.id], lastSourceOrder: sourceOrder,
                                         restReplacement: band.restReplacement,
                                         restStartNumber: band.generatedRest?.startBarNumber ?? band.barNumberValue))
        }
        let originalHorizontalFrame = horizontalFrame(prepared, original: true)
        var joined: [PreparedBand] = []
        for item in prepared {
            let currentCount = item.band.generatedRest?.barCount ?? item.restReplacement?.barCount
            let joinsPrevious = item.band.generatedRest?.joinsWithPrevious ?? item.restReplacement?.joinWithPrevious ?? false
            if let currentCount, joinsPrevious,
               let previous = joined.last,
               let previousCount = previous.band.generatedRest?.barCount ?? previous.restReplacement?.barCount,
               // A new printed prefix can contain a changed clef, key, meter
               // or direction. Keep it at its own measure. A verified plain
               // ending of the first strip may extend through later silence.
               item.restReplacement?.sourceContext == nil,
               previous.restReplacement?.sourceContext == nil
                   || previous.restReplacement?.sourceContext?.canExtendThroughFollowingRests == true,
               previous.lastSourceOrder + 1 == item.lastSourceOrder,
               consecutiveRestSources(sourceBands[previous.lastSourceOrder], item.band,
                                      lastSystemByPage: lastSystemByPage),
               !item.band.pageBreakBefore, item.label.isEmpty,
               item.markingRects.isEmpty, previous.belowMarkingIndices.isEmpty,
               previousCount + currentCount <= 999,
               previous.restStartNumber.map({ $0 <= Int.max - (previousCount + currentCount - 1) }) ?? true,
               restStartNumbersAgree(previous.restStartNumber, count: previousCount,
                                     next: item.restStartNumber) {
                var combined = previous
                if combined.restStartNumber == nil, let currentStart = item.restStartNumber {
                    let (derivedStart, overflow) = currentStart.subtractingReportingOverflow(previousCount)
                    if !overflow && derivedStart > 0 { combined.restStartNumber = derivedStart }
                }
                if var generated = combined.band.generatedRest {
                    generated.barCount += currentCount
                    generated.startBarNumber = combined.restStartNumber
                    combined.band.generatedRest = generated
                } else {
                    combined.restReplacement?.barCount += currentCount
                }
                combined.sourceBandIDs.append(contentsOf: item.sourceBandIDs)
                combined.lastSourceOrder = item.lastSourceOrder
                joined[joined.count - 1] = combined
            } else {
                joined.append(item)
            }
        }
        prepared = joined
        let fixedWidthBands = prepared.filter { !$0.hasFlexibleRestWidth }
        let retainedHorizontalFrame = fixedWidthBands.isEmpty || partScale <= 1
            ? originalHorizontalFrame : horizontalFrame(fixedWidthBands, original: false)
        let consistentSafeScale = fixedWidthBands.isEmpty ? partScale
            : originalHorizontalFrame.width / retainedHorizontalFrame.width
        var appliedScales: [Double] = []
        var safeScales: [Double] = []
        for index in prepared.indices {
            let item = prepared[index]
            let width = part.layoutSettings.useConsistentScale ? originalHorizontalFrame.width : item.originalSourceWidth
            let safeScale = part.layoutSettings.useConsistentScale ? consistentSafeScale :
                (item.hasFlexibleRestWidth ? partScale : width / item.sourceRect.width)
            let appliedScale = partScale
            prepared[index].scale = contentRect.width / width * appliedScale
            let scaledLeft = part.layoutSettings.useConsistentScale
                ? contentRect.midX + (item.sourceRect.minX - item.pageBounds.minX
                    - retainedHorizontalFrame.midX) * prepared[index].scale
                : contentRect.midX - item.sourceRect.width * prepared[index].scale / 2
            if item.hasOutsideBarNumber,
               item.renderedSourceHeight * prepared[index].scale < 12 || scaledLeft < contentRect.minX - 0.000001 {
                // Keep numbers clear of both short crops and music deliberately
                // enlarged into the margin where a number would otherwise sit.
                prepared[index].barNumberHeight = 16
                let capacity = pageMusicTop - contentRect.minY - (index == 0 ? headerBlockHeight : 0)
                guard item.labelHeight + 16 + item.markingGap < capacity else {
                    throw PartLayoutError.editorialLabelDoesNotFit(item.band.pageIndex)
                }
            }
            appliedScales.append(appliedScale)
            safeScales.append(safeScale)
        }
        let scaleInfo = PartRenderScaleInfo(requestedScale: partScale,
            appliedScale: appliedScales.min() ?? partScale,
            maximumSafeScale: safeScales.min() ?? partScale)
        let firstCapacity = pageMusicTop - headerBlockHeight - contentRect.minY
        let continuationCapacity = pageMusicTop - contentRect.minY
        let actualGap = interSystemGap
        let ranges = paginate(prepared, firstCapacity: firstCapacity, continuationCapacity: continuationCapacity,
                              gap: actualGap, balanced: part.layoutSettings.balancePages)
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
                let markingsTop = cursorTop - item.labelHeight - item.barNumberHeight
                // Only an individually oversized crop is fitted to one page. Page balancing
                // itself never reduces music scale or removes any source notation.
                let renderScale = min(item.scale, (markingsTop - contentRect.minY - item.markingGap) /
                                      (item.renderedSourceHeight + item.markingSourceHeight))
                let bandTop = markingsTop - item.aboveMarkingHeight * renderScale - item.aboveMarkingGap
                // Newly drawn rest lines can shorten to the available width
                // without constraining the size of surrounding source notation.
                let targetWidth = item.hasFlexibleRestWidth ? min(contentRect.width, item.sourceRect.width * renderScale)
                    : item.sourceRect.width * renderScale
                let destinationX: Double
                if part.layoutSettings.useConsistentScale && !item.hasFlexibleRestWidth {
                    destinationX = contentRect.midX + (item.sourceRect.minX - item.pageBounds.minX
                        - retainedHorizontalFrame.midX) * renderScale
                } else {
                    destinationX = contentRect.minX + (contentRect.width - targetWidth) / 2
                }
                let destinationRect = CGRect(x: destinationX,
                    y: bandTop - item.renderedSourceHeight * renderScale,
                    width: targetWidth, height: item.renderedSourceHeight * renderScale)
                let exclusionRects = (item.restReplacement == nil && band.generatedRest == nil ? band.exclusions : []).map { exclusion in
                    let rect = cropRect(top: exclusion.topFraction, bottom: exclusion.bottomFraction,
                                        left: exclusion.leftFraction, right: exclusion.rightFraction, in: item.pageBounds)
                    return CGRect(x: destinationRect.minX + (rect.minX - item.sourceRect.minX) * renderScale,
                                  y: destinationRect.minY + (rect.minY - item.sourceRect.minY) * renderScale,
                                  width: rect.width * renderScale, height: rect.height * renderScale)
                }
                placements.append(BandPlacement(bandID: band.id, sourcePageIndex: band.pageIndex,
                    sourceRect: item.sourceRect, destinationRect: destinationRect, exclusionRects: exclusionRects,
                    editorialLabel: item.label, editorialLabelRect: labelRect,
                    sourceMarkings: item.markingRects.enumerated().map { index, rect in
                        SourceMarkingPlacement(sourceRect: rect, destinationRect: CGRect(
                            x: destinationRect.minX + (rect.minX - item.sourceRect.minX) * renderScale,
                            y: (item.belowMarkingIndices.contains(index)
                                ? destinationRect.minY - item.belowMarkingGap : markingsTop) - rect.height * renderScale,
                            width: rect.width * renderScale, height: rect.height * renderScale),
                            isBelow: item.belowMarkingIndices.contains(index))
                    }, sourceBandIDs: item.sourceBandIDs, restReplacement: item.restReplacement,
                    restSourcePlacement: restSourcePlacement(for: item, destination: destinationRect, scale: renderScale),
                    generatedRest: band.generatedRest,
                    barNumberRect: item.hasOutsideBarNumber ? CGRect(
                        x: item.barNumberHeight > 0 ? contentRect.minX : contentRect.minX - item.barNumberWidth - 4,
                        y: item.barNumberHeight > 0 ? cursorTop - item.labelHeight - 12 : max(contentRect.minY, destinationRect.maxY - 12),
                        width: item.barNumberWidth, height: 12) : nil))
                cursorTop = destinationRect.minY - item.belowMarkingGap - item.belowMarkingHeight * renderScale - actualGap
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
            pages: pages,
            scaleInfo: scaleInfo
        )
    }

    private static func restSourcePlacement(for item: PreparedBand, destination: CGRect,
                                            scale: CGFloat) -> RestSourcePlacement? {
        guard let context = item.restReplacement?.sourceContext else { return nil }
        let bounds = item.pageBounds
        func rect(_ fragment: BandSourceMarking) -> CGRect {
            cropRect(top: fragment.topFraction, bottom: fragment.bottomFraction,
                     left: fragment.leftFraction, right: fragment.rightFraction, in: bounds)
        }
        func point(_ source: CGPoint) -> CGPoint {
            CGPoint(x: destination.minX + (source.x - item.sourceRect.minX) * scale,
                    y: destination.minY + (source.y - item.sourceRect.minY) * scale)
        }
        let fragmentRects = ([context.prefix] + (context.suffix.map { [$0] } ?? [])).map(rect)
        let startX = max(bounds.minX + context.staffLeftFraction * bounds.width, fragmentRects[0].maxX)
        let endX = min(bounds.minX + context.staffRightFraction * bounds.width,
                       fragmentRects.count > 1 ? fragmentRects[1].minX : item.sourceRect.maxX)
        let slope = tan(context.skewDegrees * .pi / 180)
        func staffY(_ fraction: Double, at x: CGFloat) -> CGFloat {
            bounds.maxY - fraction * bounds.height - slope * (x - bounds.midX)
        }
        let centerX = (startX + endX) / 2
        return RestSourcePlacement(fragments: fragmentRects.map { source in
            SourceMarkingPlacement(sourceRect: source,
                destinationRect: CGRect(origin: point(source.origin), size: CGSize(width: source.width * scale, height: source.height * scale)))
        }, staffLines: context.resolvedStaffLineGroups.flatMap { $0 }.map { fraction in
            [point(CGPoint(x: startX, y: staffY(fraction, at: startX))),
             point(CGPoint(x: endX, y: staffY(fraction, at: endX)))]
        }, staffSpace: (context.staffLineFractions[4] - context.staffLineFractions[0]) * bounds.height * scale / 4,
            restCenter: point(CGPoint(x: centerX, y: staffY(context.staffLineFractions[2], at: centerX))),
            restSpan: max(0, (endX - startX) * scale),
            additionalRestCenters: context.resolvedStaffLineGroups.dropFirst().map {
                point(CGPoint(x: centerX, y: staffY($0[2], at: centerX)))
            })
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
