import Foundation
struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
@main enum Probe {
 static var checks=0
 static func check(_ condition: Bool,_ message:String)throws {checks += 1; if !condition {throw NSError(domain:"EdgeCompletion",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
 static func staff(_ id:Int,_ y:Double)->ScoreObservedStaff {ScoreObservedStaff(StaffBandCandidate(id:id,staffLineFractions:(0..<5).map{(y+Double($0)*10)/1000},topFraction:(y-10)/1000,bottomFraction:(y+50)/1000,confidence:1,warnings:[]))}
 static func main() throws {
  let args=CommandLine.arguments
  if args.count>1 && args[1]=="replay" {
   let inv=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
   let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:args[3])))
   let start=Date();let plan=ScoreExtractionPlanner.plan(pages:inv.pages,profile:profile);let duration=Date().timeIntervalSince(start)
   let enc=JSONEncoder();enc.outputFormatting=[.prettyPrinted,.sortedKeys];try enc.encode(plan).write(to:URL(fileURLWithPath:args[4]))
   print("REPLAY pages=\(inv.pages.count) bands=\(plan.bands.count) copies=\(plan.bands.reduce(0){$0+$1.sourceMarkings.count}) canApply=\(plan.canApply) seconds=\(duration)");return
  }
  let candidate = !args.contains("--baseline")
  let profile=ScoreExtractionProfile(parts:[ScorePartDefinition(id:"piano",name:"Piano",staffCount:1)],cropMode:"compact")
  let owned=ScoreInkComponent(bounds:[0.1,0.180,0.120,0.300],staffIDs:[0])
  let label=ScoreInkComponent(bounds:[0.300,0.302,0.308,0.309],staffIDs:[])
  func page(_ components:[ScoreInkComponent],_ staves:[ScoreObservedStaff]=[staff(0,200)]) ->ScorePageAnalysis {ScorePageAnalysis(pageIndex:0,pageWidth:1000,pageHeight:1000,imageWidth:1000,imageHeight:1000,staves:staves,warnings:[],inkComponents:components)}
  func planned(_ p:ScorePageAnalysis)->ScorePlannedBand {ScoreExtractionPlanner.plan(pages:[p],profile:profile).bands[0]}
  let bare=planned(page([owned]));let completed=planned(page([owned,label]))
  try check(abs(bare.bottomFraction-0.305)<1e-12,"Fixture baseline incorrect")
  try check(abs(completed.bottomFraction-(candidate ? 0.314:0.305))<1e-12,"Detached bottom glyph not completed as expected")
  try check(completed.topFraction==bare.topFraction && completed.candidateIDs==bare.candidateIDs,"Bottom completion changed unrelated fields")
  let upper=ScoreInkComponent(bounds:[0.3,0.160,0.308,0.167],staffIDs:[])
  try check(abs(planned(page([owned,upper])).topFraction-(candidate ? 0.145:0.165))<1e-12,"Detached upper glyph not completed")
  var tall=label;tall.bounds[3]=0.330
  try check(planned(page([owned,tall])).bottomFraction==bare.bottomFraction,"Tall structure completed")
  var wide=label;wide.bounds[2]=0.450
  try check(planned(page([owned,wide])).bottomFraction==bare.bottomFraction,"Wide structure completed")
  var alternative=label;alternative.isOwnershipAlternative=true
  try check(planned(page([owned,alternative])).bottomFraction==bare.bottomFraction,"Unowned alternative hypothesis completed")
  let chain=ScoreInkComponent(bounds:[0.3,0.312,0.308,0.320],staffIDs:[])
  try check(planned(page([owned,label,chain])).bottomFraction==completed.bottomFraction,"Completion recursively chained into next row")
  let footer=ScoreInkComponent(bounds:[0.3,0.940,0.308,0.950],staffIDs:[])
  try check(planned(page([owned,label,footer])).bottomFraction==completed.bottomFraction,"Unintersected footer imported")
  let nearOther=page([owned,label],[staff(0,200),staff(1,310)])
  try check(planned(nearOther).bottomFraction==bare.bottomFraction,"Glyph nearer another staff was completed")
  let crossOther=page([owned,label],[staff(0,200),staff(1,307)])
  try check(planned(crossOther).bottomFraction==bare.bottomFraction,"Glyph crossing foreign staff core completed")
  var foreign=label;foreign.staffIDs=[1]
  try check(planned(page([owned,foreign],[staff(0,200),staff(1,500)])).bottomFraction==bare.bottomFraction,"Assigned other-staff component completed")
  let original=page([owned,label]);let override=ScorePageOverride(pageIndex:0,reason:"Manual",systems:[ScoreSystemOverride(systemIndex:0,bands:[ScoreBandOverride(partID:"piano",candidateIDs:[0],rect:[0,180,1000,305])])])
  let manual=ScoreExtractionPlanner.plan(pages:[original],profile:profile,overrides:[override])
  try check(manual.bands[0].bottomFraction==0.305,"Explicit manual rectangle changed")
  try check(!ScoreExtractionPlanner.plan(pages:[original],profile:profile,isCancelled:{true}).canApply,"Canceled planner applicable")
  try check(planned(original)==completed,"Repeated planning not deterministic")
  print("PASS \(checks) edge completion controls (candidate=\(candidate))")
 }
}
