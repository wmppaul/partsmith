import AppKit
import Foundation
import PDFKit

@main enum RestContextTests {
    struct Source: Decodable { var path: String; var sha256: String }
    struct Fixture: Decodable { var id: String; var sourceID: String; var pageIndex: Int; var band: [Double]; var expectedBarCount: Int? }
    struct Corpus: Decodable { var sources: [String: Source]; var fixtures: [Fixture] }
    static var checks = 0
    static var failures: [String] = []
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !ok() { failures.append(message); print("FAIL: \(message)") }
    }
    static func bitmap(size: CGSize, draw: (CGContext) -> Void) -> NSBitmapImageRep {
        let context = CGContext(data: nil, width: Int(size.width * 2), height: Int(size.height * 2), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.white.cgColor); context.fill(CGRect(origin: .zero, size: CGSize(width: size.width * 2, height: size.height * 2)))
        context.scaleBy(x: 2, y: 2); draw(context)
        return NSBitmapImageRep(cgImage: context.makeImage()!)
    }
    static func controlPDF(size: CGSize, draw: (CGContext) -> Void) -> PDFDocument {
        let data = NSMutableData()
        var media = CGRect(origin: .zero, size: size)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor); context.fill(media)
        draw(context)
        context.endPDFPage(); context.closePDF()
        return PDFDocument(data: data as Data)!
    }
    static func main() throws {
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: "Tests/extraction/automatic-rest-fixtures.json")))
        let out = URL(fileURLWithPath: ".build/rest-context-tests")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for sourceID in corpus.sources.keys.sorted() {
            let positives = corpus.fixtures.filter { $0.sourceID == sourceID && $0.expectedBarCount != nil }
            if positives.isEmpty { continue }
            let source = try Data(contentsOf: URL(fileURLWithPath: corpus.sources[sourceID]!.path))
            let pdf = PDFDocument(data: source)!
            for pageIndex in Set(positives.map(\.pageIndex)).sorted() {
                let page = pdf.page(at: pageIndex)!, bounds = page.bounds(for: .mediaBox)
                let image = NativeScorePageAnalyzer.render(page)!, staves = StaffBandDetector.detect(in: image)
                for fixture in positives.filter({ $0.pageIndex == pageIndex }) {
                    let r = fixture.band
                    let rect = CGRect(x: r[0], y: r[1], width: r[2]-r[0], height: r[3]-r[1])
                    guard let found = ScoreRestDetector.detect(in: image, band: rect, staffDetection: staves) else {
                        fatalError("Reviewed positive not recognized: \(fixture.id)")
                    }
                    check(found.barCount == fixture.expectedBarCount, "Recognized count matches independent source review")
                    var project = ProjectData.empty
                    project.pageCount = pdf.pageCount
                    project.projectSettings.showTitleBlock = false
                    project.projectSettings.showPartNameInHeader = true
                    let part = PartModel(id: UUID(), name: fixture.id, color: ColorData(nsColor: .systemBlue), layoutSettings: .default, createdAt: .now)
                    project.parts = [part]
                    func fragment(_ rect: CGRect) -> BandSourceMarking {
                        BandSourceMarking(topFraction: max(r[1], rect.minY), bottomFraction: min(r[3], rect.maxY),
                            leftFraction: max(r[0], rect.minX), rightFraction: max(1-r[2], 1-rect.maxX))
                    }
                    let retained = BandRestSourceContext(prefix: fragment(found.prefixBounds), suffix: found.suffixBounds.map(fragment),
                        staffLineFractions: found.staffLineFractions, skewDegrees: found.skewDegrees,
                        staffLeftFraction: found.staffLeftFraction, staffRightFraction: found.staffRightFraction)
                    let band = BandModel(id: UUID(), pageIndex: pageIndex, partID: part.id, topFraction: r[1], bottomFraction: r[3],
                        leftFraction: r[0], rightFraction: 1-r[2], excluded: false, createdAt: .now,
                        barNumberMode: .manual, barNumberValue: 42, restReplacement: BandRestReplacement(barCount: found.barCount, sourceContext: retained))
                    project.bands = [band]
                    check(retained.isValid(in: band), "Detected source fragments remain within the original strip")
                    let reopened = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(project))
                    check(reopened == project, "Automatic count, geometry and source context persist exactly")
                    let plan = try PartLayoutEngine.makePlan(project: project, pageBoundsProvider: { pdf.page(at: $0)?.bounds(for: .mediaBox) }, partID: part.id)
                    let placement = plan.pages[0].placements[0], geometry = placement.restSourcePlacement!
                    check(geometry.fragments.count == (found.suffixBounds == nil ? 1 : 2), "Both source boundaries survive into the render plan")
                    check(geometry.staffLines.count == 5 && geometry.staffSpace > 0 && geometry.restSpan > 10 * geometry.staffSpace,
                          "Generated rest has five lines, a readable space and ample horizontal room")
                    let data = try PartPDFExporter.pdfData(for: part.id, project: project, sourcePDFData: source)
                    try data.write(to: out.appendingPathComponent(fixture.id + ".pdf"))
                    let rendered = PDFDocument(data: data)!
                    let actual = bitmap(size: plan.pageSize) { $0.drawPDFPage(rendered.page(at: 0)!.pageRef!) }
                    // Compare two PDF roundtrips. Drawing the source directly
                    // to a bitmap uses different digital-font hinting than an
                    // exported PDF and can move antialiased bracket edges.
                    let control = controlPDF(size: plan.pageSize) { context in
                        let scale = placement.destinationRect.width / placement.sourceRect.width
                        context.translateBy(x: placement.destinationRect.minX - placement.sourceRect.minX * scale,
                                            y: placement.destinationRect.minY - placement.sourceRect.minY * scale)
                        context.scaleBy(x: scale, y: scale)
                        page.draw(with: .mediaBox, to: context)
                    }
                    let expected = bitmap(size: plan.pageSize) { $0.drawPDFPage(control.page(at: 0)!.pageRef!) }
                    check(actual.bytesPerRow == expected.bytesPerRow && actual.samplesPerPixel == expected.samplesPerPixel, "Reference rasters have identical format")
                    let a = actual.bitmapData!, b = expected.bitmapData!
                    var changed = 0, sampled = 0, dark = 0, maximumDelta = 0
                    var differences: [String] = []
                    for y in 0..<actual.pixelsHigh { for x in 0..<actual.pixelsWide {
                        let p = CGPoint(x: (Double(x)+0.5)/2, y: (Double(actual.pixelsHigh-y)-0.5)/2)
                        guard geometry.fragments.contains(where: { $0.destinationRect.insetBy(dx: 1, dy: 1).contains(p) }) else { continue }
                        let i = y * actual.bytesPerRow + x * actual.samplesPerPixel
                        sampled += 1
                        if b[i] < 180 { dark += 1 }
                        let delta = (0..<3).map { abs(Int(a[i+$0])-Int(b[i+$0])) }.max()!
                        maximumDelta = max(maximumDelta, delta)
                        if delta > 1 {
                            changed += 1
                            if differences.count < 20 {
                                differences.append("\(x),\(y): actual \(a[i]),\(a[i+1]),\(a[i+2]); reference \(b[i]),\(b[i+1]),\(b[i+2]); point \(p)")
                            }
                        }
                    }}
                    check(sampled > 100 && dark > 20, "Pixel comparison covers actual printed context ink")
                    check(changed == 0, "\(fixture.id): every sampled clef/key/meter/tempo/end-bar pixel is unchanged (\(changed)/\(sampled))")
                    let imageData = actual.representation(using: .png, properties: [:])!
                    try imageData.write(to: out.appendingPathComponent(fixture.id + ".png"))
                    try expected.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(fixture.id + "-reference.png"))
                    let differenceURL = out.appendingPathComponent(fixture.id + "-differences.txt")
                    if changed > 0 {
                        try ("Maximum channel difference: \(maximumDelta)\n" + differences.joined(separator: "\n"))
                            .write(to: differenceURL, atomically: true, encoding: .utf8)
                    } else if FileManager.default.fileExists(atPath: differenceURL.path) {
                        try FileManager.default.removeItem(at: differenceURL)
                    }
                    var altered = project
                    altered.bands[0].restReplacement?.sourceContext?.prefix.bottomFraction = r[3]+0.05
                    do {
                        _ = try PartLayoutEngine.makePlan(project: altered, pageBoundsProvider: { _ in bounds }, partID: part.id)
                        fatalError("Out-of-crop source context must reject export")
                    } catch PartLayoutError.invalidRestReplacement { checks += 1 }
                    var collapsed = retained
                    collapsed.staffRightFraction = (collapsed.staffLeftFraction + 1 - collapsed.prefix.rightFraction) / 2
                    check(!collapsed.isValid(in: band), "A prefix beyond the staff end cannot hide the printed rest count")
                    altered = project
                    altered.bands[0].restReplacement?.sourceContext = collapsed
                    do {
                        _ = try PartLayoutEngine.makePlan(project: altered, pageBoundsProvider: { _ in bounds }, partID: part.id)
                        check(false, "An empty usable rest span must reject export")
                    } catch PartLayoutError.invalidRestReplacement { checks += 1 }
                    var joined = project
                    var second = band; second.id = UUID(); second.topFraction += 0.2; second.bottomFraction += 0.2
                    // Even a persisted join flag cannot discard another automatic context.
                    second = band; second.id = UUID(); second.createdAt = band.createdAt.addingTimeInterval(1)
                    second.restReplacement?.joinWithPrevious = true
                    joined.bands.append(second)
                    let separate = try PartLayoutEngine.makePlan(project: joined, pageBoundsProvider: { _ in bounds }, partID: part.id)
                    check(separate.pages.flatMap(\.placements).count == 2, "Automatic context is never silently discarded by joining")
                    print("CHECK \(fixture.id): \(found.barCount) bars, \(sampled) context pixels, \(changed) changed, max delta \(maximumDelta)")
                }
            }
        }
        print("\(checks) automatic-rest source-context checks, \(failures.count) failures")
        if !failures.isEmpty { exit(1) }
    }
}
