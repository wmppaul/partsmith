import Foundation
import PDFKit

@main
enum ScorePlannerTests {
    static var assertions = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        assertions += 1
        if !condition() { throw NSError(domain: "ScorePlannerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func main() throws {
        let profile = ScoreExtractionProfile(parts: [ScorePartDefinition(id: "voice", name: "Voice", staffCount: 1), ScorePartDefinition(id: "piano", name: "Piano", staffCount: 2)])
        let staves = [0.15, 0.22, 0.30, 0.53, 0.60, 0.68].enumerated().map { i, y in
            ScoreObservedStaff(StaffBandCandidate(id: i, staffLineFractions: (0..<5).map { y + Double($0) * 0.005 }, topFraction: y - 0.01, bottomFraction: y + 0.03, confidence: 0.9, warnings: []))
        }
        var page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 800, imageWidth: 1500, imageHeight: 2000, staves: staves, warnings: [])
        let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        try check(plan.canApply && plan.bands.count == 4, "Two-system voice/piano cadence failed")
        try check(plan.bands[1].candidateIDs == [1, 2] && plan.bands[3].candidateIDs == [4, 5], "Grand-staff grouping is wrong")
        try check(plan.bands.allSatisfy { $0.editorialLabel.isEmpty && !$0.pageBreakBefore }, "Automatic plans added debug labels or forced page breaks")
        try check(plan.bands[0].topFraction < staves[0].staffLineFractions[0] - 0.03, "Preserving context padding missing")
        page.staves.removeLast()
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile).canApply, "Nondivisible count silently shifted part identity")
        page.staves = staves
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, isCancelled: { true }).canApply, "Canceled plan is applicable")
        var trimmed = profile; trimmed.leftTrimPoints = 20; trimmed.rightTrimPoints = 15
        let trimmedPlan = ScoreExtractionPlanner.plan(pages: [page], profile: trimmed)
        try check(abs(trimmedPlan.bands[0].leftFraction - 20.0/600) < 1e-10 && abs(trimmedPlan.bands[0].rightFraction - 15.0/600) < 1e-10, "Reviewed horizontal trims not applied")
        trimmed.rightTrimPoints = 600
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: trimmed).canApply, "Invalid trims accepted")
        page.analysisSkewDegrees = 1
        let skewed = ScoreExtractionPlanner.plan(pages: [page], profile: profile)
        try check(skewed.bands[0].topFraction < plan.bands[0].topFraction && skewed.bands[0].bottomFraction > plan.bands[0].bottomFraction, "Skew envelope clips one end")
        page.analysisSkewDegrees = 0
        var override = ScorePageOverride(pageIndex: 0, reason: "Source reviewed", systems: [
            ScoreSystemOverride(systemIndex: 0, bands: [ScoreBandOverride(partID: "voice", candidateIDs: [0]), ScoreBandOverride(partID: "piano", candidateIDs: [1, 2])]),
            ScoreSystemOverride(systemIndex: 1, bands: [ScoreBandOverride(partID: "voice", candidateIDs: [3]), ScoreBandOverride(partID: "piano", candidateIDs: [4, 5])])
        ])
        try check(ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Valid source-reviewed assignments rejected")
        override.systems[1].bands[0].candidateIDs = [0]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Repeated music candidate accepted")
        override.systems[1].bands[0].candidateIDs = [3]
        override.systems[1].bands[1].candidateIDs = [4]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Unaccounted detected staff accepted")
        override.ignoredCandidateIDs = [5]
        try check(ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Explicitly ignored false detection rejected")
        override.systems[1].bands[1].rect = [0, 0, 600, 30]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Source-reviewed crop clips recorded staff")
        override.systems[1].bands[1].rect = nil
        override.systems[0].bands[0].sourceMarkings = [[30, 15, 230, 35]]
        let marked = ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override])
        try check(marked.bands[0].sourceMarkings.count == 1 && marked.bands[0].sourceMarkings[0].topFraction == 15.0/800, "Shared marking coordinate conversion failed")
        override.systems[0].bands[0].sourceMarkings = [[-1, 15, 230, 35]]
        try check(!ScoreExtractionPlanner.plan(pages: [page], profile: profile, overrides: [override]).canApply, "Out-of-page source marking accepted")
        let blank = ScorePageAnalysis(pageIndex: 1, pageWidth: 600, pageHeight: 800, imageWidth: 1500, imageHeight: 2000, staves: [], warnings: [])
        try check(!ScoreExtractionPlanner.plan(pages: [page, blank], profile: profile).canApply, "Undetected page silently treated as tacet")
        let nonmusic = ScorePageOverride(pageIndex: 1, reason: "Back matter reviewed", systems: [], nonMusicReason: "Blank leaf")
        let omitted = ScoreExtractionPlanner.plan(pages: [page, blank], profile: profile, overrides: [nonmusic])
        try check(omitted.canApply && omitted.pages[1].omissions.count == 2, "Explicit nonmusic page is not accounted for")
        try check(!ScoreExtractionPlanner.plan(pages: [blank], profile: profile, overrides: [nonmusic]).canApply, "All-nonmusic score permits empty extraction")
        try compactCropTests()
        if CommandLine.arguments.contains("--corpus") { try corpusTests() }
        print("PASS \(assertions) native planner checks: cadence, grouping, crop padding, skew bounds, invalid counts, ignored candidates, nonmusic pages, shared markings and cancellation.")
    }
    static func compactCropTests() throws {
        let legacyData = Data(#"{"parts":[{"id":"upper","name":"Upper","staffCount":1},{"id":"lower","name":"Lower","staffCount":1}]}"#.utf8)
        let fixed = try JSONDecoder().decode(ScoreExtractionProfile.self, from: legacyData)
        try check(fixed.cropMode == nil && fixed.parts[0].hasLyrics == nil, "Old profile requires new crop or lyric keys")
        let width = 600, height = 600
        var pixels = [UInt8](repeating: 255, count: width * height)
        func black(_ left: Int, _ top: Int, _ right: Int, _ bottom: Int) {
            for y in top..<bottom { for x in left..<right { pixels[y * width + x] = 0 } }
        }
        let candidates = [200, 300].enumerated().map { index, y in
            StaffBandCandidate(id: index, staffLineFractions: (0..<5).map { Double(y + $0 * 8) / 600 },
                topFraction: Double(y - 16) / 600, bottomFraction: Double(y + 48) / 600, confidence: 1, warnings: [])
        }
        for top in [200, 300] { for line in 0..<5 { black(20, top + line * 8, 580, top + line * 8 + 1) } }
        black(20, 200, 22, 333) // Inter-staff system barline must not join all notes.
        black(100, 166, 103, 219); black(100, 166, 190, 169) // Target high stem and slur.
        black(95, 212, 108, 219)
        black(130, 260, 142, 269) // Detached lyric below the geometric midpoint.
        black(180, 310, 194, 316) // Lower neighbor note.
        let data = Data(pixels)
        let provider = CGDataProvider(data: data as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let components = NativeScorePageAnalyzer.notationComponents(image: image, candidates: candidates, skewDegrees: 0)!
        try check(components.contains { $0.staffIDs == [0] && $0.bounds[1] <= 166.0 / 600 }, "Analysis lost outward target stem/slur reach")
        try check(!components.contains { $0.staffIDs.count > 1 }, "Thin system barline made neighboring staff ownership ambiguous")
        black(8, 130, 10, 217); black(7, 212, 17, 219)
        let edgeProvider = CGDataProvider(data: Data(pixels) as CFData)!
        let edgeImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: edgeProvider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let edgeComponents = NativeScorePageAnalyzer.notationComponents(image: edgeImage, candidates: candidates, skewDegrees: 0)!
        try check(edgeComponents.contains { $0.staffIDs == [0] && $0.bounds[0] < 0.03 && $0.bounds[1] <= 130.0 / 600 },
                  "A long target stem at the left edge was incorrectly discarded as a system connector")
        black(550, 200, 552, 333) // Same barline near the far edge of a tilted scan.
        let degrees = -2.0, slope = tan(degrees * .pi / 180)
        var tiltedPixels = [UInt8](repeating: 255, count: width * height)
        for x in 0..<width {
            let shift = Int((slope * (Double(x) - Double(width) / 2)).rounded())
            for y in 0..<height where y + shift >= 0 && y + shift < height {
                tiltedPixels[(y + shift) * width + x] = pixels[y * width + x]
            }
        }
        let tiltedImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: CGDataProvider(data: Data(tiltedPixels) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let tiltedComponents = NativeScorePageAnalyzer.notationComponents(image: tiltedImage, candidates: candidates, skewDegrees: degrees)!
        try check(!tiltedComponents.contains { $0.staffIDs.count > 1 },
                  "Skewed edge barline was tested against unshifted staff cores and joined both instruments")
        try check(tiltedComponents.contains { $0.staffIDs == [0] && $0.bounds[1] < 175.0 / 600 && $0.bounds[0] > 0.1 },
                  "Skew-aware barline separation lost a target high stem/slur")
        var page = ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 600, imageWidth: width, imageHeight: height,
            staves: candidates.map(ScoreObservedStaff.init), warnings: [], inkComponents: components)
        var compact = fixed; compact.cropMode = "compact"; compact.parts[0].hasLyrics = true
        let bands = ScoreExtractionPlanner.plan(pages: [page], profile: compact).bands
        try check(bands.count == 2 && bands[0].topFraction * 600 < 166, "Compact crop clipped a high connected slur")
        try check(bands[0].bottomFraction * 600 > 269, "Explicit lyric floor failed to preserve the whole detached lyric")
        try check(bands[0].bottomFraction * 600 < 300, "Compact crop retains the whole neighboring staff despite separated ink")
        try check(bands[0].warnings.isEmpty, "Unambiguous synthetic notation has unexpected crop warnings")
        let original = ScoreExtractionPlanner.plan(pages: [page], profile: fixed).bands
        try check(original[0].topFraction * 600 < bands[0].topFraction * 600, "Legacy fixed profile silently uses compact geometry")
        compact.parts[0].bottomPaddingStaffSpaces = 9
        let figuredBass = ScoreExtractionPlanner.plan(pages: [page], profile: compact).bands[0]
        try check(figuredBass.bottomFraction * 600 >= 232 + 9 * 8 - 0.001, "Explicit nine-space figured-bass padding was capped by compact defaults")
        compact.parts[0].bottomPaddingStaffSpaces = nil
        page.inkComponents!.append(ScoreInkComponent(bounds: [0.3, 0.3, 0.5, 0.6], staffIDs: [0, 1]))
        let touching = ScoreExtractionPlanner.plan(pages: [page], profile: compact).bands[0]
        try check(!touching.warnings.isEmpty && touching.topFraction < 0.3
                  && touching.bottomFraction > 0.6, "Touching notation's full component was silently clipped instead of preserving and flagging")
        page.inkComponents = nil
        let oldInventory = ScoreExtractionPlanner.plan(pages: [page], profile: compact).bands[0]
        try check(oldInventory.topFraction == original[0].topFraction && !oldInventory.warnings.isEmpty,
                  "Old inventory without ink evidence silently claims compact crops")
        try check(NativeScorePageAnalyzer.notationComponents(image: image, candidates: candidates, skewDegrees: 0, isCancelled: { true }) == nil,
                  "Cancelled ink analysis returned apparently complete evidence")
        let encoded = try JSONEncoder().encode(compact)
        let decoded = try JSONDecoder().decode(ScoreExtractionProfile.self, from: encoded)
        try check(decoded == compact,
                  "Compact mode and explicit lyric profile did not round trip")

        page.inkComponents = components
        page.inkComponents!.append(ScoreInkComponent(bounds: [175.0/600, 144.0/600, 190.0/600, 162.0/600], staffIDs: []))
        let rehearsal = ScoreExtractionPlanner.plan(pages: [page], profile: compact).bands[0]
        try check(rehearsal.topFraction * 600 < 144,
                  "Detached rehearsal box outside the initial search seed was not followed from adjacent target ink")

        page.inkComponents = components
        for index in 0..<8 {
            let left = Double(60 + index * 45)
            page.inkComponents!.append(ScoreInkComponent(bounds: [left/600, 274.0/600, (left+6)/600, 280.0/600], staffIDs: []))
        }
        let lyricPlan = ScoreExtractionPlanner.plan(pages: [page], profile: compact)
        try check(lyricPlan.bands[0].bottomFraction * 600 > 280,
                  "A detached lyric baseline nearer the next staff was lost from its explicit vocal owner")
        try check(lyricPlan.bands[1].topFraction * 600 > 280,
                  "The following instrument inherited the preceding part's full lyric line")
        page.inkComponents!.append(ScoreInkComponent(bounds: [540.0/600, 276.5/600, 543.0/600, 277.5/600], staffIDs: []))
        let hyphenPlan = ScoreExtractionPlanner.plan(pages: [page], profile: compact)
        try check(hyphenPlan.bands[1].topFraction == lyricPlan.bands[1].topFraction,
                  "A trailing lyric hyphen beyond the letter span pulled the following instrument up into the whole preceding lyric row")

        compact.parts[0].hasLyrics = false
        page.inkComponents = components + [
            ScoreInkComponent(bounds: [0.28, 0.35, 0.35, 0.44], staffIDs: [0]),
            ScoreInkComponent(bounds: [0.30, 0.44, 0.70, 0.58], staffIDs: [1])
        ]
        let overlappingDynamic = ScoreExtractionPlanner.plan(pages: [page], profile: compact).bands[0]
        try check(overlappingDynamic.bottomFraction < 0.5 && !overlappingDynamic.warnings.isEmpty,
                  "A nearby foreign-staff component was silently adopted wholesale instead of requesting local edge review")
    }
    struct SourceConfig: Decodable { var source: String; var profile: ScoreExtractionProfile }
    static func corpusTests() throws {
        let sources = try JSONDecoder().decode([String: SourceConfig].self,
            from: Data(contentsOf: URL(fileURLWithPath: "Tests/full_scores/sources.json")))
        let expected: [String: [Int]] = [
            "ave": [16,16,16,16], "notte": [13,15,15,15],
            "quartet": [16,20,20,20,20,20,20,20,20,20,16,16,16,16,20,20,20,20,20,20,20,20,20,20,20],
            "schumann": [12] + Array(repeating: 15, count: 13) + [12,12],
            "trio": [12] + Array(repeating: 16, count: 32) + [0,0]
        ]
        var pageCount = 0, staffCount = 0
        for name in ["ave", "notte", "quartet", "schumann", "trio"] {
            let config = sources[name]!
            guard let document = PDFDocument(url: URL(fileURLWithPath: config.source)) else {
                throw NSError(domain: "ScorePlannerTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing \(config.source)"])
            }
            try check(document.pageCount == expected[name]!.count, "Independent source page count changed: \(name)")
            for index in 0..<document.pageCount {
                try autoreleasepool {
                    let page = document.page(at: index)!, bounds = page.bounds(for: .mediaBox)
                    let image = NativeScorePageAnalyzer.render(page)!
                    let analysis = NativeScorePageAnalyzer.analyze(pageIndex: index, image: image, pageWidth: bounds.width, pageHeight: bounds.height)
                    try check(analysis.staves.count == expected[name]![index], "\(name) p\(index+1): expected \(expected[name]![index]) staves, found \(analysis.staves.count)")
                    if name == "quartet" && index == 8 {
                        // Independently checked cello staff: an earlier 20-staff result
                        // fitted a narrow pattern inside the true five-line staff.
                        let cello = analysis.staves[3]
                        let height = (cello.staffLineFractions[4] - cello.staffLineFractions[0]) * bounds.height
                        try check(height > 13.5 && height < 15.5,
                            "Quartet p9 first cello staff uses a narrow false line pattern")
                        try check(abs(cello.staffLineFractions[4] * bounds.height - 172.4) < 1.5,
                            "Quartet p9 first cello staff omits its actual bottom line")
                    }
                    if name == "trio" && index == 15 {
                        // Independent source-center measurements from score_survey.
                        // Matching only the count once hid piano beam/staff confusion.
                        let centers = [75.7,107.7,156.6,207.5,258.6,292.7,338.2,389.5,450,481.2,521.9,565.7,629.4,659.6,702.2,742.8]
                        for (staff, center) in zip(analysis.staves, centers) {
                            try check(abs(staff.staffLineFractions[2] * bounds.height - center) < 1.5,
                                "Trio p16 staff \(staff.id) is aligned with beams instead of the actual staff")
                        }
                    }
                    pageCount += 1; staffCount += analysis.staves.count
                }
            }
            print("PASS full-source native detection: \(name), \(document.pageCount) pages")
        }
        print("PASS full corpus: \(pageCount) pages, \(staffCount) musical staves; blank/catalog leaves detected empty but still require explicit source classification.")
    }

}
