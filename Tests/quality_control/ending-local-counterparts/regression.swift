import AppKit
import CryptoKit
import Foundation
import PDFKit

@main enum SharedEndingAppTests {
    typealias D = ScoreSharedEndingDetector
    private typealias Support = EndingAppTestSupport
    static var count = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        count += 1
        guard value() else { print("FAIL: \(message)"); exit(1) }
        print("PASS: \(message)")
    }
    static func read<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }
    static var profile: ScoreExtractionProfile { Support.profile }
    static func page(_ index: Int) -> ScorePageAnalysis { Support.manualPage(index) }
    static var glyph: ScoreSharedNavigation {
        .init(anchorStaffID: 0, bounds: [0.75,0.13,0.82,0.16], recognizedText: "", isBelow: false)
    }
    static func candidate(page: Int, system: Int, first: Bool) -> D.Candidate {
        let bounds: [Double] = first ? [480,430,560,442] : [35,136,110,148]
        return D.Candidate(pageIndex: page, systemIndex: system, anchorStaffID: system * 2,
            bounds: bounds, copyBounds: [bounds[0]-2,bounds[1]-2,bounds[2]+2,bounds[3]+2],
            numberBounds: bounds, staffSpace: 4, pageWidth: 600, pageHeight: 800,
            closedRight: first, rightHookBottom: first ? 440 : nil,
            evidence: [.init(mode: "fast", text: first ? "I" : "2.", confidence: 0.5, bounds: [0.1,0.1,0.9,0.9])],
            memberCount: 1)
    }
    static func pair(secondPage: Int = 1) -> D.Pair {
        .init(first: candidate(page: 0, system: 1, first: true), second: candidate(page: secondPage, system: 0, first: false))
    }
    static func observed(_ index: Int, candidates: [D.Candidate] = [], verified: Bool = true) -> D.PageResult {
        .init(pageIndex: index, ownershipVerified: verified, systemIndices: [0,1],
            geometryProposalCount: candidates.count, mergedProposalCount: candidates.count, candidates: candidates)
    }
    static func image(white: Bool) -> CGImage {
        let ctx = CGContext(data: nil, width: 60, height: 80, bitsPerComponent: 8, bytesPerRow: 60,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 80))
        if !white { ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(CGRect(x: 5, y: 5, width: 2, height: 2)) }
        return ctx.makeImage()!
    }
    static func services(_ reports: [Int: D.PageResult]) -> ScoreSharedDirectionServices {
        .init(headings: { _, p, _, _ in page(p.pageIndex).sharedHeadings ?? [] },
            navigation: { _, p, _, _ in page(p.pageIndex).sharedNavigation ?? [] },
            references: { _, p, _, _ in [.init(sourcePageIndex: p.pageIndex, sourceBounds: [0.8,0.39,0.84,0.42], pixels: [0,1])] },
            destinations: { _, p, _, _, _ in
                p.pageIndex == 1 ? ([glyph], [.init(anchorStaffID: 0, bounds: glyph.bounds, correlation: 1,
                    templatePageIndex: 0, templateBounds: [0.8,0.39,0.84,0.42])]) : ([], [])
            }, endings: { _, p, _, _ in reports[p.pageIndex] ?? observed(p.pageIndex) })
    }
    static func run(_ pages: [ScorePageAnalysis], services: ScoreSharedDirectionServices,
                    render: ((ScorePageAnalysis, ScoreDirectionPhase) -> CGImage?)? = nil,
                    cancelled: () -> Bool = { false }) -> ScoreSharedDirectionResult {
        ScoreSharedDirectionWorkflow.analyze(analyses: pages, profile: profile,
            render: render ?? { _,_ in image(white: true) }, services: services, progress: { _ in }, isCancelled: cancelled)
    }

    static func coordinator() throws {
        let pair = pair(), pages = [page(0),page(1)]
        var svc = services([0: observed(0,candidates:[pair.first]),1: observed(1,candidates:[pair.second])])
        var pageCalls: [Int] = [], pairCalls = 0
        let underlying = svc.endings!
        svc.endings = { image, page, profile, cancel in
            pageCalls.append(page.pageIndex); return try underlying(image,page,profile,cancel)
        }
        svc.pairEndings = { results,cancel in
            pairCalls += 1
            check(pageCalls == [0,1] && results.map(\.pageIndex) == [0,1], "All selected ending pages finish before the single score-level pairing pass")
            return D.pairs(in: results,isCancelled: cancel)
        }
        check(ScoreSharedEndingMetadata.make(pairs:[pair],pages:[pages[0]]).isEmpty,
              "Missing second source page rejects the entire pair rather than publishing the first half")
        check(ScoreSharedEndingMetadata.make(pairs:[pair],pages:[pages[1]]).isEmpty,
              "Missing first source page rejects the entire pair rather than publishing the second half")
        let result = run(pages,services:svc)
        check(pairCalls == 1 && result.analyses.allSatisfy { $0.sharedEndings?.count == 1 }, "Cross-page paired ending is published atomically to both pages")
        check(result.analyses[0].sharedEndings![0].pairID == result.analyses[1].sharedEndings![0].pairID,
              "Both halves share stable pair identity")
        check(result.analyses[0].sharedEndings![0].pairPageIndices == [0,1], "Each half retains both source-page dependencies")
        check(result.analyses[0].sharedEndings![0].members[0].evidence[0].text == "I", "Literal uncertain numeral evidence is preserved without retranscription")
        check(result.analyses.allSatisfy { $0.sharedHeadings == page($0.pageIndex).sharedHeadings }, "Ending scan preserves heading metadata")
        check(result.analyses[0].sharedNavigation == page(0).sharedNavigation
              && result.analyses[1].sharedNavigation == (page(1).sharedNavigation! + [glyph]), "Ending scan preserves instructions and destination symbols")
        check(result.references.count == 1 && result.references[0].pageIndex == 1, "Ending scan does not replace destination reference provenance")
        let decoded = try JSONDecoder().decode([ScorePageAnalysis].self,from:JSONEncoder().encode(result.analyses))
        check(decoded == result.analyses, "Ending evidence and linked-source identity survive inventory round-trip")
        check(page(0).sharedEndings == nil, "Legacy inventories and memberwise initializers omit optional ending metadata")
        let legacy = try JSONDecoder().decode(ScorePageAnalysis.self,from:JSONEncoder().encode(page(0)))
        check(legacy.sharedEndings == nil, "Legacy inventory decoding remains valid")

        var noNavigation = services([0: observed(0,candidates:[pair.first]),1: observed(1,candidates:[pair.second])])
        noNavigation.navigation = { _,_,_,_ in [] }
        let withoutReferences = run(pages,services:noNavigation)
        check(withoutReferences.analyses.allSatisfy { $0.sharedEndings?.count == 1 }, "Endings run even when no navigation sentence or symbol template exists")

        let distant = self.pair(secondPage: 2)
        let distantSvc = services([0: observed(0,candidates:[distant.first]),2: observed(2,candidates:[distant.second])])
        let sparse = run([page(0),page(2)],services:distantSvc)
        check(sparse.analyses.allSatisfy { ($0.sharedEndings ?? []).isEmpty }, "Sparse selected pages cannot make unrelated endings adjacent")
        var blank = page(1); blank.staves=[]
        let affirmed = run([page(0),blank,page(2)],services:distantSvc)
        check(affirmed.analyses[0].sharedEndings?.count == 1 && affirmed.analyses[2].sharedEndings?.count == 1,
              "Affirmed white source page preserves musical adjacency")
        let unknown = run([page(0),blank,page(2)],services:distantSvc,render:{ _,_ in image(white:false) })
        check(unknown.analyses.allSatisfy { ($0.sharedEndings ?? []).isEmpty } && unknown.analyses[1].sharedEndings == nil,
              "Unknown staffless page is a barrier, not automatically a verified blank")
        var unresolved = page(1); unresolved.staves.removeLast()
        var roster: [D.PageResult] = []
        var barrierSvc = distantSvc
        barrierSvc.pairEndings = { pages,cancel in roster=pages;return D.pairs(in:pages,isCancelled:cancel) }
        let blocked = run([page(0),unresolved,page(2)],services:barrierSvc)
        check(roster.map(\.pageIndex) == [0,1,2] && !roster[1].ownershipVerified,
              "Unresolved selected page remains in the complete pairing roster")
        check(blocked.analyses.allSatisfy { ($0.sharedEndings ?? []).isEmpty }, "Unresolved intermediate system blocks a false cross-page pair")
        let badRender = run(pages,services:services([0:observed(0,candidates:[pair.first]),1:observed(1,candidates:[pair.second])]),
            render:{ p,phase in p.pageIndex==1 && phase == .endings ? nil : image(white:true) })
        check(badRender.analyses.allSatisfy { ($0.sharedEndings ?? []).isEmpty }
              && badRender.issues.contains { $0.pageIndex==1 && $0.message.contains("render") }, "Ending render failure remains a visible barrier")
        var failedSvc=services([0:observed(0,candidates:[pair.first])])
        failedSvc.endings = { _,p,_,_ in
            if p.pageIndex==1 {throw NSError(domain:"EndingOCRTest",code:1)}
            return observed(0,candidates:[pair.first])
        }
        let failed=run(pages,services:failedSvc)
        check(failed.analyses.allSatisfy { ($0.sharedEndings ?? []).isEmpty }
              && failed.issues.contains { $0.message.contains("failed") }, "OCR failure is distinct from successful zero-ending recognition")
        check(ScoreExtractionPlanner.plan(pages:failed.analyses,profile:profile).canApply, "Optional ending failure adds no acceptance gate")
        for afterPairing in [false,true] {
            var cancelled=false
            var cancelSvc=services([0:observed(0,candidates:[pair.first]),1:observed(1,candidates:[pair.second])])
            if afterPairing {
                cancelSvc.pairEndings = { pages,_ in let values=D.pairs(in:pages);cancelled=true;return values }
            } else {
                cancelSvc.endings = { _,p,_,_ in cancelled=true;return observed(p.pageIndex,candidates:[pair.first]) }
            }
            let stopped=run(pages,services:cancelSvc,cancelled:{cancelled})
            check(stopped.analyses==pages && stopped.issues.isEmpty && stopped.references.isEmpty,
                  "Cancellation \(afterPairing ? "after pairing" : "during recognition") discards all newly produced metadata")
        }
    }

    static func endingPages() -> [ScorePageAnalysis] {
        var pages=[page(0),page(1)]
        let metadata=ScoreSharedEndingMetadata.make(pairs:[pair()],pages:pages)
        for i in pages.indices { pages[i].sharedEndings=metadata[i] }
        pages[1].sharedNavigation!.append(glyph)
        return pages
    }
    static func review(_ source: Data) -> ScoreDetectionReview {
        .initial(profile:profile,analyses:endingPages(),selectedPageIndices:[0,1],sourcePDFData:source,rectifications:[])
    }
    static func recipient(_ review: ScoreDetectionReview,page: Int) -> ScorePlannedBand {
        review.plan.bands.first { $0.pageIndex==page && $0.systemIndex==(page==0 ? 1:0) && $0.partID=="cello" }!
    }
    static func endingMark(_ review: ScoreDetectionReview,page: Int) -> ScoreSourceMarking {
        review.analyses.first { $0.pageIndex==page }!.sharedEndings![0].sourceMarking
    }
    static func reassign(_ review: inout ScoreDetectionReview,page: Int) {
        let analysis=review.analyses.first { $0.pageIndex==page }!,plan=review.plan.pages.first { $0.pageIndex==page }!
        var correction=ScoreSystemAssignment.pageOverride(page:analysis,pagePlan:plan,
            existingOverride:review.overrides.first { $0.pageIndex==page })
        let system=page==0 ? 1:0
        correction.systems[system].bands[0].partID="cello"
        correction.systems[system].bands[1].partID="violin"
        review.overrides.removeAll { $0.pageIndex==page };review.overrides.append(correction);review.replan()
    }
    static func reviews(_ source: Data) throws {
        var value=review(source)
        check(value.plan.canApply && value.plan.bands.count==8,"Paired-ending review retains the complete ordinary crop plan")
        for page in [0,1] {
            let mark=endingMark(value,page:page),band=recipient(value,page:page)
            check(band.sourceMarkings.contains(mark),"Recipient receives the source-pixel ending on page\(page)")
            let owner=value.plan.bands.first { $0.pageIndex==page && $0.systemIndex==(page==0 ? 1:0) && $0.partID=="violin" }!
            check(!owner.sourceMarkings.contains(mark) && owner.topFraction<=mark.topFraction,
                  "Source owner keeps original ending in its crop without duplicate row")
        }
        let mark=endingMark(value,page:0),band=recipient(value,page:0)
        try value.removeSourceMarking(from:band.id,at:band.sourceMarkings.firstIndex(of:mark)!)
        try value.resetCropEdges(for:band.id);value.replan()
        check(!recipient(value,page:0).sourceMarkings.contains(mark),"Explicit ending-copy removal survives reset and replan")
        check(recipient(value,page:1).sourceMarkings.contains(endingMark(value,page:1)),"Removing one recipient copy does not erase the pair's other source page")
        let encodedOverrides=try JSONEncoder().encode(value.overrides)
        let encodedPages=try JSONEncoder().encode(value.analyses)
        let restored=ScoreDetectionReview.initial(profile:profile,
            analyses:try JSONDecoder().decode([ScorePageAnalysis].self,from:encodedPages),
            overrides:try JSONDecoder().decode([ScorePageOverride].self,from:encodedOverrides),
            sourcePDFData:source,rectifications:[])
        check(!recipient(restored,page:0).sourceMarkings.contains(mark),"Saved review cannot silently restore a removed ending copy")
        let doc=Support.document(source),undo=UndoManager();undo.groupsByEvent=false;doc.undoManager=undo
        let original=doc.project
        undo.beginUndoGrouping();let added=doc.addScoreParts(from:value);undo.endUndoGrouping()
        check(added==8,"Ending removal preserves Add Parts availability")
        let saved=try JSONDecoder().decode(ProjectData.self,from:JSONEncoder().encode(doc.project))
        undo.undo();check(doc.project==original,"Paired ending apply is one undoable edit")
        undo.redo();check(doc.project.bands.map(\.sourceMarkings)==saved.bands.map(\.sourceMarkings),"Redo preserves exact source pixels and removed-copy choice")

        for changedPage in [0,1] {
            var edited=review(source)
            let otherPage=1-changedPage,oldOther=edited.analyses[otherPage],removed=endingMark(edited,page:otherPage)
            let keepBand=recipient(edited,page:otherPage)
            try edited.setCropEdges(for:keepBand.id,top:keepBand.topFraction*800,bottom:keepBand.bottomFraction*800)
            let oi=edited.overrides.firstIndex { $0.pageIndex==otherPage }!,si=otherPage==0 ? 1:0
            let bi=edited.overrides[oi].systems[si].bands.firstIndex { $0.partID=="cello" }!
            let manual=[5.0,10,15,20]
            edited.overrides[oi].systems[si].bands[bi].sourceMarkings!.append(manual)
            var sides=edited.overrides[oi].systems[si].bands[bi].sourceMarkingsBelow
                ?? Array(repeating:false,count:edited.overrides[oi].systems[si].bands[bi].sourceMarkings!.count-1)
            sides.append(false);edited.overrides[oi].systems[si].bands[bi].sourceMarkingsBelow=sides
            reassign(&edited,page:changedPage)
            check(edited.analyses.allSatisfy { ($0.sharedEndings ?? []).isEmpty },"Reassigning either endpoint invalidates both halves")
            check(edited.analyses[otherPage].sharedHeadings==oldOther.sharedHeadings
                  && edited.analyses[otherPage].sharedNavigation==oldOther.sharedNavigation,
                  "Linked invalidation preserves the other page's independent direction categories")
            let after=recipient(edited,page:otherPage)
            check(!after.sourceMarkings.contains(removed),"Materialized partner override loses its stale automatic ending only")
            check(after.sourceMarkings.contains { $0.leftFraction*600==manual[0] && $0.topFraction*800==manual[1] },
                  "Distinct manual source rectangle on partner page survives linked invalidation")
            let beforeOther=keepBand.sourceMarkings.filter { $0 != removed }
            check(beforeOther.allSatisfy(after.sourceMarkings.contains),"Other automatic partner copies are preserved")
            check(edited.plan.canApply,"Linked invalidation adds optional information, not an acceptance gate")
        }
        var explicit=review(source)
        let endpoint=recipient(explicit,page:1),ending=endingMark(explicit,page:1)
        let manualOverride=ScoreSystemAssignment.pageOverride(page:explicit.analyses[1],pagePlan:explicit.plan.pages[1],existingOverride:nil)
        explicit = .initial(profile:profile,analyses:explicit.analyses,overrides:[manualOverride],sourcePDFData:source,rectifications:[])
        reassign(&explicit,page:0)
        check(explicit.plan.bands.first { $0.id==endpoint.id }!.sourceMarkings.contains(ending),
              "An initially authoritative manual ending rectangle remains manual even if identical to recognized pixels")
        let stalePage=endingPages()[0]
        var plainPage=stalePage;plainPage.sharedEndings=nil
        let plain=ScoreExtractionPlanner.plan(pages:[plainPage],profile:profile)
        var regrouped=ScoreSystemAssignment.pageOverride(page:plainPage,pagePlan:plain.pages[0],existingOverride:nil)
        let originalFirst=regrouped.systems[0].bands
        regrouped.systems[0].bands=regrouped.systems[1].bands
        regrouped.systems[1].bands=originalFirst
        for si in regrouped.systems.indices {
            for bi in regrouped.systems[si].bands.indices {
                regrouped.systems[si].bands[bi].rect=nil
                regrouped.systems[si].bands[bi].sourceMarkings=nil
                regrouped.systems[si].bands[bi].sourceMarkingsBelow=nil
            }
        }
        let stalePlan=ScoreExtractionPlanner.plan(pages:[stalePage],profile:profile,overrides:[regrouped])
        let staleMark=stalePage.sharedEndings![0].sourceMarking
        check(stalePlan.canApply && stalePlan.bands.first { $0.candidateIDs.contains(2) }?.systemIndex==0,
              "Initial override genuinely reassigns the ending anchor to a different valid system")
        check(stalePlan.bands.allSatisfy { !$0.sourceMarkings.contains(staleMark) },
              "Initial regrouping cannot copy stale recognized ending pixels into the newly assigned system")
        check(stalePlan.bands.flatMap(\.warnings).contains { $0.contains("Paired ending needs a new scan") },
              "Stale initial ending ownership is reported without blocking ordinary crop acceptance")
        var chainPages=[page(0),page(1),page(2)]
        let unrelated=D.Pair(first:candidate(page:1,system:1,first:true),second:candidate(page:2,system:0,first:false))
        let chainMetadata=ScoreSharedEndingMetadata.make(pairs:[pair(),unrelated],pages:chainPages)
        for i in chainPages.indices { chainPages[i].sharedEndings=chainMetadata[i] }
        chainPages[1].sharedNavigation!.append(glyph)
        let reference=ScoreDirectionReference(pageIndex:1,match:.init(anchorStaffID:0,bounds:glyph.bounds,
            correlation:1,templatePageIndex:0,templateBounds:[0.8,0.39,0.84,0.42]))
        var chain=ScoreDetectionReview.initial(profile:profile,analyses:chainPages,sourcePDFData:source,
            rectifications:[],directionReferences:[reference])
        let preservedID=chain.analyses[2].sharedEndings![0].pairID
        reassign(&chain,page:0)
        check(chain.analyses[1].sharedEndings?.map(\.pairID)==[preservedID]
              && chain.analyses[2].sharedEndings?.map(\.pairID)==[preservedID],
              "A different ending pair sharing the partner page is not invalidated transitively")
        check(chain.directionReferences.count==1 && chain.directionReferences[0].pageIndex==1
              && chain.directionReferences[0].match.templatePageIndex==0,
              "Linked ending invalidation preserves partner destination-reference provenance")
        var cropOnly=review(source);let target=recipient(cropOnly,page:0)
        try cropOnly.setCropEdges(for:target.id,top:target.topFraction*800-1,bottom:target.bottomFraction*800)
        check(cropOnly.analyses.allSatisfy { $0.sharedEndings?.count==1 },"Crop-only editing preserves linked ending ownership")
    }

    struct Frozen: Decodable {var pages:[D.PageResult];var pairs:[D.Pair]}
    struct Inventory: Decodable {var pages:[ScorePageAnalysis]; var source:String; var sourceSHA256:String; var rectifications:[PageRectification]?}
    struct CorpusBinding: Decodable { var path: String; var sha256: String }
    static func frozenReplay() throws {
        let bindings=try read([CorpusBinding].self,"Tests/quality_control/ending-app-integration/corpus-inputs.json")
        for binding in bindings {
            let data=try Data(contentsOf:URL(fileURLWithPath:binding.path))
            let digest=SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
            guard digest==binding.sha256 else {
                throw NSError(domain:"EndingCorpusBinding",code:1,
                    userInfo:[NSLocalizedDescriptionKey:"Frozen input changed: \(binding.path)"])
            }
        }
        print("Frozen corpus input hashes verified")
        var totalPages=0,totalPairs=0
        for (name,inventoryPath,profilePath) in [
            ("brahms",".build/qc-brahms-traced-ending-combination/inventory.json","Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json"),
            ("kv498",".build/qc-algorithm-audit/heading-dedup/kv498-native-inventory.json","Tests/quality_control/profiles/normal-mozart-trio-eb-major-kv498-score.json")
        ] {
            let frozen=try read(Frozen.self,"Tests/quality_control/native-ending-brackets-v1/\(name)-native-final.json")
            let inventory=try read(Inventory.self,inventoryPath)
            var pages=inventory.pages
            let scoreProfile=try read(ScoreExtractionProfile.self,profilePath)
            let pairs=D.pairs(in:frozen.pages);totalPages+=frozen.pages.count;totalPairs+=pairs.count
            let endingMetadata=ScoreSharedEndingMetadata.make(pairs:pairs,pages:pages)
            // Compatibility-only ending entries are removed by exact geometry;
            // the independent destination glyph and navigation sentence remain.
            for i in pages.indices {
                let endings=endingMetadata[pages[i].pageIndex] ?? []
                pages[i].sharedNavigation = (pages[i].sharedNavigation ?? []).filter { n in
                    !endings.contains { e in e.anchorStaffID==n.anchorStaffID && n.recognizedText.isEmpty
                        && zip(e.bounds,n.bounds).allSatisfy { abs($0-$1)<1e-8 } }
                }
                pages[i].sharedEndings=endings
            }
            let source=try Data(contentsOf:URL(fileURLWithPath:inventory.source))
            let plan=ScoreDetectionReview.initial(profile:scoreProfile,analyses:pages,
                sourcePDFData:source,rectifications:inventory.rectifications ?? []).plan
            check(plan.canApply,"\(name) distinct ending metadata produces a complete plan")
            check(plan.bands.count==(name=="brahms" ? 604:405),"\(name) all source systems remain assigned")
            check(plan.bands.reduce(0) { $0+$1.sourceMarkings.count }==(name=="brahms" ? 42:10),"\(name) full source-copy count retained")
            let ownerOriginals=pages.flatMap { $0.sharedEndings ?? [] }.count
            check(ownerOriginals==(name=="brahms" ? 5:1),"Same-system first/second bounds combine into the reviewed source rows")
            if name=="brahms" {
                let approved=try read(ScoreExtractionPlan.self,"output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-traced-lines/plan.json")
                check(plan.bands==approved.bands,"All604 approved Brahms crops,42copies,staff identities/order match exactly after distinct-category migration")
                check(pages.reduce(0) { $0+($1.sharedNavigation?.count ?? 0) }==2,
                      "Da Capo instruction and destination glyph remain navigation; endings are separate")
            }
            let expected=URL(fileURLWithPath:".build/shared-ending-app-tests/expected-plans",isDirectory:true)
            try FileManager.default.createDirectory(at:expected,withIntermediateDirectories:true)
            let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
            try encoder.encode(plan).write(to:expected.appendingPathComponent("\(name).json"))
        }
        check(totalPages==68 && totalPairs==5,"Entire frozen68-page ending evidence replayed without fresh Vision calls")
    }
    static func main() throws {
        try LocalCounterpartTests.run()
        let arguments=Array(CommandLine.arguments.dropFirst())
        guard arguments.isEmpty || arguments == ["--corpus"] else {
            fputs("Use test_shared_ending_app [--corpus]\n",stderr);exit(2)
        }
        try coordinator()
        try reviews(Support.sourcePDF())
        if arguments == ["--corpus"] { try frozenReplay() }
        Support.workerLifecycle(Support.sourcePDF())
        print("\(Support.checks) worker and ending-phase cancellation checks passed")
        print("\(count) ending Auto integration checks passed")
    }
}

// Self-contained deterministic score/worker fixtures. Recognition services are
// injected for failure and cancellation controls; source PDF rendering and the
// document staff-analysis worker still execute normally.
private enum EndingAppTestSupport {
    static var checks = 0
    static let checkLock = NSLock()
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checkLock.lock(); checks += 1; checkLock.unlock()
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1)
        }
    }
    static func wait(_ done: () -> Bool) {
        let deadline = Date().addingTimeInterval(30)
        while !done(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(done(), "Deterministic worker reaches its expected event before timeout")
    }
    static var profile: ScoreExtractionProfile {
        .init(parts: [.init(id: "violin", name: "Violin", staffCount: 1),
                      .init(id: "cello", name: "Cello", staffCount: 1)], cropMode: "compact")
    }
    static func sourcePDF() -> Data {
        let data = NSMutableData(); var media = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        for page in 0..<5 {
            context.beginPDFPage(nil); context.setFillColor(gray: 1, alpha: 1); context.fill(media)
            context.setStrokeColor(gray: 0, alpha: 1); context.setFillColor(gray: 0, alpha: 1)
            context.setLineWidth(0.7)
            for top in [100.0, 180, 430, 510] {
                for line in 0..<5 {
                    let y = 800 - top - Double(line) * 6
                    context.move(to: CGPoint(x: 55, y: y)); context.addLine(to: CGPoint(x: 555, y: y))
                }
                context.strokePath()
                context.fillEllipse(in: CGRect(x: 100 + Double(page), y: 800 - top - 14, width: 8, height: 5))
            }
            context.endPDFPage()
        }
        context.closePDF(); return data as Data
    }
    static func document(_ source: Data) -> PartsmithDocument {
        var project = ProjectData.empty; project.pageCount = 5; project.sourceFilename = "direction-worker-fixture.pdf"
        return PartsmithDocument(project: project, sourcePDFData: source)
    }
    static func manualPage(_ index: Int) -> ScorePageAnalysis {
        let tops = [0.20, 0.32, 0.60, 0.72]
        return .init(pageIndex: index, pageWidth: 600, pageHeight: 800, imageWidth: 1800, imageHeight: 2400,
            staves: tops.enumerated().map { item in
                ScoreObservedStaff(StaffBandCandidate(id: item.offset,
                    staffLineFractions: (0..<5).map { item.element + Double($0) * 0.006 },
                    topFraction: item.element - 0.02, bottomFraction: item.element + 0.05,
                    confidence: 1, warnings: []))
            }, warnings: [], sharedHeadings: [.init(anchorStaffID: 0, bounds: [0.2, 0.13, 0.4, 0.17], recognizedText: "Andante")],
            sharedNavigation: [.init(anchorStaffID: 1, bounds: [0.45, 0.355, 0.8, 0.39], recognizedText: "Da Capo", isBelow: true)])
    }
    final class Gate {
        private let lock = NSLock()
        private var didEnter = false
        private var cancelled = false
        let release = DispatchSemaphore(value: 0)
        func enter() { lock.lock(); didEnter = true; lock.unlock() }
        var entered: Bool { lock.lock(); defer { lock.unlock() }; return didEnter }
        func sawCancellation(_ value: Bool) { lock.lock(); cancelled = value; lock.unlock() }
        var cancellationObserved: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    }

    static func workerLifecycle(_ source: Data) {
        let baseline = document(source); var baselineDone = false; var baseReview: ScoreDetectionReview?
        var disabledCalls = 0
        let trap: ScoreSharedDirectionRunner = { _, pages, _, _, _, _ in
            disabledCalls += 1; return .init(analyses: pages, issues: [])
        }
        baseline.detectScore(profile: profile, pageIndices: [1,3], copySharedDirections: false, directionRunner: trap) {
            baseReview = $0; baselineDone = true
        }
        wait { baselineDone }
        check(disabledCalls == 0 && baseReview?.plan.canApply == true, "Opt-out makes no direction calls and preserves valid staff extraction")
        check(baseReview?.analyses.map(\.pageIndex) == [1,3], "Sparse input selection retains absolute source page indices")

        let selected = document(source); let original = selected.project
        var selectedDone = false; var selectedReview: ScoreDetectionReview?; var workerWasBackground = false
        let injected: ScoreSharedDirectionRunner = { pdf, pages, supplied, corrections, progress, isCancelled in
            workerWasBackground = !Thread.isMainThread
            check(pdf.pageCount == 5 && pages.map(\.pageIndex) == [1,3], "Runner receives a worker-owned source and only selected analyses")
            check(supplied == profile && corrections.isEmpty && !isCancelled(), "Runner captures the selected fixed profile and correction snapshot")
            progress(.init(phase: .headings, completedPages: 1, totalPages: 2))
            return .init(analyses: pages, issues: [.init(pageIndex: 3, message: "Injected optional OCR failure")])
        }
        selected.detectScore(profile: profile, pageIndices: [1,3], copySharedDirections: true, directionRunner: injected) {
            check(Thread.isMainThread, "Review completion publishes on the main thread")
            selectedReview = $0; selectedDone = true
        }
        wait { selectedDone }
        check(workerWasBackground, "Direction recognition executes off the main thread")
        check(selectedReview?.plan == baseReview?.plan, "Optional recognition failure retains the exact base staff/crop plan")
        check(selectedReview?.directionIssues.contains { $0.pageIndex == 3 && $0.message.contains("optional OCR failure") } == true,
              "Runtime failure is visible and distinct from a successful zero-match scan")
        check(selectedReview?.plan.canApply == true && selected.project == original && selected.scoreDetectionProgress == nil,
              "Failure adds no acceptance barrier, implicit document mutation or stuck progress")

        for phase: ScoreDirectionPhase in [.endings] {
            let doc = document(source), gate = Gate()
            var oldCompletions = 0; var newDone = false; var newReview: ScoreDetectionReview?
            let blocked: ScoreSharedDirectionRunner = { _, pages, _, _, progress, cancelled in
                progress(.init(phase: phase, completedPages: 0, totalPages: pages.count)); gate.enter()
                _ = gate.release.wait(timeout: .now() + 20)
                gate.sawCancellation(cancelled())
                progress(.init(phase: .destinations, completedPages: 999, totalPages: 999))
                return .init(analyses: pages, issues: [.init(pageIndex: -1, message: "STALE-RUN")])
            }
            doc.detectScore(profile: profile, pageIndices: [1], copySharedDirections: true, directionRunner: blocked) { _ in oldCompletions += 1 }
            wait { gate.entered }
            wait { doc.scoreDetectionProgress?.directionPhase == phase }
            doc.cancelScoreDetection()
            check(doc.scoreDetectionProgress == nil, "Cancellation immediately clears direction-phase progress")
            doc.detectScore(profile: profile, pageIndices: [3], copySharedDirections: false, directionRunner: trap) {
                newReview = $0; newDone = true
            }
            gate.release.signal(); wait { newDone }
            check(gate.cancellationObserved, "Every worker phase receives cooperative cancellation")
            check(oldCompletions == 0 && newReview?.analyses.map(\.pageIndex) == [3], "Canceled results cannot replace a subsequent run")
            check(newReview?.directionIssues.isEmpty == true && doc.scoreDetectionProgress == nil,
                  "Late canceled progress and warnings cannot leak into the replacement review")
            check(doc.project.parts.isEmpty && doc.project.bands.isEmpty, "Canceled preview recognition never applies partial output")
        }
        for changeGeometry in [false, true] {
            let doc = document(source), gate = Gate(); var done = false; var result: ScoreDetectionReview?
            let blocked: ScoreSharedDirectionRunner = { _, pages, _, _, _, _ in
                gate.enter(); _ = gate.release.wait(timeout: .now() + 20)
                return .init(analyses: pages, issues: [])
            }
            doc.detectScore(profile: profile, pageIndices: [1], copySharedDirections: true, directionRunner: blocked) { result = $0; done = true }
            wait { gate.entered }
            if changeGeometry { doc.updatePageRectification(.default(pageIndex: 1)) }
            else { doc.sourcePDFData = source + Data([0x20]) }
            gate.release.signal(); wait { done }
            check(result == nil && doc.scoreDetectionProgress == nil, "Source or correction changes reject stale direction review")
            check(doc.project.bands.isEmpty, "Stale direction results never mutate parts")
        }
    }
}
