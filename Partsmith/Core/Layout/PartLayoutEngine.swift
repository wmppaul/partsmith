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
    static func makePlan(
        project: ProjectData,
        pageBoundsProvider: (Int) -> CGRect?,
        partID: UUID
    ) throws -> PartRenderPlan {
        guard let part = project.parts.first(where: { $0.id == partID }) else {
            throw PartLayoutError.missingPart
        }

        let includedBands = project
            .sortedBands(for: partID)
            .filter { !$0.excluded }

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

        var pages: [PartRenderPage] = []
        var currentPlacements: [BandPlacement] = []
        var pageIndex = 0
        var cursorTop = pageMusicTop - headerBlockHeight

        for band in includedBands {
            guard validCrop(top: band.topFraction, bottom: band.bottomFraction,
                            left: band.leftFraction, right: band.rightFraction) else {
                throw PartLayoutError.invalidBand(band.pageIndex)
            }
            let pageBounds = try sourcePageBounds(at: band.pageIndex, provider: pageBoundsProvider)
            // Use the validated geometry exactly; silently widening a short crop can include another staff.
            let sourceRect = cropRect(top: band.topFraction, bottom: band.bottomFraction,
                                      left: band.leftFraction, right: band.rightFraction, in: pageBounds)
            guard band.exclusions.allSatisfy({ $0.isValid(in: band) }) else {
                throw PartLayoutError.invalidExclusion(band.pageIndex)
            }
            let fitScale = contentRect.width / sourceRect.width
            // Enlargement must never send the first or last measures outside the printable area.
            let desiredScale = min(fitScale * partScale, fitScale)
            let desiredHeight = sourceRect.height * desiredScale
            let label = band.editorialLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let labelHeight = label.isEmpty ? 0 : BandEditorialLabelStyle.height(for: label, width: contentRect.width)
            // Measured height already includes bottom padding; don't charge it twice in pagination.
            let labelBlockHeight = labelHeight

            let requiresNewPage = !currentPlacements.isEmpty &&
                (band.pageBreakBefore || cursorTop - labelBlockHeight - desiredHeight < margins.bottom)
            if requiresNewPage {
                pages.append(
                    PartRenderPage(
                        index: pageIndex,
                        drawsTitle: pageIndex == 0 && project.projectSettings.showTitleBlock,
                        placements: currentPlacements
                    )
                )
                pageIndex += 1
                currentPlacements = []
                cursorTop = pageMusicTop
            }
            guard labelHeight.isFinite, labelBlockHeight < cursorTop - contentRect.minY else {
                throw PartLayoutError.editorialLabelDoesNotFit(band.pageIndex)
            }
            let labelRect = label.isEmpty ? nil : CGRect(
                x: contentRect.minX, y: cursorTop - labelHeight, width: contentRect.width, height: labelHeight
            )
            let bandTop = cursorTop - labelBlockHeight

            // A crop is indivisible. Fit an unusually tall band below the first-page header or
            // inside a fresh continuation page instead of clamping its bottom and losing its top.
            let renderScale = min(desiredScale, (bandTop - contentRect.minY) / sourceRect.height)
            let targetHeight = sourceRect.height * renderScale
            let targetWidth = sourceRect.width * renderScale
            let destinationRect = CGRect(
                x: contentRect.minX + (contentRect.width - targetWidth) / 2,
                y: bandTop - targetHeight,
                width: targetWidth,
                height: targetHeight
            )
            let exclusionRects = band.exclusions.map { exclusion in
                let rect = cropRect(top: exclusion.topFraction, bottom: exclusion.bottomFraction,
                                    left: exclusion.leftFraction, right: exclusion.rightFraction, in: pageBounds)
                return CGRect(x: destinationRect.minX + (rect.minX - sourceRect.minX) * renderScale,
                              y: destinationRect.minY + (rect.minY - sourceRect.minY) * renderScale,
                              width: rect.width * renderScale, height: rect.height * renderScale)
            }

            currentPlacements.append(
                BandPlacement(
                    bandID: band.id,
                    sourcePageIndex: band.pageIndex,
                    sourceRect: sourceRect,
                    destinationRect: destinationRect,
                    exclusionRects: exclusionRects,
                    editorialLabel: label,
                    editorialLabelRect: labelRect
                )
            )

            cursorTop = destinationRect.minY - interSystemGap
        }

        if currentPlacements.isEmpty == false {
            pages.append(
                PartRenderPage(
                    index: pageIndex,
                    drawsTitle: pageIndex == 0 && project.projectSettings.showTitleBlock,
                    placements: currentPlacements
                )
            )
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
