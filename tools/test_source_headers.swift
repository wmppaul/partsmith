import AppKit
import CoreGraphics
import Foundation
import PDFKit

@main
enum SourceHeaderTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }

    static func main() throws {
        typealias Line = ScoreSourceHeaderDetector.TextLine
        let staff = ScoreObservedStaff(StaffBandCandidate(id: 0,
            staffLineFractions: [0.22, 0.225, 0.230, 0.235, 0.240],
            topFraction: 0.20, bottomFraction: 0.26, confidence: 1, warnings: []))
        let title = Line(text: "Trio", bounds: CGRect(x: 0.40, y: 0.08, width: 0.20, height: 0.025), confidence: 1)
        let composer = Line(text: "Johannes Brahms, Op.114", bounds: CGRect(x: 0.65, y: 0.14, width: 0.29, height: 0.014), confidence: 1)
        let dates = Line(text: "(1833–1897)", bounds: CGRect(x: 0.74, y: 0.157, width: 0.13, height: 0.012), confidence: 1)
        let folio = Line(text: "(249) 1", bounds: CGRect(x: 0.87, y: 0.05, width: 0.06, height: 0.016), confidence: 1)
        let tempo = Line(text: "Allegro", bounds: CGRect(x: 0.18, y: 0.195, width: 0.12, height: 0.015), confidence: 1)
        let select: ([Line]) -> ScoreSourceHeaderCandidate? = {
            ScoreSourceHeaderDetector.select(from: $0, firstStaff: staff, pageIndex: 3,
                imageSize: CGSize(width: 1800, height: 2600))
        }
        let found = select([folio, title, composer, dates, tempo])!
        check(found.selection.pageIndex == 3, "Header retains its source page")
        check(found.recognizedLines == ["Trio", "Johannes Brahms, Op.114", "(1833–1897)"], "Title and full composer metadata survive; page numbers and tempo stay out")
        check(found.selection.topFraction < title.bounds.minY && found.selection.bottomFraction > dates.bounds.maxY,
              "Crop pads the complete header above and below")
        check(found.selection.rightFraction < 1 - composer.bounds.maxX && found.selection.rightFraction > 0,
              "Right coordinate uses the project's right-trim convention")
        check(abs(found.selection.leftFraction - found.selection.rightFraction) < 0.000001,
              "Balanced margins preserve the printed title and composer alignment")
        check(select([folio, tempo]) == nil, "Continuation-page folio and tempo do not create a header")
        check(select([composer, dates]) == nil, "Lone composer credits do not invent an opening title")
        var small = title; small.bounds.size.height = 0.006
        check(select([small, folio]) == nil, "Small running titles do not create a source header")
        var invalid = title; invalid.bounds.origin.x = .nan
        check(select([invalid]) == nil, "Invalid OCR geometry is rejected")
        var uncertain = title; uncertain.confidence = 0.10
        check(select([uncertain]) == nil, "Uncertain OCR does not create an automatic header")
        let watermark = Line(text: "Downloaded from imslp.org", bounds: CGRect(x: 0.2, y: 0.04, width: 0.6, height: 0.03), confidence: 1)
        check(select([watermark, title, composer])?.recognizedLines.contains(watermark.text) == false,
              "Archive notices are not part of the source title")

        let fixtures: [(String, String, [String])] = [
            ("trio", "sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf", ["Trio", "Johannes Brahms", "1892"]),
            ("ave", "sample_scores/normal/04_choir/mozart_ave_verum_corpus_kv618_cpdl18715_complete_score.pdf", ["KV 618", "Mozart", "1756"]),
            ("notte", "sample_scores/normal/03_piano_vocal/mozart_notte_e_giorno_don_giovanni_score.pdf", ["Notte e giorno", "Lorenzo", "Wolfgang", "Natalia"])
        ]
        let output = URL(fileURLWithPath: ".build/source-header-previews", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, path, expected) in fixtures {
            let pdf = PDFDocument(url: URL(fileURLWithPath: path))!
            let image = NativeScorePageAnalyzer.render(pdf.page(at: 0)!)!
            let candidate = ScoreSourceHeaderDetector.detect(in: image, pageIndex: 0)
            check(candidate != nil, "\(name) opening has a useful automatic header")
            let joined = candidate!.recognizedLines.joined(separator: " | ")
            print("\(name): \(joined); \(candidate!.selection)")
            for text in expected { check(joined.contains(text), "\(name) preserves complete header text containing \(text)") }
            check(!joined.localizedCaseInsensitiveContains("allegro") && !joined.localizedCaseInsensitiveContains("adagio"),
                  "\(name) leaves performance directions with the first staff")
            try save(candidate!, image: image, to: output.appendingPathComponent("\(name).png"))
            let second = NativeScorePageAnalyzer.render(pdf.page(at: 1)!)!
            check(ScoreSourceHeaderDetector.detect(in: second, pageIndex: 1) == nil,
                  "\(name) continuation page has no invented header")
            check(ScoreSourceHeaderDetector.detect(in: image, pageIndex: 0, isCancelled: { true }) == nil,
                  "\(name) cancellation produces no suggestion")
            check(ScoreSourceHeaderDetector.detect(in: image, pageIndex: 0, staves: []) == nil,
                  "\(name) requires real music geometry; a cover alone does not become a score header")
            if name == "trio" {
                let document = PartsmithDocument(sourcePDFData: try Data(contentsOf: URL(fileURLWithPath: path)))
                document.project.pageCount = pdf.pageCount
                document.autoEstimateCurrentPageRectification()
                check(document.currentPageRectification != nil, "Trio fixture receives the app's measured deskew")
                let corrected = document.scoreReviewImage(pageIndex: 0)!
                let result = ScoreSourceHeaderDetector.detect(in: corrected, pageIndex: 0)
                check(result?.recognizedLines.contains(where: { $0.contains("Johannes Brahms") }) == true,
                      "Header detection also works in the rectified displayed coordinate space")
                try save(result!, image: corrected, to: output.appendingPathComponent("trio-deskewed.png"))
            }
        }
        print("\(checks) source-header checks passed.")
    }

    static func save(_ candidate: ScoreSourceHeaderCandidate, image: CGImage, to url: URL) throws {
        let s = candidate.selection
        let rect = CGRect(x: s.leftFraction * Double(image.width), y: s.topFraction * Double(image.height),
            width: (1 - s.leftFraction - s.rightFraction) * Double(image.width),
            height: (s.bottomFraction - s.topFraction) * Double(image.height))
        let crop = image.cropping(to: rect.integral)!
        let representation = NSBitmapImageRep(cgImage: crop)
        try representation.representation(using: .png, properties: [:])!.write(to: url)
    }
}
