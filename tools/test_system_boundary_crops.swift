import Foundation

@main enum SystemBoundaryCropTests {
    struct SourceFixture: Decodable {
        var profile: ScoreExtractionProfile
        var cases: [SourceCase]
    }
    struct SourceCase: Decodable {
        var bandID: String
        var page: ScorePageAnalysis
        var minimumBottomPoints: Double
        var maximumBottomPoints: Double
        var staffIDs: [Int]
    }
    static var assertions = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
        assertions += 1
        if !value() { throw NSError(domain: "SystemBoundaryCropTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func main() throws {
        for fixturePath in ["Tests/quality_control/brahms93521/system-boundary-components.json",
                            "Tests/quality_control/ave-system-boundary-components.json"] {
        let fixture = try JSONDecoder().decode(SourceFixture.self, from: Data(contentsOf: URL(fileURLWithPath: fixturePath)))
        for item in fixture.cases {
            let plan = ScoreExtractionPlanner.plan(pages: [item.page], profile: fixture.profile)
            let band = plan.bands.first { $0.id == item.bandID }!
            try check(plan.canApply, "Source fixture is not applicable: \(item.bandID)")
            try check(band.bottomFraction * item.page.pageHeight >= item.minimumBottomPoints,
                "A reviewed lower source landmark was clipped: \(item.bandID)")
            try check(band.bottomFraction * item.page.pageHeight < item.maximumBottomPoints,
                "Next-system detached notes/ending still enlarge the crop: \(item.bandID)")
            for component in item.page.inkComponents! where !Set(component.staffIDs).isDisjoint(with: item.staffIDs) {
                try check(band.topFraction <= component.bounds[1] && band.bottomFraction >= component.bounds[3],
                    "Connected or ambiguous target notation was removed: \(item.bandID)")
            }
            let ordered = item.page.staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
            let stride = fixture.profile.parts.map(\.staffCount).reduce(0, +)
            let systems = (0..<(ordered.count / stride)).map { system in
                var offset = system * stride
                let bands = fixture.profile.parts.map { part in
                    let ids = Array(ordered[offset..<(offset + part.staffCount)]).map(\.id)
                    offset += part.staffCount
                    return ScoreBandOverride(partID: part.id, candidateIDs: ids)
                }
                return ScoreSystemOverride(systemIndex: system, bands: bands)
            }
            var override = ScorePageOverride(pageIndex: item.page.pageIndex, reason: "Frozen source geometry", systems: systems)
            let reviewed = ScoreExtractionPlanner.plan(pages: [item.page], profile: fixture.profile, overrides: [override])
            let reviewedBand = reviewed.bands.first { $0.id == item.bandID }!
            try check(reviewed.canApply && abs(reviewedBand.bottomFraction - band.bottomFraction) < 1e-12,
                "Reviewed system boundaries differ from automatic cadence: \(item.bandID)")
            let explicitBottom = band.bottomFraction * item.page.pageHeight + 20
            let partIndex = fixture.profile.parts.firstIndex { $0.id == band.partID }!
            override.systems[band.systemIndex].bands[partIndex].rect = [0, band.topFraction * item.page.pageHeight,
                item.page.pageWidth, explicitBottom]
            let explicit = ScoreExtractionPlanner.plan(pages: [item.page], profile: fixture.profile, overrides: [override])
            try check(abs(explicit.bands.first { $0.id == item.bandID }!.bottomFraction * item.page.pageHeight - explicitBottom) < 1e-9,
                "An explicit user crop was changed: \(item.bandID)")
        }
        }
        try boundaryControls()
        print("PASS: \(assertions) system-boundary crop checks")
    }
    static func page(tops: [Double], targetID: Int, offset: Double = 0) -> ScorePageAnalysis {
        let staves = tops.enumerated().map { id, top in
            ScoreObservedStaff(StaffBandCandidate(id: id, staffLineFractions: (0..<5).map { top + Double($0) * 0.005 },
                topFraction: top - 0.01, bottomFraction: top + 0.035, confidence: 1, warnings: []))
        }
        var components = [
            ScoreInkComponent(bounds: [0.2, 0.204 + offset, 0.3, 0.232 + offset], staffIDs: [targetID]),
            ScoreInkComponent(bounds: [0.2, 0.233 + offset, 0.3, 0.241 + offset], staffIDs: []),
            ScoreInkComponent(bounds: [0.2, 0.248 + offset, 0.32, 0.257 + offset], staffIDs: [])
        ]
        if targetID + 1 < tops.count {
            components.append(ScoreInkComponent(bounds: [0.2, 0.254 + offset, 0.32, tops[targetID + 1] + 0.02],
                staffIDs: [targetID + 1]))
        }
        return ScorePageAnalysis(pageIndex: 0, pageWidth: 600, pageHeight: 1000, imageWidth: 1200,
            imageHeight: 2000, staves: staves, warnings: [], inkComponents: components)
    }
    static func boundaryControls() throws {
        let profile = ScoreExtractionProfile(parts: [ScorePartDefinition(id: "upper", name: "Upper", staffCount: 1),
            ScorePartDefinition(id: "lower", name: "Lower", staffCount: 1)], cropMode: "compact")
        var source = page(tops: [0.1, 0.2, 0.28, 0.38], targetID: 1)
        func lower(_ page: ScorePageAnalysis, _ profile: ScoreExtractionProfile) -> ScorePlannedBand {
            ScoreExtractionPlanner.plan(pages: [page], profile: profile).bands.first { $0.systemIndex == 0 && $0.partID == "lower" }!
        }
        let clean = lower(source, profile)
        try check(clean.bottomFraction >= 0.2435 && clean.bottomFraction < 0.248,
            "A detached seed relayed ownership into the following system")
        var stacked = source
        stacked.inkComponents!.removeAll { $0.staffIDs == [2] }
        stacked.inkComponents!.append(ScoreInkComponent(bounds: [0.6, 0.28, 0.65, 0.3], staffIDs: [2]))
        try check(lower(stacked, profile).bottomFraction >= 0.2595,
            "Stacked lower annotations were cut without competing following-system ink")
        source.inkComponents!.append(ScoreInkComponent(bounds: [0.6, 0.204, 0.61, 0.269], staffIDs: [1]))
        try check(lower(source, profile).bottomFraction >= 0.2715, "A long low target stem was capped at the system gap")
        source.inkComponents!.append(ScoreInkComponent(bounds: [0.5, 0.204, 0.56, 0.291], staffIDs: [1, 2]))
        try check(lower(source, profile).bottomFraction >= 0.2935, "Genuine cross-staff ambiguous notation was clipped")

        let within = ScoreExtractionProfile(parts: ["upper", "lower", "third", "fourth"].map {
            ScorePartDefinition(id: $0, name: $0, staffCount: 1)
        }, cropMode: "compact")
        let normal = page(tops: [0.1, 0.2, 0.28, 0.38], targetID: 1)
        try check(lower(normal, within).bottomFraction >= 0.2595, "Within-system low directions changed")
        let final = page(tops: [0.1, 0.2], targetID: 1)
        try check(lower(final, profile).bottomFraction >= 0.2595, "The final system on a page changed without a following system")

        var lyrics = page(tops: [0.1, 0.2, 0.28, 0.38], targetID: 1)
        lyrics.inkComponents! += (0..<10).map { index in
            let x = 0.18 + Double(index) * 0.045
            return ScoreInkComponent(bounds: [x, 0.24, x + 0.008, 0.25], staffIDs: [])
        }
        var vocal = profile; vocal.parts[1].hasLyrics = true
        try check(lower(lyrics, vocal).bottomFraction >= 0.2525, "An explicit lyric row lost its low letters")

        let grandProfile = ScoreExtractionProfile(parts: [profile.parts[0],
            ScorePartDefinition(id: "lower", name: "Grand staff", staffCount: 2)], cropMode: "compact")
        let grand = page(tops: [0.1, 0.2, 0.27, 0.4, 0.5, 0.57], targetID: 2, offset: 0.07)
        let grandBand = lower(grand, grandProfile)
        try check(grandBand.candidateIDs == [1, 2] && grandBand.bottomFraction >= 0.3135 && grandBand.bottomFraction < 0.318,
            "A grand staff's lower boundary was not grouped correctly")

        let variable = page(tops: [0.2, 0.28, 0.38], targetID: 0)
        let assignment = ScorePageOverride(pageIndex: 0, reason: "Reviewed changing instrumentation", systems: [
            ScoreSystemOverride(systemIndex: 0, bands: [ScoreBandOverride(partID: "lower", candidateIDs: [0])],
                omittedParts: [ScorePartOmission(partID: "upper", reason: "Silent")], startBarNumber: 1, barCount: 4),
            ScoreSystemOverride(systemIndex: 1, bands: [ScoreBandOverride(partID: "upper", candidateIDs: [1]),
                ScoreBandOverride(partID: "lower", candidateIDs: [2])])
        ])
        let variablePlan = ScoreExtractionPlanner.plan(pages: [variable], profile: profile, overrides: [assignment])
        try check(variablePlan.canApply && variablePlan.bands.first { $0.partID == "lower" }!.bottomFraction < 0.248,
            "Reviewed variable instrumentation did not establish the actual system boundary")
        try check(variablePlan.bands.first { $0.generatedRest != nil }?.generatedRest?.barCount == 4,
            "A boundary crop change altered the silent part's generated rests")
    }
}
