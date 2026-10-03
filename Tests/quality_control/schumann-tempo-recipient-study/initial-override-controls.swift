import Foundation
@main enum InitialOverrideControls {
 static func staff(_ id:Int,_ top:Double)->ScoreObservedStaff{ScoreObservedStaff(StaffBandCandidate(id:id,staffLineFractions:(0..<5).map{top+Double($0)*0.005},topFraction:top-0.02,bottomFraction:top+0.04,confidence:1,warnings:[]))}
 static func main()throws{
  let profile=ScoreExtractionProfile(parts:[.init(id:"a",name:"A",staffCount:1),.init(id:"b",name:"B",staffCount:1)],cropMode:"compact")
  var page=ScorePageAnalysis(pageIndex:0,pageWidth:600,pageHeight:800,imageWidth:1800,imageHeight:2400,staves:[staff(0,0.2),staff(1,0.3),staff(2,0.5),staff(3,0.6)],warnings:[])
  var heading=ScoreSharedHeading(anchorStaffID:0,bounds:[0.2,0.165,0.3,0.19],recognizedText:"Adagio")
  heading.inkBounds=[0.201,0.166,0.299,0.189]
  #if V3
  heading.sourceStaffID=0;heading.recipientPartIDs=["a","b"]
  #endif
  page.sharedHeadings=[heading]
  let automatic=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
  func raw()->ScorePageOverride{ScorePageOverride(pageIndex:0,reason:"Initial source assignment fixture",systems:[.init(systemIndex:0,bands:[.init(partID:"a",candidateIDs:[0]),.init(partID:"b",candidateIDs:[1])]),.init(systemIndex:1,bands:[.init(partID:"a",candidateIDs:[2]),.init(partID:"b",candidateIDs:[3])])])}
  var out:[[String:Any]]=[]
  func run(_ name:String,_ override:ScorePageOverride,_ expected:String,_ test:(ScoreExtractionPlan)->Bool){
   let p=ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[override]);let matched=test(p)
   out.append(["name":name,"expected":expected,"passed":matched,"canApply":p.canApply,"bands":p.bands.map{["part":$0.partID,"system":$0.systemIndex,"kind":$0.kind,"staffIDs":$0.candidateIDs,"copyCount":$0.sourceMarkings.count,"warnings":$0.warnings] as [String:Any]},"unresolved":p.pages.flatMap(\.unresolvedReasons)])
  }
  func hasWarning(_ p:ScoreExtractionPlan)->Bool{!p.canApply || p.bands.flatMap(\.warnings).contains{$0.localizedCaseInsensitiveContains("heading") || $0.localizedCaseInsensitiveContains("direction")}}
  let expectedCount=automatic.bands.first{$0.partID=="b" && $0.systemIndex==0}!.sourceMarkings.count
  precondition(automatic.canApply && expectedCount==1,"Fixture must independently require one automatic recipient copy")
  run("unchanged initial override with absent marking list",raw(),"retain the same complete B heading copy as automatic planning"){p in p.canApply && p.bands.first{$0.partID=="b" && $0.systemIndex==0}?.sourceMarkings.count==expectedCount}
  var empty=raw();empty.systems[0].bands[1].sourceMarkings=[]
  run("explicit empty marking list remains authoritative",empty,"do not resurrect the B copy removed by the user"){p in p.canApply && p.bands.first{$0.partID=="b" && $0.systemIndex==0}?.sourceMarkings.isEmpty==true}
  let captured=ScoreSystemAssignment.pageOverride(page:page,pagePlan:automatic.pages[0],existingOverride:nil)
  run("explicit captured copy survives no-op mapping",captured,"preserve the already-materialized source marking"){p in p.canApply && p.bands.first{$0.partID=="b" && $0.systemIndex==0}?.sourceMarkings.count==1}
  var movedSource=raw();movedSource.systems[0].bands[0].candidateIDs=[2];movedSource.systems[1].bands[0].candidateIDs=[0]
  run("initial override moves recognized source staff to another system",movedSource,"explicitly invalidate stale heading ownership before review binding capture",hasWarning)
  var movedRecipient=raw();movedRecipient.systems[0].bands[1].candidateIDs=[3];movedRecipient.systems[1].bands[1].candidateIDs=[1]
  run("initial override moves recipient staff to another system",movedRecipient,"explicitly invalidate stale recipient ownership before review binding capture",hasWarning)
  var cueSource=raw();cueSource.systems[0].bands[0].kind="cue";cueSource.systems[0].bands[0].label="Cue source"
  run("initial override changes source staff to cue",cueSource,"do not silently treat a recognized music source as the same eligible source",hasWarning)
  var cueRecipient=raw();cueRecipient.systems[0].bands[1].kind="cue";cueRecipient.systems[0].bands[1].label="Cue recipient"
  run("initial override changes recipient staff to cue",cueRecipient,"explicitly reconsider recipient kind before applying cached decision",hasWarning)
  #if V3
  let own=ScoreSharedHeading(anchorStaffID:0,bounds:[0.2,0.286,0.3,0.295],recognizedText:"Presto",inkBounds:[0.201,0.29,0.299,0.294],sourceStaffID:1)
  let resolved=SchumannHeadingCandidate.assignRecipients(preserved:[],measured:[heading,own],page:page,profile:profile,imageSize:CGSize(width:1800,height:2400))
  precondition(resolved.first!.recipientPartIDs?.contains("b")==false,"Fixture B must already contain its own local direction")
  page.sharedHeadings=resolved
  run("initial override moves locally supplied recipient",movedRecipient,"recheck physical local-heading supplier, not just stored part ID",hasWarning)
  run("initial override changes locally supplied recipient to cue",cueRecipient,"recheck local supplier kind, not just stored part ID",hasWarning)
  #endif
  let body:[String:Any]=["intentionalNegativeAudit":true,"automaticRecipientCopies":expectedCount,"tests":out,"failedExpectedRequirements":out.filter{$0["passed"] as? Bool != true}.count]
  print(String(decoding:try JSONSerialization.data(withJSONObject:body,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
  if out.contains(where:{$0["passed"] as? Bool != true}){exit(1)}
 }
}
