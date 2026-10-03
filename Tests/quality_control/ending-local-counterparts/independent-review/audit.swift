import Foundation
@main enum IndependentLocalEndingAudit {
 typealias L=ScoreLocalEndingPreservation
 typealias D=ScoreSharedEndingDetector
 typealias T=LocalCounterpartTests
 static var rows:[[String:Any]]=[]
 static func record(_ name:String,_ pass:Bool,_ detail:String=""){rows.append(["name":name,"passed":pass,"detail":detail])}
 static func planned(pages:[ScorePageAnalysis],profile:ScoreExtractionProfile,overrides:[ScorePageOverride]=[])->ScoreExtractionPlan{ScoreDetectionReview.initial(profile:profile,analyses:pages,overrides:overrides,sourcePDFData:Data(),rectifications:[]).plan}
 static func main()throws{
  try T.run()
  let id="medium-skewed-03-schumann-piano-quintet-op44-imslp-06822"
  let input=try T.read(T.Input.self,".build/ending-corpus-2026-10-03/\(id)/result.json")
  let cps=try T.read([ScoreEndingLocalCounterpart].self,".build/ending-local-counterparts/\(id)/counterparts.json")
  let cp=cps.first{$0.members[0].sourcePageIndex==5}!, profile=try T.read(ScoreExtractionProfile.self,input.profile)
  let pages=T.annotate(input.analyses,cp), base=planned(pages:input.analyses,profile:profile)
  let pi=pages.firstIndex{$0.pageIndex==5}!, firstEnding=pages[pi].sharedEndings!.first{$0.systemIndex==0}!, secondEnding=pages[pi].sharedEndings!.first{$0.systemIndex==1}!
  let normal=L.apply(to:base,pages:pages,overrides:[])
  record("fresh full pair suppresses exactly two copies",T.count(base)-T.count(normal)==2)
  var half=pages;half[pi].sharedEndings!.removeAll{$0.systemIndex==1}
  record("missing same-page second-system metadata does not certify full-pair suppression",L.apply(to:base,pages:half,overrides:[])==base,"Observed suppressed copies: \(T.count(base)-T.count(L.apply(to:base,pages:half,overrides:[])))")
  half=pages;half[pi].sharedEndings!.removeAll{$0.systemIndex==0}
  record("missing same-page first-system metadata does not certify full-pair suppression",L.apply(to:base,pages:half,overrides:[])==base,"Observed suppressed copies: \(T.count(base)-T.count(L.apply(to:base,pages:half,overrides:[])))")
  // Root plans/overrides are rebuilt through the public planner rather than
  // changing computed bands after their validation has completed.
  var bare=ScoreSystemAssignment.pageOverride(page:pages[pi],pagePlan:base.pages.first{$0.pageIndex==5},existingOverride:nil)
  for s in bare.systems.indices{for b in bare.systems[s].bands.indices{bare.systems[s].bands[b].sourceMarkings=nil;bare.systems[s].bands[b].sourceMarkingsBelow=nil;bare.systems[s].bands[b].automaticLocalEndingPairIDs=nil}}
  let plain=planned(pages:pages,profile:profile,overrides:[bare])
  record("unchanged initial nil-list override keeps complete local pair suppression",plain.canApply && plain.bands.filter{$0.pageIndex==5 && $0.partID=="piano" && [0,1].contains($0.systemIndex)}.allSatisfy{$0.sourceMarkings.isEmpty})
  let s0=bare.systems.firstIndex{$0.systemIndex==0}!, s1=bare.systems.firstIndex{$0.systemIndex==1}!
  let p0=bare.systems[s0].bands.firstIndex{$0.partID=="piano"}!,p1=bare.systems[s1].bands.firstIndex{$0.partID=="piano"}!
  let g0=bare.systems[s0].bands.firstIndex{$0.candidateIDs!.contains(firstEnding.anchorStaffID)}!,g1=bare.systems[s1].bands.firstIndex{$0.candidateIDs!.contains(secondEnding.anchorStaffID)}!
  func samePlan(_ value:ScorePageOverride)->Bool{
   let a=planned(pages:pages,profile:profile,overrides:[value]),b=planned(pages:input.analyses,profile:profile,overrides:[value])
   return a.canApply && a==b
  }
  var sourceCue=bare;sourceCue.systems[s1].bands[g1].kind="cue";sourceCue.systems[s1].bands[g1].label="Source cue"
  record("initial source music-to-cue invalidates both suppressions",samePlan(sourceCue))
  var recipientCue=bare;recipientCue.systems[s1].bands[p1].kind="cue";recipientCue.systems[s1].bands[p1].label="Recipient cue"
  record("initial recipient music-to-cue invalidates both suppressions",samePlan(recipientCue))
  var moved=bare
  let old0=moved.systems[s0].bands[g0],old1=moved.systems[s1].bands[g1]
  moved.systems[s0].bands[g0]=old1;moved.systems[s1].bands[g1]=old0
  record("initial global owner swap across systems invalidates both suppressions",samePlan(moved))
  moved=bare
  let oldP0=moved.systems[s0].bands[p0],oldP1=moved.systems[s1].bands[p1]
  moved.systems[s0].bands[p0]=oldP1;moved.systems[s1].bands[p1]=oldP0
  record("initial recipient swap across systems invalidates both suppressions",samePlan(moved))
  var cropped=bare;cropped.systems[s1].bands[p1].rect![1]=(cp.members[1].bounds[1]+0.00001)*pages[pi].pageHeight
  record("initial final crop clips local partner and restores all needed copies",samePlan(cropped))
  var fake=cp;fake.partID="cello"
  record("neighbor Piano ending cannot suppress Cello copy even with broad crop",!L.retained(fake,pages:pages,plan:base))
  fake=cp;fake.members[0].anchorStaffID=cp.globalMembers[0].anchorStaffID
  record("neighbor global owner cannot stand in for recipient source anchor",!L.retained(fake,pages:pages,plan:base))
  // Decoded stale input must not suppress if the actual local staff changed.
  var changedPages=pages;let si=changedPages[pi].staves.firstIndex{$0.id==cp.members[1].anchorStaffID}!
  changedPages[pi].staves[si].staffLineFractions=changedPages[pi].staves[si].staffLineFractions.map{$0-0.1}
  record("physically moved recipient staff rejects its old local bounds",!L.retained(cp,pages:changedPages,plan:base))
  var visits=0;let cancelled=L.apply(to:base,pages:pages,overrides:[],isCancelled:{visits+=1;return visits==4 || visits>4})
  record("cancellation after partial suppression restores exact original plan",cancelled==base)
  // Restore a formerly suppressed automatic ending, remove an unrelated
  // navigation copy, then invalidate assignments. The remaining materialized
  // ending must not become an accidental manual marking.
  var withNavigation=pages
  let navigation=ScoreSharedNavigation(anchorStaffID:secondEnding.anchorStaffID,bounds:[0.55,0.44,0.6,0.45],recognizedText:"D.C.",isBelow:false)
  withNavigation[pi].sharedNavigation=(withNavigation[pi].sharedNavigation ?? [])+[navigation]
  var live=ScoreDetectionReview.initial(profile:profile,analyses:withNavigation,sourcePDFData:Data(),rectifications:[])
  var materialized=ScoreSystemAssignment.pageOverride(page:withNavigation[pi],pagePlan:live.plan.pages.first{$0.pageIndex==5},existingOverride:nil)
  materialized.systems[s1].bands[p1].rect![1]=(cp.members[1].bounds[1]+0.00001)*pages[pi].pageHeight
  live.overrides=[materialized];live.replan()
  let target=live.plan.bands.first{$0.pageIndex==5 && $0.systemIndex==1 && $0.partID=="piano"}!
  let navIndex=target.sourceMarkings.firstIndex{$0.leftFraction==navigation.bounds[0]}!
  try live.removeSourceMarking(from:target.id,at:navIndex)
  let beforeInvalidation=live.plan.bands.first{$0.id==target.id}!.sourceMarkings
  record("unrelated Remove Copy leaves restored ending automatic before invalidation",beforeInvalidation.contains(secondEnding.sourceMarking))
  let index=live.overrides.firstIndex{$0.pageIndex==5}!
  live.overrides[index].systems[s1].bands[p1].kind="cue"
  live.overrides[index].systems[s1].bands[p1].label="Changed recipient kind"
  live.replan()
  let afterInvalidation=live.plan.bands.first{$0.id==target.id}?.sourceMarkings ?? []
  record("restored automatic ending materialized by unrelated Remove Copy clears after assignment invalidation",!afterInvalidation.contains(secondEnding.sourceMarking),"Retained stale ending: \(afterInvalidation.contains(secondEnding.sourceMarking)); issues: \(live.directionIssues.map(\.message))")
  let out:[String:Any]=["originalControlsCompleted":true,"tests":rows,"failures":rows.filter{$0["passed"] as? Bool != true}.count]
  let json=try JSONSerialization.data(withJSONObject:out,options:[.prettyPrinted,.sortedKeys]);try json.write(to:URL(fileURLWithPath:".build/ending-local-independent-review/results.json"));print(String(decoding:json,as:UTF8.self))
  if rows.contains(where:{$0["passed"] as? Bool != true}){exit(1)}
 }
}
