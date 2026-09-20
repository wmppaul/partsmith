import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import PDFKit

@main
enum RestDetectionTests {
    struct Source: Decodable { var path: String; var sha256: String }
    struct Fixture: Decodable {
        var id: String
        var sourceID: String
        var pageIndex: Int
        var systemIndex: Int
        var instrument: String
        var band: [Double]
        var staffRanges: [[Double]]
        var expectedBarCount: Int?
        var sourceRestCount: Int?
        var prefixLandmarks: [[Double]]?
        var suffixLandmarks: [[Double]]?
        var reason: String
        var rect: CGRect { CGRect(x: band[0], y: band[1], width: band[2] - band[0], height: band[3] - band[1]) }
    }
    struct Corpus: Decodable { var sources: [String: Source]; var fixtures: [Fixture] }
    struct ResultRecord: Encodable {
        var id: String
        var expectedBarCount: Int?
        var actualBarCount: Int?
        var staffCount: Int
        var passed: Bool
        var elapsedMilliseconds: Double
        var diagnostic: String?
    }
    static var checks = 0
    static var failures: [String] = []

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { failures.append(message); print("FAIL: \(message)") }
    }

    // Independent, intentionally adversarial engraved shapes. These cases make
    // near-miss sounding notation observable rather than relying only on scores
    // whose positive and negative bands look very different.
    static func runSyntheticChecks() {
        let width = 1200, height = 480
        let staffTop = 180.0, space = 12.0
        let band = CGRect(x: 0, y: 0.30, width: 1, height: 0.23)
        let supplied = StaffDetectionResult(candidates: [StaffBandCandidate(
            id: 0, staffLineFractions: (0..<5).map { (staffTop + Double($0) * space) / Double(height) },
            topFraction: band.minY, bottomFraction: band.maxY, confidence: 1, warnings: [])], warnings: [])
        let names = ["plain-three", "attached-line-spur", "detached-small-dot", "ink-outside-crop", "ink-inside-crop", "first-note-plus-rest", "first-whole-note-plus-rest",
                     "first-whole-note", "later-whole-note", "half-rest", "missing-barline",
                     "interior-repeat-dots", "fermata", "first-ledger-note-plus-rest",
                     "near-opening-note-plus-rest", "near-opening-whole-note-plus-rest",
                     "signature-adjacent-note-plus-rest", "opening-edge-note-plus-rest",
                     "opening-edge-whole-note-plus-rest", "opening-edge-ledger-note-plus-rest"]
        var baseline: CGImage?
        for name in names {
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.setAllowsAntialiasing(false)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.translateBy(x: 0, y: Double(height))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(gray: 0, alpha: 1)
            for line in 0..<5 {
                context.fill(CGRect(x: 80, y: staffTop + Double(line) * space, width: 1021, height: 1))
            }
            for x in [80, 440, 740, 1100] where !(name == "missing-barline" && x == 740) {
                context.fill(CGRect(x: Double(x), y: staffTop, width: 2, height: space * 4 + 1))
            }
            if name == "attached-line-spur" {
                context.fill(CGRect(x: 600, y: staffTop + space * 4 - 5, width: 3, height: 6))
            }
            if name == "detached-small-dot" {
                context.fill(CGRect(x: 600, y: staffTop + space * 4 - 5, width: 3, height: 2))
            }
            if name == "ink-outside-crop" || name == "ink-inside-crop" {
                let bottom = Int(ceil(band.maxY * Double(height)))
                context.fill(CGRect(x: 590, y: name == "ink-outside-crop" ? bottom : bottom - 2, width: 14, height: 2))
            }
            func note(_ centerX: Double, _ centerY: Double, hollow: Bool, stem: Bool) {
                context.setFillColor(gray: 0, alpha: 1)
                context.fillEllipse(in: CGRect(x: centerX - 9, y: centerY - 5, width: 18, height: 10))
                if hollow {
                    context.setFillColor(gray: 1, alpha: 1)
                    context.fillEllipse(in: CGRect(x: centerX - 5, y: centerY - 3, width: 10, height: 6))
                    context.setFillColor(gray: 0, alpha: 1)
                }
                if stem { context.fill(CGRect(x: centerX + 7, y: centerY - 30, width: 2, height: 31)) }
            }
            for (index, x) in [300.0, 590, 920].enumerated() {
                if (name == "first-whole-note" && index == 0) || (name == "later-whole-note" && index == 1) {
                    note(x, staffTop + space * 1.4, hollow: true, stem: false)
                } else if name == "half-rest" && index == 1 {
                    context.fill(CGRect(x: x - 8, y: staffTop + space * 2 - 6, width: 16, height: 6))
                } else {
                    context.fill(CGRect(x: x - 8, y: staffTop + space, width: 16, height: 7))
                }
            }
            if name == "opening-edge-note-plus-rest" { note(100, staffTop + space * 2.5, hollow: false, stem: true) }
            if name == "opening-edge-whole-note-plus-rest" { note(100, staffTop + space * 1.4, hollow: true, stem: false) }
            if name == "opening-edge-ledger-note-plus-rest" {
                note(100, staffTop + space * 5, hollow: false, stem: true)
                context.fill(CGRect(x: 87, y: staffTop + space * 5, width: 26, height: 1))
            }
            if name == "near-opening-note-plus-rest" { note(110, staffTop + space * 2.5, hollow: false, stem: true) }
            if name == "near-opening-whole-note-plus-rest" { note(110, staffTop + space * 1.4, hollow: true, stem: false) }
            if name == "signature-adjacent-note-plus-rest" {
                // An opening clef/key-like ink cluster followed closely by a
                // sounding note. Horizontal adjacency is not proof of signature.
                context.setLineWidth(2)
                context.setStrokeColor(gray: 0, alpha: 1)
                context.strokeEllipse(in: CGRect(x: 94, y: staffTop + 4, width: 18, height: 35))
                context.fill(CGRect(x: 106, y: staffTop - 8, width: 2, height: 65))
                for x in [124.0, 136.0, 148.0] {
                    context.fill(CGRect(x: x, y: staffTop + 5, width: 2, height: 21))
                    context.strokeEllipse(in: CGRect(x: x, y: staffTop + 20, width: 7, height: 8))
                }
                note(165, staffTop + space * 2.5, hollow: false, stem: true)
            }
            if name == "first-note-plus-rest" { note(168, staffTop + space * 2.5, hollow: false, stem: true) }
            if name == "first-whole-note-plus-rest" { note(168, staffTop + space * 1.4, hollow: true, stem: false) }
            if name == "first-ledger-note-plus-rest" {
                note(170, staffTop + space * 5, hollow: false, stem: true)
                context.fill(CGRect(x: 157, y: staffTop + space * 5, width: 26, height: 1))
            }
            if name == "interior-repeat-dots" {
                for y in [staffTop + space * 1.5, staffTop + space * 2.5] {
                    context.fillEllipse(in: CGRect(x: 725, y: y - 2, width: 5, height: 5))
                }
            }
            if name == "fermata" {
                context.setStrokeColor(gray: 0, alpha: 1); context.setLineWidth(3)
                context.addArc(center: CGPoint(x: 920, y: staffTop - 9), radius: 15,
                               startAngle: .pi, endAngle: .pi * 2, clockwise: false)
                context.strokePath()
                context.fillEllipse(in: CGRect(x: 917, y: staffTop - 14, width: 6, height: 6))
            }
            let image = context.makeImage()!
            if name == "plain-three" { baseline = image }
            var diagnostic: String?
            let result = ScoreRestDetector.detect(in: image, band: band, staffDetection: supplied,
                                                  diagnostic: { diagnostic = $0 })
            let expected: Int? = ["plain-three", "attached-line-spur", "ink-outside-crop"].contains(name) ? 3 : nil
            check(result?.barCount == expected,
                  "synthetic \(name): expected \(expected.map(String.init) ?? "decline"), got \(result?.barCount.description ?? "none"); \(diagnostic ?? "")")
            print("SYNTHETIC \(name): \(result?.barCount.description ?? "declined") \(diagnostic ?? "")")
        }
        guard let baseline else { return }
        check(ScoreRestDetector.detect(in: baseline, band: band, staffDetection: supplied,
                                       isCancelled: { true }) == nil, "Already-cancelled analysis does not return a claim")
        var cancellationChecks = 0
        check(ScoreRestDetector.detect(in: baseline, band: band, staffDetection: supplied,
              isCancelled: { cancellationChecks += 1; return cancellationChecks > 5 }) == nil,
              "Cancellation during raster analysis does not return a partial count")
        for invalid in [CGRect.zero, CGRect(x: -0.1, y: 0.2, width: 0.5, height: 0.4),
                        CGRect(x: 0, y: 0.2, width: 1.1, height: 0.4)] {
            check(ScoreRestDetector.detect(in: baseline, band: invalid, staffDetection: supplied) == nil,
                  "Invalid crop geometry cannot produce a rest claim")
        }
    }

    static func runRealSignatureMutations(image: CGImage, fixture: Fixture, staffDetection: StaffDetectionResult) {
        guard let staff = staffDetection.candidates.first(where: {
            $0.staffLineFractions.first.map { $0 > fixture.rect.minY && $0 < fixture.rect.maxY } ?? false
        }) else { check(false, "Real-signature mutation has target staff geometry"); return }
        let top = staff.staffLineFractions[0] * Double(image.height)
        let space = (staff.staffLineFractions[4] - staff.staffLineFractions[0]) * Double(image.height) / 4
        struct Mutation { var name: String; var position: Double; var width: Double; var stem: Int }
        var mutations = [Mutation(name: "copy-control", position: 0, width: 0, stem: 0)]
        // Exercise all five staff lines and four spaces. A hollow glyph can be
        // split by line removal and a stem can join nearby key/meter fragments.
        for position in stride(from: 0.0, through: 4.0, by: 0.5) {
            for width in [1.2, 1.6, 1.8] {
                mutations.append(Mutation(name: "whole-note-position-\(position)-width-\(width)",
                                          position: position, width: width, stem: 0))
            }
            for stem in [-1, 1] {
                mutations.append(Mutation(name: "\(stem < 0 ? "up" : "down")-stem-note-position-\(position)",
                                          position: position, width: 1.5, stem: stem))
            }
        }
        // Keep the exact originally failing off-grid shape as a regression.
        mutations.append(Mutation(name: "original-whole-note-position-1.4", position: 1.4, width: 1.8, stem: 0))
        for mutation in mutations {
            let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            if mutation.name != "copy-control" {
                context.translateBy(x: 0, y: Double(image.height)); context.scaleBy(x: 1, y: -1)
                let x = Double(image.width) * 330 / 1800
                let y = top + space * mutation.position
                context.setFillColor(gray: 0, alpha: 1)
                context.fillEllipse(in: CGRect(x: x - space * mutation.width / 2, y: y - space * 0.5,
                                               width: space * mutation.width, height: space))
                if mutation.stem == 0 {
                    context.setFillColor(gray: 1, alpha: 1)
                    context.fillEllipse(in: CGRect(x: x - space * mutation.width * 0.28, y: y - space * 0.3,
                                                   width: space * mutation.width * 0.56, height: space * 0.6))
                } else if mutation.stem < 0 {
                    context.fill(CGRect(x: x + space * (mutation.width / 2 - 0.2), y: y - space * 3,
                                        width: space * 0.2, height: space * 3.1))
                } else {
                    context.fill(CGRect(x: x - space * mutation.width / 2, y: y - space * 0.1,
                                        width: space * 0.2, height: space * 3.1))
                }
            }
            var diagnostic: String?
            let result = ScoreRestDetector.detect(in: context.makeImage()!, band: fixture.rect,
                staffDetection: staffDetection, diagnostic: { diagnostic = $0 })
            let expected: Int? = mutation.name == "copy-control" ? 4 : nil
            check(result?.barCount == expected,
                  "real signature \(mutation.name): expected \(expected.map(String.init) ?? "decline"), got \(result?.barCount.description ?? "none"); \(diagnostic ?? "")")
            print("REAL SIGNATURE \(mutation.name): \(result?.barCount.description ?? "declined")")
        }
    }

    static func runPaddedLedgerMutations(image: CGImage, fixture: Fixture, staffDetection: StaffDetectionResult) throws {
        guard let staff = staffDetection.candidates.first(where: {
            $0.staffLineFractions.first.map { $0 > fixture.rect.minY && $0 < fixture.rect.maxY } ?? false
        }) else { return }
        let sourceRect = CGRect(x: 0, y: fixture.rect.minY * Double(image.height),
                                width: Double(image.width), height: fixture.rect.height * Double(image.height)).integral
        let strip = image.cropping(to: sourceRect)!
        let canvasHeight = 420, paddingTop = 130.0
        let lines = staff.staffLineFractions.map { $0 * Double(image.height) - sourceRect.minY + paddingTop }
        let space = (lines[4] - lines[0]) / 4
        let translated = StaffDetectionResult(candidates: [StaffBandCandidate(id: 0,
            staffLineFractions: lines.map { $0 / Double(canvasHeight) }, topFraction: 0,
            bottomFraction: 1, confidence: 1, warnings: [])], warnings: [])
        // Isolate the real source strip and pad it with white space so ledger
        // notes fit without neighboring oboe ink causing a trivial refusal.
        let cases: [(Double?, Int)] = [(nil, 0)] + [-2.0, -1.5, 5.5, 6.0].flatMap { pitch in
            [-1, 1].map { (Optional(pitch), $0) }
        }
        for (position, stem) in cases {
            let context = CGContext(data: nil, width: image.width, height: canvasHeight, bitsPerComponent: 8,
                bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: image.width, height: canvasHeight))
            context.draw(strip, in: CGRect(x: 0, y: Double(canvasHeight) - paddingTop - Double(strip.height),
                                          width: Double(image.width), height: Double(strip.height)))
            let name: String
            if let position {
                name = "ledger-position-\(position)-\(stem < 0 ? "up" : "down")-stem"
                context.translateBy(x: 0, y: Double(canvasHeight)); context.scaleBy(x: 1, y: -1)
                let x = Double(image.width) * 330 / 1800, y = lines[0] + space * position
                context.setFillColor(gray: 0, alpha: 1)
                context.fillEllipse(in: CGRect(x: x - space * 0.75, y: y - space * 0.5,
                                               width: space * 1.5, height: space))
                if stem < 0 {
                    context.fill(CGRect(x: x + space * 0.55, y: y - space * 3,
                                        width: space * 0.2, height: space * 3.1))
                } else {
                    context.fill(CGRect(x: x - space * 0.75, y: y - space * 0.1,
                                        width: space * 0.2, height: space * 3.1))
                }
                let ledgers = position < 0 ? stride(from: -1.0, through: position, by: -1).map { $0 }
                    : stride(from: 5.0, through: position, by: 1).map { $0 }
                for ledger in ledgers {
                    context.fill(CGRect(x: x - space * 1.25, y: lines[0] + space * ledger,
                                        width: space * 2.5, height: max(1, space * 0.1)))
                }
            } else { name = "padded-copy-control" }
            let modified = context.makeImage()!
            var diagnostic: String?
            let result = ScoreRestDetector.detect(in: modified, band: CGRect(x: 0, y: 0, width: 1, height: 1),
                staffDetection: translated, diagnostic: { diagnostic = $0 })
            let expected: Int? = position == nil ? 4 : nil
            check(result?.barCount == expected,
                  "real signature \(name): expected \(expected.map(String.init) ?? "decline"), got \(result?.barCount.description ?? "none"); \(diagnostic ?? "")")
            print("REAL LEDGER \(name): \(result?.barCount.description ?? "declined")")
            let folder = URL(fileURLWithPath: ".build/rest-detection-tests", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try NSBitmapImageRep(cgImage: modified).representation(using: .png, properties: [:])!
                .write(to: folder.appendingPathComponent(name + ".png"))
        }
    }

    static func main() throws {
        let corpus = try JSONDecoder().decode(Corpus.self,
            from: Data(contentsOf: URL(fileURLWithPath: "Tests/extraction/automatic-rest-fixtures.json")))
        var results: [ResultRecord] = []
        let filtered = CommandLine.arguments.dropFirst().first.flatMap { arg in
            arg.hasPrefix("--fixture=") ? String(arg.dropFirst("--fixture=".count)) : nil
        }
        for sourceID in corpus.sources.keys.sorted() {
            guard let source = corpus.sources[sourceID] else { continue }
            let fixtures = corpus.fixtures.filter { $0.sourceID == sourceID && (filtered == nil || $0.id == filtered) }
            guard !fixtures.isEmpty else { continue }
            let data = try Data(contentsOf: URL(fileURLWithPath: source.path))
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            check(hash == source.sha256, "\(sourceID): source bytes match the independently reviewed corpus")
            guard let pdf = PDFDocument(data: data) else { fatalError("Fixture PDF cannot be opened: \(source.path)") }
            for pageIndex in Set(fixtures.map(\.pageIndex)).sorted() {
                guard let page = pdf.page(at: pageIndex), let image = NativeScorePageAnalyzer.render(page) else {
                    fatalError("Fixture page cannot be rendered: \(source.path) page \(pageIndex + 1)")
                }
                let staffDetection = StaffBandDetector.detect(in: image)
                let staves = staffDetection.candidates.map(ScoreObservedStaff.init)
                for fixture in fixtures.filter({ $0.pageIndex == pageIndex }) {
                    let initialFailures = failures.count
                    let targetStaves = staves.filter {
                        guard $0.staffLineFractions.count == 5 else { return false }
                        let center = ($0.staffLineFractions[0] + $0.staffLineFractions[4]) / 2
                        return center > fixture.rect.minY && center < fixture.rect.maxY
                    }
                    check(targetStaves.count == fixture.staffRanges.count,
                          "\(fixture.id): source band contains the independently counted physical staves")
                    for (observed, expected) in zip(targetStaves, fixture.staffRanges) {
                        check(abs(observed.staffLineFractions[0] - expected[0]) < 0.006
                              && abs(observed.staffLineFractions[4] - expected[1]) < 0.006,
                              "\(fixture.id): detector targets the reviewed staff, not a neighbor")
                    }
                    let started = Date()
                    var diagnostic: String?
                    let result = ScoreRestDetector.detect(in: image, band: fixture.rect, staffDetection: staffDetection, diagnostic: { diagnostic = $0 })
                    let elapsed = Date().timeIntervalSince(started) * 1000
                    let countPassed = result?.barCount == fixture.expectedBarCount
                    check(countPassed, "\(fixture.id): expected \(fixture.expectedBarCount.map(String.init) ?? "no automatic replacement"), got \(result?.barCount.description ?? "none")")
                    if let result {
                        let tolerance = 0.001
                        func covers(_ rect: CGRect, _ landmark: [Double]) -> Bool {
                            rect.minX <= landmark[0] + tolerance && rect.minY <= landmark[1] + tolerance
                                && rect.maxX >= landmark[2] - tolerance && rect.maxY >= landmark[3] - tolerance
                        }
                        check(result.restBounds.count == result.barCount, "\(fixture.id): one independently localized rest per counted bar")
                        check(result.staffLineFractions.count == 5 && result.staffLineFractions == result.staffLineFractions.sorted(),
                              "\(fixture.id): output contains ordered staff geometry")
                        check(fixture.rect.insetBy(dx: -tolerance, dy: -tolerance).contains(result.prefixBounds),
                              "\(fixture.id): retained prefix remains within the reviewed source band")
                        for landmark in fixture.prefixLandmarks ?? [] {
                            check(covers(result.prefixBounds, landmark), "\(fixture.id): original leading tempo, key, clef, and meter are preserved")
                        }
                        for landmark in fixture.suffixLandmarks ?? [] {
                            check(result.suffixBounds.map { covers($0, landmark) } ?? false,
                                  "\(fixture.id): original final double bar is preserved")
                        }
                        check(result.restBounds.allSatisfy { fixture.rect.insetBy(dx: -tolerance, dy: -tolerance).contains($0) },
                              "\(fixture.id): every counted rest lies inside the reviewed band")
                        check(result.restBounds.allSatisfy { $0.minX >= result.prefixBounds.maxX - tolerance },
                              "\(fixture.id): retained prefix does not duplicate a counted full-bar rest")
                    }
                    if fixture.id == "magic-flute-allegro-flute-four" {
                        runRealSignatureMutations(image: image, fixture: fixture, staffDetection: staffDetection)
                        try runPaddedLedgerMutations(image: image, fixture: fixture, staffDetection: staffDetection)
                    }
                    let passed = failures.count == initialFailures
                    results.append(ResultRecord(id: fixture.id, expectedBarCount: fixture.expectedBarCount,
                        actualBarCount: result?.barCount, staffCount: targetStaves.count, passed: passed,
                        elapsedMilliseconds: elapsed, diagnostic: diagnostic))
                    print("\(passed ? "PASS" : "FAIL") \(fixture.id): \(result?.barCount.description ?? "declined") (\(String(format: "%.1f", elapsed)) ms) \(diagnostic ?? "")")
                }
            }
        }
        if filtered == nil { runSyntheticChecks() }
        check(!results.isEmpty, "At least one reviewed real-score fixture ran")
        let output = URL(fileURLWithPath: ".build/rest-detection-tests", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: output.appendingPathComponent("results.json"))
        print("\(checks) rest-detection checks, \(results.count) real-score fixtures, \(failures.count) failures")
        if !failures.isEmpty { exit(1) }
    }
}
