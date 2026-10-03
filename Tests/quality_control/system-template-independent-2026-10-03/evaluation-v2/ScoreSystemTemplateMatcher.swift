import CoreGraphics
import Foundation

/// Finds source-supported similarities to explicitly assigned systems. This is
/// an assistive proposal, never an instrument recognizer or a rest counter.
enum ScoreSystemTemplateMatcher {
    enum Confidence: String, Codable, Equatable {
        case sourceSupported, needsReview
    }

    struct Suggestion: Identifiable, Equatable {
        var pageIndex: Int
        var systemIndex: Int
        var candidateIDs: [Int]
        var presentPartIDs: Set<String>
        var templatePageIndex: Int
        var templateSystemIndex: Int
        var confidence: Confidence
        var reasons: [String]
        /// Normalized top-down [left, top, right, bottom] in the analysis image.
        var sourceBounds: [Double]
        var requiresMeasureCount: Bool
        // A repeated printed layout does not imply repeated measure counts.
        var startBarNumber: Int? { nil }
        var barCount: Int? { nil }
        var id: String {
            "p\(pageIndex)-s\(systemIndex)-t\(templatePageIndex)-\(templateSystemIndex)"
        }
    }

    struct PageDiagnostic: Equatable {
        var pageIndex: Int
        var message: String
    }

    struct Result: Equatable {
        var suggestions: [Suggestion]
        var diagnostics: [PageDiagnostic]
        var cancelled: Bool
    }

    /// The provider must return the original or rectified display image used to
    /// obtain each analysis. A raw PDF raster cannot replace a rectified image.
    static func suggest(pages: [ScorePageAnalysis], profile: ScoreExtractionProfile,
                        reviewedOverrides: [ScorePageOverride],
                        imageForPage: (Int) -> CGImage?,
                        isCancelled: () -> Bool = { false }) -> Result {
        var result = Result(suggestions: [], diagnostics: [], cancelled: false)
        func cancelled() -> Result { Result(suggestions: [], diagnostics: result.diagnostics, cancelled: true) }
        guard !isCancelled() else { return cancelled() }
        let partIDs = Set(profile.parts.map(\.id))
        guard !profile.parts.isEmpty, partIDs.count == profile.parts.count,
              profile.parts.allSatisfy({ !$0.id.isEmpty && (1...4).contains($0.staffCount) }),
              Set(pages.map(\.pageIndex)).count == pages.count,
              Set(reviewedOverrides.map(\.pageIndex)).count == reviewedOverrides.count else {
            result.diagnostics.append(PageDiagnostic(pageIndex: -1, message: "Review the instrument setup and page selection first."))
            return result
        }
        var features: [Int: PageFeatures] = [:]
        for page in pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            if isCancelled() { return cancelled() }
            guard !page.staves.isEmpty else { continue }
            if reviewedOverrides.first(where: { $0.pageIndex == page.pageIndex })?.ignoredCandidateIDs?.isEmpty == false {
                result.diagnostics.append(PageDiagnostic(pageIndex: page.pageIndex,
                    message: "This page has manually ignored staff candidates. Assign its complete systems on the score."))
                continue
            }
            var failureMessage: String?
            guard let image = imageForPage(page.pageIndex),
                  let feature = measure(page: page, image: image, isCancelled: isCancelled,
                    failure: { failureMessage = $0 }) else {
                result.diagnostics.append(PageDiagnostic(pageIndex: page.pageIndex,
                    message: failureMessage ?? "The printed system connections could not be established. Assign this page on the score."))
                continue
            }
            features[page.pageIndex] = feature
        }
        if isCancelled() { return cancelled() }
        var templates: [Template] = []
        var disconnectedReviewedSystem = false
        for correction in reviewedOverrides.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            guard correction.nonMusicReason == nil else { continue }
            guard let page = features[correction.pageIndex] else {
                if correction.systems.contains(where: { !$0.bands.isEmpty && $0.requiresAssignmentReview != true }) {
                    disconnectedReviewedSystem = true
                }
                continue
            }
            for system in correction.systems.sorted(by: { $0.systemIndex < $1.systemIndex }) {
                guard system.requiresAssignmentReview != true, !system.bands.isEmpty else { continue }
                let bands = system.bands.filter { ($0.kind ?? "music") == "music" }
                let present = Set(bands.map(\.partID))
                let absent = Set((system.omittedParts ?? []).map(\.partID))
                guard present.count == bands.count, !present.isEmpty,
                      present.isDisjoint(with: absent), present.union(absent) == partIDs,
                      absent.count == (system.omittedParts ?? []).count else { continue }
                let printed = profile.parts.filter { present.contains($0.id) }
                guard printed.allSatisfy({ part in bands.first(where: { $0.partID == part.id })?.candidateIDs?.count == part.staffCount }) else { continue }
                let ids = printed.flatMap { part in bands.first(where: { $0.partID == part.id })?.candidateIDs ?? [] }
                guard Set(ids).count == ids.count else { continue }
                guard let group = page.groups.first(where: { $0.staves.map(\.id) == ids }),
                      group.systemIndex == system.systemIndex else {
                    // Choir and organ can have separate left connections within
                    // one real system. Never learn their subgroups as systems.
                    disconnectedReviewedSystem = true
                    result.diagnostics.append(PageDiagnostic(pageIndex: correction.pageIndex,
                        message: "Reviewed system \(system.systemIndex + 1) has separate or uncertain printed connections. Similar-layout matching cannot establish its complete boundary."))
                    continue
                }
                templates.append(Template(pageIndex: correction.pageIndex, systemIndex: system.systemIndex,
                    presentPartIDs: present, group: group))
            }
        }
        guard !disconnectedReviewedSystem else { return result }
        guard !templates.isEmpty else {
            result.diagnostics.append(PageDiagnostic(pageIndex: -1,
                message: "Assign at least one complete printed system first. Its instruments and source connections become the example."))
            return result
        }
        for page in features.values.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            if isCancelled() { return cancelled() }
            let correction = reviewedOverrides.first { $0.pageIndex == page.pageIndex }
            if correction?.nonMusicReason != nil { continue }
            var pageSuggestions: [Suggestion] = []
            var unsupported = false
            for group in page.groups {
                let ids = group.staves.map(\.id)
                let occupied = correction?.systems.contains { system in
                    system.bands.contains { !(Set($0.candidateIDs ?? []).intersection(ids)).isEmpty }
                } ?? false
                if occupied { continue }
                var matches: [(Template, Double)] = []
                for template in templates where template.group.staves.count == group.staves.count {
                    let scores = zip(template.group.staves, group.staves).map { similarity($0.patch, $1.patch) }
                    guard let minimum = scores.min(), minimum >= 0.48 else { continue }
                    matches.append((template, minimum))
                }
                // Multiple reviewed examples of the same roster are useful;
                // differing rosters remain separate explicit choices.
                var best: [Set<String>: (Template, Double)] = [:]
                for match in matches {
                    if best[match.0.presentPartIDs] == nil || best[match.0.presentPartIDs]!.1 < match.1 {
                        best[match.0.presentPartIDs] = match
                    }
                }
                guard !best.isEmpty else { unsupported = true; continue }
                for (template, score) in best.values.sorted(by: {
                    ($0.0.pageIndex, $0.0.systemIndex) < ($1.0.pageIndex, $1.0.systemIndex)
                }) {
                    let certain = best.count == 1 && score >= 0.72
                    var reasons = ["A continuous printed left edge connects all \(ids.count) staves.",
                        "Initial clef shapes resemble reviewed page \(template.pageIndex + 1), system \(template.systemIndex + 1)."]
                    if best.count > 1 { reasons.append("More than one reviewed instrument roster fits this source. Choose the correct roster on the score.") }
                    if score < 0.72 { reasons.append("Some clef shapes differ or are faint; inspect this system before accepting.") }
                    let needsCount = template.presentPartIDs != partIDs
                    if needsCount { reasons.append("Absent parts still need this system’s own confirmed bar count.") }
                    pageSuggestions.append(Suggestion(pageIndex: page.pageIndex, systemIndex: group.systemIndex,
                        candidateIDs: ids, presentPartIDs: template.presentPartIDs,
                        templatePageIndex: template.pageIndex, templateSystemIndex: template.systemIndex,
                        confidence: certain ? .sourceSupported : .needsReview, reasons: reasons,
                        sourceBounds: group.bounds, requiresMeasureCount: needsCount))
                }
            }
            if unsupported {
                result.diagnostics.append(PageDiagnostic(pageIndex: page.pageIndex,
                    message: "Some connected staff groups do not match a reviewed complete system. This page is left for assignment so a subgroup is not mistaken for a whole system."))
            } else { result.suggestions += pageSuggestions }
        }
        if isCancelled() { return cancelled() }
        return result
    }

    private struct StaffFeature {
        var id: Int
        var lines: [Double]
        var start: Int
        var end: Int
        var patch: [Bool]
        var space: Double { (lines[4] - lines[0]) / 4 }
    }
    private struct Group {
        var systemIndex: Int
        var staves: [StaffFeature]
        var bounds: [Double]
    }
    private struct PageFeatures { var pageIndex: Int; var groups: [Group] }
    private struct Template {
        var pageIndex: Int
        var systemIndex: Int
        var presentPartIDs: Set<String>
        var group: Group
    }
    private struct Raster {
        var width: Int
        var height: Int
        var ink: [Bool]
        func hasInk(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < width && y >= 0 && y < height && ink[y * width + x]
        }
    }

    private static func measure(page: ScorePageAnalysis, image: CGImage,
                                isCancelled: () -> Bool, failure: (String) -> Void) -> PageFeatures? {
        // Dimensions bind the provider to the staff coordinate frame; UI also
        // binds the review to its source document and rectification revision.
        guard image.width == page.imageWidth, image.height == page.imageHeight,
              page.analysisSkewDegrees.isFinite, abs(page.analysisSkewDegrees) < 12,
              Set(page.staves.map(\.id)).count == page.staves.count,
              page.staves.allSatisfy({ $0.staffLineFractions.count == 5 }),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        // A missing middle staff can leave a plausible G/F-clef piano pair.
        // Recheck this actual raster before trusting the supplied inventory.
        // This catches stale/altered inventories, not every possible failure of
        // the staff detector itself; every match still requires user acceptance.
        let fresh = StaffBandDetector.detect(in: image, isCancelled: isCancelled)
        let observed = page.staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
        let measured = fresh.candidates.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
        guard measured.count == observed.count,
              zip(measured, observed).allSatisfy({ current, previous in
                  current.staffLineFractions.count == 5 && previous.staffLineFractions.count == 5
                      && zip(current.staffLineFractions, previous.staffLineFractions).allSatisfy {
                          $0.isFinite && $1.isFinite && abs($0 - $1) * Double(image.height) <= 1
                      }
              }) else {
            failure("The detected staves no longer agree with the source image. Run Auto again before finding similar systems.")
            return nil
        }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let raster = Raster(width: image.width, height: image.height,
            ink: UnsafeBufferPointer(start: data, count: image.width * image.height).map { $0 < 210 })
        let slope = tan(page.analysisSkewDegrees * .pi / 180)
        var staves: [StaffFeature] = []
        for staff in page.staves.sorted(by: { $0.staffLineFractions[0] < $1.staffLineFractions[0] }) {
            if isCancelled() { return nil }
            guard staff.staffLineFractions.count == 5,
                  staff.staffLineFractions.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
                  zip(staff.staffLineFractions, staff.staffLineFractions.dropFirst()).allSatisfy({ $0 < $1 }) else { return nil }
            let lines = staff.staffLineFractions.map { $0 * Double(raster.height) }
            let space = (lines[4] - lines[0]) / 4
            guard space >= 3 else { return nil }
            let tolerance = max(1, Int((space * 0.15).rounded()))
            var supported = [Bool](repeating: false, count: raster.width)
            for x in 0..<raster.width {
                let shift = slope * (Double(x) - Double(raster.width) / 2)
                var votes = 0
                for line in lines {
                    let y = Int((line + shift).rounded())
                    if (-tolerance...tolerance).contains(where: { raster.hasInk(x, y + $0) }) { votes += 1 }
                }
                supported[x] = votes >= 4
            }
            let runLength = max(8, Int((4 * space).rounded()))
            guard runLength < raster.width else { return nil }
            var run = 0, first: Int?, last: Int?
            for x in 0..<raster.width {
                run = supported[x] ? run + 1 : 0
                if run >= runLength {
                    if first == nil { first = x - run + 1 }
                    last = x
                }
            }
            guard let start = first, let end = last,
                  Double(end - start) > space * 16 else { return nil }
            var feature = StaffFeature(id: staff.id, lines: lines, start: start, end: end, patch: [])
            feature.patch = clefPatch(staff: feature, raster: raster, slope: slope)
            staves.append(feature)
        }
        guard !staves.isEmpty else { return PageFeatures(pageIndex: page.pageIndex, groups: []) }
        // A missing connection is only a separator when the actual source edge
        // has a substantial blank interruption. Otherwise the page abstains.
        var groups: [[StaffFeature]] = [[staves[0]]]
        for i in 1..<staves.count {
            if isCancelled() { return nil }
            switch connection(staves[i - 1], staves[i], raster: raster, slope: slope) {
            case .connected: groups[groups.count - 1].append(staves[i])
            case .separate: groups.append([staves[i]])
            case .uncertain: return nil
            }
        }
        for group in groups {
            if continuesOutside(group.first!, upper: true, raster: raster, slope: slope)
                || continuesOutside(group.last!, upper: false, raster: raster, slope: slope) {
                failure("A printed connection continues outside a proposed system. Review the complete system boundary on the score.")
                return nil
            }
        }
        return PageFeatures(pageIndex: page.pageIndex, groups: groups.enumerated().map { index, members in
            let space = members.map(\.space).min()!
            return Group(systemIndex: index, staves: members,
                bounds: [max(0, Double(members.map(\.start).min()!) - 2 * space) / Double(raster.width),
                    max(0, members.first!.lines[0] - 3 * space) / Double(raster.height),
                    min(Double(raster.width), Double(members.map(\.end).max()!) + space) / Double(raster.width),
                    min(Double(raster.height), members.last!.lines[4] + 3 * space) / Double(raster.height)])
        })
    }

    private enum Connection { case connected, separate, uncertain }

    private static func continuesOutside(_ staff: StaffFeature, upper: Bool,
                                         raster: Raster, slope: Double) -> Bool {
        let space = staff.space, reach = max(2, Int((space * 0.65).rounded()))
        for x in max(0, staff.start - reach)...min(raster.width - 1, staff.start + reach) {
            let shift = slope * (Double(x) - Double(raster.width) / 2)
            let edge = (upper ? staff.lines[0] : staff.lines[4]) + shift
            let top = Int((upper ? edge - 1.5 * space : edge + 0.35 * space).rounded())
            let bottom = Int((upper ? edge - 0.35 * space : edge + 1.5 * space).rounded())
            guard top >= 0, bottom < raster.height, bottom > top else { continue }
            let coreTop = max(0, Int((staff.lines[0] + shift).rounded()))
            let coreBottom = min(raster.height - 1, Int((staff.lines[4] + shift).rounded()))
            let coreHits = (coreTop...coreBottom).filter { y in
                (-1...1).contains { raster.hasInk(x + $0, y) }
            }.count
            guard Double(coreHits) / Double(coreBottom - coreTop + 1) >= 0.94 else { continue }
            let outsideHits = (top...bottom).filter { y in
                (-1...1).contains { raster.hasInk(x + $0, y) }
            }.count
            if Double(outsideHits) / Double(bottom - top + 1) >= 0.8 { return true }
        }
        return false
    }
    private static func connection(_ upper: StaffFeature, _ lower: StaffFeature,
                                   raster: Raster, slope: Double) -> Connection {
        let space = min(upper.space, lower.space)
        let xCenter = (upper.start + lower.start) / 2
        let localShift = slope * (Double(xCenter) - Double(raster.width) / 2)
        let gapTop = Int((upper.lines[4] + localShift + space * 0.25).rounded())
        let gapBottom = Int((lower.lines[0] + localShift - space * 0.25).rounded())
        guard gapBottom > gapTop, gapTop >= 0, gapBottom < raster.height else { return .uncertain }
        let reach = max(2, Int((space * 0.65).rounded()))
        let left = max(0, min(upper.start, lower.start) - reach)
        let right = min(raster.width - 1, max(upper.start, lower.start) + reach)
        if abs(upper.start - lower.start) <= Int(ceil(space * 0.6)) {
            for x in left...right {
                let top = max(0, Int((upper.lines[0] + localShift).rounded()))
                let bottom = min(raster.height - 1, Int((lower.lines[4] + localShift).rounded()))
                var occupied = 0, gapOccupied = 0, missingRun = 0, longestMissing = 0
                for y in top...bottom {
                    let has = (-1...1).contains { raster.hasInk(x + $0, y) }
                    if has { occupied += 1; missingRun = 0 }
                    else { missingRun += 1; longestMissing = max(longestMissing, missingRun) }
                    if y >= gapTop && y <= gapBottom && has { gapOccupied += 1 }
                }
                if Double(occupied) / Double(bottom - top + 1) >= 0.94,
                   Double(gapOccupied) / Double(gapBottom - gapTop + 1) >= 0.96,
                   Double(longestMissing) <= max(1, space * 0.4) { return .connected }
            }
        }
        var blankRun = 0, longestBlank = 0
        for y in gapTop...gapBottom {
            if (left...right).contains(where: { raster.hasInk($0, y) }) { blankRun = 0 }
            else { blankRun += 1; longestBlank = max(longestBlank, blankRun) }
        }
        return Double(longestBlank) >= 2 * space ? .separate : .uncertain
    }

    private static let patchWidth = 28
    private static let patchHeight = 64
    private static func clefPatch(staff: StaffFeature, raster: Raster, slope: Double) -> [Bool] {
        var patch = [Bool](repeating: false, count: patchWidth * patchHeight)
        for y in 0..<patchHeight {
            let dy = Double(y) / 8 - 2
            // Staff lines alone must not make two unrelated clefs match.
            if (0...4).contains(where: { abs(dy - Double($0)) <= 0.15 }) { continue }
            for x in 0..<patchWidth {
                let sourceX = Double(staff.start) + (Double(x) / 8 + 0.35) * staff.space
                let sourceY = staff.lines[0] + dy * staff.space
                    + slope * (sourceX - Double(raster.width) / 2)
                patch[y * patchWidth + x] = raster.hasInk(Int(sourceX.rounded()), Int(sourceY.rounded()))
            }
        }
        return patch
    }

    private static func similarity(_ a: [Bool], _ b: [Bool]) -> Double {
        let countA = a.filter { $0 }.count, countB = b.filter { $0 }.count
        guard a.count == patchWidth * patchHeight, b.count == a.count,
              countA >= 18, countB >= 18 else { return 0 }
        func supported(_ source: [Bool], _ target: [Bool], dx: Int, dy: Int) -> Int {
            var found = 0
            for y in 0..<patchHeight {
                for x in 0..<patchWidth where source[y * patchWidth + x] {
                    var hit = false
                    for yy in (y + dy - 1)...(y + dy + 1) where yy >= 0 && yy < patchHeight {
                        for xx in (x + dx - 1)...(x + dx + 1) where xx >= 0 && xx < patchWidth {
                            if target[yy * patchWidth + xx] { hit = true; break }
                        }
                        if hit { break }
                    }
                    if hit { found += 1 }
                }
            }
            return found
        }
        var best = 0.0
        for dy in -2...2 {
            for dx in -3...3 {
                best = max(best, min(Double(supported(a, b, dx: dx, dy: dy)) / Double(countA),
                    Double(supported(b, a, dx: -dx, dy: -dy)) / Double(countB)))
            }
        }
        return best
    }
}
