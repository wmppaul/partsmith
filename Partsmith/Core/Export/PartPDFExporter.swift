import AppKit
import CoreGraphics
import PDFKit

struct PartPDFRenderResult {
    var data: Data
    /// The exact placements used to draw `data`, including content trimming and
    /// any page-height fitting. Preview interactions must not recompute them.
    var renderPlan: PartRenderPlan
    var scaleInfo: PartRenderScaleInfo { renderPlan.scaleInfo }
}

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
        return try renderResult(for: partID, project: document.project, pdfDocument: pdfDocument).data
    }

    /// Immutable input for background previews. Each caller owns its PDFKit
    /// document and render cache, using exactly the export layout and renderer.
    static func pdfData(for partID: UUID, project: ProjectData, sourcePDFData: Data,
                        isCancelled: () -> Bool = { false }) throws -> Data {
        try renderResult(for: partID, project: project, sourcePDFData: sourcePDFData,
                         isCancelled: isCancelled).data
    }

    static func renderResult(for partID: UUID, project: ProjectData, sourcePDFData: Data,
                             horizontalContentCache: SourceHorizontalContentCache? = nil,
                             isCancelled: () -> Bool = { false }) throws -> PartPDFRenderResult {
        guard !isCancelled() else { throw CancellationError() }
        horizontalContentCache?.prepare(for: sourcePDFData)
        guard let pdfDocument = PDFDocument(data: sourcePDFData) else { throw PartLayoutError.missingPDF }
        return try renderResult(for: partID, project: project, pdfDocument: pdfDocument,
                                horizontalContentCache: horizontalContentCache, isCancelled: isCancelled)
    }

    private static func renderResult(for partID: UUID, project: ProjectData, pdfDocument: PDFDocument,
                                     horizontalContentCache: SourceHorizontalContentCache? = nil,
                                     isCancelled: () -> Bool = { false }) throws -> PartPDFRenderResult {
        guard !isCancelled() else { throw CancellationError() }
        let sourcePageCache = SourcePageRenderCache(pdfDocument: pdfDocument, horizontalContentCache: horizontalContentCache)
        // makePlan consumes the provider synchronously; it never stores it.
        let plan = try withoutActuallyEscaping(isCancelled) { cancelled in
            try PartLayoutEngine.makePlan(
                project: project,
                pageBoundsProvider: { sourcePageCache.pageBounds(for: $0) },
                partID: partID,
                horizontalContentBoundsProvider: { band, sourceRect in
                    guard !cancelled() else { return nil }
                    return autoreleasepool {
                        sourcePageCache.horizontalContentBounds(for: band, sourceRect: sourceRect,
                            rectification: project.pageRectifications.first(where: { $0.pageIndex == band.pageIndex }),
                            isCancelled: cancelled)
                    }
                }
            )
        }
        guard !isCancelled() else { throw CancellationError() }
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
            guard !isCancelled() else { context.closePDF(); throw CancellationError() }
            context.beginPDFPage(nil as CFDictionary?)
            do {
                try render(page: page, plan: plan, project: project, sourcePageCache: sourcePageCache,
                           in: context, isCancelled: isCancelled)
            } catch {
                context.endPDFPage()
                context.closePDF()
                throw error
            }
            context.endPDFPage()
        }

        context.closePDF()
        return PartPDFRenderResult(data: mutableData as Data, renderPlan: plan)
    }

    private static func render(
        page: PartRenderPage,
        plan: PartRenderPlan,
        project: ProjectData,
        sourcePageCache: SourcePageRenderCache,
        in context: CGContext,
        isCancelled: () -> Bool = { false }
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
            guard !isCancelled() else { throw CancellationError() }
            drawEditorialLabel(for: placement, in: context)
            for marking in placement.sourceMarkings {
                try sourcePageCache.draw(pageIndex: placement.sourcePageIndex,
                    rectification: project.pageRectifications.first(where: { $0.pageIndex == placement.sourcePageIndex }),
                    sourceRect: marking.sourceRect, destinationRect: marking.destinationRect, in: context)
            }
            if placement.restBarCount != nil {
                if let preserved = placement.restSourcePlacement {
                    for fragment in preserved.fragments {
                        try sourcePageCache.draw(pageIndex: placement.sourcePageIndex,
                            rectification: project.pageRectifications.first(where: { $0.pageIndex == placement.sourcePageIndex }),
                            sourceRect: fragment.sourceRect, destinationRect: fragment.destinationRect, in: context)
                    }
                    drawSourceAlignedRest(for: placement, geometry: preserved, in: context)
                } else {
                    drawMultiBarRest(for: placement, in: context)
                }
            } else {
                try draw(placement: placement, project: project, sourcePageCache: sourcePageCache, in: context)
                drawExclusions(for: placement, in: context)
            }
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
            let leading = plan.part.layoutSettings.sideMarginPoints ?? project.projectSettings.margins.leading
            let trailing = plan.part.layoutSettings.sideMarginPoints ?? project.projectSettings.margins.trailing
            let footer = CGRect(x: leading,
                                y: max(3, (project.projectSettings.margins.bottom - 12) / 2),
                                width: plan.pageSize.width - leading - trailing,
                                height: 12)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            ("\(page.index + 1) / \(plan.pages.count)" as NSString).draw(in: footer, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
        }

    }

    private static func drawSourceAlignedRest(for placement: BandPlacement, geometry: RestSourcePlacement,
                                              in context: CGContext) {
        guard let replacement = placement.restReplacement else { return }
        let space = geometry.staffSpace
        let center = geometry.restCenter
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(NSColor.black.cgColor)
        context.setFillColor(NSColor.black.cgColor)
        context.setLineWidth(space * 0.10)
        for line in geometry.staffLines {
            context.move(to: line[0]); context.addLine(to: line[1])
        }
        context.strokePath()
        let halfWidth = min(space * 6, geometry.restSpan * 0.27)
        context.fill(CGRect(x: center.x - halfWidth, y: center.y - space * 0.24,
                            width: halfWidth * 2, height: space * 0.48))
        for x in [center.x - halfWidth, center.x + halfWidth] {
            context.fill(CGRect(x: x - space * 0.12, y: center.y - space,
                                width: space * 0.24, height: space * 2))
        }
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        ("\(replacement.barCount)" as NSString).draw(in: CGRect(x: center.x - geometry.restSpan / 2,
            y: center.y + 2.35 * space, width: geometry.restSpan, height: space * 3.2), withAttributes: [
                .font: NSFont(name: "Times-Bold", size: space * 2.5) ?? NSFont.boldSystemFont(ofSize: space * 2.5),
                .foregroundColor: NSColor.black, .paragraphStyle: paragraph
            ])
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawMultiBarRest(for placement: BandPlacement, in context: CGContext) {
        guard let barCount = placement.restBarCount else { return }
        let rect = placement.destinationRect
        let scale = rect.height / PartLayoutEngine.restStripHeight
        let staffBottom = rect.minY + 7 * scale
        let space = 5 * scale
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(NSColor.black.cgColor)
        context.setFillColor(NSColor.black.cgColor)
        context.setLineWidth(0.55 * scale)
        let inset = min(8 * scale, rect.width * 0.05)
        for line in 0..<5 {
            let y = staffBottom + CGFloat(line) * space
            context.move(to: CGPoint(x: rect.minX + inset, y: y))
            context.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
        }
        context.strokePath()
        if barCount == 1 {
            // A single complete silent measure uses the ordinary hanging rest,
            // not an H-bar with a misleading multi-measure count of one.
            context.fill(CGRect(x: rect.midX - 4 * scale, y: staffBottom + 3 * space - 3 * scale,
                                width: 8 * scale, height: 3 * scale))
            for x in [rect.minX + inset, rect.maxX - inset] {
                context.move(to: CGPoint(x: x, y: staffBottom))
                context.addLine(to: CGPoint(x: x, y: staffBottom + 4 * space))
            }
            context.strokePath()
            return
        }
        let centerY = staffBottom + 2 * space
        let halfWidth = min(34 * scale, rect.width * 0.23)
        let stemHeight = 10 * scale
        let thickness = 2.8 * scale
        context.fill(CGRect(x: rect.midX - halfWidth, y: centerY - thickness / 2,
                            width: halfWidth * 2, height: thickness))
        for x in [rect.midX - halfWidth, rect.midX + halfWidth] {
            context.fill(CGRect(x: x - 0.65 * scale, y: centerY - stemHeight / 2,
                                width: 1.3 * scale, height: stemHeight))
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Times-Bold", size: 15 * scale) ?? NSFont.systemFont(ofSize: 15 * scale, weight: .semibold),
            .foregroundColor: NSColor.black, .paragraphStyle: paragraph
        ]
        ("\(barCount)" as NSString).draw(in: CGRect(x: rect.minX, y: staffBottom + 4 * space + 2 * scale,
            width: rect.width, height: 18 * scale), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
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

        if let rect = placement.barNumberRect {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            ("\(barNumber)" as NSString).draw(in: rect, withAttributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.black
            ])
            NSGraphicsContext.restoreGraphicsState()
            return
        }

        if let geometry = placement.restSourcePlacement {
            let scale = placement.destinationRect.width / placement.sourceRect.width
            let sourceTop = placement.destinationRect.minY + placement.sourceRect.height * scale
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            ("\(barNumber)" as NSString).draw(at: CGPoint(x: placement.destinationRect.minX,
                y: sourceTop + geometry.staffSpace * 0.3), withAttributes: [
                    .font: NSFont.systemFont(ofSize: geometry.staffSpace * 2.2, weight: .semibold),
                    .foregroundColor: NSColor.black
                ])
            NSGraphicsContext.restoreGraphicsState()
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
