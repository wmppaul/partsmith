import Foundation

// Bounded adversarial regression using hash-bound real recognizer evidence.
enum LocalCounterpartTests {
    typealias L = ScoreLocalEndingPreservation
    typealias D = ScoreSharedEndingDetector
    struct Input: Decodable { var source:String;var pairs:[D.Pair];var analyses:[ScorePageAnalysis];var profile:String }
    struct Cache: Decodable { var parts:[String:[D.PageResult]] }
    static var checks=0
    static func check(_ value:Bool,_ name:String)throws {
        guard value else {throw NSError(domain:"LocalCounterpartControls",code:1,userInfo:[NSLocalizedDescriptionKey:name])}
        checks += 1
    }
    static func read<T:Decodable>(_ type:T.Type,_ path:String)throws->T {try JSONDecoder().decode(type,from:Data(contentsOf:URL(fileURLWithPath:path)))}
    static func count(_ plan:ScoreExtractionPlan)->Int {plan.bands.reduce(0){$0+$1.sourceMarkings.count}}
    static func annotate(_ source:[ScorePageAnalysis],_ cp:ScoreEndingLocalCounterpart)->[ScorePageAnalysis] {
        var pages=source
        for i in pages.indices {for j in (pages[i].sharedEndings ?? []).indices {
            if pages[i].sharedEndings![j].members==cp.globalMembers {pages[i].sharedEndings![j].localCounterparts=[cp]}
        }}
        return pages
    }
    static func run()throws {
        let id="medium-skewed-03-schumann-piano-quintet-op44-imslp-06822"
        let input=try read(Input.self,".build/ending-corpus-2026-10-03/\(id)/result.json")
        let cache=try read(Cache.self,".build/ending-local-counterparts/\(id)/local-recognition.json")
        let cps=try read([ScoreEndingLocalCounterpart].self,".build/ending-local-counterparts/\(id)/counterparts.json")
        let profile=try read(ScoreExtractionProfile.self,input.profile)
        let review=ScoreDetectionReview.initial(profile:profile,analyses:input.analyses,sourcePDFData:try Data(contentsOf:URL(fileURLWithPath:input.source)),rectifications:[])
        let base=review.plan, cp=cps.first{$0.members[0].sourcePageIndex==5}!, pair=input.pairs.first{$0.first.pageIndex==5}!
        let pages=annotate(input.analyses,cp)
        let expected=L.apply(to:base,pages:pages,overrides:[])
        try check(count(base)-count(expected)==2,"complete two-system Piano pair suppresses exactly two copies")
        try check(L.retained(cp,pages:pages,plan:base),"both complete local source boxes are retained")
        try check(L.counterpart(global:pair,partID:"piano",localPages:cache.parts["piano"]!,pages:pages,plan:base) == cp,"recognition factory creates exact source-bound counterpart")
        var malformed=cp;malformed.partID="cello"
        try check(!L.retained(malformed,pages:pages,plan:base),"another part's printed pair cannot suppress Cello")
        malformed=cp;malformed.members[0].anchorStaffID += 1
        try check(!L.retained(malformed,pages:pages,plan:base),"lower grand-staff anchor cannot stand in for first staff")
        malformed=cp;malformed.members[0].sourceSystemIndex += 1
        try check(!L.retained(malformed,pages:pages,plan:base),"same-page wrong-system pair rejected")
        malformed=cp;malformed.members[0].sourcePageIndex += 1
        try check(!L.retained(malformed,pages:pages,plan:base),"same numerals on another page rejected")
        malformed=cp;malformed.members[0].bounds[0] += 0.03;malformed.members[0].bounds[2] += 0.03
        try check(!L.retained(malformed,pages:pages,plan:base),"same numeral wrong bar position rejected")
        malformed=cp;malformed.members[0].bounds[2] -= 0.03
        try check(!L.retained(malformed,pages:pages,plan:base),"matching start but wrong bracket end rejected")
        malformed=cp;malformed.members.removeLast()
        try check(!L.retained(malformed,pages:pages,plan:base),"one local member cannot suppress either global half")
        malformed=cp;malformed.members.reverse()
        try check(!L.retained(malformed,pages:pages,plan:base),"reversed roles rejected")
        var localPages=cache.parts["piano"]!
        let at=localPages.firstIndex{$0.pageIndex==5}!
        localPages[at].candidates.removeAll{$0.role=="second"}
        try check(L.counterpart(global:pair,partID:"piano",localPages:localPages,pages:pages,plan:base)==nil,"missed local second leaves global copies")
        localPages=cache.parts["piano"]!;localPages[at].candidates += localPages[at].candidates
        try check(L.counterpart(global:pair,partID:"piano",localPages:localPages,pages:pages,plan:base)==nil,"ambiguous local counterparts leave global copies")
        localPages=cache.parts["piano"]!;localPages[at].ownershipVerified=false
        try check(L.counterpart(global:pair,partID:"piano",localPages:localPages,pages:pages,plan:base)==nil,"unverified local ownership leaves global copies")
        localPages=cache.parts["piano"]!;localPages.remove(at:at)
        try check(L.counterpart(global:pair,partID:"piano",localPages:localPages,pages:pages,plan:base)==nil,"missing local page leaves global copies")
        let pi=base.pages.firstIndex{$0.pageIndex==5}!, bi=base.pages[pi].assignments.firstIndex{$0.partID=="piano" && $0.systemIndex==1}!
        var cropped=base;cropped.pages[pi].assignments[bi].topFraction=cp.members[1].bounds[1]+0.00001
        try check(L.apply(to:cropped,pages:pages,overrides:[])==cropped,"initial crop edit clipping second padded box preserves both copies")
        var regrouped=base;regrouped.pages[pi].assignments[bi].systemIndex=12
        try check(L.apply(to:regrouped,pages:pages,overrides:[])==regrouped,"initial recipient reassignment preserves both copies")
        var unresolved=base;unresolved.pages[pi].unresolvedReasons=["needs assignment"]
        try check(L.apply(to:unresolved,pages:pages,overrides:[])==unresolved,"unresolved layout cannot suppress copies")
        var removed=pages;removed[removed.firstIndex{$0.pageIndex==5}!].sharedEndings=[]
        try check(L.apply(to:base,pages:removed,overrides:[])==base,"cleared global metadata cannot suppress stale copies")
        try check(L.apply(to:base,pages:pages,overrides:[],isCancelled:{true})==base,"cancel is atomic")
        var visits=0
        try check(L.apply(to:base,pages:pages,overrides:[],isCancelled:{visits+=1;return visits>=3})==base,"mid-pass cancel restores original")
        var manual=ScoreSystemAssignment.pageOverride(page:pages.first{$0.pageIndex==5}!,pagePlan:base.pages[pi],existingOverride:nil)
        // A separately supplied manual list has no automatic provenance.
        for si in manual.systems.indices {for j in manual.systems[si].bands.indices {manual.systems[si].bands[j].automaticLocalEndingPairIDs=nil}}
        try check(L.apply(to:base,pages:pages,overrides:[manual])==base,"explicit manual marking lists remain authoritative")
        for si in manual.systems.indices {for j in manual.systems[si].bands.indices {manual.systems[si].bands[j].sourceMarkings=[]}}
        try check(L.apply(to:base,pages:pages,overrides:[manual])==base,"explicit empty marking lists are also preserved")
        var other=pages;let oi=other.firstIndex{$0.pageIndex==5}!
        let ending=other[oi].sharedEndings!.first{$0.systemIndex==0}!
        other[oi].sharedNavigation=[.init(anchorStaffID:ending.anchorStaffID,bounds:ending.bounds,recognizedText:"",isBelow:false)]
        let protected=L.apply(to:base,pages:other,overrides:[])
        try check(count(base)-count(protected)==1,"coincident destination/navigation category is not deleted")
        other=pages;other[oi].sharedHeadings=[.init(anchorStaffID:ending.anchorStaffID,bounds:ending.bounds,recognizedText:"Allegro")]
        try check(count(base)-count(L.apply(to:base,pages:other,overrides:[]))==1,"coincident heading is not deleted")
        var malformedPage=pages[oi]
        let firstOwned=malformedPage.staves.firstIndex{$0.id==cp.members[0].anchorStaffID}!
        let pianoBand=base.bands.first{$0.pageIndex==5 && $0.systemIndex==0 && $0.partID=="piano"}!
        malformedPage.staves[firstOwned].staffLineFractions=[]
        try check(L.firstStaff(of:pianoBand,on:malformedPage)==nil,"empty staff line array rejected before indexing")
        malformedPage=pages[oi];malformedPage.staves[firstOwned].staffLineFractions[0] = .nan
        try check(L.firstStaff(of:pianoBand,on:malformedPage)==nil,"nonfinite staff lines rejected")
        malformedPage=pages[oi];malformedPage.staves[firstOwned].staffLineFractions.reverse()
        try check(L.firstStaff(of:pianoBand,on:malformedPage)==nil,"unordered staff lines rejected")
        // Exercise the actual review API and its UI crop materialization.
        var live=ScoreDetectionReview.initial(profile:profile,analyses:pages,sourcePDFData:review.sourcePDFData,rectifications:[])
        let liveSource=live.analyses.first{$0.pageIndex==5}!, livePlan=live.plan.pages.first{$0.pageIndex==5}!
        var uiCrop=ScoreSystemAssignment.pageOverride(page:liveSource,pagePlan:livePlan,existingOverride:nil)
        let us=uiCrop.systems.firstIndex{$0.systemIndex==1}!, ub=uiCrop.systems[us].bands.firstIndex{$0.partID=="piano"}!
        try check(uiCrop.systems[us].bands[ub].automaticLocalEndingPairIDs?.isEmpty==false,"crop materialization remembers automatic ending choice")
        uiCrop.systems[us].bands[ub].rect![1]=(cp.members[1].bounds[1]+0.00001)*liveSource.pageHeight
        live.overrides.append(uiCrop);live.replan()
        try check(live.plan.canApply,"real Piano recrop remains a valid review")
        let restored=live.plan.bands.filter{$0.pageIndex==5 && $0.partID=="piano" && $0.sourceMarkings.count==1}
        try check(restored.count==2,"clipping one local bracket restores both required automatic copies through review")
        let one=restored.first{$0.systemIndex==1}!
        try live.removeSourceMarking(from:one.id,at:0)
        live.replan()
        try check(live.plan.bands.first{$0.id==one.id}!.sourceMarkings.isEmpty,"explicit Remove Copy remains removed on replan")
        let li=live.overrides.firstIndex{$0.pageIndex==5}!
        live.overrides[li].systems[us].bands[ub].rect![1]=pianoBand.topFraction*liveSource.pageHeight
        // Restore original second-system crop, then narrow again: removal stays explicit.
        live.overrides[li].systems[us].bands[ub].rect![1]=base.pages[pi].assignments[bi].topFraction*liveSource.pageHeight
        live.replan()
        live.overrides[li].systems[us].bands[ub].rect![1]=(cp.members[1].bounds[1]+0.00001)*liveSource.pageHeight
        live.replan()
        try check(live.plan.bands.first{$0.id==one.id}!.sourceMarkings.isEmpty,"explicit removal survives repeated crop edits")
        let encoded=try JSONEncoder().encode(pages)
        try check(try JSONDecoder().decode([ScorePageAnalysis].self,from:encoded)==pages,"local evidence survives document serialization")
        var fullPages=input.analyses
        for counterpart in cps {fullPages=annotate(fullPages,counterpart)}
        let full=L.apply(to:base,pages:fullPages,overrides:[])
        try check(count(base)-count(full)==5,"all four native Piano pairs suppress exactly five duplicate rows")
        try check(full.bands.filter{$0.partID != "piano"}==base.bands.filter{$0.partID != "piano"},"all non-Piano bands and copied directions remain exact")
        for (a,b) in zip(base.bands,full.bands) {var x=a;x.sourceMarkings=b.sourceMarkings;try check(x==b,"all original main crops and other band fields retained")}
        // Cross-page pair: move the second system into its own adjacent selected page.
        var crossCP=cp
        crossCP.members[1].sourcePageIndex=6;crossCP.globalMembers[1].sourcePageIndex=6
        var firstPage=pages[oi], secondPage=pages[oi];secondPage.pageIndex=6
        firstPage.sharedEndings=firstPage.sharedEndings!.filter{$0.systemIndex==0}
        secondPage.sharedEndings=secondPage.sharedEndings!.filter{$0.systemIndex==1}
        for idx in firstPage.sharedEndings!.indices {firstPage.sharedEndings![idx].members=crossCP.globalMembers;firstPage.sharedEndings![idx].localCounterparts=[crossCP]}
        for idx in secondPage.sharedEndings!.indices {secondPage.sharedEndings![idx].sourcePageIndex=6;secondPage.sharedEndings![idx].members=crossCP.globalMembers;secondPage.sharedEndings![idx].localCounterparts=[crossCP]}
        var firstPlan=base.pages[pi],secondPlan=base.pages[pi]
        firstPlan.assignments.removeAll{$0.systemIndex != 0}
        secondPlan.pageIndex=6;secondPlan.assignments.removeAll{$0.systemIndex != 1}
        for i in secondPlan.assignments.indices {secondPlan.assignments[i].pageIndex=6;secondPlan.assignments[i].id += "-cross-page"}
        let crossPlan=ScoreExtractionPlan(parts:base.parts,pages:[firstPlan,secondPlan],warnings:[])
        let crossPages=[firstPage,secondPage]
        try check(count(crossPlan)-count(L.apply(to:crossPlan,pages:crossPages,overrides:[]))==2,"complete local cross-page pair suppresses both copies")
        try check(L.apply(to:crossPlan,pages:[firstPage],overrides:[])==crossPlan,"missing second source page retains both copies")
        var changed=crossPlan;let piano=changed.pages[1].assignments.firstIndex{$0.partID=="piano"}!
        changed.pages[1].assignments[piano].topFraction=crossCP.members[1].bounds[1]+0.00001
        try check(L.apply(to:changed,pages:crossPages,overrides:[])==changed,"partner page crop edit invalidates both suppressions")
        var stale=crossPages;stale[1].sharedEndings=nil
        try check(L.apply(to:crossPlan,pages:stale,overrides:[])==crossPlan,"partner page recognition invalidation retains both copies")
        var reassigned=crossPlan;let globalOwner=reassigned.pages[1].assignments.firstIndex{$0.candidateIDs.contains(crossCP.globalMembers[1].anchorStaffID)}!
        reassigned.pages[1].assignments[globalOwner].systemIndex=9
        try check(L.apply(to:reassigned,pages:crossPages,overrides:[])==reassigned,"partner source owner reassignment invalidates both suppressions")
        print("PASS local counterpart controls: \(checks) assertions (825 main-band equality checks plus controls)")
    }
}
