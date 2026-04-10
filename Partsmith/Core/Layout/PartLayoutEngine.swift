import CoreGraphics
import PDFKit

struct PartRenderPlan {
    var pageSize: CGSize
    var part: PartModel
    var resolvedTitle: String
    var resolvedSubtitle: String
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

    var errorDescription: String? {
        switch self {
        case .missingPDF:
            return "Import a source PDF before previewing or exporting a part."
        case .missingPart:
            return "Select a part before previewing or exporting."
        case .noBands:
            return "The selected part does not have any included bands yet."
        }
    }
}

enum PartLayoutEngine {
    static func makePlan(project: ProjectData, pdfDocument: PDFDocument?, partID: UUID) throws -> PartRenderPlan {
        guard let pdfDocument else {
            throw PartLayoutError.missingPDF
        }

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
        let fullPageBandWidth = max(120, pageSize.width)
        let partScale = max(0.6, min(part.layoutSettings.scale, 1.4))
        let interSystemGap = max(4, part.layoutSettings.interSystemGap)
        let headerPlacement = sourceHeaderPlacement(
            project: project,
            pdfDocument: pdfDocument,
            pageSize: pageSize
        )
        let headerBlockHeight: Double
        if part.layoutSettings.showTitle == false {
            headerBlockHeight = 0
        } else if let headerPlacement {
            headerBlockHeight = headerPlacement.destinationRect.height + 18
        } else {
            headerBlockHeight = 60
        }

        var pages: [PartRenderPage] = []
        var currentPlacements: [BandPlacement] = []
        var pageIndex = 0
        var cursorTop = pageSize.height - margins.top - headerBlockHeight

        for band in includedBands {
            guard let pdfPage = pdfDocument.page(at: band.pageIndex) else { continue }
            let sourceRect = band.cropRect(in: pdfPage.bounds(for: .mediaBox))
            let fitScale = fullPageBandWidth / sourceRect.width
            let renderScale = fitScale * partScale
            let targetHeight = sourceRect.height * renderScale
            let targetWidth = sourceRect.width * renderScale

            let requiresNewPage = cursorTop - targetHeight < margins.bottom && currentPlacements.isEmpty == false
            if requiresNewPage {
                pages.append(
                    PartRenderPage(
                        index: pageIndex,
                        drawsTitle: pageIndex == 0 && part.layoutSettings.showTitle,
                        placements: currentPlacements
                    )
                )
                pageIndex += 1
                currentPlacements = []
                cursorTop = pageSize.height - margins.top
            }

            let destinationRect = CGRect(
                x: (pageSize.width - targetWidth) / 2,
                y: max(margins.bottom, cursorTop - targetHeight),
                width: targetWidth,
                height: targetHeight
            )

            currentPlacements.append(
                BandPlacement(
                    bandID: band.id,
                    sourcePageIndex: band.pageIndex,
                    sourceRect: sourceRect,
                    destinationRect: destinationRect
                )
            )

            cursorTop = destinationRect.minY - interSystemGap
        }

        if currentPlacements.isEmpty == false {
            pages.append(
                PartRenderPage(
                    index: pageIndex,
                    drawsTitle: pageIndex == 0 && part.layoutSettings.showTitle,
                    placements: currentPlacements
                )
            )
        }

        return PartRenderPlan(
            pageSize: pageSize,
            part: part,
            resolvedTitle: resolvedTitle(for: part, project: project),
            resolvedSubtitle: resolvedSubtitle(for: part, project: project),
            headerPlacement: headerPlacement,
            pages: pages
        )
    }

    private static func sourceHeaderPlacement(
        project: ProjectData,
        pdfDocument: PDFDocument,
        pageSize: CGSize
    ) -> HeaderPlacement? {
        guard project.projectSettings.headerDisplayMode == .sourceSelection,
              let headerSelection = project.projectSettings.headerSelection,
              let pdfPage = pdfDocument.page(at: headerSelection.pageIndex)
        else {
            return nil
        }

        let sourcePageBounds = pdfPage.bounds(for: .mediaBox)
        let sourceRect = headerSelection.cropRect(in: sourcePageBounds)
        guard sourceRect.width > 0, sourceRect.height > 0 else {
            return nil
        }

        let margins = project.projectSettings.margins
        let renderScale = pageSize.width / sourcePageBounds.width
        let targetHeight = sourceRect.height * renderScale
        let destinationRect = CGRect(
            x: (sourceRect.minX - sourcePageBounds.minX) * renderScale,
            y: pageSize.height - margins.top - targetHeight,
            width: sourceRect.width * renderScale,
            height: targetHeight
        )

        return HeaderPlacement(
            sourcePageIndex: headerSelection.pageIndex,
            sourceRect: sourceRect,
            destinationRect: destinationRect
        )
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
