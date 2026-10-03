import Foundation
import AppKit
import PDFKit
import CryptoKit
@main enum IndependentReview {
 static let out=URL(fileURLWithPath:".build/generated-rest-heading-review-2026-10-03")
 static var checks:[[String:Any]]=[]
 static func check(_ ok:Bool,_ name:String) {checks.append(["passed":ok,"name":name])}
 static func staff(_ i:Int,_ y:Double)->ScoreObservedStaff {ScoreObservedStaff(StaffBandCandidate(id:i,staffLineFractions:(0..<5).map{y+Double($0)*0.005},topFraction:y-0.02,bottomFraction:y+0.04,confidence:1,warnings:[]))}
 static func source()->Data {
  let d=NSMutableData();var media=CGRect(x:0,y:0,width:600,height:800)
  let c=CGContext(consumer:CGDataConsumer(data:d)!,mediaBox:&media,nil)!
  c.beginPDFPage(nil);c.setFillColor(NSColor.white.cgColor);c.fill(media)
  c.setFillColor(NSColor.blue.cgColor);c.fill(CGRect(x:72,y:800-172,width:144,height:8))
  c.setFillColor(NSColor.green.cgColor);c.fill(CGRect(x:330,y:800-172,width:138,height:8))
  c.endPDFPage();c.closePDF();return d as Data
 }
 static func raster(_ data:Data)->Data {
  let pdf=PDFDocument(data:data)!,p=pdf.page(at:0)!,b=p.bounds(for:.mediaBox)
  let c=CGContext(data:nil,width:Int(b.width),height:Int(b.height),bitsPerComponent:8,bytesPerRow:Int(b.width)*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  c.setFillColor(gray:1,alpha:1);c.fill(b);withExtendedLifetime(pdf){p.draw(with:.mediaBox,to:c)}
  return Data(bytes:c.data!,count:Int(b.width*b.height)*4)
 }
 static func main()throws {
  let source=source();try source.write(to:out.appendingPathComponent("source.pdf"))
  let profile=ScoreExtractionProfile(parts:[.init(id:"voice",name:"Voice",staffCount:1),.init(id:"piano",name:"Piano",staffCount:2),.init(id:"violin",name:"Violin",staffCount:1)],requiresSystemAssignment:true)
  var page=ScorePageAnalysis(pageIndex:0,pageWidth:600,pageHeight:800,imageWidth:1800,imageHeight:2400,staves:[staff(0,0.2),staff(1,0.3),staff(2,0.4),staff(3,0.6),staff(4,0.65),staff(5,0.7),staff(6,0.8)],warnings:[])
  var correction:ScorePageOverride?
  correction=try ScoreSystemAssignment.assign(page:page,profile:profile,pagePlan:nil,existingOverride:nil,systemIndex:0,candidateIDs:[0,1,2],presentPartIDs:["piano","violin"],startBarNumber:1,barCount:12)
  correction=try ScoreSystemAssignment.assign(page:page,profile:profile,pagePlan:nil,existingOverride:correction,systemIndex:1,candidateIDs:[3,4,5,6],presentPartIDs:["voice","piano","violin"],startBarNumber:13,barCount:4)
  let plain=ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[correction!])
  check(plain.canApply && plain.bands.count==6,"Reviewed variable layout yields all six rows")
  guard let binding=ScoreExtractionPlanner.headingRecognitionBinding(page:page,plan:plain,anchorStaffID:0) else {fatalError("Valid generated-rest system has no heading binding")}
  check(binding.assignments.first{$0.partID=="voice"}?.kind=="generated-rest","Binding includes silent recipient kind")
  check(binding.staves.map(\.id)==[0,1,2],"Binding contains only actual physical staves")
  page.sharedHeadings=[
   .init(anchorStaffID:0,bounds:[0.12,0.205,0.36,0.215],recognizedText:"Inside anchor",recognitionBinding:binding),
   .init(anchorStaffID:0,bounds:[0.55,0.18,0.78,0.23],recognizedText:"Measured ink inside anchor",inkBounds:[0.55,0.205,0.78,0.215],recognitionBinding:binding)]
  func planned(_ p:ScorePageAnalysis?=nil,_ o:ScorePageOverride?=nil)->ScoreExtractionPlan {ScoreExtractionPlanner.plan(pages:[p ?? page],profile:profile,overrides:[o ?? correction!])}
  let plan=planned(),restID="p1-s1-voice"
  func rest(_ p:ScoreExtractionPlan)->ScorePlannedBand {p.bands.first{$0.id==restID}!}
  check(rest(plan).sourceMarkings.count==2,"Rest receives both fully contained and ink-only-contained source headings")
  check(plan.bands.first{$0.id=="p1-s1-violin"}!.sourceMarkings.count==2,"Printed recipient also receives headings in a mixed silent system")
  check(plan.bands.filter{$0.systemIndex==1}.allSatisfy{$0.sourceMarkings.isEmpty},"Nothing is copied to later system")
  check(rest(plan).generatedRest==rest(plain).generatedRest,"Heading copies cannot alter the 12-bar rest")
  for mutation in 0..<8 {
   var bad=plain;let i=bad.pages[0].assignments.firstIndex{$0.id==restID}!
   switch mutation {
    case 0:bad.pages[0].assignments[i].generatedRest=nil
    case 1:bad.pages[0].assignments[i].generatedRest!.barCount=0
    case 2:bad.pages[0].assignments[i].generatedRest!.startBarNumber=0
    case 3:bad.pages[0].assignments[i].generatedRest!.startBarNumber=Int.max
    case 4:bad.pages[0].assignments[i].candidateIDs=[2]
    case 5:bad.pages[0].assignments[i].kind="music"
    case 6:bad.pages[0].assignments[i].kind="cue"
    default:bad.pages[0].assignments[i].partID="piano"
   }
   check(ScoreExtractionPlanner.headingRecognitionBinding(page:page,plan:bad,anchorStaffID:0)==nil,"Malformed generated assignment \(mutation) cannot bind")
  }
  var badMusic=plain;let printed=badMusic.pages[0].assignments.firstIndex{$0.id=="p1-s1-piano"}!
  badMusic.pages[0].assignments[printed].generatedRest = .init(barCount:12,startBarNumber:1)
  check(ScoreExtractionPlanner.headingRecognitionBinding(page:page,plan:badMusic,anchorStaffID:0)==nil,"Music with contradictory rest payload cannot bind")
  var stale=correction!
  stale.systems[0].bands.firstIndex{$0.partID=="violin"}.map{stale.systems[0].bands[$0].partID="voice"}
  stale.systems[0].omittedParts![0].partID="violin"
  let changed=planned(nil,stale)
  check(changed.canApply && changed.bands.allSatisfy{$0.sourceMarkings.isEmpty},"Changing rest recipient and printed owner drops stale heading copies")
  var shifted=page;shifted.staves[0].staffLineFractions=shifted.staves[0].staffLineFractions.map{$0+0.001}
  check(planned(shifted).bands.allSatisfy{$0.sourceMarkings.isEmpty},"Changed physical source geometry drops stale copies")
  var timing=correction!;timing.systems[0].barCount=11
  check(rest(planned(nil,timing)).sourceMarkings.count==2 && rest(planned(nil,timing)).generatedRest?.barCount==11,"Changing only reviewed duration keeps source heading at the same physical system")
  let materialized=ScoreSystemAssignment.pageOverride(page:page,pagePlan:plan.pages[0],existingOverride:nil)
  check(rest(planned(nil,materialized)).sourceMarkings==rest(plan).sourceMarkings,"No-op materialization preserves automatic silence copies")
  var review=ScoreDetectionReview(profile:profile,analyses:[page],plan:plan,overrides:[correction!],selectedPageIndices:[0],sourcePDFData:source,rectifications:[])
  try review.setCropEdges(for:"p1-s1-violin",top:295,bottom:360)
  check(rest(review.plan).sourceMarkings==rest(plan).sourceMarkings,"Actual printed crop edit preserves silent-part copies")
  var removed=review;var removalError:String?
  do {try removed.removeSourceMarking(from:restID,at:0)} catch {removalError=error.localizedDescription}
  check(removalError==nil && rest(removed.plan).sourceMarkings.count==1,"Actual Remove Copy works for generated rest")
  var invalidated=review;invalidated.invalidateAutomaticDirections(on:0)
  check(invalidated.plan.canApply && invalidated.plan.bands.allSatisfy{$0.sourceMarkings.isEmpty},"Invalidation removes automatic rest and printed copies after a crop edit")
  var canceled=review
  let cancelled=ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[correction!],isCancelled:{true})
  check(!cancelled.canApply,"Cancelled planning cannot apply source copies")
  canceled.replan();check(rest(canceled.plan).sourceMarkings==rest(review.plan).sourceMarkings,"Repeated unchanged review deterministic")
  let document=PartsmithDocument(sourcePDFData:source);document.project.pageCount=1
  check(document.addScoreParts(from:review)==6,"Actual Add Parts accepts mixed music/rest headings")
  let voice=document.project.parts.first{$0.name=="Voice"}!,band=document.project.bands.first{$0.partID==voice.id && $0.generatedRest != nil}!
  check(band.sourceMarkings.count==2,"Applied project stores both rest source copies")
  var project=document.project;project.bands=[band]
  let reopened=try JSONDecoder().decode(ProjectData.self,from:JSONEncoder().encode(project))
  check(reopened==project,"Project codec retains source copies and generated rest")
  let layout=try PartLayoutEngine.makePlan(project:reopened,pageBoundsProvider:{_ in CGRect(x:0,y:0,width:600,height:800)},partID:voice.id)
  let placement=layout.pages[0].placements[0]
  check(placement.sourceMarkings.count==2 && placement.sourceMarkings.allSatisfy{!$0.destinationRect.intersects(placement.destinationRect)},"Layout keeps both copies clear of the rest")
  let exported=try PartPDFExporter.pdfData(for:voice.id,project:reopened,sourcePDFData:source);try exported.write(to:out.appendingPathComponent("voice-rest-headings.pdf"))
  let bytes=raster(exported)
  func blue(_ d:Data)->Int {stride(from:0,to:d.count,by:4).filter{d[$0]<80 && d[$0+1]<80 && d[$0+2]>180}.count}
  func green(_ d:Data)->Int {stride(from:0,to:d.count,by:4).filter{d[$0]<80 && d[$0+1]>180 && d[$0+2]<80}.count}
  check(blue(bytes)>100 && green(bytes)>100,"Actual exported rest renders both distinct source-ink copies")
  var noCopies=reopened;noCopies.bands[0].sourceMarkings=[]
  let without=raster(try PartPDFExporter.pdfData(for:voice.id,project:noCopies,sourcePDFData:source))
  check(blue(without)==0 && green(without)==0,"Generated rest never prints the colored anchor itself")

  removed.replan()
  check(rest(removed.plan).sourceMarkings.count==1,"Removed rest copy stays removed after replanning")
  check(removed.plan.bands.first{$0.id=="p1-s1-violin"}!.sourceMarkings.count==2,"Removing rest copy does not edit printed recipient")
  var allRemoved=removed
  do {try allRemoved.removeSourceMarking(from:restID,at:0)} catch {}
  allRemoved.replan()
  check(rest(allRemoved.plan).sourceMarkings.isEmpty,"Removing final rest copy persists explicit empty list")
  var removalThenStale=removed;removalThenStale.invalidateAutomaticDirections(on:0)
  check(rest(removalThenStale.plan).sourceMarkings.isEmpty,"Remaining automatic rest copy clears after Remove Copy then invalidation")
  var unchanged=removed;let beforeInvalid=unchanged.plan,overridesBeforeInvalid=unchanged.overrides
  do {try unchanged.removeSourceMarking(from:restID,at:99);check(false,"Invalid removal fails atomically")} catch {check(unchanged.plan==beforeInvalid && unchanged.overrides==overridesBeforeInvalid,"Invalid removal fails atomically")}
  let reconfirm=try ScoreSystemAssignment.assign(page:page,profile:profile,pagePlan:removed.plan.pages[0],existingOverride:removed.overrides[0],systemIndex:0,candidateIDs:[0,1,2],presentPartIDs:["piano","violin"],startBarNumber:1,barCount:12)
  check(rest(planned(nil,reconfirm)).sourceMarkings==rest(removed.plan).sourceMarkings,"Reconfirming unchanged silence preserves explicit removal")
  for below in [false,true] {
   var manual=correction!;manual.systems[0].omittedParts![0].sourceMarkings=[[72,164,216,172]];manual.systems[0].omittedParts![0].sourceMarkingsBelow=[below]
   var manualReview=ScoreDetectionReview.initial(profile:profile,analyses:[page],overrides:[manual],sourcePDFData:source,rectifications:[])
   check(rest(manualReview.plan).sourceMarkings.count==1 && (rest(manualReview.plan).sourceMarkings[0].isBelow==true)==below,"Explicit omission list remains authoritative, below=\(below)")
   manualReview.invalidateAutomaticDirections(on:0)
   check(rest(manualReview.plan).sourceMarkings.count==1 && (rest(manualReview.plan).sourceMarkings[0].isBelow==true)==below,"Manual omission copy survives invalidation even when rectangle equals automatic heading, below=\(below)")
  }
  for otherCategory in [false,true] {
   var pages=[page,page];pages[0].sharedHeadings=nil;pages[1].pageIndex=1;pages[1].sharedHeadings=nil
   let members:[ScoreEndingMember]=[
    .init(sourcePageIndex:0,sourceSystemIndex:0,anchorStaffID:0,bounds:[0.8,0.14,0.92,0.16],role:.first,evidence:[]),
    .init(sourcePageIndex:1,sourceSystemIndex:0,anchorStaffID:0,bounds:[0.5,0.14,0.65,0.16],role:.second,evidence:[])]
   for i in 0..<2 {pages[i].sharedEndings=[.init(sourcePageIndex:i,anchorStaffID:0,systemIndex:0,bounds:members[i].bounds,members:members)]}
   var secondOverride=correction!;secondOverride.pageIndex=1
   let ovs=[correction!,secondOverride]
   if otherCategory {
    let preliminary=ScoreExtractionPlanner.plan(pages:pages,profile:profile,overrides:ovs)
    let secondBinding=ScoreExtractionPlanner.headingRecognitionBinding(page:pages[1],plan:preliminary,anchorStaffID:0)!
    pages[1].sharedHeadings=[.init(anchorStaffID:0,bounds:members[1].bounds,recognizedText:"Coincident heading",recognitionBinding:secondBinding)]
   }
   var linked=ScoreDetectionReview.initial(profile:profile,analyses:pages,overrides:ovs,sourcePDFData:Data(),rectifications:[])
   let partnerID="p2-s1-voice",partnerBefore=linked.plan.bands.first{$0.id==partnerID}!
   check(partnerBefore.sourceMarkings.count==1,"Cross-page ending fixture copies to silent partner, shared category=\(otherCategory)")
   linked.overrides[1]=ScoreSystemAssignment.pageOverride(page:pages[1],pagePlan:linked.plan.pages[1],existingOverride:nil)
   linked.replan();linked.invalidateAutomaticDirections(on:0)
   let after=linked.plan.bands.first{$0.id==partnerID}!
   check(linked.analyses[1].sharedEndings==nil && after.sourceMarkings.count==(otherCategory ? 1:0),"Linked ending cleanup honors silent recipient category ownership, shared category=\(otherCategory)")
  }
  var trimmed=profile;trimmed.leftTrimPoints=100;trimmed.rightTrimPoints=100
  var explicitTrim=correction!;explicitTrim.systems[0].omittedParts![0].sourceMarkings=[[20,145,80,155],[530,145,580,155]]
  let trimmedPlan=ScoreExtractionPlanner.plan(pages:[page],profile:trimmed,overrides:[explicitTrim])
  var trimReview=ScoreDetectionReview.initial(profile:trimmed,analyses:[page],overrides:[explicitTrim],sourcePDFData:source,rectifications:[])
  let trimDocument=PartsmithDocument(sourcePDFData:source);trimDocument.project.pageCount=1
  check(trimmedPlan.canApply && rest(trimmedPlan).leftFraction==20.0/600 && rest(trimmedPlan).rightFraction==1-580.0/600,"Explicit silence directions expand the unprinted anchor span")
  check(trimDocument.addScoreParts(from:trimReview)==6,"Page-valid omission direction outside profile trims remains applicable")

  let output:[String:Any]=["checks":checks,"count":checks.count,"failures":checks.filter{$0["passed"] as? Bool != true}.count,"removalError":removalError ?? "none","bluePixels":blue(bytes),"greenPixels":green(bytes)]
  try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("results.json"))
  print(String(data:try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
 }
}
