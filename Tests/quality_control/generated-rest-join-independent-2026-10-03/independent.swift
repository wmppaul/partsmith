import Foundation
import AppKit
import PDFKit
struct Envelope:Codable { var project:ProjectData }
@main struct Run {
 static var observations:[[String:Any]]=[]
 static func check(_ label:String,_ value:Bool) {observations.append(["label":label,"pass":value]);if !value{print("FAIL",label)}}
 static func placements(_ p:ProjectData,_ part:UUID?=nil) throws->[BandPlacement] {try PartLayoutEngine.makePlan(project:p,pageBoundsProvider:{_ in CGRect(x:0,y:0,width:600,height:840)},partID:part ?? p.parts[0].id).pages.flatMap(\.placements)}
 static func counts(_ p:ProjectData)throws->[Int] {try placements(p).map{$0.restBarCount ?? -1}}
 static func fixture(_ n:Int=4)->ProjectData {
  var p=ProjectData.empty;p.pageCount=2;p.createdAt=Date(timeIntervalSince1970:0);p.modifiedAt=p.createdAt
  p.parts=[PartModel(id:UUID(),name:"Voice",color:ColorData(red:0,green:0,blue:1),layoutSettings:.default,createdAt:Date(timeIntervalSince1970:0))]
  p.bands=[]
  for i in 0..<n {
   let top=0.15+Double(i%2)*0.35
   let bottom=0.3+Double(i%2)*0.35
   let flag:Bool? = i > 0 ? true : nil
   let rest=BandGeneratedRest(barCount:3,startBarNumber:1+3*i,sourceSystemIndex:i%2,joinWithPrevious:flag)
   let band=BandModel(id:UUID(),pageIndex:i/2,partID:p.parts[0].id,topFraction:top,bottomFraction:bottom,leftFraction:0.03,rightFraction:0.03,excluded:false,createdAt:Date(timeIntervalSince1970:Double(i)),generatedRest:rest)
   p.bands.append(band)
  }
  return p
 }
 static func main()throws {
  let dir=CommandLine.arguments[1];let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];encoder.dateEncodingStrategy = .iso8601;let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
  let stored=try Data(contentsOf:URL(fileURLWithPath:dir+"/baseline-project.json"));let original=try decoder.decode(Envelope.self,from:stored).project;let pdf=PDFDocument(url:URL(fileURLWithPath:dir+"/source.pdf"))!
  func actual(_ p:ProjectData,_ part:UUID)throws->[BandPlacement] {
   try PartLayoutEngine.makePlan(project:p,pageBoundsProvider:{ index in pdf.page(at:index)?.bounds(for:.mediaBox) },partID:part).pages.flatMap(\.placements)
  }
  let voice=original.parts.first{$0.name=="Voice"}!.id;let piano=original.parts.first{$0.name=="Piano"}!.id
  let oldRows=try actual(original,voice);let oldPiano=try actual(original,piano);let rests=original.sortedBands(for:voice).filter{$0.generatedRest != nil};check("Real source has four exactly numbered three-bar omitted Voice systems",rests.map{$0.generatedRest!.barCount}==[3,3,3,3] && rests.map{$0.generatedRest!.startBarNumber!}==[1,4,7,10]);check("Legacy preferences remain unjoined on reopening",rests.allSatisfy{$0.generatedRest?.joinWithPrevious==nil} && oldRows.filter{$0.generatedRest != nil}.count==4)
  var candidate=original
  for b in rests.dropFirst(){let i=candidate.bands.firstIndex{$0.id==b.id}!;candidate.bands[i].generatedRest?.joinWithPrevious=true}
  candidate.bands[candidate.bands.firstIndex{$0.id==rests[0].id}!].editorialLabel="[4/4]"
  let before=try encoder.encode(candidate);let joined=try actual(candidate,voice);let first=joined[0]
  check("Real combined introduction is exactly bars1–12",first.restBarCount==12 && first.generatedRest?.startBarNumber==1 && first.generatedRest?.endBarNumber==12)
  check("Real combined introduction retains all four original references",first.sourceBandIDs==rests.map(\.id))
  check("Original source interval records remain four separate unchanged counts",candidate.bands.filter{$0.generatedRest != nil}.map{$0.generatedRest!.barCount}==original.bands.filter{$0.generatedRest != nil}.map{$0.generatedRest!.barCount})
  check("Layout does not mutate any project metadata",try encoder.encode(candidate)==before)
  check("Editorial meter stays with opening rest",first.editorialLabel=="[4/4]" && first.editorialLabelRect != nil)
  check("Opening Schnell retains exact source rectangle and page",first.sourceMarkings.map(\.sourceRect)==oldRows[0].sourceMarkings.map(\.sourceRect) && first.sourcePageIndex==oldRows[0].sourcePageIndex && first.sourceMarkings.count==1 && !first.sourceMarkings[0].isBelow)
  let oldMusic=oldRows.filter{$0.generatedRest==nil};let newMusic=joined.filter{$0.generatedRest==nil}
  check("Every printed Voice strip including written bars13–15 retains source order and pixels",oldMusic.map(\.bandID)==newMusic.map(\.bandID) && zip(oldMusic,newMusic).allSatisfy{$0.sourceRect==$1.sourceRect && $0.sourcePageIndex==$1.sourcePageIndex && $0.sourceMarkings.map(\.sourceRect)==$1.sourceMarkings.map(\.sourceRect)})
  let afterPiano=try actual(candidate,piano);check("All Piano placements remain exact",zip(oldPiano,afterPiano).allSatisfy{$0.bandID==$1.bandID && $0.sourceRect==$1.sourceRect && $0.destinationRect==$1.destinationRect} && oldPiano.count==afterPiano.count)
  let restored=try decoder.decode(ProjectData.self,from:encoder.encode(candidate));let restoredRows=try actual(restored,voice);check("Opted real project reopens without losing any original band or duration",restored==candidate && restoredRows.first?.sourceBandIDs==rests.map(\.id))
  var reordered=candidate;reordered.bands.reverse();check("Array storage order cannot change joined source provenance",try actual(reordered,voice).map(\.sourceBandIDs)==joined.map(\.sourceBandIDs))
  let cue=BandSourceMarking(topFraction:0.04,bottomFraction:0.07,leftFraction:0.15,rightFraction:0.55)
  var split=fixture();split.bands[0].sourceMarkings=[cue];split.bands[0].editorialLabel="[4/4]";split.bands[2].sourceMarkings=[cue];split.bands[2].editorialLabel="New tempo"
  let two=try placements(split);check("An internal direction creates exact6+6 segments",two.map{$0.restBarCount!}==[6,6] && two.map{$0.generatedRest!.startBarNumber!}==[1,7]);check("Each segment retains its own source-page direction",two.map(\.sourcePageIndex)==[0,1] && two.allSatisfy{$0.sourceMarkings.count==1} && two.map(\.editorialLabel)==["[4/4]","New tempo"])
  check("Each segment owns only its original interval records",two[0].sourceBandIDs==split.bands.prefix(2).map(\.id) && two[1].sourceBandIDs==split.bands.suffix(2).map(\.id))
  var below=fixture();var tail=cue;tail.isBelow=true;below.bands[2].sourceMarkings=[tail];check("Direction after bar9 preserves its boundary on both sides",try counts(below)==[6,3,3]);let br=try placements(below);check("Below direction stays on original bar7–9 interval",br[1].sourceBandIDs==[below.bands[2].id] && br[1].sourceMarkings[0].isBelow)
  var turn=fixture();turn.bands[2].pageBreakBefore=true;let turnPlan=try PartLayoutEngine.makePlan(project:turn,pageBoundsProvider:{_ in CGRect(x:0,y:0,width:600,height:840)},partID:turn.parts[0].id);check("A page-break boundary divides6+6 without creating extra duration",turnPlan.pages.count==2 && turnPlan.pages.map{$0.placements[0].restBarCount!}==[6,6] && turnPlan.pages[1].placements[0].sourceBandIDs==turn.bands.suffix(2).map(\.id))
  var hidden=fixture(3);hidden.bands[1].generatedRest=nil;hidden.bands[1].excluded=true;hidden.bands[2].generatedRest?.startBarNumber=4;check("Excluded intervening printed cue cannot be bridged despite adjacent numbers",try counts(hidden)==[3,3])
  for reverse in [false,true] {var mixed=fixture(2);let i=reverse ? 1:0;mixed.bands[i].generatedRest=nil;mixed.bands[i].restReplacement=BandRestReplacement(barCount:3,joinWithPrevious:true);mixed.bands[i].barNumberValue=i*3+1;check("Printed-rest replacement and omitted-staff rest remain distinct order\(reverse)",try placements(mixed).count==2)}
  var one=fixture(3);for i in one.bands.indices{one.bands[i].generatedRest?.barCount=1;one.bands[i].generatedRest?.startBarNumber=i+1};check("Three confirmed one-bar omissions combine to exactly3",try counts(one)==[3])
  var cap=fixture(3);cap.bands[0].generatedRest?.barCount=998;cap.bands[1].generatedRest?.barCount=1;cap.bands[1].generatedRest?.startBarNumber=999;cap.bands[2].generatedRest?.barCount=1;cap.bands[2].generatedRest?.startBarNumber=1000;check("999 limit preserves the final one-bar interval",try counts(cap)==[999,1])
  for n in [1,2,999] {let edge=BandGeneratedRest(barCount:n,startBarNumber:Int.max-(n-1),sourceSystemIndex:0);check("Valid\(n)-bar interval endingInt.max is nonoverflowing",edge.isValid && edge.endBarNumber==Int.max)}
  var maxJoin=fixture(2);maxJoin.bands[0].generatedRest=BandGeneratedRest(barCount:998,startBarNumber:Int.max-998,sourceSystemIndex:0);maxJoin.bands[1].generatedRest=BandGeneratedRest(barCount:1,startBarNumber:Int.max,sourceSystemIndex:1,joinWithPrevious:true);let atMax=try placements(maxJoin);check("A legal join can end exactlyInt.max",atMax.count==1 && atMax[0].restBarCount==999 && atMax[0].generatedRest?.endBarNumber==Int.max)
  var explicitFalse=fixture();for i in explicitFalse.bands.indices{explicitFalse.bands[i].generatedRest?.joinWithPrevious=false};let falseRoundtrip=try decoder.decode(ProjectData.self,from:encoder.encode(explicitFalse));let falseRows=try placements(falseRoundtrip);check("Explicitfalse remains nonjoining through full codec",falseRoundtrip==explicitFalse && falseRows.count==4)
  let doc=PartsmithDocument(project:fixture());let beforeBad=doc.project;let target=doc.project.bands[0].id
  for invalid in [0,-1,1000,Int.max]{check("Invalid count\(invalid) leaves full document untouched",!doc.updateBandGeneratedRest(target,barCount:invalid,joinWithPrevious:true) && doc.project==beforeBad)}
  check("Unknown band cannot alter a document",!doc.updateBandGeneratedRest(UUID(),barCount:3,joinWithPrevious:true) && doc.project==beforeBad)
  let out:[String:Any]=["checks":observations,"passed":observations.filter{($0["pass"] as? Bool)==true}.count,"total":observations.count,"realVoiceBeforeRows":oldRows.count,"realVoiceAfterRows":joined.count,"realOriginalBands":original.bands.count,"realIntroSourceIDs":rests.map{$0.id.uuidString},"realJoinedDirectionSourceRect":NSStringFromRect(first.sourceMarkings[0].sourceRect),"firstPrintedSourceID":newMusic.first!.bandID.uuidString]
  try JSONSerialization.data(withJSONObject:out,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:dir+"/independent-results.json"));try encoder.encode(candidate).write(to:URL(fileURLWithPath:dir+"/independent-candidate-project.json"));print(observations.count,"independent checks",observations.filter{($0["pass"] as? Bool)==true}.count,"passed")
  if observations.contains(where:{($0["pass"] as? Bool)==false}){exit(1)}
 }
}
