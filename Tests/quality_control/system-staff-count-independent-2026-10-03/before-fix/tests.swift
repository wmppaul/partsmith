import Foundation
import CoreGraphics
import ImageIO

@main enum IndependentStaffCounts {
 static var records:[[String:Any]]=[]
 static func check(_ yes:Bool,_ name:String){records.append(["name":name,"passed":yes]);print(yes ? "PASS" : "FAIL",name)}
 static func rejects(_ name:String,_ body:()throws->Void){do{try body();check(false,name)}catch{check(true,name)}}
 static func main() throws {
  let dir=CommandLine.arguments[1]
  let image=CGImageSourceCreateWithURL(URL(fileURLWithPath:dir+"/three-staff-systems.png") as CFURL,nil).flatMap{CGImageSourceCreateImageAtIndex($0,0,nil)}!
  let detected=StaffBandDetector.detect(in:image)
  check(detected.candidates.count==9,"Original fixture has exactly nine independently detected staves")
  guard detected.candidates.count==9 else{try finish(dir);return}
  let ids=[90,4,81,6,55,12,70,2,33]
  let staves=detected.candidates.enumerated().map{i,c in
   ScoreObservedStaff(StaffBandCandidate(id:ids[i],staffLineFractions:c.staffLineFractions,topFraction:c.topFraction,bottomFraction:c.bottomFraction,confidence:c.confidence,warnings:c.warnings))
  }
  let page=ScorePageAnalysis(pageIndex:0,pageWidth:600,pageHeight:800,imageWidth:image.width,imageHeight:image.height,staves:staves,warnings:[])
  let profile=ScoreExtractionProfile(parts:[ScorePartDefinition(id:"soprano",name:"Soprano",staffCount:1),ScorePartDefinition(id:"bass",name:"Bass",staffCount:2)],requiresSystemAssignment:true)
  let present:Set<String>=["soprano","bass"]
  func assign(_ system:Int,_ counts:[String:Int]=[:],_ old:ScorePageOverride?=nil)throws->ScorePageOverride{
   try ScoreSystemAssignment.assign(page:page,profile:profile,pagePlan:nil,existingOverride:old,systemIndex:system,candidateIDs:Array(ids[(system*3)..<(system*3+3)]).reversed(),presentPartIDs:present,startBarNumber:nil,barCount:nil,staffCounts:counts)
  }
  var first=try assign(0)
  check(first.systems[0].bands[0].candidateIDs==[90] && first.systems[0].bands[1].candidateIDs==[4,81],"Default grouping uses physical order, not numeric candidate IDs")
  let explicit=try assign(0,["soprano":1,"bass":2]);check(first==explicit,"Explicit global defaults are exactly equivalent")
  first.systems[0].bands[0].rect=[0,40,600,115]
  first.systems[0].bands[0].sourceMarkings=[[30,20,90,32]]
  first.systems[0].bands[0].pageBreakBefore=true
  let reconfirm=try assign(0,["soprano":1],first)
  check(reconfirm==first,"Partial counts keep other defaults and preserve existing crop/copies/break")
  let regroup=try assign(0,["soprano":2,"bass":1],first)
  check(regroup.systems[0].bands[0].candidateIDs==[90,4] && regroup.systems[0].bands[1].candidateIDs==[81],"Local two-plus-one groups exact original staves")
  check(regroup.systems[0].bands.allSatisfy{$0.rect==nil && $0.sourceMarkings==nil},"Regrouped ownership cannot inherit old one-staff crop or source list")
  let seeded=try assign(1,["soprano":2,"bass":1],first)
  check(seeded.systems[0]==first.systems[0],"Assigning a different count in another system preserves edited seed exactly")
  let roundtrip=try JSONDecoder().decode(ScorePageOverride.self,from:JSONEncoder().encode(seeded))
  check(roundtrip==seeded,"Saved existing override schema preserves per-system grouping")
  let review=ScoreDetectionReview.initial(profile:profile,analyses:[page],overrides:[seeded],selectedPageIndices:[0],sourcePDFData:Data("independent-fixture".utf8),rectifications:[])
  let choice=ScoreSystemAssignmentChoice(pageIndex:0,systemIndex:2,candidateIDs:[33,70,2],presentPartIDs:present,startBarNumber:nil,barCount:nil,staffCounts:["soprano":2,"bass":1])
  let applied=try ScoreSystemAssignmentBatch.applying([choice],to:review)
  check(applied.plan.canApply && applied.plan.bands.count==6,"Batch and crop planner cover all variable-count source systems")
  check(applied.plan.bands.first{$0.systemIndex==2 && $0.partID=="soprano"}?.candidateIDs==[70,2],"Batch carries local count into planned multi-staff band")
  check(applied.profile==profile && applied.analyses==review.analyses && applied.sourcePDFData==review.sourcePDFData,"Local count does not mutate profile, detector evidence or source")
  check(applied.overrides[0].systems[0]==first.systems[0],"Batch preserves old manually reviewed source crop")
  rejects("Stale result cannot replace an already applied local grouping"){_ = try ScoreSystemAssignmentBatch.applying([choice],to:applied)}
  let empty=ScoreDetectionReview.initial(profile:profile,analyses:[page],overrides:[],selectedPageIndices:[0],sourcePDFData:Data(),rectifications:[])
  let good=ScoreSystemAssignmentChoice(pageIndex:0,systemIndex:0,candidateIDs:[90,4,81],presentPartIDs:present,startBarNumber:nil,barCount:nil,staffCounts:["soprano":1,"bass":2])
  for counts in [["soprano":0],["soprano":5],["soprano":Int.min],["soprano":Int.max],["absent":1],["soprano":2],["soprano":4,"bass":1]]{
   var bad=choice;bad.staffCounts=counts
   rejects("Late invalid local count rejects atomic batch: \(counts)"){_ = try ScoreSystemAssignmentBatch.applying([good,bad],to:empty)}
   check(empty.overrides.isEmpty,"Invalid batch leaves caller review empty: \(counts)")
  }
  var calls=0
  rejects("Cancellation after a local assignment prevents result publication"){
   _ = try ScoreSystemAssignmentBatch.applying([good,choice],to:empty,isCancelled:{calls += 1;return calls>=5})
  }
  check(empty.overrides.isEmpty,"Cancellation leaves caller unchanged")
  func match(_ overrides:[ScorePageOverride],_ p:ScoreExtractionProfile=profile,_ cancel:()->Bool={false})->ScoreSystemTemplateMatcher.Result{
   ScoreSystemTemplateMatcher.suggest(pages:[page],profile:p,reviewedOverrides:overrides,imageForPage:{_ in image},isCancelled:cancel)
  }
  let ambiguous=match([seeded]);let target=ambiguous.suggestions.filter{$0.systemIndex==2}
  check(target.count==2,"Same roster with one-plus-two and two-plus-one yields two target alternatives")
  check(target.allSatisfy{$0.confidence == .needsReview},"Identical clefs cannot auto-select between distinct count groupings")
  check(Set(target.map{[$0.staffCounts["soprano"] ?? -1,$0.staffCounts["bass"] ?? -1]})==Set([[1,2],[2,1]]),"Every ambiguous suggestion carries the exact count layout")
  check(target.allSatisfy{$0.candidateIDs==[70,2,33] && $0.startBarNumber==nil && $0.barCount==nil && !$0.requiresMeasureCount},"Suggestions preserve complete physical source grouping without invented timing")
  let same=try assign(1,["soprano":1,"bass":2],first)
  let dedup=match([same]);check(dedup.suggestions.count==1 && dedup.suggestions[0].staffCounts==["soprano":1,"bass":2],"Multiple same-count examples deduplicate into one target layout")
  check(dedup.suggestions.first?.confidence == .sourceSupported,"Exact raster match with unambiguous counts remains supported")
  var reordered=seeded;reordered.systems.reverse()
  check(match([reordered])==ambiguous,"Input system order does not change ambiguity, IDs or scores")
  var stale=seeded;stale.systems[1].requiresAssignmentReview=true
  let remaining=match([stale]);check(remaining.suggestions.filter{$0.systemIndex==2}.count==1 && remaining.suggestions.filter{$0.systemIndex==2}.first?.staffCounts==["soprano":1,"bass":2],"Unresolved alternate grouping is not learned as a reviewed template")
  var malformed=first;malformed.systems[0].bands[0].candidateIDs=[90,4,81,6,55];malformed.systems[0].bands[1].candidateIDs=[12]
  check(match([malformed]).suggestions.isEmpty,"More than four staves for one part cannot become a template")
  var overlap=first;overlap.systems[0].bands[1].candidateIDs=[90,81]
  check(match([overlap]).suggestions.isEmpty,"A local grouping cannot reuse one physical staff twice")
  let cancelled=match([seeded],profile,{true});check(cancelled.cancelled && cancelled.suggestions.isEmpty,"Matcher immediate cancellation returns no count choices")
  var cancelCount=0
  let interrupted=match([seeded],profile,{cancelCount += 1;return cancelCount>5});check(interrupted.cancelled && interrupted.suggestions.isEmpty,"Matcher phase cancellation cannot publish partial count choices")
  var three=profile;three.parts.append(ScorePartDefinition(id:"alto",name:"Alto",staffCount:1))
  var withAbsent=seeded
  for i in withAbsent.systems.indices {withAbsent.systems[i].omittedParts=[ScorePartOmission(partID:"alto",reason:"Known missing staff")];withAbsent.systems[i].barCount=9;withAbsent.systems[i].startBarNumber=100}
  let absentMatches=match([withAbsent],three).suggestions.filter{$0.systemIndex==2}
  check(absentMatches.count==2 && absentMatches.allSatisfy{$0.requiresMeasureCount && $0.staffCounts["alto"]==nil && $0.barCount==nil && $0.startBarNumber==nil},"Local count templates retain omissions but never clone reviewed silent duration")
  var absentChoice=choice;absentChoice.barCount=3
  let absentReview=ScoreDetectionReview.initial(profile:three,analyses:[page],overrides:[withAbsent],selectedPageIndices:[0],sourcePDFData:Data(),rectifications:[])
  let restApplied=try ScoreSystemAssignmentBatch.applying([absentChoice],to:absentReview)
  check(restApplied.plan.bands.first{$0.systemIndex==2 && $0.partID=="alto"}?.generatedRest?.barCount==3,"Explicit target duration, not template nine bars, creates missing-part rest")
  var countForAbsent=absentChoice;countForAbsent.staffCounts["alto"]=1
  rejects("Absent part cannot receive a hidden staff-count override"){_ = try ScoreSystemAssignmentBatch.applying([countForAbsent],to:absentReview)}
  // Same total source group with a different present roster must stay separate.
  var otherRoster=withAbsent
  otherRoster.systems[1].bands=[ScoreBandOverride(partID:"soprano",candidateIDs:[6]),ScoreBandOverride(partID:"alto",candidateIDs:[55,12])]
  otherRoster.systems[1].omittedParts=[ScorePartOmission(partID:"bass",reason:"Known missing staff")]
  let rosterResults=match([otherRoster],three).suggestions.filter{$0.systemIndex==2}
  check(rosterResults.count==2 && Set(rosterResults.map{$0.presentPartIDs}).count==2 && rosterResults.allSatisfy{$0.confidence == .needsReview},"Zero-count absent layout slots distinguish equal totals with different rosters")
  try finish(dir)
 }
 static func finish(_ dir:String)throws{
  let failures=records.filter{!($0["passed"]as!Bool)}
  let result:[String:Any]=["checks":records.count,"failures":failures.count,"results":records]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:dir+"/results.json"))
  print("TOTAL",records.count,"FAILURES",failures.count)
  if !failures.isEmpty{exit(1)}
 }
}
