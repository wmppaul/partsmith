import AppKit
import CryptoKit
import Foundation
import PDFKit

@main enum SystemTemplateWorkflow {
    struct Expected: Decodable { var pageIndex: Int; var systemIndex: Int; var candidateIDs: [Int]; var presentPartIDs: Set<String> }
    struct Count: Decodable { var pageIndex: Int; var systemIndex: Int; var startBarNumber: Int; var barCount: Int }
    static func main() throws {
        let fixture = "Tests/quality_control/system-template-workflow-2026-10-03"
        let output = ".build/system-template-workflow-2026-10-03"
        func read<T: Decodable>(_ name: String, _: T.Type) throws -> T {
            try JSONDecoder().decode(T.self, from: Data(contentsOf: URL(fileURLWithPath: "\(fixture)/\(name).json")))
        }
        let inventory = try read("inventory", ExportScorePlan.Inventory.self)
        let profile = try read("profile", ScoreExtractionProfile.self)
        let seeds = try read("two-reviewed-seeds", [ScorePageOverride].self)
        let counts = try read("confirmed-silent-counts", [Count].self)
        let expected = try read("expected-source-identities", [Expected].self)
        let source = try Data(contentsOf: URL(fileURLWithPath: inventory.source))
        precondition(ExportScorePlan.hash(source) == inventory.sourceSHA256)
        let pdf = PDFDocument(data: source)!
        let initial = ScoreDetectionReview.initial(profile: profile, analyses: inventory.pages,
            overrides: seeds, sourcePDFData: source, rectifications: [])
        let proposals = ScoreSystemTemplateMatcher.suggest(pages: initial.analyses, profile: initial.profile,
            reviewedOverrides: initial.overrides, imageForPage: { pdf.page(at: $0).flatMap { NativeScorePageAnalyzer.render($0) } })
        FileHandle.standardError.write(Data("Matcher proposals: \(proposals.suggestions.count); diagnostics: \(proposals.diagnostics)\n".utf8))
        precondition(!proposals.cancelled && proposals.suggestions.count == 46 && proposals.diagnostics.isEmpty)
        precondition(proposals.suggestions.allSatisfy { $0.barCount == nil && $0.startBarNumber == nil })
        var checks: [[String: Any]] = []
        func check(_ name: String, _ value: Bool) {
            checks.append(["name": name, "pass": value]); FileHandle.standardError.write(Data("\(value ? "PASS" : "FAIL"): \(name)\n".utf8)); precondition(value, name)
        }
        check("Two reviewed seeds leave46 correct whole-system suggestions", proposals.suggestions.allSatisfy { s in
            expected.contains { $0.pageIndex == s.pageIndex && $0.systemIndex == s.systemIndex
                && $0.candidateIDs == s.candidateIDs && $0.presentPartIDs == s.presentPartIDs }
        })
        let noCounts = proposals.suggestions.map { s in ScoreSystemAssignmentChoice(pageIndex: s.pageIndex,
            systemIndex: s.systemIndex, candidateIDs: s.candidateIDs, presentPartIDs: s.presentPartIDs,
            startBarNumber: nil, barCount: nil) }
        var refusedMissingCount = false
        do { _ = try ScoreSystemAssignmentBatch.applying(noCounts, to: initial) }
        catch ScoreSystemAssignment.AssignmentError.missingRestCount { refusedMissingCount = true }
        check("Accepting silent omissions without their own counts is refused", refusedMissingCount)
        check("Failed batch leaves seed overrides untouched", initial.overrides == seeds)
        let choices = proposals.suggestions.map { s -> ScoreSystemAssignmentChoice in
            let confirmed = counts.first { $0.pageIndex == s.pageIndex && $0.systemIndex == s.systemIndex }
            return ScoreSystemAssignmentChoice(pageIndex: s.pageIndex, systemIndex: s.systemIndex,
                candidateIDs: s.candidateIDs, presentPartIDs: s.presentPartIDs,
                startBarNumber: confirmed?.startBarNumber, barCount: confirmed?.barCount)
        }
        let complete = try ScoreSystemAssignmentBatch.applying(choices, to: initial)
        check("Incomplete initial review cannot apply or export bands", !initial.plan.canApply && initial.plan.bands.isEmpty)
        check("Complete review can apply", complete.plan.canApply)
        check("96 ordered part items", complete.plan.bands.count == 96)
        check("48 source systems in each part", profile.parts.allSatisfy { p in complete.plan.bands.filter { $0.partID == p.id }.count == 48 })
        check("All92 printed assignments preserve source identity and order", expected.allSatisfy { e in
            let bands = complete.plan.bands.filter { $0.pageIndex == e.pageIndex && $0.systemIndex == e.systemIndex && $0.generatedRest == nil }
            let ordered = profile.parts.filter { e.presentPartIDs.contains($0.id) }.flatMap { p in bands.first { $0.partID == p.id }?.candidateIDs ?? [] }
            return Set(bands.map(\.partID)) == e.presentPartIDs && ordered == e.candidateIDs
        })
        check("No staff duplicated or dropped", inventory.pages.allSatisfy { page in
            let ids = complete.plan.bands.filter { $0.pageIndex == page.pageIndex }.flatMap(\.candidateIDs)
            return ids.sorted() == page.staves.map(\.id).sorted() && Set(ids).count == ids.count
        })
        let rests = complete.plan.bands.filter { $0.generatedRest != nil }
        check("Four confirmed3-bar rests retain12 initial vocal bars", rests.count == 4
            && rests.allSatisfy { $0.partID == "voice" && $0.pageIndex == 0 && $0.generatedRest?.barCount == 3 }
            && rests.compactMap { $0.generatedRest?.startBarNumber } == [1,4,7,10])
        check("No measure counts invented for43 new full-roster systems", complete.plan.bands.filter { b in
            choices.contains { $0.pageIndex == b.pageIndex && $0.systemIndex == b.systemIndex && $0.barCount == nil }
        }.allSatisfy { $0.barCount == nil && $0.startBarNumber == nil })
        let finalSeedPage = complete.overrides.first { $0.pageIndex == 0 }!
        for index in [0,4] {
            check("Reviewed seed system\(index+1) metadata remains exact", finalSeedPage.systems[index] == seeds[0].systems[index])
            let after = complete.plan.bands.filter { $0.pageIndex == 0 && $0.systemIndex == index }
            let page = inventory.pages[0]
            func sameRect(_ source: [Double], _ normalized: [Double]) -> Bool {
                let points = [normalized[0] * page.pageWidth, normalized[1] * page.pageHeight,
                    normalized[2] * page.pageWidth, normalized[3] * page.pageHeight]
                return zip(source, points).allSatisfy { abs($0 - $1) < 1e-9 }
            }
            check("Reviewed seed system\(index+1) source crop edges remain exact", seeds[0].systems[index].bands.allSatisfy { original in
                guard let band = after.first(where: { $0.partID == original.partID }), let rect = original.rect else { return false }
                return sameRect(rect, [band.leftFraction, band.topFraction, 1-band.rightFraction, band.bottomFraction])
                    && band.candidateIDs == original.candidateIDs && band.sourceMarkings.isEmpty
            })
            check("Reviewed seed system\(index+1) omission copies remain exact", (seeds[0].systems[index].omittedParts ?? []).allSatisfy { omission in
                guard let band = after.first(where: { $0.partID == omission.partID }) else { return false }
                let copies = omission.sourceMarkings ?? []
                return copies.count == band.sourceMarkings.count && zip(copies, band.sourceMarkings).allSatisfy { rect, marking in
                    sameRect(rect, [marking.leftFraction, marking.topFraction, 1-marking.rightFraction, marking.bottomFraction])
                }
            })
        }
        check("Opening reviewed original-source tempo copy retained", complete.plan.bands.first {
            $0.pageIndex == 0 && $0.systemIndex == 0 && $0.partID == "voice"
        }?.sourceMarkings.count == 1)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(inventory).write(to: URL(fileURLWithPath: output + "/workflow-inventory.json"))
        try encoder.encode(complete.overrides).write(to: URL(fileURLWithPath: output + "/workflow-overrides.json"))
        try encoder.encode(complete.plan).write(to: URL(fileURLWithPath: output + "/batch-plan.json"))
        try JSONSerialization.data(withJSONObject: ["checks": checks, "sourceSHA256": inventory.sourceSHA256,
            "seedSystems": 2, "matchedSystems": 46, "partItems": 96, "confirmedOmittedBars": 12,
            "status": "Identity/rest workflow validated; musical crop quality remains a separate review."],
            options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: output + "/workflow-summary.json"))
        try ExportScorePlan.main()
        let exported = try Data(contentsOf: URL(fileURLWithPath: output + "/parts/plan.json"))
        let decoded = try JSONDecoder().decode(ScoreExtractionPlan.self, from: exported)
        precondition(decoded == complete.plan, "Exporter replan must equal accepted batch plan")
        print("Matcher → batch → review → native apply/layout/export: \(checks.count) checks;96 items; accepted/exported plans identical.")
    }
}
