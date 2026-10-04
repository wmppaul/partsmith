import AppKit
import PDFKit

@main enum PreviewCropUITests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1; precondition(value(), message)
    }
    static func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let source = try Data(contentsOf: URL(fileURLWithPath: "sample_scores/lightly_skewed/10_brahms_string_quartet_no3_op67_imslp_242312.pdf"))
        let sourcePDF = PDFDocument(data: source)!
        var project = ProjectData.empty
        project.pageCount = sourcePDF.pageCount
        project.projectSettings.showTitleBlock = false
        let part = PartModel(id: UUID(), name: "Violin I", color: ColorData(nsColor: .systemBlue), layoutSettings: .default, createdAt: .now)
        project.parts = [part]
        for i in 0..<3 {
            project.bands.append(BandModel(id: UUID(), pageIndex: 0, partID: part.id,
                topFraction: 0.17 + Double(i) * 0.19, bottomFraction: 0.30 + Double(i) * 0.19,
                leftFraction: 0, rightFraction: 0, excluded: false, createdAt: .now, barNumberMode: .hidden))
        }
        let result = try PartPDFExporter.renderResult(for: part.id, project: project, sourcePDFData: source)
        let output = PDFDocument(data: result.data)!
        let container = PDFPreviewContainerView(frame: CGRect(x: 0, y: 0, width: 980, height: 850))
        let window = NSWindow(contentRect: container.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = container
        window.layoutIfNeeded()
        let pdfView = container.subviews.compactMap { $0 as? PDFView }.first!
        let overlay = container.subviews.last!
        var selected: UUID?, commits: [(BandModel, PartPreviewCropGeometry.CropEdges)] = []
        func update(_ enabled: Bool = true, pdf: PDFDocument? = nil, plan: PartRenderPlan? = nil) {
            container.update(pdfDocument: pdf ?? output, plan: plan ?? result.renderPlan, project: project,
                selectedBandID: selected, canEdit: enabled,
                sourceBounds: { sourcePDF.page(at: $0)?.bounds(for: .mediaBox) },
                onSelect: { selected = $0 }, onCrop: { commits.append(($0, $1)) })
            container.layoutSubtreeIfNeeded(); pump()
        }
        update()
        let placement = result.renderPlan.pages[0].placements[0]
        let page = output.page(at: 0)!
        func windowPoint(_ pdfPoint: CGPoint) -> CGPoint { pdfView.convert(pdfView.convert(pdfPoint, from: page), to: nil) }
        func event(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        }
        let center = windowPoint(CGPoint(x: placement.destinationRect.midX, y: placement.destinationRect.midY))
        overlay.mouseDown(with: event(.leftMouseDown, center)); overlay.mouseUp(with: event(.leftMouseUp, center))
        check(selected == placement.bandID && commits.isEmpty, "Click selects the source band without resizing or rendering")
        update()
        let top = windowPoint(CGPoint(x: placement.destinationRect.midX, y: placement.destinationRect.maxY))
        check(overlay.hitTest(container.convert(top, from: nil)) === overlay, "A visible handle receives mouse hits")
        overlay.mouseDown(with: event(.leftMouseDown, top))
        for delta in 1...20 {
            overlay.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: top.x, y: top.y - CGFloat(delta))))
            check(commits.isEmpty, "Dragging changes no document data before mouse-up")
        }
        overlay.displayIfNeeded()
        if let bitmap = container.bitmapImageRepForCachingDisplay(in: container.bounds) {
            container.cacheDisplay(in: container.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: ".build/preview-crop-drag.png"))
        }
        overlay.mouseUp(with: event(.leftMouseUp, CGPoint(x: top.x, y: top.y - 20)))
        check(commits.count == 1 && commits[0].0.id == placement.bandID, "Mouse-up makes exactly one source-band edit")
        let expected = PartPreviewCropGeometry.cropEdges(for: project.bands[0], placement: placement,
            sourcePageBounds: sourcePDF.page(at: 0)!.bounds(for: .mediaBox), edge: .top,
            outputDeltaY: -20 / pdfView.scaleFactor)!
        check(abs(commits[0].1.topFraction - expected.topFraction) < 0.000001,
            "Real PDFView mouse conversion matches source geometry and zoom")
        check(commits[0].1.bottomFraction == project.bands[0].bottomFraction, "Top drag keeps bottom unchanged")
        overlay.mouseDown(with: event(.leftMouseDown, top))
        overlay.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: top.x, y: top.y - 30)))
        overlay.cancelOperation(nil)
        overlay.mouseUp(with: event(.leftMouseUp, CGPoint(x: top.x, y: top.y - 30)))
        check(commits.count == 1, "Escape/cancel discards the draft")
        overlay.mouseDown(with: event(.leftMouseDown, top))
        overlay.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: top.x, y: top.y - 30)))
        update(false)
        overlay.mouseUp(with: event(.leftMouseUp, CGPoint(x: top.x, y: top.y - 30)))
        check(commits.count == 1 && overlay.hitTest(container.convert(top, from: nil)) == nil,
            "A stale rendering disables hit targets and cancels a drag")
        update()
        let bottom = windowPoint(CGPoint(x: placement.destinationRect.midX, y: placement.destinationRect.minY))
        overlay.mouseDown(with: event(.leftMouseDown, bottom))
        overlay.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: bottom.x, y: bottom.y + 15)))
        overlay.mouseUp(with: event(.leftMouseUp, CGPoint(x: bottom.x, y: bottom.y + 15)))
        check(commits.count == 2 && commits[1].1.bottomFraction < project.bands[0].bottomFraction,
            "Bottom handle trims upward in actual PDFView coordinates")
        check(commits[1].1.topFraction == project.bands[0].topFraction, "Bottom handle preserves top")

        // PDFKit can scroll/zoom without sending that event through our overlay.
        overlay.mouseDown(with: event(.leftMouseDown, top))
        pdfView.autoScales = false
        pdfView.scaleFactor *= 1.7
        pump()
        overlay.mouseUp(with: event(.leftMouseUp, top))
        check(commits.count == 2, "A PDFKit zoom cancels an in-flight drag from the old transform")
        let zoomTop = windowPoint(CGPoint(x: placement.destinationRect.midX, y: placement.destinationRect.maxY))
        overlay.mouseDown(with: event(.leftMouseDown, zoomTop))
        let clip = pdfView.documentView!.enclosingScrollView!.contentView
        clip.scroll(to: CGPoint(x: clip.bounds.minX, y: clip.bounds.minY + 25))
        pump()
        overlay.mouseUp(with: event(.leftMouseUp, zoomTop))
        check(commits.count == 2, "A direct scroll cancels the old coordinate frame's drag")
        let scrollBefore = clip.bounds.origin
        let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: -80, wheel2: 0, wheel3: 0)!
        overlay.scrollWheel(with: NSEvent(cgEvent: scroll)!)
        pump()
        check(clip.bounds.origin != scrollBefore, "Scrolling over a crop reaches the actual PDF scroll view")

        selected = result.renderPlan.pages[0].placements[1].bandID
        update()
        let middle = result.renderPlan.pages[0].placements[1]
        pdfView.go(to: PDFDestination(page: page, at: CGPoint(x: 0, y: middle.destinationRect.maxY + 60)))
        pump()
        let middleBefore = windowPoint(CGPoint(x: middle.destinationRect.midX, y: middle.destinationRect.maxY))
        project.bands[0].bottomFraction -= 0.05
        let resized = try PartPDFExporter.renderResult(for: part.id, project: project, sourcePDFData: source)
        let resizedPDF = PDFDocument(data: resized.data)!
        update(pdf: resizedPDF, plan: resized.renderPlan)
        let newMiddlePage = resized.renderPlan.pages.first { $0.placements.contains { $0.bandID == selected } }!
        let newMiddle = newMiddlePage.placements.first { $0.bandID == selected }!
        let middleAfter = pdfView.convert(pdfView.convert(CGPoint(x: newMiddle.destinationRect.midX,
            y: newMiddle.destinationRect.maxY), from: resizedPDF.page(at: newMiddlePage.index)!), to: nil)
        check(abs(middleAfter.y - middleBefore.y) < 3, "A reflow keeps the selected system at its viewport position")
        check(abs(pdfView.scaleFactor - (top.y - bottom.y) / placement.destinationRect.height * 1.7) < 0.001,
            "Refreshing a crop preserves the user's manual PDF zoom")
        window.close()
        print("PASS: \(checks) native Preview interaction checks (offscreen window; no active app modified)")
    }
}
