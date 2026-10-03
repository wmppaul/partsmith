import CoreGraphics
import Foundation

/// No sample files, cached OCR or scratch checkout are required by these tests.
enum LocalEndingControls {
    typealias D = ScoreSharedEndingDetector
    typealias L = ScoreLocalEndingPreservation
    static var checks = 0
    static func check(_ value: Bool, _ name: String) throws {
        guard value else { throw NSError(domain: "LocalEndingControls", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
        checks += 1
    }
    static let profile = ScoreExtractionProfile(parts: [
        .init(id: "violin", name: "Violin", staffCount: 1), .init(id: "cello", name: "Cello", staffCount: 1)
    ], cropMode: "compact")
    static func page(_ index: Int) -> ScorePageAnalysis {
        .init(pageIndex: index, pageWidth: 600, pageHeight: 800, imageWidth: 1800, imageHeight: 2400,
            staves: [0.20, 0.32, 0.60, 0.72].enumerated().map { i, top in
                ScoreObservedStaff(StaffBandCandidate(id: i,
                    staffLineFractions: (0..<5).map { top + Double($0)*0.006 },
                    topFraction: top-0.02, bottomFraction: top+0.05, confidence: 1, warnings: []))
            }, warnings: [])
    }
    static func candidate(page: Int = 0, system: Int = 0, first: Bool, local: Bool = false,
                          split: Bool = false) -> D.Candidate {
        let x: [Double] = split ? (first ? [480,560] : [35,110]) : (first ? [300,380] : [380,450])
        let top = Double(system)*320 + (local ? 236.0 : 140.0)
        let b = [x[0],top,x[1],top+12]
        return .init(pageIndex: page, systemIndex: system, anchorStaffID: system*2 + (local ? 1 : 0),
            bounds: b, copyBounds: [b[0]-1,b[1]-1,b[2]+1,b[3]+1], numberBounds: b,
            staffSpace: 4.8, pageWidth: 600, pageHeight: 800, closedRight: first,
            rightHookBottom: first ? top+10 : nil,
            evidence: [.init(mode: "fast", text: first ? "I" : "2.", confidence: 0.9, bounds: [0.1,0.1,0.9,0.9])], memberCount: 1)
    }
    static func observed(_ index: Int, _ candidates: [D.Candidate]) -> D.PageResult {
        .init(pageIndex: index, ownershipVerified: true, systemIndices: [0,1], geometryProposalCount: candidates.count,
            mergedProposalCount: candidates.count, candidates: candidates)
    }
    static func annotated(_ pages: [ScorePageAnalysis], pair: D.Pair) -> [ScorePageAnalysis] {
        let metadata = ScoreSharedEndingMetadata.make(pairs: [pair], pages: pages)
        return pages.map { p in var copy=p;copy.sharedEndings=metadata[p.pageIndex] ?? [];return copy }
    }
    static func attach(_ cp: ScoreEndingLocalCounterpart, to pages: [ScorePageAnalysis]) -> [ScorePageAnalysis] {
        pages.map { p in var copy=p
            copy.sharedEndings=copy.sharedEndings?.map { e in var value=e;value.localCounterparts=e.members==cp.globalMembers ? [cp] : nil;return value }
            return copy
        }
    }
    static func count(_ plan: ScoreExtractionPlan) -> Int { plan.bands.reduce(0) { $0+$1.sourceMarkings.count } }
    static func image() -> CGImage {
        let c=CGContext(data:nil,width:60,height:80,bitsPerComponent:8,bytesPerRow:60,
            space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
        c.setFillColor(gray:1,alpha:1);c.fill(CGRect(x:0,y:0,width:60,height:80));return c.makeImage()!
    }
    static func services(pair: D.Pair, local: [Int:D.PageResult]) -> ScoreSharedDirectionServices {
        .init(headings:{_,_,_,_ in []},navigation:{_,_,_,_ in []},references:{_,_,_,_ in []},destinations:{_,_,_,_,_ in ([],[])},
            endings:{_,p,_,_ in observed(p.pageIndex,[pair.first,pair.second].filter{$0.pageIndex==p.pageIndex})},
            localEndings:{_,p,_,_,_,_,_ in local[p.pageIndex] ?? observed(p.pageIndex,[])})
    }
    static func run() throws {
        let pair=D.Pair(first:candidate(first:true),second:candidate(first:false))
        let local=observed(0,[candidate(first:true,local:true),candidate(first:false,local:true)])
        let pages=annotated([page(0)],pair:pair), base=ScoreExtractionPlanner.plan(pages:pages,profile:profile)
        guard let cp=L.counterpart(global:pair,partID:"cello",localPages:[local],pages:pages,plan:base) else {
            throw NSError(domain:"LocalEndingControls",code:2,userInfo:[NSLocalizedDescriptionKey:"Synthetic complete counterpart must be accepted"])
        }
        let withLocal=attach(cp,to:pages), after=ScoreExtractionPlanner.plan(pages:withLocal,profile:profile)
        try check(count(base)==1 && count(after)==0,"complete own-staff pair suppresses exactly one shared row")
        for (a,b) in zip(base.bands,after.bands) {var unchanged=a;unchanged.sourceMarkings=b.sourceMarkings;try check(unchanged==b,"main crops and unrelated band fields retained")}
        for bad in 0..<7 {
            var changed=cp
            switch bad {
            case 0:changed.partID="violin"
            case 1:changed.members[0].anchorStaffID=0
            case 2:changed.members[0].sourcePageIndex=1
            case 3:changed.members[0].sourceSystemIndex=1
            case 4:changed.members[0].bounds[0]+=0.03;changed.members[0].bounds[2]+=0.03
            case 5:changed.members[0].bounds[2]-=0.03
            default:changed.members.removeLast()
            }
            try check(!L.retained(changed,pages:pages,plan:base),"wrong part, staff, page, system, endpoints or incomplete pair rejected: \(bad)")
        }
        var ambiguous=local;ambiguous.candidates+=local.candidates
        try check(L.counterpart(global:pair,partID:"cello",localPages:[ambiguous],pages:pages,plan:base)==nil,"ambiguous local pair leaves shared copy")
        var incomplete=local;incomplete.candidates.removeLast()
        try check(L.counterpart(global:pair,partID:"cello",localPages:[incomplete],pages:pages,plan:base)==nil,"missing second local bracket leaves shared copy")
        var unverified=local;unverified.ownershipVerified=false
        try check(L.counterpart(global:pair,partID:"cello",localPages:[unverified],pages:pages,plan:base)==nil,"unknown ownership cannot suppress copy")
        try check(L.counterpart(global:pair,partID:"cello",localPages:[],pages:pages,plan:base)==nil,"missing page cannot suppress copy")
        let recipient=base.bands.first{$0.partID=="cello" && $0.systemIndex==0}!
        for bad in 0..<3 {
            var malformed=pages[0]
            if bad==0 {malformed.staves[1].staffLineFractions=[]}
            else if bad==1 {malformed.staves[1].staffLineFractions[0] = .nan}
            else {malformed.staves[1].staffLineFractions.reverse()}
            try check(L.firstStaff(of:recipient,on:malformed)==nil,"invalid staff-line arrays reject before indexing: \(bad)")
        }
        var live=ScoreDetectionReview.initial(profile:profile,analyses:withLocal,sourcePDFData:Data(),rectifications:[])
        var edit=ScoreSystemAssignment.pageOverride(page:withLocal[0],pagePlan:live.plan.pages[0],existingOverride:nil)
        let ei=edit.systems[0].bands.firstIndex{$0.partID=="cello"}!
        try check(edit.systems[0].bands[ei].automaticLocalEndingPairIDs?.count==1,"UI crop materialization preserves automatic provenance")
        edit.systems[0].bands[ei].rect![1]=(cp.members[0].bounds[1]+0.001)*800
        live.overrides=[edit];live.replan()
        try check(live.plan.canApply && count(live.plan)==1,"actual review crop edit restores clipped ending")
        try live.removeSourceMarking(from:recipient.id,at:0);live.replan()
        try check(count(live.plan)==0,"explicit Remove Copy persists through replan")
        live.overrides[0].systems[0].bands[ei].rect![1]=recipient.topFraction*800;live.replan()
        live.overrides[0].systems[0].bands[ei].rect![1]=(cp.members[0].bounds[1]+0.001)*800;live.replan()
        try check(count(live.plan)==0,"manual removal persists through later crop changes")
        var directed=withLocal
        directed[0].sharedHeadings=[.init(anchorStaffID:0,bounds:[0.1,0.14,0.2,0.17],recognizedText:"Andante")]
        var reassignment=ScoreDetectionReview.initial(profile:profile,analyses:directed,sourcePDFData:Data(),rectifications:[])
        var cropped=ScoreSystemAssignment.pageOverride(page:directed[0],pagePlan:reassignment.plan.pages[0],existingOverride:nil)
        cropped.systems[0].bands[ei].rect![1]=(cp.members[0].bounds[1]+0.001)*800
        reassignment.overrides=[cropped];reassignment.replan()
        let restored=reassignment.plan.bands.first{$0.id==recipient.id}!
        let unrelated=restored.sourceMarkings.firstIndex{$0.leftFraction==0.1}!
        try reassignment.removeSourceMarking(from:recipient.id,at:unrelated)
        try check(reassignment.plan.bands.first{$0.id==recipient.id}!.sourceMarkings.count==1,
                  "removing unrelated heading materializes the restored automatic ending")
        var cueChange=reassignment
        cueChange.overrides[0].systems[0].bands[ei].kind="cue"
        cueChange.overrides[0].systems[0].bands[ei].label="Reviewed cue"
        cueChange.replan()
        try check(cueChange.analyses[0].sharedEndings==nil && !cueChange.plan.bands.flatMap(\.sourceMarkings).contains(pages[0].sharedEndings![0].sourceMarking),
                  "music-to-cue invalidation removes an automatic ending materialized by an unrelated edit")
        let vi=reassignment.overrides[0].systems[0].bands.firstIndex{$0.partID=="violin"}!
        reassignment.overrides[0].systems[0].bands[vi].candidateIDs=[1]
        reassignment.overrides[0].systems[0].bands[ei].candidateIDs=[0]
        reassignment.overrides[0].systems[0].bands[vi].rect=nil
        reassignment.overrides[0].systems[0].bands[ei].rect=nil
        reassignment.replan()
        try check(reassignment.analyses[0].sharedEndings==nil && !reassignment.plan.bands.flatMap(\.sourceMarkings).contains(pages[0].sharedEndings![0].sourceMarking),
                  "reassignment removes a restored automatic copy materialized by an unrelated edit")
        var manual=edit;manual.systems[0].bands[ei].automaticLocalEndingPairIDs=nil
        try check(count(ScoreExtractionPlanner.plan(pages:withLocal,profile:profile,overrides:[manual]))==0,"initial explicit empty marking list stays authoritative")
        try check(L.apply(to:base,pages:withLocal,overrides:[],isCancelled:{true})==base,"suppression cancellation returns original plan")
        let encoded=try JSONEncoder().encode(withLocal)
        try check(try JSONDecoder().decode([ScorePageAnalysis].self,from:encoded)==withLocal,"counterpart provenance round-trips")
        let legacy=try JSONDecoder().decode(ScoreBandOverride.self,from:Data("{\"partID\":\"cello\",\"sourceMarkings\":[]}".utf8))
        try check(legacy.automaticLocalEndingPairIDs==nil,"legacy explicit override decodes without automatic marker")
        let decodedEdit=try JSONDecoder().decode(ScorePageOverride.self,from:JSONEncoder().encode(edit))
        try check(decodedEdit==edit && decodedEdit.systems[0].bands[ei].automaticLocalEndingPairIDs?.count==1,
                  "automatic crop-edit provenance survives override serialization")
        // Same-page, different-system pair: both matching page-local metadata
        // entries must exist. The other system's entry is not a substitute.
        let split=D.Pair(first:candidate(first:true,split:true),second:candidate(system:1,first:false,split:true))
        let splitLocal=observed(0,[candidate(first:true,local:true,split:true),candidate(system:1,first:false,local:true,split:true)])
        let splitPages=annotated([page(0)],pair:split), splitPlan=ScoreExtractionPlanner.plan(pages:splitPages,profile:profile)
        let splitCP=L.counterpart(global:split,partID:"cello",localPages:[splitLocal],pages:splitPages,plan:splitPlan)!
        let complete=attach(splitCP,to:splitPages)
        try check(count(L.apply(to:splitPlan,pages:complete,overrides:[]))==0,"two-system local pair suppresses both shared rows")
        for system in [0,1] {
            var missing=complete;missing[0].sharedEndings!.removeAll{$0.systemIndex==system}
            try check(L.apply(to:splitPlan,pages:missing,overrides:[])==splitPlan,"missing corresponding same-page member prevents suppression: \(system)")
        }
        // Equivalent ownership and crop checks apply when members cross pages.
        let cross=D.Pair(first:candidate(system:1,first:true,split:true),second:candidate(page:1,first:false,split:true))
        let crossPages=annotated([page(0),page(1)],pair:cross), crossPlan=ScoreExtractionPlanner.plan(pages:crossPages,profile:profile)
        let crossLocals=[observed(0,[candidate(system:1,first:true,local:true,split:true)]),observed(1,[candidate(page:1,first:false,local:true,split:true)])]
        let crossCP=L.counterpart(global:cross,partID:"cello",localPages:crossLocals,pages:crossPages,plan:crossPlan)!
        let crossAttached=attach(crossCP,to:crossPages)
        try check(count(L.apply(to:crossPlan,pages:crossAttached,overrides:[]))==0,"complete cross-page pair suppresses both copies")
        try check(L.apply(to:crossPlan,pages:[crossAttached[0]],overrides:[])==crossPlan,"missing partner page preserves both copies")
        var clipped=crossPlan;let ci=clipped.pages[1].assignments.firstIndex{$0.partID=="cello" && $0.systemIndex==0}!
        clipped.pages[1].assignments[ci].topFraction=crossCP.members[1].bounds[1]+0.001
        try check(L.apply(to:clipped,pages:crossAttached,overrides:[])==clipped,"partner crop change preserves both copies")
        for heading in [false,true] {
            var coincident=crossAttached
            let partner=coincident[1].sharedEndings![0]
            if heading {
                coincident[1].sharedHeadings=[.init(anchorStaffID:partner.anchorStaffID,bounds:partner.bounds,recognizedText:"Andante")]
            } else {
                coincident[1].sharedNavigation=[.init(anchorStaffID:partner.anchorStaffID,bounds:partner.bounds,recognizedText:"",isBelow:false)]
            }
            var linked=ScoreDetectionReview.initial(profile:profile,analyses:coincident,sourcePDFData:Data(),rectifications:[])
            let partnerPlan=linked.plan.pages.first{$0.pageIndex==1}!
            linked.overrides=[ScoreSystemAssignment.pageOverride(page:coincident[1],pagePlan:partnerPlan,existingOverride:nil)]
            linked.replan()
            linked.invalidateAutomaticDirections(on:0)
            let band=linked.plan.bands.first{$0.pageIndex==1 && $0.systemIndex==0 && $0.partID=="cello"}!
            try check(linked.analyses[1].sharedEndings==nil && band.sourceMarkings.contains(partner.sourceMarking),
                      "linked ending-only cleanup preserves coincident \(heading ? "heading" : "navigation/destination") copy")
            try check(heading ? linked.analyses[1].sharedHeadings==coincident[1].sharedHeadings : linked.analyses[1].sharedNavigation==coincident[1].sharedNavigation,
                      "linked cleanup preserves independent direction metadata")
        }
        try coordinator(pair:pair,local:local)
        print("\(checks) self-contained local-ending controls passed")
    }
    static func coordinator(pair:D.Pair,local:D.PageResult) throws {
        let input=[page(0),page(1),page(2)], svc=services(pair:pair,local:[0:local])
        var calls:[String]=[],rendered:[Int]=[],progress:[ScoreDirectionProgress]=[],globalRoster:[Int]=[]
        var tracked=svc
        tracked.localEndings={_,p,_,_,part,systems,_ in calls.append("\(p.pageIndex):\(part):\(systems.sorted())");return local}
        tracked.pairEndings={results,cancel in globalRoster=results.map(\.pageIndex);return D.pairs(in:results,isCancelled:cancel)}
        let result=ScoreSharedDirectionWorkflow.analyze(analyses:input,profile:profile,
            render:{p,phase in if phase == .localEndings {rendered.append(p.pageIndex)};return image()},services:tracked,
            progress:{progress.append($0)},isCancelled:{false})
        try check(globalRoster==[0,1,2],"global pairing keeps complete selected roster")
        try check(rendered==[0] && calls==["0:cello:[0]"],"local recognition scans only paired page/system recipients")
        let localProgress=progress.filter{$0.phase == .localEndings}
        try check(localProgress.map(\.completedPages)==[0,1] && localProgress.allSatisfy{$0.totalPages==1},"local phase reports paired physical-page progress")
        try check(result.analyses[0].sharedEndings?.first?.localCounterparts?.count==1,"workflow publishes complete local counterpart")
        try check(ScoreExtractionPlanner.plan(pages:result.analyses,profile:profile).bands.allSatisfy{$0.sourceMarkings.isEmpty},"workflow result suppresses only proven duplicate")
        for mode in 0..<4 {
            var failed=svc
            failed.localEndings={_,p,_,_,_,_,_ in
                if mode==0 {throw NSError(domain:"localOCR",code:7)}
                var value=local
                if mode==1 {value.ownershipVerified=false}
                if mode==2 {value.candidates.removeLast()}
                return value
            }
            let kept=ScoreSharedDirectionWorkflow.analyze(analyses:input,profile:profile,
                render:{_,phase in phase == .localEndings && mode==3 ? nil : image()},services:failed,progress:{_ in},isCancelled:{false})
            try check(count(ScoreExtractionPlanner.plan(pages:kept.analyses,profile:profile))==1,"local failure or incomplete evidence keeps global copy: \(mode)")
            try check(kept.analyses[0].sharedEndings?.count==1,"optional local failure retains global metadata: \(mode)")
            if mode != 2 {try check(!kept.issues.isEmpty,"local failure emits optional information: \(mode)")}
        }
        for mode in 0..<3 {
            var cancel=false,staged=svc
            staged.localEndings={_,_,_,_,_,_,_ in if mode==1 {cancel=true};return local}
            let stopped=ScoreSharedDirectionWorkflow.analyze(analyses:input,profile:profile,render:{_,_ in image()},services:staged,
                progress:{p in if p.phase == .localEndings && ((mode==0 && p.completedPages==0) || (mode==2 && p.completedPages==p.totalPages)) {cancel=true}},
                isCancelled:{cancel})
            try check(stopped.analyses==input && stopped.issues.isEmpty,"local-stage cancellation never publishes partial metadata: \(mode)")
        }
        var noPairs=svc, localCalls=0
        noPairs.endings={_,p,_,_ in observed(p.pageIndex,[])}
        noPairs.localEndings={_,p,_,_,_,_,_ in localCalls+=1;return observed(p.pageIndex,[])}
        _=ScoreSharedDirectionWorkflow.analyze(analyses:input,profile:profile,render:{_,_ in image()},services:noPairs,progress:{_ in},isCancelled:{false})
        try check(localCalls==0,"no global pair means no extra local scan")
        var unrelated=page(1);unrelated.staves.removeLast()
        var validAround=svc;validAround.localEndings={_,p,_,_,_,_,_ in localCalls+=1;return observed(p.pageIndex,[])}
        let blocked=ScoreSharedDirectionWorkflow.analyze(analyses:[page(0),unrelated,page(2)],profile:profile,render:{_,_ in image()},services:validAround,progress:{_ in},isCancelled:{false})
        try check(blocked.analyses[1].sharedEndings==nil,"unresolved page remains a global pairing barrier and has no local scan")
    }
}
