import CoreGraphics
import CryptoKit
import Foundation
import PDFKit

/// Independent source-position checks plus detector-only corpus comparison.
/// This never calls a part planner or assumes a divisible instrument count.
@main
enum StaffRecallTests {
    struct Failure: Error, CustomStringConvertible { let description: String }
    struct Score: Decodable { let id: String; let path: String; let sha256: String; let pageCount: Int }
    struct Corpus: Decodable { let scores: [Score] }
    struct ObservedStaff: Codable { let staffLineFractions: [Double] }
    struct ObservedPage: Codable { let pageIndex: Int; let staves: [ObservedStaff] }
    struct Inventory: Decodable { let sourceSHA256: String; let pages: [ObservedPage] }
    struct PageChange: Codable {
        let page: Int; let beforeCount: Int; let afterCount: Int
        let addedStaffLines: [[Double]]; let missingStaffLines: [[Double]]
        let movedStaffLines: [[[Double]]]
    }
    struct ScoreResult: Codable {
        let id: String; let sourceSHA256: String; let pages: [ObservedPage]
        let changes: [PageChange]; let error: String?
    }
    struct Report: Codable {
        let detectorSHA256: String; let executableSHA256: String; let corpusSHA256: String
        let baseline: String; let results: [ScoreResult]
        let limitation: String
    }
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw Failure(description: message) }
    }
    static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func image(width: Int = 1400, height: Int = 1800, draw: (CGContext) -> Void) -> CGImage {
        let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(gray: 1, alpha: 1); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
        c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 1, y: -1); draw(c)
        return c.makeImage()!
    }
    static func lines(_ c: CGContext, y: Double, space: Double = 12, left: Int = 100, right: Int = 1300,
                      slope: Double = 0, bow: Double = 0, count: Int = 5) {
        c.setStrokeColor(gray: 0, alpha: 1); c.setLineWidth(1.6)
        for line in 0..<count {
            for x in left...right {
                let offset = slope * (Double(x) - 700) + bow * sin(Double(x - left) / Double(right - left) * .pi)
                let point = CGPoint(x: Double(x), y: y + Double(line) * space + offset)
                if x == left { c.move(to: point) } else { c.addLine(to: point) }
            }
        }
        c.strokePath()
    }
    static func synthetic() throws {
        let nonlinear = image { c in
            lines(c, y: 280, slope: -0.004, bow: 2)
            lines(c, y: 670, slope: 0.007, bow: -2)
            lines(c, y: 1040, slope: 0.005, bow: 2)
            lines(c, y: 1430, slope: 0.008, bow: 0)
        }
        let found = StaffBandDetector.detect(in: nonlinear)
        try check(found.candidates.count == 4, "Different local tilts/bows: expected four complete staffs, got \(found.candidates.count)")
        for (staff, y) in zip(found.candidates, [282.0, 668, 1042, 1430]) {
            try check(abs(staff.staffLineFractions[0] * 1800 - y) <= 6,
                      "Nonlinear fixture recovered wrong line phase at \(staff.staffLineFractions[0] * 1800), expected \(y)")
            try check(staff.staffLineFractions.count == 5, "A recovered staff lacks five observed lines")
        }
        let shortBeams = image { c in
            for y in [240.0, 600, 1000, 1400] { lines(c, y: y, left: 440, right: 625) }
        }
        try check(StaffBandDetector.detect(in: shortBeams).candidates.isEmpty,
                  "Short beam/ledger groups became staffs")
        let disconnected = image { c in
            lines(c, y: 420, left: 120, right: 275, slope: -0.013)
            lines(c, y: 420, left: 1110, right: 1265, slope: -0.013)
            // Wide text/ink blocks must not corroborate the absent middle lines.
            c.setFillColor(gray: 0, alpha: 1)
            for y in stride(from: 405, to: 465, by: 18) {
                c.fill(CGRect(x: 525, y: y, width: 260, height: 9))
            }
        }
        try check(StaffBandDetector.detect(in: disconnected).candidates.isEmpty,
                  "Disconnected outer fragments/text invented an intervening staff")
        let fourLines = image { c in lines(c, y: 600, count: 4) }
        try check(StaffBandDetector.detect(in: fourLines).candidates.isEmpty,
                  "Four lines were completed by guessing a fifth")
        let flatBlocks = image { c in
            c.setFillColor(gray: 0, alpha: 1)
            for y in stride(from: 150, to: 1400, by: 180) {
                c.fill(CGRect(x: 100, y: y, width: 1200, height: 30))
            }
        }
        try check(StaffBandDetector.detect(in: flatBlocks).candidates.isEmpty,
                  "Flat saturated beams split into invented staff lines")
        try check(StaffBandDetector.detect(in: nonlinear, isCancelled: { true }).candidates.isEmpty,
                  "Cancelled recovery returned partial candidates")
        print("PASS: nonlinear local tilt, curved lines, short beams, disconnected fragments, text, four-line and flat-block negatives, cancellation")
    }
    // Kept independent from NativeScorePageAnalyzer so its ink-component changes
    // do not affect this detector regression and corpus experiment.
    static func render(_ page: PDFPage) -> CGImage {
        let b = page.bounds(for: .mediaBox)
        let scale = min(1800 / b.width, 2600 / b.height)
        let w = Int((b.width * scale).rounded()), h = Int((b.height * scale).rounded())
        let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(gray: 1, alpha: 1); c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        c.scaleBy(x: CGFloat(w) / b.width, y: CGFloat(h) / b.height)
        c.translateBy(x: -b.minX, y: -b.minY); page.draw(with: .mediaBox, to: c)
        return c.makeImage()!
    }
    static func sourcePositions() throws {
        let cases: [(String, String, Int, Int, Int, [Double])] = [
            ("sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf",
             "33ba263af431caa89d16530adcce3bf230b9c8b2e2367b737835c112fcfc99c8", 25, 20, 0,
             [184, 194, 203, 213, 223]),
            ("sample_scores/medium_skewed/09_schumann_frauenliebe_und_leben_op42_imslp_51733.pdf",
             "111250c3cf1a830f8aca75256e79e64807c24a8271454159bf71eda0c2942801", 14, 15, 14,
             [2184, 2196, 2209, 2222, 2235])
        ]
        for (path, hash, number, count, index, expected) in cases {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            try check(sha(data) == hash, "Source fixture changed: \(path)")
            let doc = PDFDocument(data: data)!
            let raster = render(doc.page(at: number - 1)!)
            let result = StaffBandDetector.detect(in: raster)
            try check(result.candidates.count == count, "\(path) p\(number): expected \(count) physical staffs, got \(result.candidates.count)")
            let staff = result.candidates[index]
            // Coordinates measured on the actual source, independent of both
            // old/new detections and any instrument-group/modulo assumption.
            let coordinates = staff.staffLineFractions.map { $0 * Double(raster.height) }
            for (actual, target) in zip(coordinates, expected) {
                try check(abs(actual - target) < 3, "\(path) p\(number): recovered wrong physical staff/line phase: \(coordinates)")
            }
            try check(staff.topFraction * Double(raster.height) < expected[0] - 6 &&
                      staff.bottomFraction * Double(raster.height) > expected[4] + 6,
                      "\(path) p\(number): recovered staff core clipped")
            print("PASS: \(path) p\(number), \(count) physical staffs, critical five-line coordinates \(coordinates)")
        }
    }
    static func sourceNonmusic() throws {
        let corpusData = try Data(contentsOf: URL(fileURLWithPath: "Tests/quality_control/corpus.json"))
        let corpus = try JSONDecoder().decode(Corpus.self, from: corpusData)
        let cases: [(String, [Int])] = [
            ("medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf", [1]),
            ("medium_skewed/09_schumann_frauenliebe_und_leben_op42_imslp_51733.pdf", [1, 18]),
            ("medium_skewed/10_schubert_winterreise_d911_imslp_00414.pdf", [1, 2]),
            ("lightly_skewed/10_brahms_string_quartet_no3_op67_imslp_242312.pdf", [26])
        ]
        for (suffix, numbers) in cases {
            guard let score = corpus.scores.first(where: { $0.path.hasSuffix(suffix) }) else {
                throw Failure(description: "Missing nonmusic source fixture: \(suffix)")
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: score.path))
            try check(sha(data) == score.sha256, "Nonmusic source fixture hash changed")
            let doc = PDFDocument(data: data)!
            for number in numbers {
                let result = StaffBandDetector.detect(in: render(doc.page(at: number - 1)!))
                try check(result.candidates.isEmpty, "Nonmusic typography invented \(result.candidates.count) staffs: \(score.path) p\(number)")
            }
        }
        print("PASS: real Brahms title/catalogue, Frauenliebe title/blank, Winterreise title/blank generate no staffs")
    }
    static func ledgerAndProseNegatives() throws {
        let cases: [(String, String, Int, [Double])] = [
            ("sample_scores/normal/02_orchestra/beethoven_egmont_overture_op84_score.pdf", "9be852e58c42cf5477bda7b197427033d3e779b996c5f6e6c3149dfb7352ae9c", 47,
             [215,323.5,450,558.5,667,793.5,909,1036,1176,1316,1424,1551,1678,1786]),
            ("sample_scores/rest_detection/01_full_scores/beethoven_symphony_no5_op67_complete_imslp52624.pdf", "9319765d21a573cdc8523288de6ca6d6b7cfd456a12f533de0d30a694a71474f", 106, [])
        ]
        for (path,hash,number,tops) in cases {
            let data=try Data(contentsOf:URL(fileURLWithPath:path)); try check(sha(data)==hash,"New source negative changed")
            let document=PDFDocument(data:data)!
            let image=render(document.page(at:number-1)!)
            let result=StaffBandDetector.detect(in:image)
            try check(result.candidates.count==tops.count,"\(path) p\(number): actual source requires \(tops.count) staves, got \(result.candidates.count)")
            for (staff,top) in zip(result.candidates,tops) {
                for (index,line) in staff.staffLineFractions.enumerated() {
                    try check(abs(line*Double(image.height)-(top+Double(index)*12))<2,"True staff/phase changed on Egmont p47")
                }
            }
        }
        let repeatedLedger=image { c in
            for x in stride(from:140,to:1260,by:50) { lines(c,y:500,left:x,right:x+24) }
        }
        try check(StaffBandDetector.detect(in:repeatedLedger).candidates.isEmpty,"Distributed short ledger groups became a staff")
        let brokenButReal=image { c in
            for x in stride(from:120,to:1260,by:130) { lines(c,y:500,left:x,right:x+95) }
        }
        let broken=StaffBandDetector.detect(in:brokenButReal)
        try check(broken.candidates.count==1,"Interrupted real five-line staff was rejected")
        print("PASS: source Egmont p47 ledger negative with all 14 true staff positions, Beethoven p106 prose negative, distributed ledger synthetic, interrupted staff positive")
    }
    static func harmonicSpacing() throws {
        // Real five-line staves with shorter, weaker beams halfway between
        // their lines. The extra peaks must not halve the staff spacing.
        let beamed = image { c in
            for y in [380.0, 850, 1320] {
                lines(c, y: y, space: 16)
                for line in 0..<4 { lines(c, y: y + Double(line) * 16 + 8,
                                             space: 16, left: 450, right: 1000, count: 1) }
            }
        }
        let found = StaffBandDetector.detect(in: beamed)
        try check(found.candidates.count == 3, "Weak interline beams must retain three complete staves")
        for (staff, top) in zip(found.candidates, [380.0, 850, 1320]) {
            for (index, line) in staff.staffLineFractions.enumerated() {
                try check(abs(line * 1800 - (top + Double(index) * 16)) < 2,
                          "Beam interference chose half-spacing rather than real lines")
            }
        }
        let mixed = image { c in
            lines(c, y: 280, space: 8)
            for y in [650.0, 1080, 1500] {
                lines(c, y: y, space: 16)
                for line in 0..<4 { lines(c, y: y + Double(line) * 16 + 8,
                                             space: 16, left: 450, right: 1000, count: 1) }
            }
        }
        let mixedFound = StaffBandDetector.detect(in: mixed)
        try check(mixedFound.candidates.count == 4, "Genuine small staff must survive larger-staff disambiguation")
        for (staff, pair) in zip(mixedFound.candidates, [(280.0,8.0),(650,16),(1080,16),(1500,16)]) {
            for (index, line) in staff.staffLineFractions.enumerated() {
                try check(abs(line * 1800 - (pair.0 + Double(index) * pair.1)) < 2,
                          "Mixed engraving sizes changed physical staff lines")
            }
        }
        // A larger spacing mode elsewhere on the page must not swallow two
        // genuine small staffs even when their lines form a larger harmonic.
        let smallPairAndLarge = image { c in
            lines(c, y: 280, space: 8); lines(c, y: 328, space: 8)
            for y in [650.0, 1080, 1500] {
                lines(c, y: y, space: 16)
                for line in 0..<4 { lines(c, y: y + Double(line) * 16 + 8,
                                             space: 16, left: 450, right: 1000, count: 1) }
            }
        }
        let guarded = StaffBandDetector.detect(in: smallPairAndLarge)
        try check(guarded.candidates.count == 5, "Strong small staffs were swallowed by a larger harmonic")
        for (staff, pair) in zip(guarded.candidates, [(280.0,8.0),(328,8),(650,16),(1080,16),(1500,16)]) {
            for (index, line) in staff.staffLineFractions.enumerated() {
                try check(abs(line * 1800 - (pair.0 + Double(index) * pair.1)) < 2,
                          "Replacement gate swallowed genuine small staff lines")
            }
        }
        let paired = image { c in lines(c, y: 600); lines(c, y: 672) }
        let pairedFound = StaffBandDetector.detect(in: paired)
        try check(pairedFound.candidates.count == 2, "Two close real staves were joined into a double-spacing harmonic")
        for (staff, top) in zip(pairedFound.candidates, [600.0,672]) {
            for (index, line) in staff.staffLineFractions.enumerated() {
                try check(abs(line * 1800 - (top + Double(index) * 12)) < 2, "Double-spacing harmonic displaced real staff")
            }
        }
        let path = "sample_scores/lightly_skewed/06_puccini_la_boheme_sc67_imslp_885132.pdf"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        try check(sha(data) == "1be78420e0c033982feacb556d5362b7525568d7ba66cd37bdecf2f5f8c46a04", "Bohème source changed")
        let document = PDFDocument(data: data)!
        let raster = render(document.page(at: 166)!)
        withExtendedLifetime(document) {}
        let actual = StaffBandDetector.detect(in: raster)
        let expected = [[1242.0,1257,1271,1286.5,1302], [1387,1401,1415.5,1431,1447],
                        [1603.5,1618,1633,1648.5,1663.5], [1728,1741.5,1756.5,1771.5,1787],
                        [1958,1972,1986.5,2002,2017], [2092,2106.5,2120.5,2137,2152]]
        try check(actual.candidates.count == expected.count, "Bohème p167 must recover all six physical piano staves")
        for (staff, lines) in zip(actual.candidates, expected) {
            for (fraction, target) in zip(staff.staffLineFractions, lines) {
                try check(abs(fraction * Double(raster.height) - target) < 3,
                          "Bohème p167 recovered wrong staff phase/spacing")
            }
        }
        print("PASS: interline beams, genuine mixed engraving sizes, double-spacing negative and source Bohème p167 six independent five-line positions")
    }
    static func option(_ name: String, default value: String) -> String {
        guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return value }
        return CommandLine.arguments[index + 1]
    }
    static func corpus() throws {
        let corpusPath = option("--corpus", default: "Tests/quality_control/corpus.json")
        let corpusData = try Data(contentsOf: URL(fileURLWithPath: corpusPath))
        let scores = try JSONDecoder().decode(Corpus.self, from: corpusData).scores
        let offset = Int(option("--offset", default: "0"))!, stride = Int(option("--stride", default: "1"))!
        let baseline = option("--baseline", default: ".build/auto-qc/candidate/all-samples")
        let out = URL(fileURLWithPath: option("--out", default: ".build/staff-recall-corpus.json"))
        let detector = URL(fileURLWithPath: option("--detector-source", default: "Partsmith/Core/Detection/StaffBandDetector.swift"))
        let detectorHash = sha(try Data(contentsOf: detector))
        let exeHash = sha(try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0])))
        var results: [ScoreResult] = []
        func save() throws {
            let report = Report(detectorSHA256: detectorHash, executableSHA256: exeHash, corpusSHA256: sha(corpusData),
                                baseline: baseline, results: results,
                                limitation: "Detector geometry diagnostics only. Added/moved candidates require source review; no instrument identity, crop/export, rest inference, or visual pass is implied.")
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: out, options: .atomic)
        }
        for (position, score) in scores.enumerated() where position % stride == offset {
            var pages: [ObservedPage] = [], changes: [PageChange] = []
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: score.path))
                try check(sha(data) == score.sha256, "Corpus source hash mismatch")
                let oldURL = URL(fileURLWithPath: baseline).appendingPathComponent(score.id).appendingPathComponent("inventory/inventory.json")
                let old = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf: oldURL))
                try check(old.sourceSHA256 == score.sha256, "Baseline source hash mismatch")
                let doc = PDFDocument(data: data)!
                try check(doc.pageCount == score.pageCount && old.pages.count == doc.pageCount, "Page count mismatch")
                for pageIndex in 0..<doc.pageCount {
                    let found: [ObservedStaff] = autoreleasepool {
                        StaffBandDetector.detect(in: render(doc.page(at: pageIndex)!)).candidates.map {
                            ObservedStaff(staffLineFractions: $0.staffLineFractions)
                        }
                    }
                    let previous = old.pages.first { $0.pageIndex == pageIndex }!.staves
                    pages.append(ObservedPage(pageIndex: pageIndex, staves: found))
                    var used = Set<Int>(), moved: [[[Double]]] = [], missing: [[Double]] = []
                    for staff in previous {
                        let lines = staff.staffLineFractions, space = (lines[4] - lines[0]) / 4
                        let best = found.indices.filter { !used.contains($0) }.min {
                            abs(found[$0].staffLineFractions[0] - lines[0]) < abs(found[$1].staffLineFractions[0] - lines[0])
                        }
                        guard let best, abs(found[best].staffLineFractions[0] - lines[0]) < space * 2.5 else {
                            missing.append(lines); continue
                        }
                        used.insert(best)
                        if zip(lines, found[best].staffLineFractions).contains(where: { abs($0 - $1) > 0.00001 }) {
                            moved.append([lines, found[best].staffLineFractions])
                        }
                    }
                    let added = found.indices.filter { !used.contains($0) }.map { found[$0].staffLineFractions }
                    if !added.isEmpty || !missing.isEmpty || !moved.isEmpty {
                        changes.append(PageChange(page: pageIndex + 1, beforeCount: previous.count, afterCount: found.count,
                                                  addedStaffLines: added, missingStaffLines: missing, movedStaffLines: moved))
                    }
                    if pageIndex % 20 == 0 { print("\(score.id) \(pageIndex + 1)/\(doc.pageCount)"); fflush(stdout) }
                }
                results.append(ScoreResult(id: score.id, sourceSHA256: score.sha256, pages: pages, changes: changes, error: nil))
                print("DONE \(score.id): \(pages.count) pages, \(changes.count) changed pages")
            } catch {
                results.append(ScoreResult(id: score.id, sourceSHA256: score.sha256, pages: pages, changes: changes, error: String(describing: error)))
                print("ERROR \(score.id): \(error)")
            }
            try save(); fflush(stdout)
        }
        try check(results.allSatisfy { $0.error == nil }, "One or more corpus sources failed; inspect \(out.path)")
    }
    static func main() throws {
        if CommandLine.arguments.contains("--corpus") { try corpus() }
        else { try synthetic(); try sourcePositions(); try sourceNonmusic(); try ledgerAndProseNegatives(); try harmonicSpacing() }
    }
}
