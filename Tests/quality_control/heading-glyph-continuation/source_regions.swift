import Foundation
import CoreGraphics
import ImageIO

struct SourceReviewItem: Decodable {
    var number: Int
    var `case`: String
    var page: Int
    var anchorStaffID: Int
    var acceptedHeading: ScoreSharedHeading
}
struct SourceReviewInput: Decodable { var inventory: String; var reviewSourceSHA256: String }
struct SourceReviewInventory: Decodable { var pages: [ScorePageAnalysis] }

@main enum GlyphSourceRegions {
    static func main() throws {
        let base = ".build/heading-glyph-continuation-2026-10-03"
        let dir = "Tests/quality_control/heading-glyph-continuation"
        let decoder = JSONDecoder()
        let items = try decoder.decode([SourceReviewItem].self, from: Data(contentsOf: URL(fileURLWithPath: "\(dir)/index.json")))
        let inputs = try decoder.decode([String: SourceReviewInput].self, from: Data(contentsOf: URL(fileURLWithPath: "\(dir)/inputs.json")))
        var rows: [[String: Any]] = []
        for item in items {
            let inventory = try decoder.decode(SourceReviewInventory.self, from: Data(contentsOf: URL(fileURLWithPath: inputs[item.case]!.inventory)))
            let page = inventory.pages.first { $0.pageIndex == item.page - 1 }!
            let anchor = page.staves.first { $0.id == item.anchorStaffID }!
            let path = ".build/accepted-heading-source-review/\(item.case)-p\(item.page).png"
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            let old = item.acceptedHeading.bounds
            let new = ScoreSharedHeadingDetector.continuedGlyphBounds(in: image, bounds: old, anchor: anchor)
            let enclosed = new[0] <= old[0] && new[1] <= old[1] && new[2] >= old[2] && new[3] >= old[3]
            rows.append(["number":item.number,"case":item.case,"page":item.page,"old":old,"new":new,
                         "enclosesOriginal":enclosed,"changed":new != old,
                         "pixelSize":[image.width,image.height]])
        }
        let result: [String: Any] = ["rows":rows,"count":rows.count,
            "changed":rows.filter { $0["changed"] as? Bool == true }.count,
            "nonShrinking":rows.allSatisfy { $0["enclosesOriginal"] as? Bool == true }]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: "\(base)/source-regions.json"))
        print(String(decoding:data,as:UTF8.self))
    }
}
