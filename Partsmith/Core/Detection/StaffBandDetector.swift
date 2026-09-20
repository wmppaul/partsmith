import CoreGraphics
import Foundation

/// A geometrical proposal, not an identified instrument or a verified part.
/// All coordinates are fractions of the supplied image, with zero at the top.
struct StaffBandCandidate: Identifiable, Equatable {
    var id: Int
    var staffLineFractions: [Double]
    var topFraction: Double
    var bottomFraction: Double
    var confidence: Double
    var warnings: [String]
}

struct StaffDetectionResult {
    var candidates: [StaffBandCandidate]
    var warnings: [String]
}

/// Finds repeated, widely supported five-line patterns entirely on the Mac.
/// Supply the same (optionally rectified) image used for band editing. This
/// detector does not deskew, recognize music, infer instruments, or join staves.
enum StaffBandDetector {
    static func detect(in image: CGImage, isCancelled: () -> Bool = { false }) -> StaffDetectionResult {
        guard let raster = Raster(image: image) else {
            return StaffDetectionResult(candidates: [], warnings: ["This page could not be analyzed."])
        }

        let profile = rowProfile(raster, isCancelled: isCancelled)
        if isCancelled() { return StaffDetectionResult(candidates: [], warnings: []) }
        let peaks = linePeaks(profile)
        var staffs = staffPatterns(peaks, width: raster.width, isCancelled: isCancelled)
        // A scan may bow slightly or retain a little skew even after deskew.
        // Seek agreeing five-line patterns in independent horizontal windows;
        // only add a missed staff when at least two windows support it.
        let windows = [(0.08, 0.40), (0.34, 0.66), (0.60, 0.92)]
        let localStaffs = windows.map { left, right in
            let local = rowProfile(raster, leftFraction: left, rightFraction: right, isCancelled: isCancelled)
            return staffPatterns(linePeaks(local), width: raster.width, isCancelled: isCancelled)
        }
        for (windowIndex, windowStaffs) in localStaffs.enumerated() {
            for localStaff in windowStaffs {
                let space = (localStaff.lines[4] - localStaff.lines[0]) / 4
                guard !staffs.contains(where: { overlaps(localStaff, $0) }) else { continue }
                var matches = [localStaff]
                for otherIndex in localStaffs.indices where otherIndex != windowIndex {
                    if let match = localStaffs[otherIndex].first(where: {
                        let otherSpace = ($0.lines[4] - $0.lines[0]) / 4
                        return abs(otherSpace - space) < space * 0.20
                            && abs($0.lines[0] - localStaff.lines[0]) < space * 0.9
                    }) { matches.append(match) }
                }
                guard matches.count >= 2 else { continue }
                let meanLines = (0..<5).map { line in matches.map { $0.lines[line] }.reduce(0, +) / Double(matches.count) }
                staffs.append(Staff(
                    lines: meanLines,
                    confidence: matches.map(\.confidence).reduce(0, +) / Double(matches.count) * 0.85,
                    usesLocalEvidence: true
                ))
            }
        }
        staffs.sort { $0.lines[0] < $1.lines[0] }
        if isCancelled() { return StaffDetectionResult(candidates: [], warnings: []) }
        guard !staffs.isEmpty else {
            return StaffDetectionResult(candidates: [], warnings: [
                "No reliable five-line staves found. Check the page orientation or rectification, or draw bands manually."
            ])
        }

        let height = Double(raster.height)
        var candidates: [StaffBandCandidate] = []
        for (index, staff) in staffs.enumerated() {
            let first = staff.lines[0]
            let last = staff.lines[4]
            let space = (last - first) / 4
            let previous = index > 0 ? staffs[index - 1].lines[4] : 0
            let next = index + 1 < staffs.count ? staffs[index + 1].lines[0] : height - 1
            let upperLimit = index > 0 ? (previous + first) / 2 : 0
            let lowerLimit = index + 1 < staffs.count ? (last + next) / 2 : height - 1
            let top = quietBoundary(
                near: max(upperLimit, first - 3.5 * space),
                lower: max(upperLimit, first - 5 * space),
                upper: first - 1.25 * space,
                space: space,
                profile: profile
            )
            let bottom = quietBoundary(
                near: min(lowerLimit, last + 3.5 * space),
                lower: last + 1.25 * space,
                upper: min(lowerLimit, last + 5 * space),
                space: space,
                profile: profile
            )
            var warnings: [String] = []
            if staff.usesLocalEvidence {
                warnings.append("Staff lines may be tilted, curved, or interrupted. Check both ends of this band.")
            }
            if staff.confidence < 0.72 {
                warnings.append("Some staff lines are faint or interrupted; verify this proposal.")
            }
            if (index > 0 && first - previous < 5 * space)
                || (index + 1 < staffs.count && next - last < 5 * space) {
                warnings.append("A neighboring staff is close. Suggested edges may cut target notation; expand the crop and keep neighboring ink when needed.")
            }
            candidates.append(StaffBandCandidate(
                id: index,
                staffLineFractions: staff.lines.map { $0 / height },
                topFraction: max(0, min(top, first - 0.5 * space)) / height,
                bottomFraction: min(height, max(bottom, last + 0.5 * space)) / height,
                confidence: staff.confidence,
                warnings: warnings
            ))
        }
        return StaffDetectionResult(candidates: candidates, warnings: [
            "Staff proposals need review. Instrument identity, changing staff order, shared markings, and multi-staff instruments are not inferred."
        ])
    }

    private struct Raster {
        let width: Int
        let height: Int
        let pixels: [UInt8]

        init?(image: CGImage) {
            guard image.width > 0, image.height > 0 else { return nil }
            // Bound memory and keep staff spacing large enough to distinguish
            // engraved lines from their anti-aliased neighboring pixels.
            let scale = min(1, 1800.0 / Double(image.width), 2600.0 / Double(image.height))
            width = max(1, Int((Double(image.width) * scale).rounded()))
            height = max(1, Int((Double(image.height) * scale).rounded()))
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard let data = context.data else { return nil }
            pixels = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height))
        }
    }

    private struct Row {
        var ink: Double
        var support: Double
    }

    private struct Peak {
        var y: Double
        var strength: Double
        var support: Double
    }

    private struct Staff {
        var lines: [Double]
        var confidence: Double
        var usesLocalEvidence = false
    }

    private static func rowProfile(
        _ raster: Raster, leftFraction: Double = 0.035, rightFraction: Double = 0.965,
        isCancelled: () -> Bool
    ) -> [Row] {
        let left = Int(Double(raster.width) * leftFraction)
        let right = max(left + 1, Int(Double(raster.width) * rightFraction))
        let columnCount = 12
        var profile: [Row] = []
        profile.reserveCapacity(raster.height)
        for y in 0..<raster.height {
            if isCancelled() { return [] }
            var totalInk = 0
            var supportedColumns = 0
            for column in 0..<columnCount {
                let start = left + (right - left) * column / columnCount
                let end = left + (right - left) * (column + 1) / columnCount
                guard end > start else { continue }
                var count = 0
                for x in start..<end where raster.pixels[y * raster.width + x] < 195 {
                    count += 1
                }
                totalInk += count
                if Double(count) / Double(end - start) >= 0.32 { supportedColumns += 1 }
            }
            profile.append(Row(
                ink: Double(totalInk) / Double(right - left),
                support: Double(supportedColumns) / Double(columnCount)
            ))
        }
        return profile
    }

    private static func linePeaks(_ profile: [Row]) -> [Peak] {
        // Dense beamed passages can keep the entire staff above the absolute
        // ink threshold. A local threshold still separates the long staff
        // lines from the shorter beams between them.
        let isLine = profile.indices.map { row in
            let localMaximum = (max(0, row - 4)...min(profile.count - 1, row + 4))
                .map { profile[$0].ink }.max() ?? 0
            return profile[row].ink >= max(0.22, localMaximum * 0.78)
                && profile[row].support >= 0.333
        }
        var peaks: [Peak] = []
        var index = 0
        while index < profile.count {
            guard isLine[index] else {
                index += 1
                continue
            }
            let start = index
            var strongest = index
            while index + 1 < profile.count,
                  isLine[index + 1] {
                index += 1
                if profile[index].ink > profile[strongest].ink { strongest = index }
            }
            // A thick text/beam block is not a staff line. The y centroid
            // prevents alternating raster thickness from distorting spacing.
            let end = index
            if end - start <= 8 {
                var weightedY = 0.0
                var weight = 0.0
                for row in start...end {
                    let value = max(0, profile[row].ink - 0.15)
                    weightedY += (Double(row) + 0.5) * value
                    weight += value
                }
                peaks.append(Peak(
                    y: weightedY / max(weight, 0.0001),
                    strength: profile[strongest].ink,
                    support: profile[strongest].support
                ))
            }
            index += 1
        }
        return peaks
    }

    private static func staffPatterns(_ peaks: [Peak], width: Int, isCancelled: () -> Bool) -> [Staff] {
        guard peaks.count >= 5 else { return [] }
        let minimumSpace = max(3.0, Double(width) / 600)
        let maximumSpace = max(12.0, Double(width) / 40)
        var patterns: [Staff] = []
        for first in 0..<(peaks.count - 4) {
            if isCancelled() { return [] }
            // Fit spacing over the full five-line height. Using only the
            // first interval amplifies one-pixel scan/rasterization errors.
            for last in (first + 4)..<peaks.count {
                let space = (peaks[last].y - peaks[first].y) / 4
                if space < minimumSpace { continue }
                if space > maximumSpace { break }
                let tolerance = max(1.25, space * 0.18)
                var indices = [first]
                var spacingError = 0.0
                for line in 1...3 {
                    let expectedY = peaks[first].y + Double(line) * space
                    let searchStart = indices.last! + 1
                    guard let match = nearestPeak(peaks, startingAt: searchStart, to: expectedY),
                          match < last, abs(peaks[match].y - expectedY) <= tolerance else { break }
                    indices.append(match)
                    spacingError += abs(peaks[match].y - expectedY) / tolerance
                }
                guard indices.count == 4 else { continue }
                indices.append(last)
                let actualSpace = (peaks[indices[4]].y - peaks[first].y) / 4
                let gaps = (1...4).map { peaks[indices[$0]].y - peaks[indices[$0 - 1]].y }
                guard gaps.allSatisfy({ abs($0 - actualSpace) <= max(1.3, actualSpace * 0.20) }) else { continue }
                let meanStrength = indices.map { peaks[$0].strength }.reduce(0, +) / 5
                let meanSupport = indices.map { peaks[$0].support }.reduce(0, +) / 5
                // Distributed evidence prevents a run of short note beams or
                // ledger lines from masquerading as a complete staff.
                guard meanSupport >= 0.45, meanStrength >= 0.28 else { continue }
                let confidence = min(1, max(0, 0.45 * min(1, meanStrength / 0.65)
                    + 0.40 * meanSupport + 0.15 * (1 - spacingError / 3)))
                patterns.append(Staff(lines: indices.map { peaks[$0].y }, confidence: confidence))
            }
        }

        // Competing interpretations share lines. Prefer the strongest evidence
        // and then restore reading order. Equal scores have a stable tie break.
        patterns.sort {
            if abs($0.confidence - $1.confidence) > 0.000001 { return $0.confidence > $1.confidence }
            return $0.lines[0] < $1.lines[0]
        }
        var accepted: [Staff] = []
        for pattern in patterns {
            guard !accepted.contains(where: { overlaps(pattern, $0) }) else { continue }
            accepted.append(pattern)
        }
        return accepted.sorted { $0.lines[0] < $1.lines[0] }
    }

    private static func overlaps(_ first: Staff, _ second: Staff) -> Bool {
        let space = (first.lines[4] - first.lines[0]) / 4
        return first.lines[0] < second.lines[4] + space && first.lines[4] > second.lines[0] - space
    }

    private static func nearestPeak(_ peaks: [Peak], startingAt start: Int, to y: Double) -> Int? {
        guard start < peaks.count else { return nil }
        var lower = start
        var upper = peaks.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if peaks[middle].y < y { lower = middle + 1 } else { upper = middle }
        }
        if lower == peaks.count { return peaks.count - 1 }
        if lower > start && abs(peaks[lower - 1].y - y) < abs(peaks[lower].y - y) { return lower - 1 }
        return lower
    }

    private static func quietBoundary(
        near preferred: Double, lower: Double, upper: Double, space: Double, profile: [Row]
    ) -> Double {
        let start = max(0, min(profile.count - 1, Int(lower.rounded(.up))))
        let end = max(start, min(profile.count - 1, Int(upper.rounded(.down))))
        var best = max(start, min(end, Int(preferred.rounded())))
        var bestCost = Double.infinity
        for row in start...end {
            let localInk = (max(0, row - 1)...min(profile.count - 1, row + 1))
                .map { profile[$0].ink }.reduce(0, +) / 3
            let cost = localInk + 0.025 * abs(Double(row) - preferred) / max(space, 1)
            if cost < bestCost {
                bestCost = cost
                best = row
            }
        }
        return Double(best)
    }
}
