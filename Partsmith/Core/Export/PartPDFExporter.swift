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
        let plan = try PartLayoutEngine.makePlan(project: document.project, pdfDocument: document.pdfDocument, partID: partID)
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
            context.beginPDFPage(nil)
            render(page: page, plan: plan, sourceDocument: document.pdfDocument, in: context)
            context.endPDFPage()
        }

        context.closePDF()
        return mutableData as Data
    }

    private static func render(page: PartRenderPage, plan: PartRenderPlan, sourceDocument: PDFDocument?, in context: CGContext) {
        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: plan.pageSize))

        if plan.part.layoutSettings.showPartNameLabel {
            drawPartNameLabel(for: plan, in: context)
        }

        if page.drawsTitle {
            if let headerPlacement = plan.headerPlacement {
                draw(headerPlacement: headerPlacement, sourceDocument: sourceDocument, in: context)
            } else {
                drawTitle(for: plan, in: context)
            }
        }

        for placement in page.placements {
            draw(placement: placement, sourceDocument: sourceDocument, in: context)
        }

        context.restoreGState()
    }

    private static func drawTitle(for plan: PartRenderPlan, in context: CGContext) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.black
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        let titleSize = plan.resolvedTitle.size(withAttributes: titleAttributes)
        let titleOrigin = CGPoint(
            x: (plan.pageSize.width - titleSize.width) / 2,
            y: plan.pageSize.height - 42 - titleSize.height
        )
        plan.resolvedTitle.draw(at: titleOrigin, withAttributes: titleAttributes)

        if plan.resolvedSubtitle.isEmpty == false {
            let subtitleSize = plan.resolvedSubtitle.size(withAttributes: subtitleAttributes)
            let subtitleOrigin = CGPoint(
                x: (plan.pageSize.width - subtitleSize.width) / 2,
                y: titleOrigin.y - subtitleSize.height - 6
            )
            plan.resolvedSubtitle.draw(at: subtitleOrigin, withAttributes: subtitleAttributes)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawPartNameLabel(for plan: PartRenderPlan, in context: CGContext) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        let labelSize = plan.part.name.size(withAttributes: labelAttributes)
        let labelOrigin = CGPoint(
            x: 48,
            y: plan.pageSize.height - 30 - labelSize.height
        )
        plan.part.name.draw(at: labelOrigin, withAttributes: labelAttributes)

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func draw(placement: BandPlacement, sourceDocument: PDFDocument?, in context: CGContext) {
        guard let pdfPage = sourceDocument?.page(at: placement.sourcePageIndex) else { return }

        context.saveGState()
        context.clip(to: placement.destinationRect)

        let xScale = placement.destinationRect.width / placement.sourceRect.width
        let yScale = placement.destinationRect.height / placement.sourceRect.height

        context.translateBy(
            x: placement.destinationRect.minX - placement.sourceRect.minX * xScale,
            y: placement.destinationRect.minY - placement.sourceRect.minY * yScale
        )
        context.scaleBy(x: xScale, y: yScale)
        pdfPage.draw(with: .mediaBox, to: context)

        context.restoreGState()
    }

    private static func draw(headerPlacement: HeaderPlacement, sourceDocument: PDFDocument?, in context: CGContext) {
        guard let pdfPage = sourceDocument?.page(at: headerPlacement.sourcePageIndex) else { return }

        context.saveGState()
        context.clip(to: headerPlacement.destinationRect)

        let xScale = headerPlacement.destinationRect.width / headerPlacement.sourceRect.width
        let yScale = headerPlacement.destinationRect.height / headerPlacement.sourceRect.height

        context.translateBy(
            x: headerPlacement.destinationRect.minX - headerPlacement.sourceRect.minX * xScale,
            y: headerPlacement.destinationRect.minY - headerPlacement.sourceRect.minY * yScale
        )
        context.scaleBy(x: xScale, y: yScale)
        pdfPage.draw(with: .mediaBox, to: context)

        context.restoreGState()
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
