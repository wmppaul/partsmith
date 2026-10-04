// Native export regression: enlargement may remove only blank side space.
// Every rendered strip is compared with an independent PDF roundtrip of its
// COMPLETE original crop, transformed at the chosen scale without side trimming.
import AppKit
import Foundation
import PDFKit

@main enum ScaleExportTests {
    static var checks = 0
    static var failures: [String] = []
    static let output = URL(fileURLWithPath: ".build/scale-export-tests")
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { failures.append(message); print("FAIL: \(message)") }
    }
    static func approximately(_ a: Double, _ b: Double, tolerance: Double = 0.000001) -> Bool {
        abs(a - b) <= tolerance
    }
    static func sourceRect(_ band: BandModel, _ bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX + band.leftFraction * bounds.width,
            y: bounds.maxY - band.bottomFraction * bounds.height,
            width: (1 - band.leftFraction - band.rightFraction) * bounds.width,
            height: (band.bottomFraction - band.topFraction) * bounds.height)
    }
    static func pdf(size: CGSize, draw: (CGContext) throws -> Void) rethrows -> Data {
        let data = NSMutableData(); var bounds = CGRect(origin: .zero, size: size)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &bounds, nil)!
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor); context.fill(bounds)
        try draw(context)
        context.endPDFPage(); context.closePDF()
        return data as Data
    }
    static func synthetic(edgeInk: Bool = false) -> Data {
        pdf(size: CGSize(width: 600, height: 800)) { c in
            c.setStrokeColor(NSColor.black.cgColor); c.setFillColor(NSColor.black.cgColor)
            c.setLineWidth(0.6)
            for y in stride(from: 400.0, through: 432, by: 8) {
                c.move(to: CGPoint(x: 170, y: y)); c.addLine(to: CGPoint(x: 430, y: y)); c.strokePath()
            }
            for x in [170.0, 250, 330, 430] {
                c.fill(CGRect(x: x, y: 400, width: 1, height: 32))
            }
            for (x, y) in [(190.0, 408.0), (410.0, 420.0)] {
                c.fillEllipse(in: CGRect(x: x-4, y: y-3, width: 8, height: 6))
                c.fill(CGRect(x: x+3, y: y, width: 1, height: 24))
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
            ("Fl." as NSString).draw(at: CGPoint(x: 145, y: 416), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.black])
            ("Andante" as NSString).draw(at: CGPoint(x: 80, y: 600), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.black])
            NSGraphicsContext.restoreGraphicsState()
            if edgeInk {
                // Both a small dot and a thin ledger line are intentional ink,
                // not disposable scan noise. Enlargement must retain them.
                c.fillEllipse(in: CGRect(x: 7, y: 415, width: 1.6, height: 1.6))
                c.fill(CGRect(x: 588, y: 420, width: 8, height: 0.4))
            }
        }
    }
    static func project(name: String, bands: [(Int, Double, Double)]) -> ProjectData {
        var p = ProjectData.empty
        p.projectSettings.margins = PageMargins(top: 48, leading: 48, bottom: 48, trailing: 48)
        p.projectSettings.showTitleBlock = false
        p.projectSettings.showPartNameInHeader = false
        p.projectSettings.margins.bottom = 0 // Omit the footer from pixel controls.
        var part = PartModel(id: UUID(), name: name, color: ColorData(nsColor: .systemBlue), layoutSettings: .default, createdAt: .now)
        part.layoutSettings.balancePages = false
        p.parts = [part]
        p.pageCount = (bands.map { $0.0 }.max() ?? 0) + 1
        p.bands = bands.enumerated().map { i, value in
            BandModel(id: UUID(), pageIndex: value.0, partID: part.id,
                topFraction: value.1, bottomFraction: value.2, leftFraction: 0, rightFraction: 0,
                excluded: false, createdAt: Date(timeIntervalSince1970: Double(i)), barNumberMode: .hidden)
        }
        return p
    }
    static func plan(_ project: ProjectData, source: Data, trim: Bool = true) throws -> PartRenderPlan {
        let cache = SourcePageRenderCache(pdfDocument: PDFDocument(data: source)!)
        return try PartLayoutEngine.makePlan(project: project, pageBoundsProvider: { cache.pageBounds(for: $0) },
            partID: project.parts[0].id, horizontalContentBoundsProvider: trim ? { band, rect in
                cache.horizontalContentBounds(for: band, sourceRect: rect,
                    rectification: project.pageRectifications.first { $0.pageIndex == band.pageIndex })
            } : nil)
    }
    static func bitmap(_ page: PDFPage) -> NSBitmapImageRep {
        let bounds = page.bounds(for: .mediaBox), scale = 2.0
        let c = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(NSColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: bounds.width*scale, height: bounds.height*scale))
        c.scaleBy(x: scale, y: scale); c.drawPDFPage(page.pageRef!)
        return NSBitmapImageRep(cgImage: c.makeImage()!)
    }
    static func fullCropReference(_ page: PartRenderPage, plan: PartRenderPlan, project: ProjectData, source: Data) throws -> Data {
        let sourcePDF = PDFDocument(data: source)!, cache = SourcePageRenderCache(pdfDocument: sourcePDF)
        return try pdf(size: plan.pageSize) { c in
            for placement in page.placements {
                let band = project.bands.first { $0.id == placement.bandID }!
                let full = sourceRect(band, sourcePDF.page(at: band.pageIndex)!.bounds(for: .mediaBox))
                let scale = placement.destinationRect.width / placement.sourceRect.width
                let destination = CGRect(x: placement.destinationRect.minX + (full.minX-placement.sourceRect.minX)*scale,
                    y: placement.destinationRect.minY, width: full.width*scale, height: full.height*scale)
                let correction = project.pageRectifications.first { $0.pageIndex == band.pageIndex }
                // This deliberately draws all source ink inside the ORIGINAL crop,
                // including anything outside the exporter's proposed horizontal trim.
                try cache.draw(pageIndex: band.pageIndex, rectification: correction, sourceRect: full, destinationRect: destination, in: c)
                for marking in placement.sourceMarkings {
                    try cache.draw(pageIndex: band.pageIndex, rectification: correction,
                        sourceRect: marking.sourceRect, destinationRect: marking.destinationRect, in: c)
                }
            }
        }
    }
    static func verifyPixels(name: String, project: ProjectData, source: Data, plan: PartRenderPlan, data: Data, save: Bool) throws {
        let actualPDF = PDFDocument(data: data)!
        check(actualPDF.pageCount == plan.pages.count, "\(name): export page count matches the analyzed plan")
        var changed = 0, maximum = 0, dark = 0, examined = 0
        for page in plan.pages {
            let actual = bitmap(actualPDF.page(at: page.index)!)
            let referenceData = try fullCropReference(page, plan: plan, project: project, source: source)
            let expected = bitmap(PDFDocument(data: referenceData)!.page(at: 0)!)
            check(actual.pixelsWide == expected.pixelsWide && actual.pixelsHigh == expected.pixelsHigh, "\(name): reference dimensions agree")
            let a = actual.bitmapData!, b = expected.bitmapData!
            for y in 0..<actual.pixelsHigh { for x in 0..<actual.pixelsWide {
                let ia = y * actual.bytesPerRow + x * actual.samplesPerPixel
                let ib = y * expected.bytesPerRow + x * expected.samplesPerPixel
                examined += 1
                if b[ib] < 180 { dark += 1 }
                let delta = (0..<3).map { abs(Int(a[ia+$0])-Int(b[ib+$0])) }.max()!
                maximum = max(maximum, delta)
                if delta > (project.parts[0].layoutSettings.scale <= 1 ? 0 : 2) { changed += 1 }
            }}
            if save && page.index == 0 {
                try actual.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
                try expected.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + "-complete-source-reference.png"))
            }
        }
        check(dark > 100, "\(name): real source ink is included in the comparison")
        check(changed == 0, "\(name): complete original-source ink and copied markings survive (changed \(changed)/\(examined), max channel delta \(maximum))")
        if save { try data.write(to: output.appendingPathComponent(name + ".pdf")) }
    }
    static func runFixture(name: String, source: Data, base: ProjectData, exactGrowth: Bool, save: Bool = true) throws -> [Double] {
        var applied: [Double] = []
        let originalBands = base.bands
        for value in [0.8, 1.0, 1.25, 1.4] {
            var p = base; p.parts[0].layoutSettings.scale = value
            let planned = try plan(p, source: source)
            let result = try PartPDFExporter.renderResult(for: p.parts[0].id, project: p, sourcePDFData: source)
            let label = name + "-" + String(format: "%.2f", value)
            check(p.bands == originalBands, "\(label): source crop records are unchanged")
            check(approximately(planned.scaleInfo.appliedScale, result.scaleInfo.appliedScale), "\(label): preview/export scale feedback matches the real plan")
            let pageBounds = PDFDocument(data: source)!.page(at: p.bands[0].pageIndex)!.bounds(for: .mediaBox)
            let originalWidth = sourceRect(p.bands[0], pageBounds).width
            let contentWidth = planned.pageSize.width-p.projectSettings.margins.leading-p.projectSettings.margins.trailing
            let placed = planned.pages[0].placements[0]
            let factor = (placed.destinationRect.width/placed.sourceRect.width)/(contentWidth/originalWidth)
            applied.append(factor)
            check(approximately(factor, planned.scaleInfo.appliedScale), "\(label): feedback reports actual notation enlargement")
            check(planned.pages.flatMap(\.placements).map(\.bandID) == p.sortedBands(for: p.parts[0].id).map(\.id), "\(label): every source strip retains reading order")
            for placement in planned.pages.flatMap(\.placements) {
                check(placement.destinationRect.minX >= p.projectSettings.margins.leading-0.000001 &&
                    placement.destinationRect.maxX <= planned.pageSize.width-p.projectSettings.margins.trailing+0.000001,
                    "\(label): complete output crop stays inside chosen margins")
                let original = p.bands.first { $0.id == placement.bandID }!
                let bounds = PDFDocument(data: source)!.page(at: original.pageIndex)!.bounds(for: .mediaBox)
                let full = sourceRect(original, bounds)
                check(approximately(placement.sourceRect.minY, full.minY) && approximately(placement.sourceRect.height, full.height),
                    "\(label): top and bottom note-preserving crop edges do not move")
            }
            if value <= 1 {
                let old = try plan(p, source: source, trim: false)
                check(planned.pages.flatMap(\.placements).map(\.sourceRect) == old.pages.flatMap(\.placements).map(\.sourceRect) &&
                    planned.pages.flatMap(\.placements).map(\.destinationRect) == old.pages.flatMap(\.placements).map(\.destinationRect),
                    "\(label): scale <=1 retains the original untrimmed layout exactly")
            }
            if exactGrowth { check(approximately(factor, value), "\(label): requested enlargement is realized when blank space allows it") }
            try verifyPixels(name: label, project: p, source: source, plan: planned, data: result.data, save: save)
            print("\(label): applied \(String(format: "%.4f", factor)), max safe \(String(format: "%.4f", planned.scaleInfo.maximumSafeScale)), width limited \(planned.scaleInfo.isWidthLimited)")
        }
        return applied
    }
    static func checkMarginPersistence(source: Data, base: ProjectData) throws {
        struct Envelope: Codable { var project: ProjectData }
        var initial = base
        initial.projectSettings.margins.leading = 36
        initial.projectSettings.margins.trailing = 52
        initial.parts.append(PartModel(id: UUID(), name: "Untouched part", color: ColorData(nsColor: .systemRed),
            layoutSettings: .default, createdAt: .now))
        let document = PartsmithDocument(project: initial, sourcePDFData: source)
        let undo = UndoManager(); undo.groupsByEvent = false; document.undoManager = undo
        let partID = initial.parts[0].id
        func edit(_ points: Double?) {
            undo.beginUndoGrouping(); document.updatePartSideMargins(partID, points: points); undo.endUndoGrouping()
        }
        let originalPlan = try plan(initial, source: source)
        edit(12)
        check(document.project.parts[0].layoutSettings.sideMarginPoints == 12 &&
            document.project.parts[1] == initial.parts[1] && document.project.projectSettings.margins == initial.projectSettings.margins,
            "Part side-margin edits leave other parts and legacy project margins unchanged")
        check(document.project.bands == initial.bands && document.sourcePDFData == source,
            "Changing margins never edits source crops or embedded PDF data")
        let wider = try plan(document.project, source: source)
        check(wider.pages[0].placements[0].destinationRect.minX == 12 &&
            wider.pages[0].placements[0].destinationRect.maxX == wider.pageSize.width-12,
            "The selected part uses its persisted side-margin override in the native layout")
        undo.undo()
        check(document.project == initial && document.project.parts[0].layoutSettings.sideMarginPoints == nil,
            "One Undo exactly restores the prior project and inherited asymmetric margins")
        undo.redo()
        check(document.project.parts[0].layoutSettings.sideMarginPoints == 12,
            "Redo restores the complete part side-margin override")
        edit(nil)
        let resetPlan = try plan(document.project, source: source)
        check(resetPlan.pages[0].placements[0].destinationRect == originalPlan.pages[0].placements[0].destinationRect,
            "Reset restores the original asymmetric project-margin placement")
        undo.undo()
        check(document.project.parts[0].layoutSettings.sideMarginPoints == 12,
            "Resetting part side margins is itself undoable")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let package = output.appendingPathComponent("Side margin persistence.partsmithproject")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        for value: Double? in [12, 18, 0, nil] {
            edit(value)
            try encoder.encode(Envelope(project: document.project)).write(to: package.appendingPathComponent("project.json"))
            try source.write(to: package.appendingPathComponent("source.pdf"))
            let stored = try decoder.decode(Envelope.self, from: Data(contentsOf: package.appendingPathComponent("project.json"))).project
            let reopened = PartsmithDocument(project: stored, sourcePDFData: try Data(contentsOf: package.appendingPathComponent("source.pdf")))
            check(reopened.project.parts[0].layoutSettings.sideMarginPoints == value && reopened.sourcePDFData == source,
                "Saving and reopening preserves margin choice \(String(describing: value)), including zero versus inherited")
            let reopenedPlan = try plan(reopened.project, source: source)
            let savedPlan = try plan(document.project, source: source)
            check(reopenedPlan.pages[0].placements[0].destinationRect == savedPlan.pages[0].placements[0].destinationRect,
                "Reopened margin choice produces exactly the same output geometry")
        }
        var oldSettings = try JSONSerialization.jsonObject(with: JSONEncoder().encode(initial.parts[0].layoutSettings)) as! [String: Any]
        oldSettings.removeValue(forKey: "sideMarginPoints")
        let legacy = try JSONDecoder().decode(PartLayoutSettings.self, from: JSONSerialization.data(withJSONObject: oldSettings))
        check(legacy.sideMarginPoints == nil, "Projects saved before the margin control inherit their original project margins")
        undo.removeAllActions()
        let beforeInvalid = document.project
        for invalid in [-1.0, 145, .nan, .infinity] { document.updatePartSideMargins(partID, points: invalid) }
        check(document.project == beforeInvalid && !undo.canUndo,
            "Invalid margin values neither change the project nor create Undo steps")
    }
    static func checkLargeGapPersistence(source: Data, base: ProjectData) throws {
        var initial = base
        initial.projectSettings.interSystemGap = 192
        let document = PartsmithDocument(project: initial, sourcePDFData: source)
        let undo = UndoManager(); undo.groupsByEvent = false; document.undoManager = undo
        let partID = initial.parts[0].id
        undo.beginUndoGrouping(); document.updatePartGap(partID, gap: 200); undo.endUndoGrouping()
        check(document.project.parts[0].layoutSettings.interSystemGap == 200,
            "The document accepts a 200-point system gap without the old 48-point clamp")
        check(document.project.bands == initial.bands && document.sourcePDFData == source,
            "A large gap never changes source crops or embedded score data")
        undo.undo()
        check(document.project == initial, "One Undo restores the previous system gap and project")
        undo.redo()
        check(document.project.parts[0].layoutSettings.interSystemGap == 200, "Redo restores the 200-point system gap")
        let encoded = try JSONEncoder().encode(document.project)
        let restored = try JSONDecoder().decode(ProjectData.self, from: encoded)
        let reopened = PartsmithDocument(project: restored, sourcePDFData: source)
        check(reopened.project.parts[0].layoutSettings.interSystemGap == 200,
            "Saving and reopening preserves a 200-point system gap")
        undo.beginUndoGrouping(); document.createPart(name: "Inherited gap", color: .systemGreen); undo.endUndoGrouping()
        check(document.project.parts.last?.layoutSettings.interSystemGap == 192,
            "New parts inherit a 192-point project gap without reducing it to 48")
        undo.undo()
        check(document.project.parts.count == initial.parts.count && document.project.parts[0].layoutSettings.interSystemGap == 200,
            "Undoing a new part preserves the preceding gap edit")
    }
    static func checkAnalysisOrientation(source: Data, project: ProjectData) {
        let pdf = PDFDocument(data: source)!, shared = SourceHorizontalContentCache()
        let cache = SourcePageRenderCache(pdfDocument: pdf, horizontalContentCache: shared)
        let bounds = pdf.page(at: 0)!.bounds(for: .mediaBox), band = project.bands[0]
        let music = cache.horizontalContentBounds(for: band, sourceRect: sourceRect(band, bounds), rectification: nil)!
        var direction = band; direction.topFraction = 0.23; direction.bottomFraction = 0.26
        let upper = cache.horizontalContentBounds(for: direction, sourceRect: sourceRect(direction, bounds), rectification: nil)!
        check(music.minX > 140 && music.minX < 146 && music.maxX > 430,
            "Bottom-up PDF music coordinates query the correct top-down analysis rows")
        check(upper.minX > 73 && upper.minX < 82 && upper.maxX < 150,
            "The asymmetric upper direction uses its own horizontal bounds, not the music's rows")
        check(shared.analysisCount == 1, "Different vertical crops share one source raster analysis")
        var masked = band
        masked.exclusions = [BandExclusion(topFraction: band.topFraction, bottomFraction: band.bottomFraction,
            leftFraction: 0, rightFraction: 0)]
        check(cache.horizontalContentBounds(for: masked, sourceRect: sourceRect(masked, bounds), rectification: nil) == music,
            "Whiteout masks never cause intended source ink to be classified as blank side space")
        var empty = band; empty.topFraction = 0.1; empty.bottomFraction = 0.2
        check(cache.horizontalContentBounds(for: empty, sourceRect: sourceRect(empty, bounds), rectification: nil) == nil,
            "A completely blank crop does not invent a content extent")
        let cancelledCache = SourceHorizontalContentCache()
        let cancellable = SourcePageRenderCache(pdfDocument: pdf, horizontalContentCache: cancelledCache)
        var calls = 0
        let interrupted = cancellable.horizontalContentBounds(for: band, sourceRect: sourceRect(band, bounds), rectification: nil,
            isCancelled: { calls += 1; return calls > 8 })
        check(interrupted == nil && cancelledCache.analysisCount == 0,
            "Cancellation during row scanning does not cache partial ink geometry")
        check(cancellable.horizontalContentBounds(for: band, sourceRect: sourceRect(band, bounds), rectification: nil) == music &&
            cancelledCache.analysisCount == 1, "After cancellation, a complete analysis rebuilds correct bounds")
        pdf.page(at: 0)!.rotation = 90
        check(cache.horizontalContentBounds(for: band, sourceRect: sourceRect(band, bounds), rectification: nil) == nil,
            "Rotated PDF pages retain original crops instead of mixing coordinate spaces")
    }
    static func wait(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(90)
        while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(condition(), "Enlarged native preview finishes within its timeout")
    }
    static func main() throws {
        setbuf(stdout, nil)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let syntheticSource = synthetic()
        let standard = project(name: "Side whitespace", bands: [(0, 0.43, 0.52)])
        try checkMarginPersistence(source: syntheticSource, base: standard)
        try checkLargeGapPersistence(source: syntheticSource, base: standard)
        checkAnalysisOrientation(source: syntheticSource, project: standard)
        _ = try runFixture(name: "spacious-digital", source: syntheticSource, base: standard, exactGrowth: true)
        var withMarking = standard
        withMarking.bands[0].sourceMarkings = [BandSourceMarking(topFraction: 0.23, bottomFraction: 0.26, leftFraction: 0.12, rightFraction: 0.74)]
        _ = try runFixture(name: "copied-edge-direction", source: syntheticSource, base: withMarking, exactGrowth: true)
        let edge = try runFixture(name: "tiny-edge-ink", source: synthetic(edgeInk: true), base: standard, exactGrowth: false)
        check(edge[2] < 1.04 && edge[3] < 1.04, "Tiny intended edge ink prevents enlargement that would clip it")
        var corrected = standard
        corrected.pageRectifications = [PageRectification(pageIndex: 0,
            topLeft: FractionPoint(x: 0.02, y: 0.01), topRight: FractionPoint(x: 0.98, y: 0.03),
            bottomRight: FractionPoint(x: 0.99, y: 0.99), bottomLeft: FractionPoint(x: 0.01, y: 0.98))]
        _ = try runFixture(name: "rectified-digital", source: syntheticSource, base: corrected, exactGrowth: true)
        let beethoven = try Data(contentsOf: URL(fileURLWithPath: "Tests/extraction/sources/beethoven-op67-pages-7-8.pdf"))
        let flute = project(name: "Flauti", bands: [(0, 0.307, 0.367), (1, 0.016, 0.09), (1, 0.516, 0.55)])
        let realGrowth = try runFixture(name: "beethoven-flute", source: beethoven, base: flute, exactGrowth: false)
        check(realGrowth[2] > 1.03 && realGrowth[3] >= realGrowth[2], "Actual scanned Beethoven notation enlarges above1 without losing source ink")
        var narrow = flute
        narrow.parts[0].layoutSettings.scale = 1.4
        narrow.parts[0].layoutSettings.sideMarginPoints = 12
        let narrowPlan = try plan(narrow, source: beethoven)
        let narrowResult = try PartPDFExporter.renderResult(for: narrow.parts[0].id, project: narrow, sourcePDFData: beethoven)
        try verifyPixels(name: "beethoven-narrow-margins", project: narrow, source: beethoven, plan: narrowPlan, data: narrowResult.data, save: true)
        var normal = flute; normal.parts[0].layoutSettings.scale = 1.4
        let normalPlan = try plan(normal, source: beethoven)
        check(narrowPlan.pages[0].placements[0].destinationRect.width > normalPlan.pages[0].placements[0].destinationRect.width+40,
            "Smaller side margins visibly increase notation width at the content limit")
        var defaultMargins = normal
        defaultMargins.projectSettings.margins.leading = ProjectData.empty.projectSettings.margins.leading
        defaultMargins.projectSettings.margins.trailing = ProjectData.empty.projectSettings.margins.trailing
        let defaultMarginPlan = try plan(defaultMargins, source: beethoven)
        let defaultMarginResult = try PartPDFExporter.renderResult(for: defaultMargins.parts[0].id,
            project: defaultMargins, sourcePDFData: beethoven)
        try verifyPixels(name: "beethoven-default-18pt-margins", project: defaultMargins, source: beethoven,
            plan: defaultMarginPlan, data: defaultMarginResult.data, save: true)
        check(defaultMarginPlan.pages[0].placements[0].destinationRect.width > normalPlan.pages[0].placements[0].destinationRect.width+40,
            "New 18-point side margins visibly widen scanned notation while preserving complete source ink")
        let sharedAnalysis = SourceHorizontalContentCache()
        _ = try PartPDFExporter.renderResult(for: normal.parts[0].id, project: normal, sourcePDFData: beethoven,
            horizontalContentCache: sharedAnalysis)
        check(sharedAnalysis.analysisCount == 2, "Three Beethoven bands rasterize their two source pages exactly once")
        var revised = normal; revised.parts[0].layoutSettings.scale = 1.25
        revised.parts[0].layoutSettings.interSystemGap = 28
        _ = try PartPDFExporter.renderResult(for: revised.parts[0].id, project: revised, sourcePDFData: beethoven,
            horizontalContentCache: sharedAnalysis)
        check(sharedAnalysis.analysisCount == 2, "Scale and spacing refreshes reuse page ink analysis")
        let correctionCache = SourceHorizontalContentCache()
        var correctedEnlarged = corrected; correctedEnlarged.parts[0].layoutSettings.scale = 1.4
        _ = try PartPDFExporter.renderResult(for: correctedEnlarged.parts[0].id, project: correctedEnlarged,
            sourcePDFData: syntheticSource, horizontalContentCache: correctionCache)
        correctedEnlarged.pageRectifications[0].topLeft.x = 0.04
        _ = try PartPDFExporter.renderResult(for: correctedEnlarged.parts[0].id, project: correctedEnlarged,
            sourcePDFData: syntheticSource, horizontalContentCache: correctionCache)
        check(correctionCache.analysisCount == 2, "Changing rectification invalidates cached horizontal ink geometry")
        let disabledAnalysis = SourceHorizontalContentCache()
        _ = try PartPDFExporter.renderResult(for: standard.parts[0].id, project: standard, sourcePDFData: syntheticSource,
            horizontalContentCache: disabledAnalysis)
        check(disabledAnalysis.analysisCount == 0, "Historical scale1 does not rasterize pages for new side-space analysis")
        // Repeated scale/gap changes use real scanned pages and a large part.
        var large = flute
        large.bands = (0..<120).map { i in
            var band = flute.bands[i%3]; band.id = UUID(); band.createdAt = Date(timeIntervalSince1970: Double(i)); return band
        }
        large.parts[0].layoutSettings.scale = 1.25
        let renderer = PartPreviewRenderer()
        let start = Date()
        renderer.update(PartPreviewSnapshot(partID: large.parts[0].id, project: large, sourcePDFData: beethoven))
        check(Date().timeIntervalSince(start) < 0.25, "Enlarged large-score render is enqueued without blocking the UI")
        large.parts[0].layoutSettings.scale = 1.4; large.parts[0].layoutSettings.interSystemGap = 12
        let latest = PartPreviewSnapshot(partID: large.parts[0].id, project: large, sourcePDFData: beethoven)
        renderer.update(latest)
        var heartbeat = false; DispatchQueue.main.async { heartbeat = true }
        wait { heartbeat }
        wait { !renderer.isRendering }
        check(renderer.errorMessage == nil && renderer.renderedSnapshot == latest, "Only the latest above1 slider values become visible")
        check(renderer.pdfDocument!.pageCount > 5, "Performance case exports the complete120-strip part")
        print("120-strip enlarged preview: \(String(format: "%.3f", Date().timeIntervalSince(start))) seconds")
        let refreshStart = Date()
        large.parts[0].layoutSettings.interSystemGap = 18
        let refreshed = PartPreviewSnapshot(partID: large.parts[0].id, project: large, sourcePDFData: beethoven)
        renderer.update(refreshed); wait { !renderer.isRendering }
        check(renderer.errorMessage == nil && renderer.renderedSnapshot == refreshed,
            "A completed enlarged preview can change spacing with cached source analysis")
        print("120-strip cached spacing refresh: \(String(format: "%.3f", Date().timeIntervalSince(refreshStart))) seconds")
        // Reusing this renderer with a different PDF containing tiny side ink
        // must not apply cached bounds from the spacious first document.
        let edgeSource = synthetic(edgeInk: true)
        var edgeProject = standard; edgeProject.parts[0].layoutSettings.scale = 1.4
        let spaciousSource = PartPreviewSnapshot(partID: edgeProject.parts[0].id, project: edgeProject, sourcePDFData: syntheticSource)
        renderer.update(spaciousSource); wait { !renderer.isRendering }
        check(renderer.renderedSnapshot == spaciousSource, "The same part first renders with spacious source geometry")
        let changedSource = PartPreviewSnapshot(partID: edgeProject.parts[0].id, project: edgeProject, sourcePDFData: edgeSource)
        renderer.update(changedSource); wait { !renderer.isRendering }
        check(renderer.errorMessage == nil && renderer.renderedSnapshot == changedSource, "Source replacement invalidates previous ink analysis")
        let edgePlan = try plan(edgeProject, source: edgeSource)
        try verifyPixels(name: "changed-source-cache", project: edgeProject, source: edgeSource, plan: edgePlan, data: renderer.pdfDocument!.dataRepresentation()!, save: false)
        var cancelledChecks = 0
        do {
            _ = try PartPDFExporter.renderResult(for: large.parts[0].id, project: large, sourcePDFData: beethoven,
                isCancelled: { cancelledChecks += 1; return cancelledChecks > 3 })
            check(false, "Superseded content analysis cancels before publishing a PDF")
        } catch is CancellationError { check(true, "Superseded content analysis cancels before publishing a PDF") }
        print("\(failures.isEmpty ? "PASS" : "FAIL"): \(checks) scale/export checks; \(failures.count) failures")
        if !failures.isEmpty { exit(1) }
    }
}
