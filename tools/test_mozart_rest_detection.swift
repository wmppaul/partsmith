import AppKit
import CryptoKit
import Foundation
import PDFKit

/// Reproduces the user's K488 opening with native analysis and compact Auto
/// crops. Staff IDs only establish the reviewed first-system instrument order;
/// no manually tightened crop rectangles are used for the positive cases.
@main enum MozartRestDetectionTests {
    static let output = URL(fileURLWithPath: ".build/mozart-rest-detection")
    static var failures: [String] = []
    static var records: [[String: String]] = []
    static func check(_ okay: Bool, _ name: String, _ diagnostic: String = "") {
        records.append(["case": name, "passed": String(okay), "diagnostic": diagnostic])
        if !okay { failures.append(name); print("FAIL \(name): \(diagnostic)") }
    }
    static func save(_ image: CGImage, _ name: String) throws {
        try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent(name + ".png"))
    }
    static func main() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let source = "Tests/quality_control/mozart-rest-detection-2026-10-04/source-page-1.pdf"
        let pdf = PDFDocument(url: URL(fileURLWithPath: source))!
        let page = pdf.page(at: 0)!, image = NativeScorePageAnalyzer.render(page)!
        let pageBounds = page.bounds(for: .mediaBox)
        let analysis = NativeScorePageAnalyzer.analyze(pageIndex: 0, image: image,
            pageWidth: pageBounds.width, pageHeight: pageBounds.height)
        let names = ["Flute", "Clarinet", "Bassoon", "Horn", "Piano", "Violin1", "Violin2", "Viola", "Cello"]
        let profile = ScoreExtractionProfile(parts: names.enumerated().map {
            ScorePartDefinition(id: String($0.offset), name: $0.element, staffCount: $0.element == "Piano" ? 2 : 1)
        }, cropMode: "compact")
        var at = 0
        let assignments = profile.parts.map { part -> ScoreBandOverride in
            defer { at += part.staffCount }
            return ScoreBandOverride(partID: part.id, candidateIDs: Array(analysis.staves[at..<(at + part.staffCount)]).map(\.id))
        }
        let correction = ScorePageOverride(pageIndex: 0, reason: "Reviewed opening system; detector regression excerpt",
            systems: [ScoreSystemOverride(systemIndex: 0, bands: assignments, barCount: 5)],
            ignoredCandidateIDs: analysis.staves.dropFirst(10).map(\.id))
        let plan = ScoreExtractionPlanner.plan(pages: [analysis], profile: profile, overrides: [correction])
        let detected = StaffBandDetector.detect(in: image)
        let bands = Dictionary(uniqueKeysWithValues: plan.pages[0].assignments.map { band in
            (band.partID, CGRect(x: band.leftFraction, y: band.topFraction,
                 width: 1 - band.leftFraction - band.rightFraction, height: band.bottomFraction - band.topFraction))
        })
        func recognize(_ image: CGImage, _ id: String, _ name: String, expected: Int?) -> ScoreRestDetector.Detection? {
            var notes: [String] = []
            let result = ScoreRestDetector.detect(in: image, band: bands[id]!, staffDetection: detected,
                diagnostic: { notes.append($0) })
            check(result?.barCount == expected, name, notes.joined(separator: "; "))
            return result
        }
        for id in 0..<names.count {
            let result = recognize(image, String(id), "native-auto-\(names[id])", expected: (1...4).contains(id) ? 5 : nil)
            if let result {
                check(result.canExtendThroughFollowingRests, "\(names[id])-ordinary-closing-bar")
                check(result.prefixBounds.maxX < result.restBounds.map(\.minX).min()!, "\(names[id])-prefix-keeps-meter-before-rest")
            }
            let band = bands[String(id)]!
            try save(image.cropping(to: CGRect(x: band.minX * Double(image.width), y: band.minY * Double(image.height),
                width: band.width * Double(image.width), height: band.height * Double(image.height)).integral)!, "auto-\(names[id])")
        }
        let piano = recognize(image, "4", "grand-staff-count-is-five-not-ten", expected: 5)!
        check(piano.staffLineGroups?.count == 2 && piano.staffLineGroups?.flatMap { $0 }.count == 10,
              "grand-staff-retains-both-five-line-groups")
        let clarinet = detected.candidates[1]
        let pianoStaves = [detected.candidates[4], detected.candidates[5]]
        func mutate(staff: StaffBandCandidate, x: Double, position: Double, kind: String) -> CGImage {
            let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.translateBy(x: 0, y: Double(image.height)); context.scaleBy(x: 1, y: -1)
            context.setFillColor(gray: 0, alpha: 1); context.setStrokeColor(gray: 0, alpha: 1)
            let top = staff.staffLineFractions[0] * Double(image.height)
            let space = (staff.staffLineFractions[4] - staff.staffLineFractions[0]) * Double(image.height) / 4
            let y = top + position * space
            if kind == "fermata" {
                context.setLineWidth(space * 0.2)
                context.addArc(center: CGPoint(x: x, y: y), radius: space, startAngle: .pi, endAngle: 0, clockwise: false)
                context.strokePath()
                context.fillEllipse(in: CGRect(x: x - space * 0.2, y: y - space * 0.3, width: space * 0.4, height: space * 0.4))
            } else if kind == "meter" {
                // Copy the printed common-time glyph into an internal measure.
                let glyph = image.cropping(to: CGRect(x: 405, y: top + space * 0.75, width: 26, height: space * 2.5).integral)!
                context.saveGState(); context.translateBy(x: x, y: top + space * 3.25); context.scaleBy(x: 1, y: -1)
                context.draw(glyph, in: CGRect(x: 0, y: 0, width: glyph.width, height: glyph.height)); context.restoreGState()
            } else if kind == "closing-double" {
                context.fill(CGRect(x: x, y: top, width: space * 0.18, height: space * 4))
            } else if kind == "closing-word" {
                context.fill(CGRect(x: x, y: top - space, width: space * 0.7, height: space))
            } else {
                context.fillEllipse(in: CGRect(x: x - space * 0.75, y: y - space * 0.45, width: space * 1.5, height: space * 0.9))
                if kind == "whole" {
                    context.setFillColor(gray: 1, alpha: 1)
                    context.fillEllipse(in: CGRect(x: x - space * 0.42, y: y - space * 0.25, width: space * 0.84, height: space * 0.5))
                } else {
                    let down = kind == "down"
                    context.fill(CGRect(x: x + space * (down ? -0.75 : 0.58), y: down ? y : y - space * 3,
                        width: space * 0.17, height: space * 3))
                }
            }
            return context.makeImage()!
        }
        // Notes both inside the newly recognized empty signature gap and after
        // the meter must remain music, even when the measure also has a rest.
        for x in [380.0, 450, 740] {
            for position in stride(from: 0.0, through: 4.0, by: 0.5) {
                for kind in ["whole", "up", "down"] {
                    let changed = mutate(staff: clarinet, x: x, position: position, kind: kind)
                    _ = recognize(changed, "1", "clarinet-\(kind)-x\(x)-pitch\(position)", expected: nil)
                }
            }
        }
        for (hand, staff) in pianoStaves.enumerated() {
            let changed = mutate(staff: staff, x: 740, position: 2.5, kind: "up")
            _ = recognize(changed, "4", "piano-hand-\(hand)-playing", expected: nil)
            try save(changed.cropping(to: CGRect(x: 0, y: bands["4"]!.minY * Double(image.height), width: Double(image.width),
                height: bands["4"]!.height * Double(image.height)).integral)!, "piano-one-hand-\(hand)-playing")
        }
        // Equal counts alone cannot establish a grand-staff measure mapping.
        // Shift one lower-hand barline while preserving its staff lines/rests.
        do {
            let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.translateBy(x: 0, y: Double(image.height)); context.scaleBy(x: 1, y: -1)
            let staff = pianoStaves[1], x = piano.boundaryFractions[2] * Double(image.width)
            let top = staff.staffLineFractions[0] * Double(image.height)
            let bottom = staff.staffLineFractions[4] * Double(image.height)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: x - 3, y: top - 2, width: 6, height: bottom - top + 4))
            context.setFillColor(gray: 0, alpha: 1)
            for line in staff.staffLineFractions {
                context.fill(CGRect(x: x - 3, y: line * Double(image.height), width: 6, height: 1))
            }
            context.fill(CGRect(x: x + 25, y: top, width: 2, height: bottom - top + 1))
            _ = recognize(context.makeImage()!, "4", "grand-staff-conflicting-boundaries", expected: nil)
        }
        for kind in ["fermata", "meter"] {
            _ = recognize(mutate(staff: clarinet, x: 1120, position: -1.5, kind: kind), "1", "clarinet-internal-\(kind)", expected: nil)
            _ = recognize(mutate(staff: pianoStaves[1], x: 1120, position: -1.5, kind: kind), "4", "piano-internal-\(kind)", expected: nil)
        }
        for kind in ["closing-double", "closing-word"] {
            let x = kind == "closing-double" ? 1716.0 : 1732.0
            let result = recognize(mutate(staff: clarinet, x: x, position: 0, kind: kind), "1", "\(kind)-source-preserved", expected: 5)
            check(result?.canExtendThroughFollowingRests == false, "\(kind)-stops-cross-system-join")
        }
        check(ScoreRestDetector.detect(in: image, band: bands["4"]!, staffDetection: detected,
            isCancelled: { true }) == nil, "grand-staff-cancellation")
        let report: [String: Any] = ["checks": records.count, "failures": failures, "cases": records,
            "sourceSHA256": SHA256.hash(data: try Data(contentsOf: URL(fileURLWithPath: source))).map { String(format: "%02x", $0) }.joined()]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("results.json"))
        print("\(failures.isEmpty ? "PASS" : "FAIL") \(records.count) native Mozart rest checks; \(failures.count) failures")
        if !failures.isEmpty { exit(1) }
    }
}
