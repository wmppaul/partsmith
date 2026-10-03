import Foundation
import CoreGraphics

@main enum HeadingLocalControls {
    static var checks: [[String: Any]] = []
    static func check(_ name: String, _ value: @autoclosure () -> Bool) { let passed=value();print("CHECK: \(passed ? "PASS" : "FAIL"): "+name);fflush(stdout);checks.append(["name": name, "passed": passed]) }
    static let profile = ScoreExtractionProfile(parts: [.init(id: "a", name: "A", staffCount: 1), .init(id: "b", name: "B", staffCount: 2)])
    static func staff(_ id: Int, _ y: Double) -> ScoreObservedStaff {
        ScoreObservedStaff(StaffBandCandidate(id: id, staffLineFractions: (0..<5).map { y + Double($0) * 0.005 }, topFraction: y-0.02, bottomFraction: y+0.04, confidence: 1, warnings: []))
    }
    static func clean() -> ScorePageAnalysis {
        .init(pageIndex: 0, pageWidth: 600, pageHeight: 800, imageWidth: 1800, imageHeight: 2400,
              staves: [staff(0,0.20),staff(1,0.30),staff(2,0.38),staff(3,0.60),staff(4,0.70),staff(5,0.78)], warnings: [])
    }
    static func page() -> ScorePageAnalysis {
        var p = clean(); let plan = ScoreExtractionPlanner.plan(pages: [p], profile: profile)
        var h = ScoreSharedHeading(anchorStaffID: 0, bounds: [0.18,0.165,0.32,0.19], recognizedText: "Adagio.", inkBounds: [0.181,0.17,0.319,0.188])
        h.recognitionBinding = ScoreExtractionPlanner.headingRecognitionBinding(page: p, plan: plan, anchorStaffID: 0)
        h.localCounterparts = [.init(partID: "b", anchorStaffID: 1, bounds: [0.18,0.265,0.32,0.295], inkBounds: [0.181,0.272,0.319,0.29], recognizedText: "Adagio.")]
        p.sharedHeadings = [h]; return p
    }
    static func plan(_ p: ScorePageAnalysis, _ overrides: [ScorePageOverride] = []) -> ScoreExtractionPlan { ScoreExtractionPlanner.plan(pages: [p], profile: profile, overrides: overrides) }
    static func target(_ p: ScoreExtractionPlan) -> ScorePlannedBand { p.bands.first { $0.partID == "b" && $0.systemIndex == 0 } ?? { print("MISSING TARGET",p);fflush(stdout);fatalError("missing test target") }() }
    static func copyCount(_ p: ScorePageAnalysis) -> Int { target(plan(p)).sourceMarkings.count }
    static func review(_ p: ScorePageAnalysis = page()) -> ScoreDetectionReview {
        .initial(profile: profile, analyses: [p], sourcePDFData: Data(), rectifications: [])
    }
    static func explicit(_ p: ScorePageAnalysis, markings: [[Double]]?) -> ScorePageOverride {
        let q = plan(p)
        var o = ScoreSystemAssignment.pageOverride(page: p, pagePlan: q.pages.first, existingOverride: nil)
        for s in o.systems.indices { for b in o.systems[s].bands.indices {
            o.systems[s].bands[b].sourceMarkings = markings
            o.systems[s].bands[b].automaticLocalHeadingBounds = nil
        } }
        return o
    }
    static func main() throws {
        let original = page(); var p = original
        check("complete own first-staff local proof suppresses automatic duplicate", copyCount(p) == 0)
        check("complete source owner remains retained", plan(p).bands.first!.sourceMarkings.isEmpty)
        var baseline = p; baseline.sharedHeadings![0].localCounterparts = nil
        check("legacy no counterpart keeps required shared copy", copyCount(baseline) == 1)
        check("all original music crop rectangles unchanged", zip(plan(p).bands,plan(baseline).bands).allSatisfy { $0.topFraction == $1.topFraction && $0.bottomFraction == $1.bottomFraction && $0.leftFraction == $1.leftFraction && $0.rightFraction == $1.rightFraction })
        let positive = p.sharedHeadings![0].localCounterparts![0]
        func reject(_ name: String, _ mutate: (inout ScoreHeadingLocalCounterpart)->Void) {
            var candidate = original; var local = positive; mutate(&local); candidate.sharedHeadings![0].localCounterparts = [local]
            check(name, copyCount(candidate) == 1)
        }
        reject("another instrument cannot certify local heading") { $0.partID = "a" }
        reject("piano interior staff is not first-staff heading owner") { $0.anchorStaffID = 2 }
        reject("different system staff cannot certify local heading") { $0.anchorStaffID = 4 }
        reject("same words at different musical position") { $0.bounds = [0.60,0.265,0.74,0.295]; $0.inkBounds = [0.601,0.272,0.739,0.29] }
        reject("lower neighboring instruction cannot substitute") { $0.bounds = [0.18,0.335,0.32,0.36]; $0.inkBounds = [0.181,0.34,0.319,0.355] }
        reject("cut capital top keeps copy") { $0.inkBounds[1] = 0.26; $0.bounds[1] = 0.255 }
        reject("partial right-hand letter keeps copy") { $0.inkBounds[2] = 1.001; $0.bounds[2] = 1.01 }
        reject("unmeasured empty local ink keeps copy") { $0.inkBounds = [] }
        reject("nonfinite local ink keeps copy") { $0.inkBounds[1] = .nan }
        reject("local ink outside certified source box") { $0.inkBounds[0] = 0.17 }
        reject("inverted local source box") { $0.bounds = [0.32,0.265,0.18,0.295] }
        reject("different tempo word is not equivalent") { $0.recognizedText = "Andante." }
        reject("partial phrase cannot suppress full phrase") { $0.recognizedText = "Ada" }
        reject("punctuation deletion is not allowed") { $0.recognizedText = "Adagio" }
        reject("additional metronome value changes full text") { $0.recognizedText = "Adagio. = 108" }
        p = original; p.sharedHeadings![0].recognizedText = "Adagio. = 108"
        check("global extra metronome text requires copy", copyCount(p) == 1)
        p = original; p.sharedHeadings![0].recognizedText = "SCHERZO\nAdagio."
        check("global stacked title requires complete equivalent", copyCount(p) == 1)
        p = original; p.sharedHeadings![0].localCounterparts![0].recognizedText = "  ADAGIO.  "
        check("case and surrounding whitespace only normalization", copyCount(p) == 0)
        p = original; p.sharedHeadings![0].recognitionBinding = nil
        check("legacy heading without recognition binding cannot suppress separate local copy", copyCount(p) == 1)
        p = original; p.sharedHeadings![0].localCounterparts = [positive,positive]
        check("ambiguous duplicate local proofs fail conservatively", copyCount(p) == 1)
        p = original; p.sharedHeadings![0].recognitionBinding!.systemIndex = 1
        let stale = plan(p)
        check("stale source binding produces visible warning", stale.bands.contains { $0.warnings.contains { $0.contains("ownership") } })
        check("stale binding never moves automatic source into other system", stale.bands.allSatisfy { $0.sourceMarkings.isEmpty })
        p = original; var second = p.sharedHeadings![0]; second.bounds = [0.18,0.18,0.32,0.205]; second.recognizedText = "SCHERZO"
        p.sharedHeadings!.append(second)
        check("coalesced block discards unmeasured local proof", ScoreSharedHeading.coalesced(p.sharedHeadings!)[0].localCounterparts == nil)
        let q = plan(original); var noOp = explicit(original, markings: nil)
        check("initial no-op nil-list override reapplies local proof", target(plan(original,[noOp])).sourceMarkings.isEmpty)
        noOp = explicit(baseline, markings: nil)
        check("initial no-op nil-list override retains required copy", target(plan(baseline,[noOp])).sourceMarkings.count == 1)
        let globalRect = [108.0,132.0,192.0,152.0]
        check("explicit retained copy remains authoritative", target(plan(original,[explicit(original, markings: [globalRect])])).sourceMarkings.count == 1)
        check("explicit empty list remains authoritative", target(plan(baseline,[explicit(baseline, markings: [])])).sourceMarkings.isEmpty)
        var r = review(); let id = target(r.plan).id, bottom = target(r.plan).bottomFraction*800
        try r.setCropEdges(for: id, top: 0.28*800, bottom: bottom)
        check("actual UI crop edit restores heading after clipping local top", target(r.plan).sourceMarkings.count == 1)
        try r.setCropEdges(for: id, top: 0.29*800, bottom: bottom)
        check("second crop edit does not duplicate restored copy", target(r.plan).sourceMarkings.count == 1)
        try r.resetCropEdges(for: id)
        check("reset complete crop suppresses restored automatic duplicate", target(r.plan).sourceMarkings.isEmpty)
        try r.setCropEdges(for: id, top: 0.28*800, bottom: bottom)
        try r.removeSourceMarking(from: id, at: 0)
        check("explicit Remove Copy wins immediately", target(r.plan).sourceMarkings.isEmpty)
        try r.resetCropEdges(for: id); try r.setCropEdges(for: id, top: 0.28*800, bottom: bottom)
        check("explicit removal remains after future crop edits", target(r.plan).sourceMarkings.isEmpty)
        r = review(); var edit = ScoreSystemAssignment.pageOverride(page: original,pagePlan: r.plan.pages.first,existingOverride:nil)
        edit.systems[0].bands[1].rect![1] = 0.28*800; r.overrides = [edit]; r.replan()
        check("assignment editor materialized empty list also restores copy", target(r.plan).sourceMarkings.count == 1)
        r.overrides[0].systems[0].bands[1].kind = "cue";r.overrides[0].systems[0].bands[1].label = "editorial cue";r.replan()
        check("reassignment clears restored automatic copy", target(r.plan).sourceMarkings.isEmpty)
        check("reassignment warns without an acceptance gate", r.plan.canApply && !r.directionIssues.isEmpty)
        p = original;p.sharedNavigation = [.init(anchorStaffID:0,bounds:original.sharedHeadings![0].bounds,recognizedText:"D.C.",isBelow:false)]
        check("coincident navigation remains when heading suppressed", copyCount(p) == 1)
        r = review(p); let collisionID=target(r.plan).id; try r.setCropEdges(for:collisionID,top:0.28*800,bottom:target(r.plan).bottomFraction*800);try r.resetCropEdges(for:collisionID)
        check("local restore/reset preserves coincident other-category copy", target(r.plan).sourceMarkings.count == 1)
        p = original;p.sharedNavigation = [.init(anchorStaffID:0,bounds:[0.60,0.16,0.70,0.19],recognizedText:"D.C.",isBelow:false)]
        r=review(p);try r.removeSourceMarking(from:target(r.plan).id,at:0);try r.setCropEdges(for:target(r.plan).id,top:0.28*800,bottom:target(r.plan).bottomFraction*800)
        check("removing unrelated navigation does not disable automatic heading restoration", target(r.plan).sourceMarkings.count == 1)
        var materialized=ScoreSystemAssignment.pageOverride(page:r.analyses[0],pagePlan:r.plan.pages.first,existingOverride:r.overrides.first)
        materialized.systems[0].bands[1].sourceMarkings = target(r.plan).sourceMarkings.map { [$0.leftFraction*600,$0.topFraction*800,(1-$0.rightFraction)*600,$0.bottomFraction*800] }
        materialized.systems[0].bands[1].sourceMarkingsBelow = target(r.plan).sourceMarkings.map { $0.isBelow == true }
        materialized.systems[0].bands[1].kind="cue";materialized.systems[0].bands[1].label="cue";r.overrides=[materialized];r.replan()
        check("materialized restored heading cannot become stale manual copy", target(r.plan).sourceMarkings.isEmpty)
        let encoder=JSONEncoder(),decoder=JSONDecoder();let bytes=try encoder.encode(original);let restored=try decoder.decode(ScorePageAnalysis.self,from:bytes);check("local metadata codec roundtrip",restored==original)
        var legacy=original;legacy.sharedHeadings![0].localCounterparts=nil;let old=try encoder.encode(legacy)
        check("legacy optional field absent",!String(decoding:old,as:UTF8.self).contains("localCounterparts"))
        let restoredLegacy=try decoder.decode(ScorePageAnalysis.self,from:old);check("legacy codec roundtrip",restoredLegacy==legacy)
        for limit in [1,2,3,5,10] {
            var calls=0;let canceled=ScoreExtractionPlanner.plan(pages:[original],profile:profile,isCancelled:{calls+=1;return calls>=limit})
            check("cancellation cannot return partially suppressed plan at checkpoint \(limit)",calls<limit || canceled.pages.isEmpty)
        }
        check("repeated identical planning is deterministic",plan(original)==q)
        let out=CommandLine.arguments.dropFirst().first ?? ".build/heading-local-ownership-2026-10-03/results.json"
        try JSONSerialization.data(withJSONObject:checks,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:out))
        let failed=checks.filter { $0["passed"] as? Bool != true };print("\(checks.count-failed.count)/\(checks.count) independent heading-local controls pass")
        for f in failed {print("FAIL: \(f["name"]!)")};if !failed.isEmpty {exit(1)}
    }
}
