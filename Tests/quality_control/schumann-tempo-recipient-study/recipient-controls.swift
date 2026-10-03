import CoreGraphics
import Foundation
@main enum RecipientControls {
 static var checks:[[String:Any]]=[]
 static func record(_ name:String,_ okay:Bool){checks.append(["name":name,"passed":okay])}
 static func staff(_ id:Int,_ top:Double)->ScoreObservedStaff{ScoreObservedStaff(StaffBandCandidate(id:id,staffLineFractions:(0..<5).map{top+Double($0)*0.005},topFraction:top-0.02,bottomFraction:top+0.04,confidence:1,warnings:[]))}
 static func main()throws{
  let profile=ScoreExtractionProfile(parts:[.init(id:"a",name:"A",staffCount:1),.init(id:"b",name:"B",staffCount:1)],cropMode:"compact")
  let page=ScorePageAnalysis(pageIndex:0,pageWidth:600,pageHeight:800,imageWidth:1800,imageHeight:2400,staves:[staff(0,0.2),staff(1,0.3),staff(2,0.5),staff(3,0.6)],warnings:[])
  let plan=ScoreExtractionPlanner.plan(pages:[page],profile:profile),a=plan.bands[0],b=plan.bands[1]
  func h(_ name:String,_ anchor:Int,_ source:Int,_ box:[Double])->ScoreSharedHeading{
   var x=ScoreSharedHeading(anchorStaffID:anchor,bounds:box,recognizedText:name);x.sourceStaffID=source;x.inkBounds=[box[0]+0.001,box[1]+0.001,box[2]-0.001,box[3]-0.001];return x
  }
  let global=h("Adagio",0,0,[0.20,0.17,0.30,0.19])
  let local=h("Adagio",0,1,[0.20,0.27,0.30,0.29])
  func resolve(_ old:[ScoreSharedHeading],_ added:[ScoreSharedHeading])->[ScoreSharedHeading]{SchumannHeadingCandidate.assignRecipients(preserved:old,measured:added,page:page,profile:profile,imageSize:CGSize(width:1800,height:2400))}
  var result=resolve([global],[local])
  record("existing global source heading remains byte-for-byte metadata equal",result.first==global)
  record("same-event staff-group repeat adds no recipient copies",result.last?.recipientPartIDs==[])
  var otherPosition=local;otherPosition.bounds=[0.6,0.27,0.7,0.29];otherPosition.inkBounds=[0.601,0.271,0.699,0.289]
  result=resolve([global],[otherPosition])
  record("identical word at another musical x position still reaches other part",result.last!.recipientPartIDs!.contains("a"))
  var otherSystem=local;otherSystem.anchorStaffID=2;otherSystem.sourceStaffID=3;otherSystem.bounds=[0.2,0.57,0.3,0.59];otherSystem.inkBounds=[0.201,0.571,0.299,0.589]
  result=resolve([global],[otherSystem])
  record("identical word in a later system does not use earlier global source",result.last!.recipientPartIDs!.contains("a"))
  let first=h("Schneller",0,0,[0.2,a.topFraction+0.002,0.3,0.195])
  let second=h("Presto",0,1,[0.2,b.topFraction+0.002,0.3,0.295])
  result=resolve([],[first,second])
  record("correct own headings at the same x keep each recipient's local wording",result.allSatisfy{$0.recipientPartIDs==[]})
  var below=second;below.bounds=[0.2,0.306,0.3,0.318];below.inkBounds=[0.201,0.307,0.299,0.317]
  result=resolve([],[first,below])
  record("incidental heading below target staff top cannot substitute for a heading above it",result[0].recipientPartIDs!.contains("b"))
  var incomplete=second;incomplete.inkBounds=[0.201,b.topFraction-0.001,0.299,0.294]
  result=resolve([],[first,incomplete])
  record("partially missing own-source glyph is not complete local evidence",result[0].recipientPartIDs!.contains("b"))
  var missing=second;missing.inkBounds=nil
  record("missing source pixel evidence cannot certify local containment",resolve([],[first,missing])[0].recipientPartIDs!.contains("b"))
  var noProvenance=second;noProvenance.sourceStaffID=nil
  record("no source-staff provenance cannot certify own printed tempo",resolve([],[first,noProvenance])[0].recipientPartIDs!.contains("b"))
  var wrong=second;wrong.sourceStaffID=0
  record("another instrument's source heading cannot certify recipient's own heading",resolve([],[first,wrong])[0].recipientPartIDs!.contains("b"))
  var p=page;var targeted=global;targeted.recipientPartIDs=["b"];p.sharedHeadings=[targeted]
  let filtered=ScoreExtractionPlanner.plan(pages:[p],profile:profile)
  record("planner applies explicit recipient list",filtered.bands[0].sourceMarkings.isEmpty && filtered.bands[1].sourceMarkings.count==1)
  targeted.recipientPartIDs=[];p.sharedHeadings=[targeted]
  record("planner honors already-supplied event without an added copy",ScoreExtractionPlanner.plan(pages:[p],profile:profile).bands.allSatisfy{$0.sourceMarkings.isEmpty})
  targeted.recipientPartIDs=nil;p.sharedHeadings=[targeted]
  record("nil metadata retains historical global planner behavior",ScoreExtractionPlanner.plan(pages:[p],profile:profile).bands[1].sourceMarkings.count==1)
  record("source band geometry unchanged for recipient filtering",zip(plan.bands,filtered.bands).allSatisfy{$0.topFraction==$1.topFraction && $0.bottomFraction==$1.bottomFraction && $0.leftFraction==$1.leftFraction && $0.rightFraction==$1.rightFraction})
  let data=try JSONSerialization.data(withJSONObject:checks,options:[.prettyPrinted,.sortedKeys]);print(String(decoding:data,as:UTF8.self));if checks.contains(where:{$0["passed"] as? Bool != true}){exit(1)}
 }
}
