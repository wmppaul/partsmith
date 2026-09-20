import AppKit
import CoreGraphics
import PDFKit

enum PartPDFExporter {
    static func previewDocument(for partID: UUID, in document: PartsmithDocument) throws -> PDFDocument {
        let data = try pdfData(for: partID, in: document)
        guard let previewDocument = PDFDocument(data: data) else {
            throw NSError(domain: "Partsmith", code: 2001, userInfo: [NSLocalizedDescriptionKey: "The preview PDF could not be generated."])
        }
        return previewDocument
    }

    static func export(partID: UUID, document: PartsmithDocument, to url: URL) throws {
        let data = try pdfData(for: partID, in: document)
        try data.write(to: url, options: .atomic)
    }

    static func exportAll(document: PartsmithDocument, to directoryURL: URL) throws {
        let exportableParts = document.project.parts.filter { part in
            document.project.bands.contains { $0.partID == part.id && !$0.excluded }
        }

        guard exportableParts.isEmpty == false else {
            throw NSError(domain: "Partsmith", code: 2003, userInfo: [NSLocalizedDescriptionKey: "There are no parts with included bands to export."])
        }

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var usedNames: Set<String> = []
        for part in exportableParts {
            let filename = uniqueFilename(for: part.name, usedNames: &usedNames)
            let url = directoryURL
                .appendingPathComponent(filename)
                .appendingPathExtension("pdf")
            try export(partID: part.id, document: document, to: url)
        }
    }

    private static func pdfData(for partID: UUID, in document: PartsmithDocument) throws -> Data {
        guard let pdfDocument = document.pdfDocument else {
            throw PartLayoutError.missingPDF
        }

        let sourcePageCache = SourcePageRenderCache(pdfDocument: pdfDocument)
        let plan = try PartLayoutEngine.makePlan(
            project: document.project,
            pageBoundsProvider: { sourcePageCache.pageBounds(for: $0) },
            partID: partID
        )
        let mutableData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: plan.pageSize)

        let metadata: [CFString: Any] = [
            kCGPDFContextCreator: "Partsmith",
            kCGPDFContextTitle: plan.part.name
        ]

        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, metadata as CFDictionary) else {
            throw NSError(domain: "Partsmith", code: 2002, userInfo: [NSLocalizedDescriptionKey: "The PDF export context could not be created."])
        }

        for page in plan.pages {
            context.beginPDFPage(nil as CFDictionary?)
            do {
                try render(page: page, plan: plan, project: document.project, sourcePageCache: sourcePageCache, in: context)
            } catch {
                context.endPDFPage()
                context.closePDF()
                throw error
            }
            context.endPDFPage()
        }

        context.closePDF()
        return mutableData as Data
    }

    private static func render(
        page: PartRenderPage,
        plan: PartRenderPlan,
        project: ProjectData,
        sourcePageCache: SourcePageRenderCache,
        in context: CGContext
    ) throws {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: plan.pageSize))

        if plan.showsPartNameInHeader {
            drawPartNameLabel(for: plan, in: context)
        }

        if page.drawsTitle {
            if let headerPlacement = plan.headerPlacement {
                try draw(headerPlacement: headerPlacement, project: project, sourcePageCache: sourcePageCache, in: context)
            } else {
                drawTitle(for: plan, in: context)
            }
        }

        for placement in page.placements {
            drawEditorialLabel(for: placement, in: context)
            for marking in placement.sourceMarkings {
                try sourcePageCache.draw(pageIndex: placement.sourcePageIndex,
                    rectification: project.pageRectifications.first(where: { $0.pageIndex == placement.sourcePageIndex }),
                    sourceRect: marking.sourceRect, destinationRect: marking.destinationRect, in: context)
            }
            try draw(placement: placement, project: project, sourcePageCache: sourcePageCache, in: context)
            drawExclusions(for: placement, in: context)
            drawBarNumber(for: placement, project: project, in: context)
        }

        // Keep output page numbers distinct from printed source-page numbers
        // that may remain inside the preserved score strips.
        if project.projectSettings.margins.bottom >= 20 {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.darkGray,
                .paragraphStyle: paragraph
            ]
            let footer = CGRect(x: project.projectSettings.margins.leading,
                                y: max(3, (project.projectSettings.margins.bottom - 12) / 2),
                                width: plan.pageSize.width - project.projectSettings.margins.leading - project.projectSettings.margins.trailing,
                                height: 12)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            ("\(page.index + 1) / \(plan.pages.count)" as NSString).draw(in: footer, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
        }

    }

    private static func drawEditorialLabel(for placement: BandPlacement, in context: CGContext) {
        guard let rect = placement.editorialLabelRect else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (placement.editorialLabel as NSString).draw(with: rect,
                                                  options: BandEditorialLabelStyle.drawingOptions,
                                                  attributes: BandEditorialLabelStyle.attributes)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawTitle(for plan: PartRenderPlan, in context: CGContext) {
        guard let titleBlock = plan.titleBlockRect else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.darkGray,
            .paragraphStyle: paragraph
        ]

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        let titleRect = CGRect(
            x: titleBlock.minX, y: titleBlock.maxY - 29,
            width: titleBlock.width, height: 29
        )
        plan.resolvedTitle.draw(in: titleRect, withAttributes: titleAttributes)

        if plan.resolvedSubtitle.isEmpty == false {
            let subtitleRect = CGRect(
                x: titleBlock.minX, y: titleBlock.maxY - 47,
                width: titleBlock.width, height: 17
            )
            plan.resolvedSubtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawPartNameLabel(for plan: PartRenderPlan, in context: CGContext) {
        guard let labelRect = plan.partNameRect else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        plan.part.name.draw(in: labelRect, withAttributes: labelAttributes)

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func draw(
        placement: BandPlacement,
        project: ProjectData,
        sourcePageCache: SourcePageRenderCache,
        in context: CGContext
    ) throws {
        try sourcePageCache.draw(
            pageIndex: placement.sourcePageIndex,
            rectification: project.pageRectifications.first(where: { $0.pageIndex == placement.sourcePageIndex }),
            sourceRect: placement.sourceRect,
            destinationRect: placement.destinationRect,
            in: context
        )
    }

    private static func drawBarNumber(
        for placement: BandPlacement,
        project: ProjectData,
        in context: CGContext
    ) {
        guard let band = project.bands.first(where: { $0.id == placement.bandID }),
              let barNumber = band.displayedBarNumber
        else {
            return
        }

        let label = "\(barNumber)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        let labelSize = label.size(withAttributes: attributes)
        let badgeRect = CGRect(
            x: placement.destinationRect.minX + 8,
            y: placement.destinationRect.maxY - labelSize.height - 12,
            width: labelSize.width + 16,
            height: labelSize.height + 8
        )

        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.96).setFill()
        badgePath.fill()

        NSColor.black.withAlphaComponent(0.18).setStroke()
        badgePath.lineWidth = 0.8
        badgePath.stroke()

        label.draw(
            at: CGPoint(
                x: badgeRect.minX + (badgeRect.width - labelSize.width) / 2,
                y: badgeRect.minY + (badgeRect.height - labelSize.height) / 2
            ),
            withAttributes: attributes
        )

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawExclusions(for placement: BandPlacement, in context: CGContext) {
        guard !placement.exclusionRects.isEmpty else { return }
        context.saveGState()
        // At outer crop edges, cover subpixel sampling fringes as well. Interior edges stay exact
        // so a mask cannot erase neighboring notation that was intentionally retained.
        let rects = placement.exclusionRects.map { rect -> CGRect in
            var minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
            if abs(minX - placement.destinationRect.minX) < 0.00001 { minX -= 0.5 }
            if abs(maxX - placement.destinationRect.maxX) < 0.00001 { maxX += 0.5 }
            if abs(minY - placement.destinationRect.minY) < 0.00001 { minY -= 0.5 }
            if abs(maxY - placement.destinationRect.maxY) < 0.00001 { maxY += 0.5 }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
        context.clip(to: placement.destinationRect.insetBy(dx: -0.5, dy: -0.5))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rects)
        context.restoreGState()
    }

    private static func draw(
        headerPlacement: HeaderPlacement,
        project: ProjectData,
        sourcePageCache: SourcePageRenderCache,
        in context: CGContext
    ) throws {
        try sourcePageCache.draw(
            pageIndex: headerPlacement.sourcePageIndex,
            rectification: project.pageRectifications.first(where: { $0.pageIndex == headerPlacement.sourcePageIndex }),
            sourceRect: headerPlacement.sourceRect,
            destinationRect: headerPlacement.destinationRect,
            in: context
        )
    }

    private static func uniqueFilename(for partName: String, usedNames: inout Set<String>) -> String {
        let baseName = sanitizedPathComponent(partName, fallback: "Part")
        var candidate = baseName
        var suffix = 2

        while usedNames.contains(candidate.lowercased()) {
            candidate = "\(baseName) \(suffix)"
            suffix += 1
        }

        usedNames.insert(candidate.lowercased())
        return candidate
    }

    private static func sanitizedPathComponent(_ string: String, fallback: String) -> String {
        let sanitized = string
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }
}
