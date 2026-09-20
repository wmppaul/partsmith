import AppKit
import Foundation
import PDFKit

@main
enum MultiBarRestTests {
    static var checks = 0
    static let output = URL(fileURLWithPath: ".build/rest-tests", isDirectory: true)
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }

    static func sourceFixture() -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        context.setStrokeColor(NSColor.black.cgColor)
        context.setFillColor(NSColor.black.cgColor)
        context.setLineWidth(0.6)
        for (index, count) in [4, 5, 3].enumerated() {
            let bottom = CGFloat(800 - (160 + index * 200) - 24)
            for line in 0..<5 {
                let y = bottom + CGFloat(line) * 6
                context.move(to: CGPoint(x: 60, y: y))
                context.addLine(to: CGPoint(x: 540, y: y))
            }
            for bar in 0...count {
                let x = 60 + CGFloat(bar) * 480 / CGFloat(count)
                context.move(to: CGPoint(x: x, y: bottom))
                context.addLine(to: CGPoint(x: x, y: bottom + 24))
            }
            context.strokePath()
            for bar in 0..<count {
                let x = 60 + (CGFloat(bar) + 0.5) * 480 / CGFloat(count)
                if index == 2 && bar == count - 1 {
                    context.fillEllipse(in: CGRect(x: x - 4, y: bottom + 9, width: 8, height: 5))
                    context.fill(CGRect(x: x + 3.5, y: bottom + 11, width: 0.8, height: 22))
                } else {
                    context.fill(CGRect(x: x - 4, y: bottom + 15, width: 8, height: 3))
                }
            }
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    static func project() -> ProjectData {
        var project = ProjectData.empty
        project.pageCount = 1
        project.projectSettings.showTitleBlock = false
        project.projectSettings.showPartNameInHeader = true
        let part = PartModel(id: UUID(), name: "Synthetic rest layout", color: ColorData(nsColor: .systemBlue),
            layoutSettings: .default, createdAt: Date(timeIntervalSince1970: 0))
        project.parts = [part]
        project.bands = (0..<3).map { index in
            BandModel(id: UUID(), pageIndex: 0, partID: part.id,
                topFraction: Double(140 + index * 200) / 800,
                bottomFraction: Double(200 + index * 200) / 800,
                leftFraction: 0.1, rightFraction: 0.1, excluded: false,
                createdAt: Date(timeIntervalSince1970: Double(index)), barNumberMode: .hidden)
        }
        return project
    }

    static func plan(_ project: ProjectData) throws -> PartRenderPlan {
        try PartLayoutEngine.makePlan(project: project,
            pageBoundsProvider: { $0 == 0 ? CGRect(x: 0, y: 0, width: 600, height: 800) : nil },
            partID: project.parts[0].id)
    }

    static func placements(_ project: ProjectData) throws -> [BandPlacement] {
        try plan(project).pages.flatMap(\.placements)
    }

    static func verifyBounds(_ plan: PartRenderPlan, project: ProjectData) {
        let margins = project.projectSettings.margins
        let content = CGRect(x: margins.leading, y: margins.bottom,
            width: plan.pageSize.width - margins.leading - margins.trailing,
            height: plan.pageSize.height - margins.top - margins.bottom)
        for page in plan.pages {
            var previousBottom = plan.partNameRect?.minY ?? content.maxY
            for placement in page.placements {
                check(content.insetBy(dx: -0.0001, dy: -0.0001).contains(placement.destinationRect),
                      "Generated rest strips remain inside the output margins")
                check(placement.destinationRect.maxY <= previousBottom + 0.0001,
                      "Generated rests and remaining source music never overlap")
                previousBottom = placement.destinationRect.minY
            }
        }
    }

    static func export(_ project: ProjectData, source: Data, name: String) throws -> PDFDocument {
        let data = try PartPDFExporter.pdfData(for: project.parts[0].id, project: project, sourcePDFData: source)
        try data.write(to: output.appendingPathComponent(name))
        return PDFDocument(data: data)!
    }

    static func main() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let source = sourceFixture()
        try source.write(to: output.appendingPathComponent("synthetic-source.pdf"))
        let original = project()
        let originalPlacements = try placements(original)
        let legacy = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(original))
        check(legacy == original && legacy.bands.allSatisfy { $0.restReplacement == nil },
              "Existing projects without rest replacements preserve their original source crops")
        let oldRest = try JSONDecoder().decode(BandRestReplacement.self, from: Data(#"{"barCount":4}"#.utf8))
        check(oldRest == BandRestReplacement(barCount: 4), "Missing rest join preference defaults to separate strips")

        var separate = original
        separate.bands[0].restReplacement = BandRestReplacement(barCount: 4)
        separate.bands[1].restReplacement = BandRestReplacement(barCount: 5)
        let separatePlacements = try placements(separate)
        check(separatePlacements.count == 3 && separatePlacements.map { $0.restReplacement?.barCount } == [4, 5, nil],
              "Explicit counts condense only selected whole bands and do not infer replacement for neighboring music")
        check(separatePlacements[0].destinationRect.height < originalPlacements[0].destinationRect.height
              && separatePlacements[0].sourceRect == originalPlacements[0].sourceRect,
              "A compact rest reserves less output height while retaining its exact source crop")
        check(separatePlacements[2].sourceRect == originalPlacements[2].sourceRect
              && separatePlacements[2].destinationRect.size == originalPlacements[2].destinationRect.size,
              "The sounding source band retains every crop edge and its original output scale")
        check(separatePlacements.map(\.sourceBandIDs) == original.bands.map { [$0.id] },
              "Unjoined placements retain each source band's identity")
        var smaller = separate
        smaller.parts[0].layoutSettings.scale = 0.7
        let smallerPlacements = try placements(smaller)
        check(abs(smallerPlacements[0].destinationRect.height / separatePlacements[0].destinationRect.height - 0.7) < 0.000001,
              "Generated rest size follows the same user scale as surrounding music")
        verifyBounds(try plan(separate), project: separate)
        let separatePDF = try export(separate, source: source, name: "synthetic-separate-4-5.pdf")
        check((separatePDF.string ?? "").contains("4") && (separatePDF.string ?? "").contains("5"),
              "Production PDF export prints each verified multi-bar rest count")

        var joined = separate
        joined.bands[1].restReplacement?.joinWithPrevious = true
        joined.bands[0].barNumberValue = 42
        joined.bands[0].barNumberMode = .manual
        joined.bands[1].barNumberValue = 46
        let joinedPlacements = try placements(joined)
        check(joinedPlacements.count == 2 && joinedPlacements[0].restReplacement == BandRestReplacement(barCount: 9)
              && joinedPlacements[0].sourceBandIDs == Array(original.bands.prefix(2).map(\.id)),
              "Explicitly joining adjacent four- and five-bar rests produces one nine-bar rest with both source identities")
        check(joined.bands[0].restReplacement?.barCount == 4 && joined.bands[1].restReplacement?.barCount == 5,
              "Joining in layout never rewrites the original individual bar counts")
        verifyBounds(try plan(joined), project: joined)
        let joinedPDF = try export(joined, source: source, name: "synthetic-joined-9.pdf")
        check((joinedPDF.string ?? "").contains("9") && (joinedPDF.string ?? "").contains("42"),
              "A joined rest prints its duration and keeps its starting source bar number distinct")
        let roundtrip = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(joined))
        check(roundtrip == joined && roundtrip.bands[1].restReplacement?.joinWithPrevious == true,
              "Rest counts, explicit joining, source geometry and other band settings round trip exactly")
        var restored = separate
        restored.bands.indices.forEach { restored.bands[$0].restReplacement = nil }
        check(restored == original, "Restoring source notation leaves the original project byte-for-byte in model values")
        let restoredPlacements = try placements(restored)
        check(zip(originalPlacements, restoredPlacements).allSatisfy {
            $0.sourceRect == $1.sourceRect && $0.destinationRect == $1.destinationRect
                && $0.exclusionRects == $1.exclusionRects && $0.restReplacement == nil
        }, "Clearing replacements restores exactly the original layout and source coordinates")
        _ = try export(restored, source: source, name: "synthetic-restored-source.pdf")

        var annotated = separate
        annotated.bands[0].editorialLabel = "Allegro — retain this direction"
        annotated.bands[0].sourceMarkings = [BandSourceMarking(topFraction: 0.04, bottomFraction: 0.065,
            leftFraction: 0.2, rightFraction: 0.6)]
        let annotatedRest = try placements(annotated)[0]
        var annotatedSource = annotated
        annotatedSource.bands[0].restReplacement = nil
        let annotationBefore = try placements(annotatedSource)[0]
        check(annotatedRest.editorialLabel == annotationBefore.editorialLabel
              && annotatedRest.sourceMarkings.count == 1
              && annotatedRest.sourceMarkings[0].sourceRect == annotationBefore.sourceMarkings[0].sourceRect,
              "Condensing a rest keeps editorial directions and verified source marking crops")
        check(annotatedRest.sourceMarkings[0].destinationRect == annotationBefore.sourceMarkings[0].destinationRect,
              "Source marking placement keeps its horizontal mapping and original aspect ratio")
        _ = try export(annotated, source: source, name: "synthetic-annotated-rest.pdf")
        for barrier in 0..<5 {
            var blocked = separate
            blocked.bands[1].restReplacement?.joinWithPrevious = true
            switch barrier {
            case 0: blocked.bands[0].editorialLabel = "Tempo change"
            case 1: blocked.bands[1].sourceMarkings = annotated.bands[0].sourceMarkings
            case 2: blocked.bands[1].pageBreakBefore = true
            case 3: blocked.bands[0].barNumberValue = 42; blocked.bands[1].barNumberValue = 99
            default: blocked.bands[0].restReplacement = BandRestReplacement(barCount: 999)
            }
            let blockedPlacements = try placements(blocked)
            check(blockedPlacements.count == 3,
                  "Rest joining stops at annotations, page breaks, contradictory bar numbers and oversized counts")
        }
        var throughMusic = separate
        throughMusic.bands[1].restReplacement = nil
        throughMusic.bands[2].restReplacement = BandRestReplacement(barCount: 3, joinWithPrevious: true)
        let throughMusicPlacements = try placements(throughMusic)
        check(throughMusicPlacements.count == 3, "Rest joining never skips an intervening source music band")
        var throughExcluded = throughMusic
        throughExcluded.bands[1].excluded = true
        let excludedPlacements = try placements(throughExcluded)
        check(excludedPlacements.count == 2 && excludedPlacements.allSatisfy { $0.sourceBandIDs.count == 1 },
              "An excluded source band remains a joining boundary and remains absent from output")
        var unknownStart = separate
        unknownStart.bands[1].barNumberValue = 5
        unknownStart.bands[1].restReplacement?.joinWithPrevious = true
        unknownStart.bands[2].barNumberValue = 50
        unknownStart.bands[2].restReplacement = BandRestReplacement(barCount: 3, joinWithPrevious: true)
        let unknownStartPlacements = try placements(unknownStart)
        check(unknownStartPlacements.count == 2,
              "A known start number later in a joined run still blocks a contradictory following number")
        for count in [Int.min, -1, 0, 1, 1000, Int.max] {
            var invalid = original
            invalid.bands[0].restReplacement = BandRestReplacement(barCount: count)
            do {
                _ = try plan(invalid)
                fatalError("Invalid multi-bar rest count accepted: \(count)")
            } catch PartLayoutError.invalidRestReplacement(0) {
                check(true, "Invalid rest count fails before export instead of printing a misleading duration")
            }
        }
        var masked = separate
        masked.bands[0].exclusions = [BandExclusion(topFraction: 0.19, bottomFraction: 0.22,
            leftFraction: 0.2, rightFraction: 0.7)]
        let maskedPlacements = try placements(masked)
        check(maskedPlacements[0].exclusionRects.isEmpty && !masked.bands[0].exclusions.isEmpty,
              "Source whiteouts cannot erase generated rest notation and remain available when restoring the source")
        try realBrahmsExample()
        print("PASS: \(checks) multi-bar rest model, layout and native PDF checks")
    }

    static func realBrahmsExample() throws {
        struct Envelope: Decodable { var project: ProjectData }
        let package = URL(fileURLWithPath: "output/pdf/brahms-trio-medium/Brahms Clarinet Trio Op. 114.partsmithproject")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var project = try decoder.decode(Envelope.self, from: Data(contentsOf: package.appendingPathComponent("project.json"))).project
        let source = try Data(contentsOf: package.appendingPathComponent("source.pdf"))
        let partID = UUID(uuidString: "734CF9D9-B1E8-4150-B5FA-C309824D9334")!
        let restID = UUID(uuidString: "722F70DA-D570-45ED-8E3D-AFB4EE91F90C")!
        guard let index = project.bands.firstIndex(where: { $0.id == restID }) else {
            fatalError("Verified Brahms six-bar rest fixture is missing")
        }
        let original = project
        project.bands[index].restReplacement = BandRestReplacement(barCount: 6)
        let data = try PartPDFExporter.pdfData(for: partID, project: project, sourcePDFData: source)
        try data.write(to: output.appendingPathComponent("Brahms-Clarinet-six-bar-rest.pdf"))
        let sourcePDF = PDFDocument(data: source)!
        let plan = try PartLayoutEngine.makePlan(project: project,
            pageBoundsProvider: { sourcePDF.page(at: $0)?.bounds(for: .mediaBox) }, partID: partID)
        let flattened = plan.pages.flatMap(\.placements)
        check(flattened.filter { $0.restReplacement != nil }.count == 1
              && flattened.first { $0.bandID == restID }?.restReplacement?.barCount == 6,
              "The actual Brahms example replaces only the independently verified six-rest internal band")
        let sourceBands = project.sortedBands(for: partID)
        let restingIndex = sourceBands.firstIndex { $0.id == restID }!
        let nextBand = sourceBands[restingIndex + 1]
        check(nextBand.restReplacement == nil && flattened.contains { $0.bandID == nextBand.id && $0.restReplacement == nil },
              "The following Brahms staff keeps its initial three rests and subsequent sounding entry intact")
        project.bands[index].restReplacement = nil
        check(project == original, "Restoring the actual Brahms replacement restores all original stored geometry and metadata")
    }
}
