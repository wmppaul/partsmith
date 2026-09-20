import Foundation

struct ScorePartDefinition: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var staffCount: Int
    var topPaddingStaffSpaces: Double?
    var bottomPaddingStaffSpaces: Double?
    var hasLyrics: Bool?
}

struct ScoreExtractionProfile: Codable, Equatable {
    var parts: [ScorePartDefinition]
    var topPaddingStaffSpaces: Double?
    var bottomPaddingStaffSpaces: Double?
    var leftTrimPoints: Double?
    var rightTrimPoints: Double?
    /// Missing keeps the original fixed-padding behavior of saved profiles.
    var cropMode: String?
}

struct ScoreObservedStaff: Codable, Equatable, Identifiable {
    var id: Int
    var staffLineFractions: [Double]
    var topFraction: Double
    var bottomFraction: Double
    var confidence: Double
    var warnings: [String]

    init(_ candidate: StaffBandCandidate) {
        id = candidate.id
        staffLineFractions = candidate.staffLineFractions
        topFraction = candidate.topFraction
        bottomFraction = candidate.bottomFraction
        confidence = candidate.confidence
        warnings = candidate.warnings
    }
}

struct ScorePageAnalysis: Codable, Equatable {
    var pageIndex: Int
    var pageWidth: Double
    var pageHeight: Double
    var imageWidth: Int
    var imageHeight: Int
    var staves: [ScoreObservedStaff]
    var warnings: [String]
    var textSuggestions: [String] = []
    var analysisSkewDegrees: Double = 0
    /// Analysis-only components in the original image coordinate system. No
    /// staff removal or connector separation is applied to exported pixels.
    var inkComponents: [ScoreInkComponent]?
}

struct ScoreInkComponent: Codable, Equatable {
    /// [left, top, right, bottom] as page fractions (right is an edge, not trim).
    var bounds: [Double]
    var staffIDs: [Int]
}

struct ScorePartOmission: Codable, Equatable {
    var partID: String
    var reason: String
}

/// Explicitly reviewed source coordinates; these are not detector corrections.
struct ScoreBandOverride: Codable, Equatable {
    var partID: String
    var candidateIDs: [Int]?
    /// [left, top, right, bottom] in source PDF points, top-down.
    var rect: [Double]?
    var label: String?
    var kind: String?
    var pageBreakBefore: Bool?
    var sourceMarkings: [[Double]]?
}

struct ScoreSystemOverride: Codable, Equatable {
    var systemIndex: Int
    var label: String?
    var movementLabel: String?
    var bands: [ScoreBandOverride]
    var omittedParts: [ScorePartOmission]?
}

struct ScorePageOverride: Codable, Equatable {
    var pageIndex: Int
    var reason: String
    var systems: [ScoreSystemOverride]
    var nonMusicReason: String?
    var ignoredCandidateIDs: [Int]?
}

struct ScoreSourceMarking: Codable, Equatable {
    var topFraction: Double
    var bottomFraction: Double
    var leftFraction: Double
    var rightFraction: Double
}

struct ScorePlannedBand: Codable, Equatable, Identifiable {
    var id: String
    var partID: String
    var pageIndex: Int
    var systemIndex: Int
    var candidateIDs: [Int]
    var topFraction: Double
    var bottomFraction: Double
    var leftFraction: Double
    /// Trim amount from the right, consistent with BandModel.
    var rightFraction: Double
    var editorialLabel: String = ""
    var pageBreakBefore: Bool = false
    var kind: String = "music"
    var sourceMarkings: [ScoreSourceMarking] = []
    var provenance: String
    var warnings: [String]
}

struct ScoreSystemOmission: Codable, Equatable {
    var systemIndex: Int
    var partID: String
    var reason: String
}

struct ScorePagePlan: Codable, Equatable {
    var pageIndex: Int
    var assignments: [ScorePlannedBand]
    var omissions: [ScoreSystemOmission]
    var unresolvedReasons: [String]
    var warnings: [String]
}

struct ScoreExtractionPlan: Codable, Equatable {
    var parts: [ScorePartDefinition]
    var pages: [ScorePagePlan]
    var warnings: [String]
    var canApply: Bool { !bands.isEmpty && pages.allSatisfy { $0.unresolvedReasons.isEmpty } }
    var bands: [ScorePlannedBand] { pages.flatMap(\.assignments) }
}

/// Assigns geometric staves only after the instrumentation profile is reviewed.
/// Crops deliberately retain neighboring ink. Neither detection nor this planner
/// identifies every target mark; the completed part still needs visual review.
enum ScoreExtractionPlanner {
    static func plan(
        pages: [ScorePageAnalysis], profile: ScoreExtractionProfile,
        overrides: [ScorePageOverride] = [], isCancelled: () -> Bool = { false }
    ) -> ScoreExtractionPlan {
        let names = profile.parts.map(\.id)
        let invalidProfile = profile.parts.isEmpty || Set(names).count != names.count
            || profile.parts.contains { $0.id.isEmpty || $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.staffCount < 1 }
            || ![nil, "fixed", "compact"].contains(profile.cropMode)
        let padding = [profile.topPaddingStaffSpaces, profile.bottomPaddingStaffSpaces, profile.leftTrimPoints, profile.rightTrimPoints]
            + profile.parts.flatMap { [$0.topPaddingStaffSpaces, $0.bottomPaddingStaffSpaces] }
        let invalidPadding = padding.compactMap { $0 }.contains { !$0.isFinite || $0 < 0 }
            || pages.contains { (profile.leftTrimPoints ?? 0) + (profile.rightTrimPoints ?? 0) >= $0.pageWidth }
        let duplicatePages = Set(pages.map(\.pageIndex)).count != pages.count
        let duplicateOverrides = Set(overrides.map(\.pageIndex)).count != overrides.count
            || !Set(overrides.map(\.pageIndex)).isSubset(of: Set(pages.map(\.pageIndex)))
        if invalidProfile || invalidPadding || duplicatePages || duplicateOverrides {
            return ScoreExtractionPlan(parts: profile.parts, pages: pages.map {
                ScorePagePlan(pageIndex: $0.pageIndex, assignments: [], omissions: [],
                    unresolvedReasons: ["Invalid instrumentation profile or duplicate page input."], warnings: [])
            }, warnings: ["Correct the profile and page inventory before planning."])
        }
        var planned: [ScorePagePlan] = []
        for page in pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            if isCancelled() { break }
            if let correction = overrides.first(where: { $0.pageIndex == page.pageIndex }) {
                planned.append(reviewedPage(page, profile: profile, override: correction))
            } else {
                planned.append(automaticPage(page, profile: profile))
            }
        }
        if isCancelled() {
            return ScoreExtractionPlan(parts: profile.parts, pages: [], warnings: ["Score planning was canceled."])
        }
        return ScoreExtractionPlan(parts: profile.parts, pages: planned, warnings: [
            "Part names and staff grouping come from the reviewed instrumentation profile, not automatic instrument recognition.",
            "Inspect all target notation and source context before export. Compact crops follow detected ink; detached directions and touching notation still need review."
        ])
    }

    private static func automaticPage(_ page: ScorePageAnalysis, profile: ScoreExtractionProfile) -> ScorePagePlan {
        var output = ScorePagePlan(pageIndex: page.pageIndex, assignments: [], omissions: [], unresolvedReasons: [], warnings: page.warnings)
        let stride = profile.parts.map(\.staffCount).reduce(0, +)
        guard page.pageWidth > 0, page.pageHeight > 0, !page.staves.isEmpty,
              page.staves.count % stride == 0 else {
            output.unresolvedReasons = ["Found \(page.staves.count) staves; the reviewed profile expects \(stride) per system. Review missing staves or changing instrumentation; no assignments were guessed."]
            return output
        }
        let ordered = page.staves.sorted { ($0.staffLineFractions.first ?? 0) < ($1.staffLineFractions.first ?? 0) }
        guard ordered.allSatisfy({ validStaff($0) }), Set(ordered.map(\.id)).count == ordered.count else {
            output.unresolvedReasons = ["The staff inventory contains invalid geometry."]
            return output
        }
        let spaces = ordered.map { ($0.staffLineFractions[4] - $0.staffLineFractions[0]) / 4 }
        if spaces.max()! > spaces.min()! * 1.75 {
            output.unresolvedReasons = ["Staff sizes vary substantially; review the system layout before assigning instruments."]
            return output
        }
        // A conspicuous gap inside a proposed system can indicate a missed staff
        // or reduced instrumentation. Fail closed instead of shifting every part.
        if ordered.count > stride && stride > 1 {
            var inner: [Double] = [], boundaries: [Double] = []
            for i in 1..<ordered.count {
                let gap = ordered[i].staffLineFractions[0] - ordered[i-1].staffLineFractions[4]
                if i % stride == 0 { boundaries.append(gap) } else { inner.append(gap) }
            }
            let typicalBoundary = boundaries.sorted()[boundaries.count / 2]
            if let largest = inner.max(), largest > max(typicalBoundary * 1.8, spaces.max()! * 14) {
                output.unresolvedReasons = ["A large gap falls inside the proposed system cadence. Review changed or missing staves before assignment."]
                return output
            }
        }
        let lyricOffsets = profile.parts.reduce(into: (offset: 0, indices: Set<Int>())) { result, part in
            if part.hasLyrics == true { result.indices.insert(result.offset + part.staffCount - 1) }
            result.offset += part.staffCount
        }.indices
        let lyricIDs = Set(ordered.enumerated().filter { lyricOffsets.contains($0.offset % stride) }.map { $0.element.id })
        let lyrics = lyricComponents(page: page, staffIDs: lyricIDs)
        for system in 0..<(ordered.count / stride) {
            var offset = system * stride
            for part in profile.parts {
                let staves = Array(ordered[offset..<(offset + part.staffCount)])
                let crop = cropBounds(staves, page: page, profile: profile, part: part, lyricOwners: lyrics)
                output.assignments.append(band(partID: part.id, page: page, system: system, staves: staves, rect: crop.rect,
                    label: "", kind: "music", breakBefore: false, provenance: "native-profile-cadence", warnings: staves.flatMap(\.warnings) + crop.warnings))
                offset += part.staffCount
            }
        }
        return output
    }

    private static func reviewedPage(_ page: ScorePageAnalysis, profile: ScoreExtractionProfile, override: ScorePageOverride) -> ScorePagePlan {
        var output = ScorePagePlan(pageIndex: page.pageIndex, assignments: [], omissions: [], unresolvedReasons: [], warnings: ["Reviewed page override: \(override.reason)"])
        let partIDs = Set(profile.parts.map(\.id))
        if let reason = override.nonMusicReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, override.systems.isEmpty {
            output.omissions = profile.parts.map { ScoreSystemOmission(systemIndex: -1, partID: $0.id, reason: reason) }
            return output
        }
        guard !override.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !override.systems.isEmpty, Set(override.systems.map(\.systemIndex)).count == override.systems.count,
              override.systems.map(\.systemIndex) == Array(0..<override.systems.count) else {
            output.unresolvedReasons = ["Reviewed overrides require a reason and ordered, contiguous system indices starting at zero."]
            return output
        }
        let availableIDs = Set(page.staves.map(\.id))
        let ignoredIDs = override.ignoredCandidateIDs ?? []
        let musicIDs = override.systems.flatMap(\.bands).filter { ($0.kind ?? "music") == "music" }.flatMap { $0.candidateIDs ?? [] }
        let allIDs = override.systems.flatMap(\.bands).flatMap { $0.candidateIDs ?? [] }
        guard musicIDs.count == Set(musicIDs).count,
              ignoredIDs.count == Set(ignoredIDs).count,
              Set(ignoredIDs).isDisjoint(with: Set(allIDs)),
              Set(allIDs + ignoredIDs) == availableIDs else {
            output.unresolvedReasons = ["Account for every detected staff exactly once as music or an explicitly ignored candidate; only labeled cue bands may reuse staves."]
            return output
        }
        let lyricIDs = Set(override.systems.flatMap(\.bands).filter { assigned in
            profile.parts.first { $0.id == assigned.partID }?.hasLyrics == true
        }.compactMap { $0.candidateIDs?.last })
        let lyrics = lyricComponents(page: page, staffIDs: lyricIDs)
        for system in override.systems {
            let omitted = system.omittedParts ?? []
            let coverage = system.bands.map(\.partID) + omitted.map(\.partID)
            guard Set(coverage) == partIDs, coverage.count == partIDs.count,
                  omitted.allSatisfy({ !$0.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                output.unresolvedReasons.append("System \(system.systemIndex + 1) must account for every part exactly once, with reasons for omitted staves.")
                continue
            }
            for omission in omitted {
                output.omissions.append(ScoreSystemOmission(systemIndex: system.systemIndex, partID: omission.partID, reason: omission.reason))
            }
            for assigned in system.bands {
                let ids = assigned.candidateIDs ?? []
                let staves = ids.compactMap { id in page.staves.first { $0.id == id } }
                guard ids.count == Set(ids).count, staves.count == ids.count,
                      staves.allSatisfy({ validStaff($0) }), !ids.isEmpty || assigned.rect != nil else {
                    output.unresolvedReasons.append("Invalid candidate IDs for \(assigned.partID), system \(system.systemIndex + 1).")
                    continue
                }
                if (assigned.kind ?? "music") == "music", !ids.isEmpty,
                   ids != Array(ids.min()!...ids.max()!) {
                    output.unresolvedReasons.append("A music band must group consecutive candidates in reading order.")
                    continue
                }
                let crop = assigned.rect.map { CropBounds(rect: $0, warnings: []) }
                    ?? cropBounds(staves, page: page, profile: profile, part: profile.parts.first { $0.id == assigned.partID }!, lyricOwners: lyrics)
                let rect = crop.rect
                guard validRect(rect, page: page), staves.allSatisfy({
                    $0.staffLineFractions[0] * page.pageHeight >= rect[1] && $0.staffLineFractions[4] * page.pageHeight <= rect[3]
                }) else {
                    output.unresolvedReasons.append("Reviewed crop is invalid or cuts staff lines for \(assigned.partID), system \(system.systemIndex + 1).")
                    continue
                }
                let markingRects = assigned.sourceMarkings ?? []
                guard markingRects.allSatisfy({ validRect($0, page: page) && $0[0] >= rect[0] && $0[2] <= rect[2] }) else {
                    output.unresolvedReasons.append("Shared source markings must be valid page rectangles inside the crop's horizontal span.")
                    continue
                }
                let kind = assigned.kind ?? "music"
                guard kind == "music" || kind == "cue", kind != "cue" || !(assigned.label ?? "").isEmpty else {
                    output.unresolvedReasons.append("Cue bands need an explicit editorial label.")
                    continue
                }
                let label = [system.movementLabel, assigned.label].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
                output.assignments.append(band(partID: assigned.partID, page: page, system: system.systemIndex,
                    staves: staves, rect: rect, label: label, kind: kind, breakBefore: assigned.pageBreakBefore ?? false,
                    provenance: "reviewed-override", warnings: (ids.isEmpty ? ["Crop supplied by source review; not supported by detected staff IDs."] : []) + crop.warnings))
                output.assignments[output.assignments.count - 1].sourceMarkings = markingRects.map {
                    ScoreSourceMarking(topFraction: $0[1] / page.pageHeight, bottomFraction: $0[3] / page.pageHeight,
                        leftFraction: $0[0] / page.pageWidth, rightFraction: 1 - $0[2] / page.pageWidth)
                }
            }
        }
        if !output.unresolvedReasons.isEmpty { output.assignments = []; output.omissions = [] }
        return output
    }

    private static func validStaff(_ staff: ScoreObservedStaff) -> Bool {
        let lines = staff.staffLineFractions
        return lines.count == 5 && lines.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
            && zip(lines, lines.dropFirst()).allSatisfy { $0 < $1 }
    }

    private static func validRect(_ rect: [Double], page: ScorePageAnalysis) -> Bool {
        rect.count == 4 && rect.allSatisfy(\.isFinite) && rect[0] >= 0 && rect[1] >= 0
            && rect[0] < rect[2] && rect[1] < rect[3] && rect[2] <= page.pageWidth && rect[3] <= page.pageHeight
    }

    private static func generousRect(_ staves: [ScoreObservedStaff], page: ScorePageAnalysis,
                                     profile: ScoreExtractionProfile, part: ScorePartDefinition) -> [Double] {
        let first = staves.first!, last = staves.last!
        let space = max((first.staffLineFractions[4] - first.staffLineFractions[0]) / 4,
                        (last.staffLineFractions[4] - last.staffLineFractions[0]) / 4)
        let topPadding = part.topPaddingStaffSpaces ?? profile.topPaddingStaffSpaces ?? 7
        let bottomPadding = part.bottomPaddingStaffSpaces ?? profile.bottomPaddingStaffSpaces ?? 7
        let skewPadding = abs(tan(page.analysisSkewDegrees * .pi / 180)) * page.pageWidth / page.pageHeight / 2
        return [profile.leftTrimPoints ?? 0,
                max(0, first.staffLineFractions[0] - space * topPadding - skewPadding) * page.pageHeight,
                page.pageWidth - (profile.rightTrimPoints ?? 0),
                min(1, last.staffLineFractions[4] + space * bottomPadding + skewPadding) * page.pageHeight]
    }

    private struct CropBounds {
        var rect: [Double]
        var warnings: [String]
    }

    /// Lyric rows are explicit profile evidence, not a general text/dynamic
    /// classifier. A repeated baseline spanning several measures is kept with
    /// its vocal staff even when descenders are nearer the following staff.
    private static func lyricComponents(page: ScorePageAnalysis, staffIDs: Set<Int>) -> [Int: Int] {
        guard !staffIDs.isEmpty, let components = page.inkComponents,
              components.allSatisfy({ $0.bounds.count == 4 && $0.bounds.allSatisfy(\.isFinite) }) else { return [:] }
        var result: [Int: Int] = [:]
        for staff in page.staves where staffIDs.contains(staff.id) && validStaff(staff) {
            let space = (staff.staffLineFractions[4] - staff.staffLineFractions[0]) / 4
            let lastLine = staff.staffLineFractions[4]
            var rows: [[(index: Int, center: Double)]] = []
            for (index, component) in components.enumerated() where component.staffIDs.isEmpty {
                let box = component.bounds, center = (box[1] + box[3]) / 2
                let height = box[3] - box[1], width = (box[2] - box[0]) * page.pageWidth / page.pageHeight
                guard center > lastLine, center < lastLine + 6 * space,
                      height > 0.4 * space, height < 2.8 * space,
                      width > 0.12 * space, width < 6 * space else { continue }
                if let row = rows.firstIndex(where: { values in
                    abs(values.map(\.center).reduce(0, +) / Double(values.count) - center) < 0.6 * space
                }) { rows[row].append((index, center)) }
                else { rows.append([(index, center)]) }
            }
            for row in rows where row.count >= 8 {
                let left = row.map { components[$0.index].bounds[0] }.min()!
                let right = row.map { components[$0.index].bounds[2] }.max()!
                guard right - left >= 0.22 else { continue }
                let center = row.map(\.center).reduce(0, +) / Double(row.count)
                for (index, component) in components.enumerated() where component.staffIDs.isEmpty {
                    let box = component.bounds
                    let height = box[3] - box[1]
                    let width = (box[2] - box[0]) * page.pageWidth / page.pageHeight
                    let distance = abs((box[1] + box[3]) / 2 - center)
                    let inTextSpan = box[0] >= left - space * page.pageHeight / page.pageWidth
                        && box[2] <= right + space * page.pageHeight / page.pageWidth
                    // Syllable hyphens can continue across a melisma after the
                    // last letter. Keep short, thin marks on this established
                    // lyric baseline with its voice, even outside the text span.
                    let trailingHyphen = distance < 0.35 * space && height <= 0.5 * space
                        && width >= height * 1.5 && width <= 2 * space
                    if (distance < 0.85 * space && height < 3 * space && inTextSpan) || trailingHyphen {
                        result[index] = staff.id
                    }
                }
            }
        }
        return result
    }

    private static func cropBounds(_ staves: [ScoreObservedStaff], page: ScorePageAnalysis,
                                   profile: ScoreExtractionProfile, part: ScorePartDefinition,
                                   lyricOwners: [Int: Int]) -> CropBounds {
        let broad = generousRect(staves, page: page, profile: profile, part: part)
        guard profile.cropMode == "compact" else { return CropBounds(rect: broad, warnings: []) }
        guard let components = page.inkComponents,
              components.allSatisfy({ component in
                  component.bounds.count == 4 && component.bounds.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
                    && component.bounds[0] < component.bounds[2] && component.bounds[1] < component.bounds[3]
                    && component.staffIDs.allSatisfy { id in page.staves.contains { $0.id == id } }
              }) else {
            return CropBounds(rect: broad, warnings: ["Compact crop evidence is unavailable. Broad context retained; run Auto again and review the crop edges."])
        }
        let first = staves.first!, last = staves.last!
        let space = max((first.staffLineFractions[4] - first.staffLineFractions[0]) / 4,
                        (last.staffLineFractions[4] - last.staffLineFractions[0]) / 4)
        let firstLine = first.staffLineFractions[0], lastLine = last.staffLineFractions[4]
        let skew = abs(tan(page.analysisSkewDegrees * .pi / 180)) * page.pageWidth / page.pageHeight / 2
        let explicitTop = part.topPaddingStaffSpaces ?? profile.topPaddingStaffSpaces
        let explicitBottom = part.bottomPaddingStaffSpaces ?? profile.bottomPaddingStaffSpaces
        // Defaults guide discovery. Only explicitly entered padding forces blank
        // output space; otherwise the crop follows the selected notation below.
        let seedTop = min(first.topFraction, firstLine - max(3, explicitTop ?? 3) * space - skew)
        let seedBottom = max(last.bottomFraction,
            lastLine + max(part.hasLyrics == true ? 4 : 2.5, explicitBottom ?? 2.5) * space + skew)
        let ids = Set(staves.map(\.id))
        let allStaves = page.staves.filter(validStaff)
        let staffLookup = Dictionary(allStaves.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var selected = Set<Int>(), ambiguous = Set<Int>()
        var foreignEdgeNeedsReview = false
        for (index, component) in components.enumerated() {
            let owners = Set(component.staffIDs), box = component.bounds
            if !owners.isDisjoint(with: ids) {
                if owners.isSubset(of: ids) { selected.insert(index) }
                else { ambiguous.insert(index) }
                continue
            }
            guard owners.isEmpty else { continue }
            if let lyricOwner = lyricOwners[index] {
                if ids.contains(lyricOwner) { selected.insert(index) }
                continue
            }
            guard box[1] < seedBottom, box[3] > seedTop else { continue }
            let center = (box[1] + box[3]) / 2
            let nearest = allStaves.min { lhs, rhs in
                max(lhs.staffLineFractions[0] - center, center - lhs.staffLineFractions[4], 0)
                    < max(rhs.staffLineFractions[0] - center, center - rhs.staffLineFractions[4], 0)
            }
            // A preceding detached low slur should not automatically become the
            // following instrument's upper envelope. Proximity to the target's
            // connected ink can still recover a genuinely high detached mark.
            if nearest.map({ ids.contains($0.id) }) == true || box[3] > firstLine {
                selected.insert(index)
            }
        }
        // Follow detached articulations and directions locally, rather than
        // growing the full-width seed into another staff. Do not propagate from
        // ambiguous multi-staff components: that would join the entire score.
        for _ in 0..<4 {
            var additional = Set<Int>()
            for (index, component) in components.enumerated() where !selected.contains(index) && !ambiguous.contains(index) {
                if let lyricOwner = lyricOwners[index], !ids.contains(lyricOwner) { continue }
                let box = component.bounds
                if part.hasLyrics == true && box[1] >= lastLine { continue }
                if box[3] < firstLine, part.id != profile.parts.first?.id {
                    let center = (box[1] + box[3]) / 2
                    let nearest = allStaves.min { lhs, rhs in
                        max(lhs.staffLineFractions[0] - center, center - lhs.staffLineFractions[4], 0)
                            < max(rhs.staffLineFractions[0] - center, center - rhs.staffLineFractions[4], 0)
                    }
                    // Do not walk upward through a preceding part's detached
                    // low slur or lyric row. High target ink connected to this
                    // staff is already retained; detached inter-staff ink needs
                    // source review rather than transitive bbox ownership.
                    if nearest.map({ !ids.contains($0.id) }) == true { continue }
                }
                var touchesNeighbor = false
                if !component.staffIDs.isEmpty {
                    let neighbors = component.staffIDs.compactMap { staffLookup[$0] }
                    guard neighbors.count == component.staffIDs.count,
                          neighbors.allSatisfy({ $0.staffLineFractions[0] > lastLine }),
                          box[1] > lastLine, box[1] < lastLine + 6 * space,
                          neighbors.allSatisfy({ box[1] < $0.staffLineFractions[0] - 1.5 * space }) else { continue }
                    // A low f/pp may physically touch the next part's beamed
                    // group. The whole foreign group is not evidence of target
                    // ownership; surface a specific lower-edge review instead.
                    touchesNeighbor = true
                }
                if selected.contains(where: { otherIndex in
                    let other = components[otherIndex].bounds
                    let horizontalGap = max(box[0] - other[2], other[0] - box[2], 0) * page.pageWidth / page.pageHeight
                    let verticalGap = max(box[1] - other[3], other[1] - box[3], 0)
                    return horizontalGap <= space && verticalGap <= 1.75 * space
                }) {
                    if touchesNeighbor { foreignEdgeNeedsReview = true }
                    else { additional.insert(index) }
                }
            }
            if additional.isEmpty { break }
            selected.formUnion(additional)
        }
        let clearance = max(space * 0.5, 2 / page.pageHeight)
        var top = firstLine - max(0.5, explicitTop ?? 0.5) * space - skew
        var bottom = lastLine + max(0.5, explicitBottom ?? 0.5) * space + skew
        for index in selected.union(ambiguous) {
            top = min(top, components[index].bounds[1] - clearance)
            bottom = max(bottom, components[index].bounds[3] + clearance)
        }
        var warnings: [String] = []
        if !ambiguous.isEmpty {
            warnings.append("Notation connected to this staff also touches a neighboring staff. The complete ambiguous ink is retained; review this crop locally.")
        }
        if foreignEdgeNeedsReview {
            warnings.append("Check detached low dynamics and slurs at the lower edge: nearby ink connects to the following staff, so its ownership is uncertain. Expand this crop locally if the target marking continues below it.")
        }
        return CropBounds(rect: [broad[0], max(0, top) * page.pageHeight, broad[2], min(1, bottom) * page.pageHeight], warnings: warnings)
    }

    private static func band(partID: String, page: ScorePageAnalysis, system: Int, staves: [ScoreObservedStaff], rect: [Double],
                             label: String, kind: String, breakBefore: Bool, provenance: String, warnings: [String]) -> ScorePlannedBand {
        ScorePlannedBand(id: "p\(page.pageIndex + 1)-s\(system + 1)-\(partID)", partID: partID, pageIndex: page.pageIndex,
            systemIndex: system, candidateIDs: staves.map(\.id), topFraction: rect[1] / page.pageHeight,
            bottomFraction: rect[3] / page.pageHeight, leftFraction: rect[0] / page.pageWidth,
            rightFraction: 1 - rect[2] / page.pageWidth, editorialLabel: label, pageBreakBefore: breakBefore,
            kind: kind, provenance: provenance, warnings: warnings)
    }
}
