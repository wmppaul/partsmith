import Foundation
@main enum IndependentBatchAudit {
 static func main() throws {
  var results:[[String:Any]]=[]
  func record(_ name:String,_ passed:Bool,_ evidence:String="") {results.append(["name":name,"passed":passed,"evidence":evidence])}
  func rejected(_ name:String,_ op:()throws->ScoreDetectionReview) {do {let value=try op();record(name,false,"Accepted; canApply=\(value.plan.canApply); assignments=" + value.plan.bands.map{String($0.systemIndex)+":"+String(describing:$0.candidateIDs)}.joined(separator:";"))}catch{record(name,true,String(describing:error))}}
        let profile = ScoreExtractionProfile(parts: [
            ScorePartDefinition(id: "voice", name: "Voice", staffCount: 1),
            ScorePartDefinition(id: "piano", name: "Piano", staffCount: 2)
        ], requiresSystemAssignment: true)
        let staves = [0.12, 0.18, 0.24, 0.40, 0.47, 0.68, 0.75, 0.82].enumerated().map { index, top in
            ScoreObservedStaff(StaffBandCandidate(id: index,
                staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
                topFraction: top - 0.01, bottomFraction: top + 0.03, confidence: 1, warnings: []))
        }
        let page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800,
            imageWidth: 1800, imageHeight: 2400, staves: staves, warnings: [])
        var seed = try ScoreSystemAssignment.assign(page: page, profile: profile, pagePlan: nil,
            existingOverride: nil, systemIndex: 0, candidateIDs: [0, 1, 2], presentPartIDs: ["voice", "piano"],
            startBarNumber: 1, barCount: 3)
        seed.systems[0].bands[0].rect = [0, 70, 600, 115]
        seed.systems[0].bands[0].sourceMarkings = [[30, 40, 95, 55]]
        seed.systems[0].bands[0].pageBreakBefore = true
        let initial = ScoreDetectionReview.initial(profile: profile, analyses: [page], overrides: [seed],
            selectedPageIndices: [0], sourcePDFData: Data("immutable-source".utf8), rectifications: [])

        let silent = ScoreSystemAssignmentChoice(pageIndex: 0, systemIndex: 1, candidateIDs: [3, 4],
            presentPartIDs: ["piano"], startBarNumber: 4, barCount: 4)
        let full = ScoreSystemAssignmentChoice(pageIndex: 0, systemIndex: 2, candidateIDs: [5, 6, 7],
            presentPartIDs: ["voice", "piano"], startBarNumber: nil, barCount: nil)

  for threshold in 1...6 {
   var calls=0
   rejected("Cancellation checkpoint \(threshold)") {try ScoreSystemAssignmentBatch.applying([silent,full],to:initial,isCancelled:{calls += 1;return calls>=threshold})}
   record("Input exact after cancellation \(threshold)",initial.overrides == [seed] && initial.analyses == [page])
  }
  var badSecond=full;badSecond.candidateIDs=[5,6,99]
  rejected("Late assignment error is atomic") {try ScoreSystemAssignmentBatch.applying([silent,badSecond],to:initial)}
  record("Input exact after late assignment error",initial.overrides == [seed] && initial.analyses == [page])
  var duplicatePage=initial;duplicatePage.analyses.append(page)
  rejected("Duplicated analysis page rejected") {try ScoreSystemAssignmentBatch.applying([silent],to:duplicatePage)}
  var duplicateOverride=initial;duplicateOverride.overrides.append(seed)
  rejected("Duplicated override page rejected") {try ScoreSystemAssignmentBatch.applying([silent],to:duplicateOverride)}
  var invalidPage=initial;invalidPage.analyses[0].pageWidth = .nan
  rejected("Nonfinite source dimensions rejected") {try ScoreSystemAssignmentBatch.applying([silent],to:invalidPage)}
  var reversedUpper=silent;reversedUpper.systemIndex=2
  var reversedLower=full;reversedLower.systemIndex=1
  rejected("Disjoint new systems must follow physical reading order") {try ScoreSystemAssignmentBatch.applying([reversedLower,reversedUpper],to:initial)}
  let normal=try ScoreSystemAssignmentBatch.applying([full,silent],to:initial)
  record("Normal reversed choice list sorts by correct system indices",normal.plan.canApply && normal.overrides[0].systems[1].bands[0].candidateIDs == [3,4] && normal.overrides[0].systems[2].bands[0].candidateIDs == [5])
  record("Existing explicit source copy and crop survive",normal.overrides[0].systems[0] == seed.systems[0])
  rejected("Current assigned review rejects stale reuse") {try ScoreSystemAssignmentBatch.applying([silent,full],to:normal)}
  try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
  print("\(results.filter{$0["passed"] as? Bool == true}.count)/\(results.count) independent checks passed")
 }
}
