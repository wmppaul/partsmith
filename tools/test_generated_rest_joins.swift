import AppKit
import Foundation
import PDFKit

@main enum GeneratedRestJoinTests {
    static var checks = 0
    static func check(_ value: Bool, _ message: String) {
        checks += 1
        if !value { fatalError(message) }
    }
    static func fixture() -> ProjectData {
        var p = ProjectData.empty
        let part = PartModel(id: UUID(), name: "Voice", color: ColorData(red: 0, green: 0, blue: 1),
                             layoutSettings: .default, createdAt: .now)
        p.parts = [part]; p.pageCount = 2
        p.bands = (0..<4).map { i in
            BandModel(id: UUID(), pageIndex: i / 2, partID: part.id,
                topFraction: 0.1 + Double(i % 2) * 0.3, bottomFraction: 0.2 + Double(i % 2) * 0.3,
                leftFraction: 0.05, rightFraction: 0.05, excluded: false, createdAt: .now,
                barNumberMode: .manual, barNumberValue: i * 3 + 1,
                generatedRest: BandGeneratedRest(barCount: 3, startBarNumber: i * 3 + 1,
                                                sourceSystemIndex: i % 2, joinWithPrevious: i > 0 ? true : nil))
        }
        return p
    }
    static func placements(_ p: ProjectData) throws -> [BandPlacement] {
        try PartLayoutEngine.makePlan(project: p,
            pageBoundsProvider: { _ in CGRect(x: 0, y: 0, width: 600, height: 800) },
            partID: p.parts[0].id).pages.flatMap(\.placements)
    }
    static func main() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let base = fixture(), stored = try encoder.encode(base)
        let merged = try placements(base)
        check(merged.count == 1 && merged[0].restBarCount == 12, "Four confirmed three-bar rests make one twelve-bar rest")
        check(merged[0].generatedRest?.startBarNumber == 1 && merged[0].generatedRest?.endBarNumber == 12,
              "Joined duration retains its exact first and last measure")
        check(merged[0].sourceBandIDs == base.sortedBands(for: base.parts[0].id).map(\.id),
              "Every original source reference survives in order across page boundaries")
        check(try encoder.encode(base) == stored, "Layout leaves document rows and durations untouched")
        let decoded = try JSONDecoder().decode(ProjectData.self, from: stored)
        let decodedRows = try placements(decoded)
        check(decoded == base && decodedRows.count == 1, "Join preference and all original rows survive reopening")
        let legacy = try JSONDecoder().decode(BandGeneratedRest.self,
            from: Data(#"{"barCount":3,"startBarNumber":1,"sourceSystemIndex":0}"#.utf8))
        check(legacy.joinWithPrevious == nil, "Legacy documents do not opt into joining")
        var separate = base
        for i in separate.bands.indices { separate.bands[i].generatedRest?.joinWithPrevious = nil }
        check(try placements(separate).count == 4, "Joining is opt-in")

        let cue = BandSourceMarking(topFraction: 0.04, bottomFraction: 0.07, leftFraction: 0.1, rightFraction: 0.6)
        var opening = base; opening.bands[0].sourceMarkings = [cue]; opening.bands[0].editorialLabel = "Opening"
        let openingRows = try placements(opening)
        check(openingRows.count == 1 && openingRows[0].sourceMarkings.count == 1
              && openingRows[0].editorialLabel == "Opening", "Opening heading and label stay before the combined rest")
        let singleOpening = try placements({ var p = opening; p.bands = [p.bands[0]]; return p }())
        check(openingRows[0].sourceMarkings[0].sourceRect == singleOpening[0].sourceMarkings[0].sourceRect,
              "Opening copy still reads the exact original source rectangle")
        for (reason, mutate) in [
            ("internal cue", { (p: inout ProjectData) in p.bands[1].sourceMarkings = [cue] }),
            ("internal label", { (p: inout ProjectData) in p.bands[1].editorialLabel = "Tempo change" }),
            ("requested page turn", { (p: inout ProjectData) in p.bands[1].pageBreakBefore = true }),
            ("unknown first number", { (p: inout ProjectData) in p.bands[0].generatedRest?.startBarNumber = nil }),
            ("unknown following number", { (p: inout ProjectData) in p.bands[1].generatedRest?.startBarNumber = nil }),
            ("measure gap", { (p: inout ProjectData) in p.bands[1].generatedRest?.startBarNumber = 5 }),
            ("measure overlap", { (p: inout ProjectData) in p.bands[1].generatedRest?.startBarNumber = 3 }),
            ("following direction", { (p: inout ProjectData) in var c = cue; c.isBelow = true; p.bands[0].sourceMarkings = [c] })
        ] {
            var p = base; mutate(&p)
            let rows = try placements(p)
            check(rows.count > 1 && rows[0].sourceBandIDs == [p.bands[0].id], "Preserve boundary at \(reason)")
            check(rows.flatMap(\.sourceBandIDs) == p.sortedBands(for: p.parts[0].id).map(\.id), "Preserve all references at \(reason)")
        }
        var excluded = base; excluded.bands[1].excluded = true
        let excludedRows = try placements(excluded)
        check(excludedRows.count == 2 && excludedRows[0].restBarCount == 3 && excludedRows[1].restBarCount == 6,
              "An excluded source interval cannot disappear into a joined rest")
        var limit = base; limit.bands = Array(limit.bands.prefix(2))
        limit.bands[0].generatedRest?.barCount = 999; limit.bands[1].generatedRest?.startBarNumber = 1000
        check(try placements(limit).count == 2, "Joined counts cannot exceed 999")
        limit.bands[0].generatedRest?.startBarNumber = Int.max - 998
        check(try placements(limit).count == 2, "The final valid measure cannot overflow while considering a join")
        var music = base; music.bands[1].generatedRest = nil
        let withMusic = try placements(music)
        check(withMusic.count == 3 && withMusic[1].generatedRest == nil, "Printed music interrupts the rest chain")
        check(withMusic[1].sourceBandIDs == [music.bands[1].id], "Playing music is never absorbed into a rest")

        let document = PartsmithDocument(project: separate)
        let undo = UndoManager(); undo.groupsByEvent = false; document.undoManager = undo
        undo.beginUndoGrouping()
        check(document.updateBandGeneratedRest(separate.bands[1].id, barCount: 3, joinWithPrevious: true), "Document accepts the layout preference")
        undo.endUndoGrouping()
        check(document.project.bands[1].generatedRest?.joinWithPrevious == true, "Preference stored on its original row")
        undo.undo(); check(document.project == separate, "Undo restores the complete previous project")
        undo.redo(); check(document.project.bands[1].generatedRest?.joinWithPrevious == true, "Redo restores the preference")
        undo.beginUndoGrouping()
        check(document.updateBandGeneratedRestCount(separate.bands[1].id, barCount: 4), "Existing count editor still works")
        undo.endUndoGrouping()
        check(document.project.bands[1].generatedRest?.joinWithPrevious == true, "A count-only edit preserves the layout preference")
        let beforeBad = document.project
        check(!document.updateBandGeneratedRest(separate.bands[1].id, barCount: 1000, joinWithPrevious: false)
              && document.project == beforeBad, "Invalid edits change neither count nor join preference")
        print("\(checks) generated-rest join checks passed")
    }
}
