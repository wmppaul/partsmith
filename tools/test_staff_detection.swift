// Run from the repository root:
// bash tools/test_staff_detection.sh --samples
import AppKit
import CoreGraphics
import Foundation
import PDFKit

@main
enum StaffDetectionTests {
    static func main() throws {
        try syntheticTests()
        try documentTests()
        if CommandLine.arguments.contains("--samples") { try sampleReport() }
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "StaffDetectionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    private static func image(
        width: Int = 1400, height: Int = 1800, draw: (CGContext) -> Void
    ) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        draw(context)
        return context.makeImage()!
    }

    private static func drawStaff(_ context: CGContext, y: CGFloat, space: CGFloat, gray: CGFloat = 0) {
        context.setStrokeColor(gray: gray, alpha: 1)
        context.setLineWidth(1.3)
        for line in 0..<5 {
            context.move(to: CGPoint(x: 120, y: y + CGFloat(line) * space))
            context.addLine(to: CGPoint(x: 1270, y: y + CGFloat(line) * space))
        }
        context.strokePath()
        context.setFillColor(gray: 0, alpha: 1)
        // Stems, noteheads, beams, and widely separated ledger notes.
        for index in 0..<12 {
            let x = CGFloat(190 + index * 80)
            let noteY = y + CGFloat(index % 7 - 1) * space
            context.fillEllipse(in: CGRect(x: x, y: noteY, width: 14, height: 9))
            context.fill(CGRect(x: x + 11, y: noteY - 30, width: 2, height: 34))
            if index % 3 == 0 { context.fill(CGRect(x: x + 11, y: noteY - 30, width: 65, height: 4)) }
        }
    }

    private static func syntheticTests() throws {
        let blank = StaffBandDetector.detect(in: image { _ in })
        try check(blank.candidates.isEmpty, "Blank page generated a staff.")

        let textAndRules = image { context in
            context.setFillColor(gray: 0, alpha: 1)
            for row in 0..<40 {
                for column in 0..<55 {
                    context.fill(CGRect(x: 100 + column * 20, y: 100 + row * 30, width: 8, height: 12))
                }
            }
            context.fill(CGRect(x: 100, y: 1450, width: 1200, height: 2))
        }
        try check(StaffBandDetector.detect(in: textAndRules).candidates.isEmpty, "Text/rules generated a staff.")

        let score = image { context in
            drawStaff(context, y: 320, space: 12)
            drawStaff(context, y: 740, space: 12, gray: 0.40)
            drawStaff(context, y: 1100, space: 12)
            // A separate cluster of five short beams must not become a staff.
            context.setFillColor(gray: 0, alpha: 1)
            for line in 0..<5 { context.fill(CGRect(x: 450, y: 1450 + line * 12, width: 150, height: 3)) }
        }
        let result = StaffBandDetector.detect(in: score)
        try check(result.candidates.count == 3, "Expected 3 synthetic staves, got \(result.candidates.count).")
        for (index, expectedY) in [320.0, 740, 1100].enumerated() {
            let staff = result.candidates[index]
            try check(abs(staff.staffLineFractions[0] * 1800 - expectedY) < 2, "Top-down staff order or geometry is wrong.")
            try check(staff.topFraction * 1800 <= expectedY - 25, "Crop clipped upper notation.")
            try check(staff.bottomFraction * 1800 >= expectedY + 48 + 25, "Crop clipped lower notation.")
            try check(staff.confidence >= 0 && staff.confidence <= 1, "Confidence is not normalized.")
        }
        try check(result.candidates == StaffBandDetector.detect(in: score).candidates, "Detection is not deterministic.")

        let adjacent = image { context in
            drawStaff(context, y: 450, space: 12)
            drawStaff(context, y: 535, space: 12)
        }
        let close = StaffBandDetector.detect(in: adjacent)
        try check(close.candidates.count == 2, "Adjacent staves were joined or omitted.")
        try check(close.candidates[0].bottomFraction <= close.candidates[1].topFraction, "Adjacent proposals overlap.")
        try check(!close.candidates[0].warnings.isEmpty, "Close notation has no review warning.")
        let tilted = image { context in
            context.concatenate(CGAffineTransform(a: 1, b: 0.006, c: 0, d: 1, tx: 0, ty: 0))
            drawStaff(context, y: 320, space: 12)
            drawStaff(context, y: 850, space: 12)
        }
        try check(StaffBandDetector.detect(in: tilted).candidates.count == 2, "Mildly tilted staves were lost.")
        let imperfect = image { context in
            context.setFillColor(gray: 0, alpha: 1)
            for offset in [0, 13, 24, 35, 48] {
                context.fill(CGRect(x: 120, y: 550 + offset, width: 1150, height: 2))
            }
        }
        try check(StaffBandDetector.detect(in: imperfect).candidates.count == 1, "Small scan spacing errors were amplified.")
        print("PASS: blank, text/rules, beams, engraved/faint/tilted staves, scan spacing, top-down geometry, crop padding, determinism, adjacent staves.")
    }

    private struct Sample: Codable {
        var file: String
        var page: Int
        var count: Int
        var expectedCount: Int
        var confidence: [Double]
        var lineTops: [Double]
        var image: String
        var mode: String
    }

    private static func documentTests() throws {
        let url = URL(fileURLWithPath: "Partsmith/Resources/Fixtures/SampleScoreFixture.pdf")
        let source = try Data(contentsOf: url)
        let document = PartsmithDocument(sourcePDFData: source)
        document.project.pageCount = 2
        document.createPart(name: "Test part", color: .systemBlue)
        let partID = document.selectedPartID!
        let raster = image { context in
            drawStaff(context, y: 320, space: 12)
            drawStaff(context, y: 440, space: 12)
            drawStaff(context, y: 900, space: 12)
            drawStaff(context, y: 1020, space: 12)
        }
        let review = StaffDetectionPage(
            pageIndex: 0, image: raster, result: StaffBandDetector.detect(in: raster),
            sourcePDFData: source, rectification: nil
        )
        let undoManager = UndoManager()
        document.undoManager = undoManager
        undoManager.beginUndoGrouping()
        try check(document.addStaffBands(from: review, groups: [[0, 1], [2, 3]], partID: partID) == 2, "Grouped bands were not created.")
        undoManager.endUndoGrouping()
        try check(document.project.bands.count == 2, "Wrong number of grouped bands.")
        try check(document.addStaffBands(from: review, groups: [[0, 1], [2, 3]], partID: partID) == 0, "Duplicate proposals were added.")
        undoManager.undo()
        try check(document.project.bands.isEmpty, "Adding proposals was not a single undoable edit.")
        undoManager.redo()
        try check(document.project.bands.count == 2, "Redo did not restore proposed bands.")
        document.currentPageIndex = 1
        try check(document.addStaffBands(from: review, groups: [[0]], partID: partID) == nil, "Stale page review was applied.")
        document.currentPageIndex = 0
        var changed = review
        changed.rectification = .default(pageIndex: 0)
        try check(document.addStaffBands(from: changed, groups: [[0]], partID: partID) == nil, "Stale rectification was applied.")
        try check(document.addStaffBands(from: review, groups: [[0, 2]], partID: partID) == nil, "Nonconsecutive multi-staff band was accepted.")
        try check(document.addStaffBands(from: review, groups: [[0], [0]], partID: partID) == nil, "Repeated candidate IDs were accepted.")

        var callback = false
        var detected: StaffDetectionPage?
        document.detectStaffBands { result in callback = true; detected = result }
        let deadline = Date().addingTimeInterval(15)
        while !callback && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        try check(callback && detected?.result.candidates.count == 2, "Background detection failed on the fixture.")
        callback = false
        document.detectStaffBands { _ in callback = true }
        document.cancelStaffDetection()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        try check(!callback, "Canceled detection delivered a result.")
        callback = false
        var staleResult: StaffDetectionPage?
        document.detectStaffBands { result in callback = true; staleResult = result }
        document.currentPageIndex = 1
        let staleDeadline = Date().addingTimeInterval(15)
        while !callback && Date() < staleDeadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        try check(callback && staleResult == nil, "Background stale result was not rejected.")
        print("PASS: multi-staff grouping, duplicate suppression, undo/redo, input validation, background detection, cancellation, and stale-result guards.")
    }

    private static func sampleReport() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("artifacts/staff-detection-review")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let paths = [
            "Partsmith/Resources/Fixtures/SampleScoreFixture.pdf",
            "sample_scores/normal/01_chamber/mozart_string_quartet_kv387_score.pdf",
            "sample_scores/normal/01_chamber/mozart_trio_eb_major_kv498_score.pdf",
            "sample_scores/normal/04_choir/mozart_ave_verum_corpus_kv618_cpdl18715_complete_score.pdf",
            "sample_scores/lightly_skewed/02_brahms_clarinet_trio_op114_imslp_114011.pdf",
            "sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf"
        ]
        let expectedCounts = [[2, 2], [16, 16, 16], [16, 20, 20], [16, 16, 16], [12, 16, 16], [16, 20, 20]]
        var samples: [Sample] = []
        for (fileIndex, path) in paths.enumerated() {
            guard let document = PDFDocument(url: root.appendingPathComponent(path)) else {
                throw NSError(domain: "StaffDetectionTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open \(path)"])
            }
            for pageIndex in 0..<min(document.pageCount, 3) {
                guard let page = document.page(at: pageIndex), let raster = rasterize(page) else { continue }
                let result = StaffBandDetector.detect(in: raster)
                let expected = expectedCounts[fileIndex][pageIndex]
                let name = "sample-\(fileIndex)-page-\(pageIndex + 1).png"
                try writeOverlay(raster, candidates: result.candidates, to: output.appendingPathComponent(name))
                let sample = Sample(
                    file: path, page: pageIndex + 1, count: result.candidates.count, expectedCount: expected,
                    confidence: result.candidates.map(\.confidence),
                    lineTops: result.candidates.map { $0.staffLineFractions[0] }, image: name, mode: "Source"
                )
                samples.append(sample)
                print("\(path) page \(pageIndex + 1): \(sample.count)/\(expected) staves")
                if fileIndex < 5 {
                    try check(sample.count == expected, "Regression in \(path) page \(pageIndex + 1): expected \(expected), found \(sample.count).")
                }
                if fileIndex >= 4,
                   let estimate = PageRectificationEstimator.estimate(for: page, pageIndex: pageIndex),
                   let rectified = SourcePageRenderCache(pdfDocument: document, rasterScale: 1800 / page.bounds(for: .mediaBox).width)
                    .rectifiedDisplayImage(for: pageIndex, rectification: estimate.rectification) {
                    let corrected = StaffBandDetector.detect(in: rectified)
                    let correctedName = "sample-\(fileIndex)-page-\(pageIndex + 1)-rectified.png"
                    try writeOverlay(rectified, candidates: corrected.candidates, to: output.appendingPathComponent(correctedName))
                    samples.append(Sample(
                        file: path, page: pageIndex + 1, count: corrected.candidates.count, expectedCount: expected,
                        confidence: corrected.candidates.map(\.confidence),
                        lineTops: corrected.candidates.map { $0.staffLineFractions[0] }, image: correctedName,
                        mode: "App rectification (\(String(format: "%.3f", estimate.angleDegrees))°)"
                    ))
                    print("  after app rectification: \(corrected.candidates.count)/\(expected) staves")
                }
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(samples).write(to: output.appendingPathComponent("results.json"))
        let cards = samples.map { sample in
            "<article><h2>\(sample.file) — page \(sample.page)</h2><p>\(sample.mode): \(sample.count)/\(sample.expectedCount) expected staff proposals. Blue: staff lines. Green: editable crop. Count agreement does not verify crop edges.</p><img src='\(sample.image)' width='800'></article>"
        }.joined(separator: "\n")
        try "<!doctype html><meta charset='utf-8'><title>Native staff detector review</title><style>body{font:16px system-ui;margin:32px;background:#eef0f3}article{padding:20px;background:white;margin-bottom:30px}h2{font-size:18px}img{max-width:100%;height:auto}</style><h1>Native offline staff proposals</h1>\(cards)"
            .write(to: output.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        print("Review: \(output.path)/index.html")
    }

    private static func rasterize(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = 1800 / bounds.width
        let context = CGContext(data: nil, width: 1800, height: Int((bounds.height * scale).rounded(.up)), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    private static func writeOverlay(_ image: CGImage, candidates: [StaffBandCandidate], to url: URL) throws {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for candidate in candidates {
            context.setFillColor(CGColor(red: 0.0, green: 0.7, blue: 0.35, alpha: 0.10))
            context.setStrokeColor(CGColor(red: 0.0, green: 0.55, blue: 0.2, alpha: 0.8))
            let rectangle = CGRect(x: 8, y: height * (1 - candidate.bottomFraction), width: width - 16, height: height * (candidate.bottomFraction - candidate.topFraction))
            context.fill(rectangle)
            context.setLineWidth(2)
            context.stroke(rectangle)
            context.setStrokeColor(CGColor(red: 0.0, green: 0.4, blue: 0.95, alpha: 0.6))
            for fraction in candidate.staffLineFractions {
                let y = height * (1 - fraction)
                context.move(to: CGPoint(x: 20, y: y))
                context.addLine(to: CGPoint(x: width - 20, y: y))
            }
            context.strokePath()
        }
        let representation = NSBitmapImageRep(cgImage: context.makeImage()!)
        try representation.representation(using: .png, properties: [:])!.write(to: url)
    }
}
