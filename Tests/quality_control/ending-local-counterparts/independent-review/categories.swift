import Foundation
@main enum CounterpartCategoryAudit {
 typealias L=ScoreLocalEndingPreservation
 typealias T=LocalCounterpartTests
 static func main()throws{
  let id="medium-skewed-03-schumann-piano-quintet-op44-imslp-06822"
  let input=try T.read(T.Input.self,".build/ending-corpus-2026-10-03/\(id)/result.json")
  let cps=try T.read([ScoreEndingLocalCounterpart].self,".build/ending-local-counterparts/\(id)/counterparts.json")
  var cp=cps.first{$0.members[0].sourcePageIndex==5}!, profile=try T.read(ScoreExtractionProfile.self,input.profile)
  var first=input.analyses.first{$0.pageIndex==5}!, second=first
  first.staves=first.staves.filter{$0.id<6};second.staves=second.staves.filter{(6..<12).contains($0.id)};second.pageIndex=6
  first.sharedNavigation=nil;second.sharedNavigation=nil;first.sharedHeadings=nil;second.sharedHeadings=nil
  cp.members[1].sourcePageIndex=6;cp.members[1].sourceSystemIndex=0
  cp.globalMembers[1].sourcePageIndex=6;cp.globalMembers[1].sourceSystemIndex=0
  func ending(_ member:ScoreEndingMember)->ScoreSharedEnding {
   .init(sourcePageIndex:member.sourcePageIndex,anchorStaffID:member.anchorStaffID,systemIndex:member.sourceSystemIndex,bounds:member.bounds,members:cp.globalMembers,localCounterparts:[cp])
  }
  first.sharedEndings=[ending(cp.globalMembers[0])];second.sharedEndings=[ending(cp.globalMembers[1])]
  let secondEnding=second.sharedEndings![0]
  var rows:[[String:Any]]=[]
  for kind in ["navigation","heading"] {
   var pages=[first,second]
   if kind=="navigation" {pages[1].sharedNavigation=[.init(anchorStaffID:secondEnding.anchorStaffID,bounds:secondEnding.bounds,recognizedText:"D.C.",isBelow:false)]}
   else {pages[1].sharedHeadings=[.init(anchorStaffID:secondEnding.anchorStaffID,bounds:secondEnding.bounds,recognizedText:"Allegro")]}
   var live=ScoreDetectionReview.initial(profile:profile,analyses:pages,sourcePDFData:Data(),rectifications:[])
   precondition(live.plan.canApply && L.retained(cp,pages:pages,plan:live.plan),"Cross-page fixture must retain both complete local sources")
   let target=live.plan.bands.first{$0.pageIndex==6 && $0.partID=="piano"}!
   precondition(target.sourceMarkings.contains(secondEnding.sourceMarking),"Coincident category must retain its source copy initially")
   let materialized=ScoreSystemAssignment.pageOverride(page:pages[1],pagePlan:live.plan.pages.first{$0.pageIndex==6},existingOverride:nil)
   live.overrides=[materialized];live.replan()
   precondition(live.plan.bands.first{$0.id==target.id}!.sourceMarkings.contains(secondEnding.sourceMarking),"Materialization must retain category before invalidation")
   live.invalidateAutomaticDirections(on:5)
   let survived=live.plan.bands.first{$0.id==target.id}?.sourceMarkings.contains(secondEnding.sourceMarking)==true
   let categoryExists=kind=="navigation" ? live.analyses.first{$0.pageIndex==6}?.sharedNavigation?.isEmpty==false : live.analyses.first{$0.pageIndex==6}?.sharedHeadings?.isEmpty==false
   rows.append(["name":"coincident \(kind) survives linked ending invalidation","passed":survived && categoryExists,"categoryMetadataRemains":categoryExists,"sourceCopyRemains":survived,"canApply":live.plan.canApply])
  }
  let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]);let path=CommandLine.arguments.count>1 ? CommandLine.arguments[1]:".build/ending-local-independent-review/category-results.json";try data.write(to:URL(fileURLWithPath:path));print(String(decoding:data,as:UTF8.self));if rows.contains(where:{$0["passed"] as? Bool != true}){exit(1)}
 }
}
