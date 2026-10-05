import AppKit
import Foundation
import PDFKit

/// Rendering/layout checks independent of image recognition: confirmed silence
/// may join, but a new musical boundary or unaccounted source system may not.
@main enum DefaultRestJoinTests {
    static var checks = 0
    static var failures: [String] = []
    static let output = URL(fileURLWithPath: ".build/default-rest-joins", isDirectory: true)
    static func check(_ ok: Bool, _ message: String) {
        checks += 1
        if !ok { failures.append(message); print("FAIL: \(message)") }
    }
    static func fixture() -> ProjectData {
        var project = ProjectData.empty
        project.pageCount = 4
        project.projectSettings.showTitleBlock = false
        let part = PartModel(id: UUID(), name: "Piano", color: ColorData(nsColor: .systemPurple),
                             layoutSettings: .default, createdAt: .now)
        project.parts = [part]
        project.parts[0].layoutSettings.usesSharedLayout = true
        project.bands = [5, 5, 6, 5, 4, 4, 5, 5].enumerated().map { index, count in
            var band = BandModel(id: UUID(), pageIndex: index / 2, partID: part.id,
                topFraction: index % 2 == 0 ? 0.1 : 0.5, bottomFraction: index % 2 == 0 ? 0.3 : 0.7,
                leftFraction: 0.05, rightFraction: 0.05, excluded: false,
                createdAt: Date(timeIntervalSince1970: Double(index)), barNumberMode: .hidden,
                generatedRest: BandGeneratedRest(barCount: count, sourceSystemIndex: index % 2))
            band.sourceSystemIndex = index % 2
            return band
        }
        project.bands[0].generatedRest = nil
        project.bands[0].restReplacement = BandRestReplacement(barCount: 5, sourceContext: openingContext())
        return project
    }
    static func openingContext() -> BandRestSourceContext {
        var result = BandRestSourceContext(
            prefix: BandSourceMarking(topFraction: 0.1, bottomFraction: 0.3, leftFraction: 0.05, rightFraction: 0.74),
            suffix: BandSourceMarking(topFraction: 0.1, bottomFraction: 0.3, leftFraction: 0.92, rightFraction: 0.05),
            staffLineFractions: [0.15, 0.1575, 0.165, 0.1725, 0.18], skewDegrees: 0,
            staffLeftFraction: 0.15, staffRightFraction: 0.94)
        result.staffLineGroups = [result.staffLineFractions, [0.23, 0.2375, 0.245, 0.2525, 0.26]]
        result.canExtendThroughFollowingRests = true
        return result
    }
    static func plan(_ project: ProjectData) throws -> PartRenderPlan {
        try PartLayoutEngine.makePlan(project: project,
            pageBoundsProvider: { (0..<project.pageCount).contains($0) ? CGRect(x: 0, y: 0, width: 600, height: 800) : nil },
            partID: project.parts[0].id)
    }
    static func placements(_ project: ProjectData) throws -> [BandPlacement] { try plan(project).pages.flatMap(\.placements) }
    static func main() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let original = fixture(), data = try encoder.encode(original)
        let rows = try placements(original)
        check(rows.count == 1 && rows[0].restBarCount == 39, "Opening grand staff plus seven omitted systems combine into 39 bars by default")
        check(rows[0].sourceBandIDs == original.sortedBands(for: original.parts[0].id).map(\.id), "All eight source references survive joining")
        check(rows[0].restReplacement?.sourceContext == original.bands[0].restReplacement?.sourceContext, "Joining retains the opening clefs, signatures, bracket and ending fragment")
        check(try encoder.encode(original) == data, "Layout never modifies original counts, geometry or join preferences")
        let reopened = try JSONDecoder().decode(ProjectData.self, from: data)
        let reopenedRows = try placements(reopened)
        check(reopened == original && reopenedRows.first?.restBarCount == 39, "Saving/reopening retains default joining and every source row")
        let missingPreference = try JSONDecoder().decode(BandRestReplacement.self, from: Data(#"{"barCount":5}"#.utf8))
        check(missingPreference.joinWithPrevious, "An absent replacement preference enables default joining")
        let explicitFalse = try JSONDecoder().decode(BandRestReplacement.self, from: Data(#"{"barCount":5,"joinWithPrevious":false}"#.utf8))
        check(!explicitFalse.joinWithPrevious, "An explicit separation preference survives decoding")

        let cue = BandSourceMarking(topFraction: 0.04, bottomFraction: 0.07, leftFraction: 0.1, rightFraction: 0.6)
        var heading = original
        heading.bands[0].editorialLabel = "Allegro"
        heading.bands[0].sourceMarkings = [cue]
        let headingRows = try placements(heading)
        check(headingRows.count == 1 && headingRows[0].editorialLabel == "Allegro" && headingRows[0].sourceMarkings.count == 1,
              "Opening directions stay attached to the combined rest")
        let barriers: [(String, (inout ProjectData) -> Void)] = [
            ("explicit separation", { $0.bands[1].generatedRest?.joinWithPrevious = false }),
            ("requested page turn", { $0.bands[1].pageBreakBefore = true }),
            ("internal tempo label", { $0.bands[1].editorialLabel = "Andante" }),
            ("internal source direction", { $0.bands[1].sourceMarkings = [cue] }),
            ("direction after preceding system", { var following = cue; following.isBelow = true; $0.bands[0].sourceMarkings = [following] }),
            ("repeat or double-bar ending", { $0.bands[0].restReplacement?.sourceContext?.canExtendThroughFollowingRests = false }),
            ("unverified ending", { $0.bands[0].restReplacement?.sourceContext?.canExtendThroughFollowingRests = nil }),
            ("missing source system", { $0.bands[1].sourceSystemIndex = 2; $0.bands[1].generatedRest?.sourceSystemIndex = 2 }),
            ("repeated source system", { $0.bands[1].sourceSystemIndex = 0; $0.bands[1].generatedRest?.sourceSystemIndex = 0 })
        ]
        for (name, mutate) in barriers {
            var blocked = original; mutate(&blocked)
            let result = try placements(blocked)
            check(result.count > 1 && result[0].sourceBandIDs == [blocked.bands[0].id], "Keep boundary: \(name)")
            check(result.flatMap(\.sourceBandIDs) == blocked.sortedBands(for: blocked.parts[0].id).map(\.id), "Preserve source rows at \(name)")
        }
        var music = original
        music.bands[1].generatedRest = nil
        let musicRows = try placements(music)
        check(musicRows.count == 3 && musicRows[1].restBarCount == nil && musicRows[1].sourceBandIDs == [music.bands[1].id], "A sounding system interrupts the rest run and remains untouched")
        var excluded = original; excluded.bands[1].excluded = true
        let excludedRows = try placements(excluded)
        check(excludedRows.count == 2 && excludedRows[0].restBarCount == 5 && excludedRows[1].restBarCount == 29, "An excluded source interval cannot disappear into a combined count")
        var gap = original
        gap.bands = Array(gap.bands.prefix(2)); gap.bands[1].pageIndex = 2
        gap.bands[1].sourceSystemIndex = 0; gap.bands[1].generatedRest?.sourceSystemIndex = 0
        check(try placements(gap).count == 2, "Unknown bar numbers cannot bridge an unselected page")
        gap.bands[1].pageIndex = 1; gap.bands[1].sourceSystemIndex = 1; gap.bands[1].generatedRest?.sourceSystemIndex = 1
        check(try placements(gap).count == 2, "A next-page run cannot skip its first system")
        var missingLastSystem = original
        missingLastSystem.bands = [original.bands[0], original.bands[2]]
        var otherPart = original.parts[0]; otherPart.id = UUID(); otherPart.name = "Violin"
        missingLastSystem.parts.append(otherPart)
        var laterSystem = original.bands[1]; laterSystem.id = UUID(); laterSystem.partID = otherPart.id
        laterSystem.generatedRest = nil
        missingLastSystem.bands.append(laterSystem)
        let missingLastRows = try placements(missingLastSystem)
        check(missingLastRows.count == 2 && missingLastRows.map(\.restBarCount) == [5, 6],
              "Another part's later system prevents a cross-page join that would skip silence")
        check(missingLastRows.flatMap(\.sourceBandIDs) == [original.bands[0].id, original.bands[2].id],
              "Project-wide continuity checks never add another instrument's source row to this part")
        missingLastSystem.bands[2].excluded = true
        check(try placements(missingLastSystem).count == 2,
              "An excluded row on another part still proves a missing source system")

        var knownLater = original
        knownLater.bands[1].generatedRest?.startBarNumber = 6
        let knownRows = try placements(knownLater)
        check(knownRows.count == 1 && knownRows[0].restBarCount == 39, "One later starting number can anchor an otherwise unnumbered run")
        knownLater.bands[2].generatedRest?.startBarNumber = 20
        let contradictory = try placements(knownLater)
        check(contradictory.count == 2 && contradictory[0].restBarCount == 10, "A derived start cannot conceal a contradictory later bar number")
        var overlap = original
        overlap.bands[0].barNumberValue = 1
        overlap.bands[1].generatedRest?.startBarNumber = 5
        check(try placements(overlap).first?.restBarCount == 5, "Overlapping explicit numbers stop a join")
        var impossibleStart = original
        impossibleStart.bands[1].generatedRest?.startBarNumber = 3
        check(try placements(impossibleStart).first?.restBarCount == 5, "Backward inference may not create zero or negative starting bars")
        var oversized = original
        oversized.bands[0].restReplacement?.barCount = 999
        check(try placements(oversized).first?.restBarCount == 999, "Combined counts never overflow the supported 999 bars")
        var numberLimit = original
        numberLimit.bands = Array(numberLimit.bands.prefix(2))
        numberLimit.bands[0].barNumberValue = Int.max - 4
        check(try placements(numberLimit).count == 2, "A final valid measure cannot overflow when joining unnumbered following silence")
        var sourceLimit = original
        sourceLimit.bands = Array(sourceLimit.bands.prefix(2))
        sourceLimit.bands[0].sourceSystemIndex = Int.max
        check(try placements(sourceLimit).count == 2, "A corrupt maximal system index cannot overflow continuity checks")

        var bare = original
        bare.bands[0].restReplacement?.sourceContext = nil
        bare.bands[2].generatedRest = nil
        bare.bands[2].restReplacement = BandRestReplacement(barCount: 6)
        check(try placements(bare).first?.restBarCount == 39, "Bare manual and generated rests share the same default continuity rules")
        var newContext = original
        newContext.bands[1].generatedRest = nil
        var another = openingContext()
        another.prefix.topFraction += 0.4; another.prefix.bottomFraction += 0.4
        another.suffix!.topFraction += 0.4; another.suffix!.bottomFraction += 0.4
        another.staffLineFractions = another.staffLineFractions.map { $0 + 0.4 }
        another.staffLineGroups = another.staffLineGroups?.map { $0.map { $0 + 0.4 } }
        newContext.bands[1].restReplacement = BandRestReplacement(barCount: 5, sourceContext: another)
        let contextRows = try placements(newContext)
        check(contextRows.count == 2 && contextRows[0].restBarCount == 5 && contextRows[1].restBarCount == 34, "A new source context remains visible and can anchor its own following run")

        let document = PartsmithDocument(project: original)
        let undo = UndoManager(); undo.groupsByEvent = false; document.undoManager = undo
        undo.beginUndoGrouping()
        check(document.updateBandGeneratedRest(original.bands[1].id, barCount: 5, joinWithPrevious: false), "The document accepts a separation override")
        undo.endUndoGrouping()
        let separatedRows = try placements(document.project)
        check(document.project.bands[1].generatedRest?.joinWithPrevious == false && separatedRows.count == 2, "Explicit false separates even when default joining is on")
        undo.undo()
        let undoneRows = try placements(document.project)
        check(document.project == original && undoneRows.count == 1, "Undo restores source data and default joined preview")
        undo.redo(); check(document.project.bands[1].generatedRest?.joinWithPrevious == false, "Redo recalls explicit separation")
        undo.beginUndoGrouping()
        check(document.updateBandGeneratedRestCount(original.bands[1].id, barCount: 6), "Changing a separated rest count succeeds")
        undo.endUndoGrouping()
        check(document.project.bands[1].generatedRest?.joinWithPrevious == false, "Count-only edits preserve separation")
        try verifyGrandStaffExport(original)
        let report: [String: Any] = ["checks": checks, "failures": failures]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
        print("\(checks) default rest joining checks; \(failures.count) failures")
        if !failures.isEmpty { exit(1) }
    }
    static func verifyGrandStaffExport(_ project: ProjectData) throws {
        let renderPlan = try plan(project), placement = renderPlan.pages[0].placements[0]
        guard let geometry = placement.restSourcePlacement else { fatalError("Missing retained grand staff geometry") }
        check(geometry.staffLines.count == 10, "A compressed grand staff retains ten staff lines")
        check(geometry.additionalRestCenters.count == 1, "The lower staff receives a distinct rest symbol")
        check(geometry.fragments.count == 2, "Opening and closing grand staff fragments both remain present")
        let source = NSMutableData(); var box = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: source)!, mediaBox: &box, nil)!
        for page in 0..<project.pageCount {
            context.beginPDFPage(nil)
            if page == 0 {
                context.setStrokeColor(NSColor.black.cgColor); context.setLineWidth(0.6)
                for fraction in openingContext().staffLineGroups!.flatMap({ $0 }) {
                    let y = 800 - fraction * 800
                    context.move(to: CGPoint(x: 90, y: y)); context.addLine(to: CGPoint(x: 564, y: y))
                }
                for x in [90.0, 560.0] {
                    context.move(to: CGPoint(x: x, y: 592)); context.addLine(to: CGPoint(x: x, y: 680))
                }
                context.strokePath()
            }
            context.endPDFPage()
        }
        context.closePDF()
        let pdfData = try PartPDFExporter.pdfData(for: project.parts[0].id, project: project, sourcePDFData: source as Data)
        try pdfData.write(to: output.appendingPathComponent("grand-staff-39-bars.pdf"))
        let pdf = PDFDocument(data: pdfData)!
        let words = (pdf.string ?? "").components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        check(words.filter { $0 == "39" }.count == 1, "The exported grand staff prints one shared count of 39")
        let size = renderPlan.pageSize
        let rasterContext = CGContext(data: nil, width: Int(size.width * 4), height: Int(size.height * 4), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        rasterContext.setFillColor(NSColor.white.cgColor)
        rasterContext.fill(CGRect(x: 0, y: 0, width: size.width * 4, height: size.height * 4))
        rasterContext.scaleBy(x: 4, y: 4); rasterContext.drawPDFPage(pdf.page(at: 0)!.pageRef!)
        let bitmap = NSBitmapImageRep(cgImage: rasterContext.makeImage()!)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("grand-staff-39-bars.png"))
        let bytes = bitmap.bitmapData!
        for staff in 0..<2 {
            let middle = geometry.staffLines[staff * 5 + 2]
            let center = CGPoint(x: (middle[0].x + middle[1].x) / 2, y: (middle[0].y + middle[1].y) / 2)
            // Above and below the center line: a thin staff line alone cannot pass.
            for delta in [-0.15, 0.15] {
                let x = Int(center.x * 4), y = Int((size.height - center.y - delta * geometry.staffSpace) * 4)
                let offset = y * bitmap.bytesPerRow + x * bitmap.samplesPerPixel
                check((0..<3).allSatisfy { bytes[offset + $0] < 100 }, "Staff \(staff + 1) renders its own solid multi-bar rest")
            }
        }
    }
}
