import Foundation

@main enum CropEditEndingControls {
    typealias L = LocalEndingControls
    struct Check: Codable { var name:String; var passed:Bool; var detail:String }
    static var checks:[Check]=[]
    static func check(_ value:Bool,_ name:String,_ detail:String="") {checks.append(.init(name:name,passed:value,detail:detail))}
    static func same(_ a:ScoreDetectionReview,_ b:ScoreDetectionReview)->Bool {
        a.plan==b.plan && a.overrides==b.overrides && a.analyses==b.analyses && a.directionIssues==b.directionIssues
            && a.sourcePDFData==b.sourcePDFData && a.rectifications==b.rectifications
    }
    static func main() throws {
        let pair=L.D.Pair(first:L.candidate(first:true),second:L.candidate(first:false))
        let pages=L.annotated([L.page(0)],pair:pair)
        let local=L.observed(0,[L.candidate(first:true,local:true),L.candidate(first:false,local:true)])
        let base=ScoreExtractionPlanner.plan(pages:pages,profile:L.profile)
        let cp=L.L.counterpart(global:pair,partID:"cello",localPages:[local],pages:pages,plan:base)!
        let withLocal=L.attach(cp,to:pages), ending=withLocal[0].sharedEndings![0].sourceMarking
        let initial=ScoreDetectionReview.initial(profile:L.profile,analyses:withLocal,sourcePDFData:Data(),rectifications:[])
        let band=initial.plan.bands.first {$0.partID=="cello" && $0.systemIndex==0}!
        let id=band.id, top=band.topFraction*800, bottom=band.bottomFraction*800
        let clippedTop=(cp.members[0].bounds[1]+0.001)*800
        func count(_ review:ScoreDetectionReview)->Int {review.plan.bands.first {$0.id==id}!.sourceMarkings.filter {$0==ending}.count}
        func provenance(_ review:ScoreDetectionReview)->[String]? {
            review.overrides.first {$0.pageIndex==0}?.systems.first {$0.systemIndex==0}?.bands.first {$0.partID=="cello"}?.automaticLocalEndingPairIDs
        }
        check(initial.plan.canApply && count(initial)==0 && initial.overrides.isEmpty,"initial local ending suppresses global without an override")
        var clipped=initial
        try clipped.setCropEdges(for:id,top:clippedTop,bottom:bottom)
        check(count(clipped)==1,"actual setCropEdges restores global ending when local source is clipped","copied ending count=\(count(clipped))")
        check(provenance(clipped)==[withLocal[0].sharedEndings![0].pairID],"actual API materializes automatic local-ending identity")
        check(clipped.analyses==initial.analyses && clipped.directionIssues==initial.directionIssues,"crop edit retains recognition and category bindings")
        try clipped.setCropEdges(for:id,top:top,bottom:bottom)
        check(count(clipped)==0,"actual reversed crop suppresses the ending again")
        try clipped.setCropEdges(for:id,top:clippedTop,bottom:bottom)
        check(count(clipped)==1,"second actual crop clip restores ending again")
        try clipped.resetCropEdges(for:id)
        check(count(clipped)==0 && clipped.plan.canApply,"actual resetCropEdges restores local retention")
        try clipped.setCropEdges(for:id,top:clippedTop,bottom:bottom)
        check(count(clipped)==1,"actual clip after reset retains automatic provenance")

        var noop=initial
        try noop.setCropEdges(for:id,top:top,bottom:bottom)
        try noop.setCropEdges(for:id,top:clippedTop,bottom:bottom)
        check(count(noop)==1,"a no-op UI edge edit does not turn suppression into explicit removal")
        var firstReset=initial
        try firstReset.resetCropEdges(for:id)
        try firstReset.setCropEdges(for:id,top:clippedTop,bottom:bottom)
        check(count(firstReset)==1,"reset used as the first UI action retains automatic identity")

        if let index=clipped.plan.bands.first(where:{$0.id==id})!.sourceMarkings.firstIndex(of:ending) {
            try clipped.removeSourceMarking(from:id,at:index)
            check(count(clipped)==0 && provenance(clipped)?.contains(withLocal[0].sharedEndings![0].pairID)==false,"Remove Copy deliberately clears restored-ending provenance")
            try clipped.setCropEdges(for:id,top:top,bottom:bottom)
            try clipped.setCropEdges(for:id,top:clippedTop,bottom:bottom)
            try clipped.resetCropEdges(for:id)
            try clipped.setCropEdges(for:id,top:clippedTop,bottom:bottom)
            check(count(clipped)==0,"Remove Copy stays removed through reverse reset and later clipping")
        } else {check(false,"restored-copy removal can be exercised","baseline bug prevented the global copy from returning")}
        var ordinary=ScoreDetectionReview.initial(profile:L.profile,analyses:pages,sourcePDFData:Data(),rectifications:[])
        let oi=ordinary.plan.bands.first {$0.id==id}!.sourceMarkings.firstIndex(of:ending)!
        try ordinary.removeSourceMarking(from:id,at:oi)
        try ordinary.setCropEdges(for:id,top:clippedTop,bottom:bottom)
        try ordinary.resetCropEdges(for:id)
        check(count(ordinary)==0,"ordinary explicit Remove Copy remains authoritative")

        for supplied in [false,true] {
            var explicit=ScoreSystemAssignment.pageOverride(page:withLocal[0],pagePlan:initial.plan.pages[0],existingOverride:nil)
            explicit.reason="Existing reviewed reason"
            let i=explicit.systems[0].bands.firstIndex {$0.partID=="cello"}!
            let custom:[Double]=[20,110,70,122]
            explicit.systems[0].bands[i].automaticLocalEndingPairIDs=nil
            explicit.systems[0].bands[i].sourceMarkings=supplied ? [custom] : []
            explicit.systems[0].label="Kept system label";explicit.systems[0].movementLabel="Kept movement"
            var reviewed=ScoreDetectionReview.initial(profile:L.profile,analyses:withLocal,overrides:[explicit],sourcePDFData:Data(),rectifications:[])
            let beforeMarkings=reviewed.plan.bands.first {$0.id==id}!.sourceMarkings
            try reviewed.setCropEdges(for:id,top:clippedTop,bottom:bottom)
            try reviewed.resetCropEdges(for:id)
            check(reviewed.plan.bands.first {$0.id==id}!.sourceMarkings==beforeMarkings && provenance(reviewed)==nil,"initial explicit \(supplied ? "nonempty":"empty") list remains authoritative")
            check(reviewed.overrides[0].reason==explicit.reason && reviewed.overrides[0].systems[0].label==explicit.systems[0].label && reviewed.overrides[0].systems[0].movementLabel==explicit.systems[0].movementLabel,"existing override reason and labels remain exact (\(supplied))")
        }

        var directed=withLocal
        directed[0].sharedHeadings=[.init(anchorStaffID:0,bounds:[0.1,0.14,0.2,0.17],recognizedText:"Andante")]
        directed[0].sharedNavigation=[.init(anchorStaffID:0,bounds:[0.8,0.14,0.9,0.17],recognizedText:"D.C.",isBelow:false)]
        var categories=ScoreDetectionReview.initial(profile:L.profile,analyses:directed,sourcePDFData:Data(),rectifications:[])
        let unrelated=categories.plan.bands.first {$0.id==id}!.sourceMarkings.filter {$0 != ending}
        try categories.setCropEdges(for:id,top:clippedTop,bottom:bottom)
        check(categories.plan.bands.first {$0.id==id}!.sourceMarkings.filter {$0 != ending}==unrelated && categories.analyses==directed,"actual crop edit preserves unrelated heading and navigation copies/metadata")
        check(count(categories)==1,"actual crop restores ending alongside unrelated direction categories")
        let bi=categories.overrides[0].systems[0].bands.firstIndex {$0.partID=="cello"}!
        categories.overrides[0].systems[0].bands[bi].kind="cue"
        categories.overrides[0].systems[0].bands[bi].label="Reviewed cue"
        categories.replan()
        check(categories.analyses[0].sharedEndings==nil && !categories.plan.bands.flatMap(\.sourceMarkings).contains(ending),"later music-to-cue ownership change invalidates automatic ending evidence")

        var invalid=initial
        do {try invalid.setCropEdges(for:id,top:300,bottom:bottom);check(false,"invalid edge request throws")}
        catch {check(true,"invalid edge request throws")}
        check(same(invalid,initial),"rejected edge request is atomic and leaves review untouched")
        do {try invalid.resetCropEdges(for:"missing-band");check(false,"unavailable reset throws")}
        catch {check(true,"unavailable reset throws")}
        check(same(invalid,initial),"unavailable reset leaves review untouched")

        var restPage=L.page(0);restPage.staves=Array(restPage.staves.prefix(1))
        var omission=try ScoreSystemAssignment.assign(page:restPage,profile:L.profile,pagePlan:nil,existingOverride:nil,systemIndex:0,candidateIDs:[0],presentPartIDs:["violin"],startBarNumber:144,barCount:6)
        omission.reason="Six silent bars explicitly reviewed"
        var restReview=ScoreDetectionReview.initial(profile:L.profile,analyses:[restPage],overrides:[omission],sourcePDFData:Data(),rectifications:[])
        let printed=restReview.plan.bands.first {$0.generatedRest==nil}!, rest=restReview.plan.bands.first {$0.generatedRest != nil}!
        let restsBefore=restReview.plan.bands.filter {$0.generatedRest != nil}
        let omissionsBefore=restReview.plan.pages[0].omissions
        try restReview.setCropEdges(for:printed.id,top:printed.topFraction*800,bottom:printed.bottomFraction*800)
        try restReview.resetCropEdges(for:printed.id)
        check(restReview.plan.bands.filter {$0.generatedRest != nil}==restsBefore && restReview.plan.pages[0].omissions==omissionsBefore,"crop and reset preserve existing generated rests and omission reasons")
        check(restReview.overrides[0].reason==omission.reason && restReview.overrides[0].systems[0].startBarNumber==144 && restReview.overrides[0].systems[0].barCount==6,"existing rest measure span and review reason remain exact")
        let validRestState=restReview
        do {try restReview.setCropEdges(for:rest.id,top:0,bottom:800);check(false,"generated rest cannot be edited as source crop")}
        catch {check(true,"generated rest cannot be edited as source crop")}
        do {try restReview.resetCropEdges(for:rest.id);check(false,"generated rest cannot reset source crop")}
        catch {check(true,"generated rest cannot reset source crop")}
        check(same(restReview,validRestState),"both rejected generated-rest edits are atomic")
        // Exercise the materialization helper's no-existing-override path with
        // an already reviewed plan. This is a model-level state, not a claim
        // that automatic instrument recognition generates omitted rests.
        var materialized=ScoreDetectionReview(profile:L.profile,analyses:[restPage],plan:validRestState.plan,sourcePDFData:Data(),rectifications:[])
        do {
            try materialized.setCropEdges(for:printed.id,top:printed.topFraction*800,bottom:printed.bottomFraction*800)
            check(materialized.plan.bands.filter {$0.generatedRest != nil}==restsBefore && materialized.plan.pages[0].omissions==omissionsBefore,"no-override materialization preserves a pre-reviewed omission plan")
        } catch {check(false,"no-override materialization preserves a pre-reviewed omission plan",String(describing:error))}

        // This unchanged suite contains category-specific linked cleanup and
        // recognition-cancellation controls. It previously passed despite the
        // actual crop API bug because it materialized overrides by hand.
        try L.run()
        let enc=JSONEncoder();enc.outputFormatting=[.prettyPrinted,.sortedKeys]
        try enc.encode(checks).write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
        print("Actual crop API: \(checks.filter(\.passed).count)/\(checks.count) passed; existing local-ending controls: \(L.checks) passed")
    }
}
