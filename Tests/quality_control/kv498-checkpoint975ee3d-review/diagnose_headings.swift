import AppKit
import Foundation
import PDFKit

@main enum DiagnoseHeadings {
    struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
    static func main() throws {
        let base = ".build/auto-qc/checkpoint975ee3d/corpus/normal-mozart-trio-eb-major-kv498-score/"
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: URL(fileURLWithPath: base + "inventory/inventory.json")))
        let profile = try JSONDecoder().decode(ScoreExtractionProfile.self, from: Data(contentsOf: URL(fileURLWithPath: "Tests/quality_control/profiles/normal-mozart-trio-eb-major-kv498-score.json")))
        let pdf = PDFDocument(url: URL(fileURLWithPath: "sample_scores/normal/01_chamber/mozart_trio_eb_major_kv498_score.pdf"))!
        var results: [[String:Any]] = []
        for (oneBased, system) in [(1,1),(12,3),(13,3),(17,1)] {
            let analysis = inventory.pages.first { $0.pageIndex == oneBased - 1 }!
            let page = pdf.page(at: oneBased - 1)!
            let image = NativeScorePageAnalyzer.render(page, maximumWidth: 2200, maximumHeight: 3200)!
            let plan = ScoreExtractionPlanner.plan(pages: [analysis], profile: profile)
            let ordered = analysis.staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
            let staff = ordered[(system - 1) * 4]
            let previous = system == 1 ? 0 : ordered[(system - 1) * 4 - 1].staffLineFractions[4]
            let top = staff.staffLineFractions[0], space = (staff.staffLineFractions[4] - top) / 4
            var observations: [[String: Any]] = []
            let headings = ScoreSharedHeadingDetector.detect(in: image, page: analysis, profile: profile,
                observedText: { anchor, lines in
                    for line in lines {
                        let b = line.bounds
                        var reasons: [String] = []
                        if line.confidence < 0.8 { reasons.append("confidence below 0.8") }
                        if b.maxY > top { reasons.append("OCR box crosses staff top") }
                        if b.minY < max(0, top - 12 * space) { reasons.append("above 12-space window") }
                        if b.midY <= (previous + top) / 2 { reasons.append("closer to previous staff than current anchor") }
                        if !ScoreSharedHeadingDetector.isHeading(line.text) { reasons.append("not a recognized heading phrase") }
                        observations.append(["ocrPassAnchorStaffID":anchor,"text":line.text,"confidence":line.confidence,
                            "sourceRect":[b.minX * analysis.pageWidth,b.minY * analysis.pageHeight,b.maxX * analysis.pageWidth,b.maxY * analysis.pageHeight],
                            "oracleAnchorStaffID":staff.id,"rejectionReasonsForOracleAnchor":reasons,
                            "selectedForOracleAnchor":ScoreSharedHeadingDetector.select(from:[line],anchor:staff,previousStaffBottom:previous,imageSize:CGSize(width:image.width,height:image.height)).count])
                    }
                })
            results.append(["sourcePage":oneBased,"sourceSystem":system,"imageSize":[image.width,image.height],"canApply":plan.canApply,
                            "unresolvedReasons":plan.pages.flatMap(\.unresolvedReasons),"bands":plan.bands.count,
                            "anchorStaffID":staff.id,"staffTopPoints":top * analysis.pageHeight,
                            "regionalWindowYPoints":[max(previous + (system > 1 ? space : 0),top - 12 * space) * analysis.pageHeight,(top-space * 0.3) * analysis.pageHeight],
                            "headings":headings.map { ["text":$0.recognizedText,"bounds":$0.bounds,"anchorStaffID":$0.anchorStaffID] as [String:Any] },"observations":observations])
            print("Page \(oneBased): canApply \(plan.canApply), observed \(observations.count), selected \(headings.count)")
            fflush(stdout)
        }
        try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath: ".build/auto-qc/kv498-headings/diagnosis.json"))
    }
}
