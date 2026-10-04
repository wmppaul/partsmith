import AppKit
import Foundation
import PDFKit

/// Shared layout ownership, migration, undo, PDF, and asynchronous preview checks.
/// Optional legacy baselines were rendered by the untouched pre-change engine.
@main enum SharedLayoutTests {
    struct Envelope: Codable { var project: ProjectData }
    static var checks: [[String: Any]] = []
    static var failures = 0
    static let output = URL(fileURLWithPath: ".build/shared-layout-tests")
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        let passed = condition()
        checks.append(["check": message, "passed": passed])
        if !passed { failures += 1; print("FAIL: \(message)") }
    }
    static func close(_ a: Double, _ b: Double) -> Bool { abs(a-b) < 0.000001 }
    static func settings(_ document: PartsmithDocument, _ id: UUID) -> PartLayoutSettings {
        document.part(withID: id)!.layoutSettings.resolved(in: document.project.projectSettings)
    }
    static func margins(_ document: PartsmithDocument, _ id: UUID) -> PageMargins {
        document.part(withID: id)!.layoutSettings.outputMargins(in: document.project.projectSettings)
    }
    static func grouped(_ undo: UndoManager, _ body: () -> Void) {
        undo.beginUndoGrouping(); body(); undo.endUndoGrouping()
    }
    static func wait(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(60)
        while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(condition(), "Background preview completes within the timeout")
    }
    static func pixels(_ page: PDFPage) -> Data {
        let bounds = page.bounds(for: .mediaBox)
        let c = CGContext(data: nil, width: Int(bounds.width), height: Int(bounds.height), bitsPerComponent: 8,
            bytesPerRow: Int(bounds.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(gray: 1, alpha: 1); c.fill(bounds); c.drawPDFPage(page.pageRef!)
        return Data(bytes: c.data!, count: Int(bounds.width * bounds.height) * 4)
    }
    static func sourcePDF() -> Data {
        let data = NSMutableData(); var bounds = CGRect(x: 0, y: 0, width: 600, height: 800)
        let c = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &bounds, nil)!
        c.beginPDFPage(nil); c.setFillColor(gray: 1, alpha: 1); c.fill(bounds)
        c.setStrokeColor(gray: 0, alpha: 1); c.setFillColor(gray: 0, alpha: 1); c.setLineWidth(0.7)
        for base in [650.0, 490, 330, 170] {
            for row in 0..<5 {
                let y = base + Double(row) * 8
                c.move(to: CGPoint(x: 30, y: y)); c.addLine(to: CGPoint(x: 570, y: y)); c.strokePath()
            }
            for x in [30.0, 200, 380, 570] { c.fill(CGRect(x: x, y: base, width: 1, height: 32)) }
            c.fillEllipse(in: CGRect(x: 72, y: base + 6, width: 8, height: 5))
            c.fill(CGRect(x: 79, y: base + 9, width: 1, height: 28))
        }
        c.endPDFPage(); c.closePDF(); return data as Data
    }
    static func populatedDocument(source: Data) -> PartsmithDocument {
        var p = ProjectData.empty
        p.pageCount = 1; p.projectSettings.showTitleBlock = false
        let d = PartsmithDocument(project: p, sourcePDFData: source)
        for name in ["Violin I", "Violin II", "Viola"] { d.createPart(name: name, color: .systemBlue) }
        d.project.bands = d.project.parts.flatMap { part in
            (0..<4).map { i in
                BandModel(id: UUID(), pageIndex: 0, partID: part.id,
                    topFraction: 0.125 + Double(i) * 0.2, bottomFraction: 0.205 + Double(i) * 0.2,
                    leftFraction: 0, rightFraction: 0, excluded: false,
                    createdAt: Date(timeIntervalSince1970: Double(i)), barNumberMode: .hidden)
            }
        }
        return d
    }
    static func testOwnership(source: Data) throws -> PartsmithDocument {
        let d = populatedDocument(source: source), ids = d.project.parts.map(\.id)
        check(d.project.parts.allSatisfy { $0.layoutSettings.usesSharedLayout == true }, "All newly created app parts use the shared score layout")
        d.updatePartScale(ids[0], scale: 1.1)
        d.updatePartGap(ids[1], gap: 44)
        d.updatePartSideMargins(ids[2], points: 24)
        check(ids.allSatisfy { close(settings(d, $0).scale, 1.1) && settings(d, $0).interSystemGap == 44 }, "Editing any linked part synchronizes scale and gap across every linked part")
        check(ids.allSatisfy { margins(d, $0).leading == 24 && margins(d, $0).trailing == 24 }, "Editing shared margins updates both edges of every linked part")
        check(close(d.project.projectSettings.defaultScale, 1.1) && d.project.projectSettings.interSystemGap == 44, "Shared edits update project defaults for future parts")
        d.createPart(name: "Cello", color: .systemOrange)
        let future = d.project.parts.last!.id
        check(settings(d, future).scale == 1.1 && settings(d, future).interSystemGap == 44 && margins(d, future).leading == 24, "A part created after shared edits inherits the current values")

        let beforeLocal = settings(d, ids[1]), beforeMargins = margins(d, ids[1])
        d.setPartLayoutOverride(ids[1], enabled: true)
        check(d.part(withID: ids[1])!.layoutSettings.usesSharedLayout == false, "Customizing one part explicitly opts it out of synchronization")
        check(settings(d, ids[1]).scale == beforeLocal.scale && settings(d, ids[1]).interSystemGap == beforeLocal.interSystemGap && margins(d, ids[1]) == beforeMargins, "Entering custom layout preserves its exact appearance")
        d.updatePartScale(ids[0], scale: 1.2); d.updatePartGap(ids[0], gap: 70); d.updatePartSideMargins(ids[0], points: 9)
        check(settings(d, ids[1]).scale == 1.1 && settings(d, ids[1]).interSystemGap == 44 && margins(d, ids[1]).leading == 24, "A custom part retains all three values while shared settings change")
        d.updatePartScale(ids[1], scale: 0.8); d.updatePartGap(ids[1], gap: 100); d.updatePartSideMargins(ids[1], points: 45)
        check(settings(d, ids[0]).scale == 1.2 && settings(d, ids[0]).interSystemGap == 70 && margins(d, ids[0]).leading == 9, "Local edits never change sibling parts or project defaults")
        d.setPartLayoutOverride(ids[1], enabled: false)
        check(settings(d, ids[1]).scale == 1.2 && settings(d, ids[1]).interSystemGap == 70 && margins(d, ids[1]).leading == 9, "Returning to the shared layout adopts its latest values")

        let untouched = d.project
        d.selectedPartID = ids[0]; d.selectedPartID = ids[2]
        check(d.project == untouched, "Switching selected parts does not change shared settings")
        d.setPartLayoutOverride(ids[2], enabled: true)
        d.updatePartScale(ids[2], scale: 0.9); d.updatePartGap(ids[2], gap: 32); d.updatePartSideMargins(ids[2], points: 33)
        d.updatePartBalancedPages(ids[2], enabled: false)
        d.applyPartLayoutToAllParts(ids[2])
        check(d.project.parts.allSatisfy { $0.layoutSettings.usesSharedLayout == true }, "Use these settings for all parts re-links existing overrides")
        check(d.project.parts.allSatisfy { settings(d, $0.id).scale == 0.9 && settings(d, $0.id).interSystemGap == 32 && margins(d, $0.id).leading == 33 }, "Use these settings for all parts transfers scale, gap, and margins together")
        check(d.part(withID: ids[2])!.layoutSettings.balancePages == false && d.part(withID: ids[0])!.layoutSettings.balancePages, "Sharing scale, gap, and margins preserves unrelated per-part settings")
        check(d.sourcePDFData == source && d.project.bands == untouched.bands, "Layout synchronization does not alter source PDF bytes or source crops")
        return d
    }
    static func testUndoAndPersistence(_ d: PartsmithDocument) throws {
        let undo = UndoManager(); undo.groupsByEvent = false; d.undoManager = undo
        let id = d.project.parts[0].id, before = d.project
        grouped(undo) { d.updatePartGap(id, gap: 148) }
        let after = d.project
        check(d.project.parts.allSatisfy { settings(d, $0.id).interSystemGap == 148 }, "One shared action changes every linked part")
        undo.undo(); check(d.project == before, "One Undo restores the complete shared edit")
        undo.redo(); check(d.project == after, "One Redo restores the complete shared edit")
        grouped(undo) { d.setPartLayoutOverride(id, enabled: true) }
        grouped(undo) { d.updatePartGap(id, gap: 18) }
        let custom = d.project
        grouped(undo) { d.applyPartLayoutToAllParts(id) }
        let shared = d.project
        undo.undo(); check(d.project == custom, "Undo all-parts promotion restores the prior override and every sibling")
        undo.redo(); check(d.project == shared, "Redo all-parts promotion restores values and shared ownership together")
        grouped(undo) { d.setPartLayoutOverride(id, enabled: true) }
        grouped(undo) { d.updatePartScale(id, scale: 1.05) }
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let encoded = try encoder.encode(Envelope(project: d.project))
        let reopened = try decoder.decode(Envelope.self, from: encoded).project
        check(reopened == d.project, "Saving and reopening preserves shared ownership, override values, and project defaults")
        try encoded.write(to: output.appendingPathComponent("shared-and-custom-project.json"))
        d.undoManager = nil

        let asymmetric = populatedDocument(source: d.sourcePDFData!)
        asymmetric.project.projectSettings.margins.leading = 12; asymmetric.project.projectSettings.margins.trailing = 42
        let a = asymmetric.project.parts[0].id, b = asymmetric.project.parts[1].id
        asymmetric.setPartLayoutOverride(a, enabled: true)
        asymmetric.updatePartSideMargins(b, points: 18)
        check(margins(asymmetric, a).leading == 12 && margins(asymmetric, a).trailing == 42, "A custom override freezes asymmetric source-project margins without averaging them")
        let asymRoundtrip = try decoder.decode(Envelope.self, from: encoder.encode(Envelope(project: asymmetric.project))).project
        check(asymRoundtrip.parts[0].layoutSettings.outputMargins(in: asymRoundtrip.projectSettings).leading == 12 && asymRoundtrip.parts[0].layoutSettings.outputMargins(in: asymRoundtrip.projectSettings).trailing == 42, "Asymmetric local margins survive save and reopen")
        asymmetric.applyPartLayoutToAllParts(a)
        check(asymmetric.project.parts.allSatisfy { margins(asymmetric, $0.id).leading == 12 && margins(asymmetric, $0.id).trailing == 42 }, "Sharing a custom layout preserves an asymmetric pair for all parts")
    }
    static func testRendering(_ d: PartsmithDocument, source: Data) throws {
        for part in d.project.parts.prefix(3) {
            let rendered = try PartPDFExporter.renderResult(for: part.id, project: d.project, sourcePDFData: source)
            let effective = settings(d, part.id)
            check(rendered.renderPlan.part.layoutSettings.scale == effective.scale && rendered.renderPlan.part.layoutSettings.interSystemGap == effective.interSystemGap, "Export uses resolved settings for \(part.name)")
            check(rendered.renderPlan.pages.flatMap(\.placements).count == 4, "Shared and custom export retain all four source systems for \(part.name)")
            let requested = effective.interSystemGap
            let page = rendered.renderPlan.pages.first { $0.placements.count > 1 }!
            let first = page.placements[0], second = page.placements[1]
            check(close(first.destinationRect.minY - second.destinationRect.maxY, requested), "\(part.name) uses its exact resolved gap in the exported PDF")
            try rendered.data.write(to: output.appendingPathComponent("\(part.name).pdf"))
        }
        let linked = d.project.parts[1].id
        let first = PartPreviewSnapshot(partID: linked, project: d.project, sourcePDFData: source)
        d.updatePartGap(linked, gap: 26)
        let intermediate = PartPreviewSnapshot(partID: linked, project: d.project, sourcePDFData: source)
        check(first != intermediate, "A shared layout edit invalidates the linked part's preview snapshot")
        d.updatePartScale(linked, scale: 0.75); d.updatePartGap(linked, gap: 56)
        let final = PartPreviewSnapshot(partID: linked, project: d.project, sourcePDFData: source)
        let renderer = PartPreviewRenderer()
        renderer.update(first); renderer.update(intermediate); renderer.update(final)
        wait { !renderer.isRendering }
        check(renderer.errorMessage == nil && renderer.renderedSnapshot == final, "Superseded shared-layout renders cannot overwrite the latest preview")
        check(renderer.renderPlan?.scaleInfo.requestedScale == 0.75 && renderer.renderPlan?.part.layoutSettings.interSystemGap == 56, "The visible preview resolves the final shared scale and gap")
        let export = try PartPDFExporter.previewDocument(for: linked, in: d), preview = renderer.pdfDocument!
        check(preview.pageCount == export.pageCount, "Background preview and ordinary export paginate shared layout identically")
        check((0..<preview.pageCount).allSatisfy { pixels(preview.page(at: $0)!) == pixels(export.page(at: $0)!) }, "Every shared-layout preview page matches exported PDF pixels")
        renderer.cancel(clearPreview: true)
    }
    static func testLegacyBaselines(_ baseline: URL) throws {
        let source = try Data(contentsOf: baseline.appendingPathComponent("source.pdf"))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        for variant in ["original", "uniform-custom", "mixed-custom", "asymmetric"] {
            let folder = baseline.appendingPathComponent(variant)
            let p = try decoder.decode(Envelope.self, from: Data(contentsOf: folder.appendingPathComponent("project.json"))).project
            if variant == "mixed-custom" {
                check(p.parts.allSatisfy { $0.layoutSettings.usesSharedLayout == false }, "Differing legacy layouts become explicit local overrides")
            } else {
                check(p.parts.allSatisfy { $0.layoutSettings.usesSharedLayout == true }, "\(variant): equal legacy layouts become synchronized")
            }
            if variant == "uniform-custom" {
                check(p.projectSettings.defaultScale == 1.2 && p.projectSettings.interSystemGap == 60 && p.projectSettings.margins.leading == 24, "Common non-default legacy values become project settings without changing appearance")
            }
            for (i, part) in p.parts.enumerated() {
                let rendered = try PartPDFExporter.renderResult(for: part.id, project: p, sourcePDFData: source)
                let after = PDFDocument(data: rendered.data)!, before = PDFDocument(url: folder.appendingPathComponent("part-\(i).pdf"))!
                check(after.pageCount == before.pageCount, "\(variant) part \(i): migration preserves legacy pagination")
                let matches = after.pageCount == before.pageCount && (0..<after.pageCount).allSatisfy { page in
                    pixels(after.page(at: page)!) == (try? Data(contentsOf: folder.appendingPathComponent("part-\(i)-page-\(page).rgba")))
                }
                check(matches, "\(variant) part \(i): every migrated page matches pre-change export pixels")
            }
        }
    }
    static func testLegacyMigrationEdges() throws {
        var legacy = ProjectData.empty
        legacy.parts = ["Linked", "Custom"].map { name in
            PartModel(id: UUID(), name: name, color: ColorData(nsColor: .systemBlue), layoutSettings: .default, createdAt: .now)
        }
        legacy.projectSettings.margins.leading = 12; legacy.projectSettings.margins.trailing = 42
        legacy.parts[1].layoutSettings.scale = 0.85
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let migrated = try decoder.decode(ProjectData.self, from: encoder.encode(legacy))
        check(migrated.parts[0].layoutSettings.usesSharedLayout == true && migrated.parts[1].layoutSettings.usesSharedLayout == false,
              "Mixed legacy layouts link the part matching project values and preserve the differing part")
        let d = PartsmithDocument(project: migrated)
        d.updatePartSideMargins(migrated.parts[0].id, points: 30)
        let custom = margins(d, migrated.parts[1].id)
        check(custom.leading == 12 && custom.trailing == 42,
              "A migrated legacy override freezes inherited asymmetric margins before later shared edits")
        var mixedVersion = legacy
        mixedVersion.projectSettings.defaultScale = 1.25
        mixedVersion.parts[0].layoutSettings.usesSharedLayout = true
        mixedVersion.parts[0].layoutSettings.scale = 0.7 // stale literal value must remain immaterial.
        let reopened = try decoder.decode(ProjectData.self, from: encoder.encode(mixedVersion))
        check(reopened.projectSettings.defaultScale == 1.25 && reopened.parts[0].layoutSettings.resolved(in: reopened.projectSettings).scale == 1.25,
              "Decoding a mixed-version project never replaces explicit shared settings with stale part values")
    }
    static func main() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let source = sourcePDF(); try source.write(to: output.appendingPathComponent("source.pdf"))
        let document = try testOwnership(source: source)
        try testUndoAndPersistence(document)
        try testRendering(document, source: source)
        try testLegacyMigrationEdges()
        if let baseline = CommandLine.arguments.dropFirst().first { try testLegacyBaselines(URL(fileURLWithPath: baseline)) }
        let report: [String: Any] = ["checks": checks, "count": checks.count, "failures": failures,
            "legacyBaseline": CommandLine.arguments.dropFirst().first ?? "not supplied"]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
        print("\(checks.count) shared-layout checks; \(failures) failures.")
        if failures != 0 { exit(1) }
    }
}
