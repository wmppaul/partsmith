import CoreGraphics
import Foundation

/// Counts aligned printed bar boundaries in the staves selected for one system.
/// This is an editable assignment suggestion, not rhythmic recognition: it cannot
/// distinguish an anacrusis from a complete measure or infer an omitted measure.
/// The supplied raster must use the same display coordinates as the staves.
enum ScoreSystemBarCounter {
    struct Suggestion: Equatable {
        var barCount: Int
        var boundaryFractions: [Double]
        var supportingStaffCount: Int
        var selectedStaffCount: Int
        var explanation: String {
            "Found \(barCount) printed bars. Check pickups and split measures before assigning."
        }
    }

    private struct Stroke {
        var left: Int
        var right: Int
        var center: Double { Double(left + right) / 2 }
    }
    private struct StaffEvidence {
        var boundaries: [Double]
        var left: Double
        var right: Double
        var top: Double
        var bottom: Double
        var space: Double
    }

    static func suggest(in image: CGImage, staves: [ScoreObservedStaff],
                        skewDegrees: Double = 0,
                        diagnostic: ((String) -> Void)? = nil,
                        isCancelled: () -> Bool = { false }) -> Suggestion? {
        func reject(_ reason: String) -> Suggestion? { diagnostic?(reason); return nil }
        guard !isCancelled(), !staves.isEmpty, skewDegrees.isFinite,
              abs(skewDegrees) <= 5, Set(staves.map(\.id)).count == staves.count else {
            return reject("Select distinct staves from one complete system.")
        }
        let factor = min(1, 1800.0 / Double(image.width), 2600.0 / Double(image.height))
        let width = max(1, Int((Double(image.width) * factor).rounded()))
        let height = max(1, Int((Double(image.height) * factor).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return reject("Raster unavailable.") }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pointer = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return reject("Raster unavailable.")
        }
        let pixels = UnsafeBufferPointer(start: pointer, count: width * height)
        func black(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < width && y >= 0 && y < height && pixels[y * width + x] < 180
        }
        let slope = tan(skewDegrees * .pi / 180)
        var evidence: [StaffEvidence] = []
        for staff in staves {
            if isCancelled() { return nil }
            let lines = staff.staffLineFractions.map { $0 * Double(height) }
            guard lines.count == 5, lines.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < Double(height) }),
                  zip(lines, lines.dropFirst()).allSatisfy({ $0 < $1 }) else {
                return reject("Incomplete staff geometry.")
            }
            let space = (lines[4] - lines[0]) / 4
            guard space >= 3, space <= Double(height) * 0.04 else {
                return reject("Staff resolution is insufficient.")
            }
            let radius = max(1, Int((space * 0.18).rounded()))
            // Follow local line phase after a scan has been deskewed. The source
            // itself is never changed. Small windows tolerate gentle scan bow.
            let tile = max(24, Int(space * 6))
            let maxOffset = max(2, Int((space * 0.4).rounded()))
            var anchors: [(x: Int, offset: Double)] = []
            for x in stride(from: 0, to: width, by: tile) {
                var bestOffset = 0, bestScore = -1
                for offset in -maxOffset...maxOffset {
                    var score = 0
                    for column in stride(from: max(0, x - tile / 2), through: min(width - 1, x + tile / 2), by: 2) {
                        for line in lines {
                            let row = Int((line + slope * (Double(column) - Double(width) / 2)).rounded()) + offset
                            if black(column, row) { score += 2 }
                            if black(column, row - 1) || black(column, row + 1) { score += 1 }
                        }
                    }
                    if score > bestScore || (score == bestScore && abs(offset) < abs(bestOffset)) {
                        bestOffset = offset; bestScore = score
                    }
                }
                anchors.append((x, Double(bestOffset)))
            }
            var offsets = [Double](repeating: 0, count: width), anchorIndex = 0
            for x in 0..<width {
                while anchorIndex + 1 < anchors.count && anchors[anchorIndex + 1].x < x { anchorIndex += 1 }
                let a = anchors[anchorIndex], b = anchors[min(anchorIndex + 1, anchors.count - 1)]
                let t = b.x == a.x ? 0 : Double(x - a.x) / Double(b.x - a.x)
                offsets[x] = slope * (Double(x) - Double(width) / 2) + a.offset + (b.offset - a.offset) * t
            }
            func ink(_ x: Int, _ y: Double) -> Bool {
                black(x, Int((y + offsets[x]).rounded()))
            }
            // Find the actual five-line extent, excluding instrument-name ink.
            let lineSupport = (0..<width).filter { x in
                lines.filter { line in (-radius...radius).contains { ink(x, line + Double($0)) } }.count >= 4
            }
            guard let left = lineSupport.first, let right = lineSupport.last,
                  Double(right - left) >= space * 16 else {
                diagnostic?("Staff \(staff.id): no complete line extent."); continue
            }
            let coreTop = Int(lines[0].rounded()), coreBottom = Int(lines[4].rounded())
            var columns: [Int] = []
            for x in left...right {
                let count = (coreTop...coreBottom).filter { ink(x, Double($0)) }.count
                let spansSpaces = zip(lines, lines.dropFirst()).allSatisfy { a, b in
                    let middle = (a + b) / 2
                    return (-1...1).contains { ink(x, middle + Double($0)) }
                }
                if Double(count) / Double(coreBottom - coreTop + 1) >= 0.86 && spansSpaces { columns.append(x) }
            }
            var strokes: [Stroke] = []
            for x in columns {
                if let last = strokes.last, x - last.right <= max(1, Int(space * 0.12)) + 1 {
                    strokes[strokes.count - 1].right = x
                } else { strokes.append(Stroke(left: x, right: x)) }
            }
            // Adjacent strokes of a double or repeat bar are one boundary.
            var boundaries: [Stroke] = []
            for stroke in strokes {
                if let last = boundaries.last, Double(stroke.left - last.right) <= space * 0.9 {
                    boundaries[boundaries.count - 1].right = stroke.right
                } else { boundaries.append(stroke) }
            }
            // Clef stems belong to the opening prefix, not a new measure.
            boundaries = boundaries.filter {
                $0.center <= Double(left) + space || $0.center >= Double(left) + space * 4.5
            }
            guard (1...256).contains(boundaries.count) else { continue }

            diagnostic?("Staff \(staff.id): candidate strokes at \(boundaries.map { Int($0.center) }).")
            // Keep an actual ink column for connector checks. The geometric
            // midpoint of a merged double bar can lie in its white gap.
            evidence.append(StaffEvidence(boundaries: boundaries.map { Double($0.left) },
                left: Double(left), right: Double(right), top: lines[0], bottom: lines[4], space: space))
        }
        guard !isCancelled(), !evidence.isEmpty else { return reject("No complete barline pattern found.") }
        // Compare each boundary across staves before comparing complete
        // patterns: note stems can span all five lines in an individual staff.
        // The five horizontal lines establish the opening edge even in scores
        // that print no vertical opening line on the upper wind staves.
        guard staves.count >= 2 else { return reject("A single staff needs a manual count.") }
        let required = max(2, staves.count / 2 + 1)
        guard evidence.count >= required else { return reject("Too few complete staves.") }
        let typicalSpace = evidence.map(\.space).sorted()[evidence.count / 2]
        let tolerance = max(2, typicalSpace * 1.1)
        let left = evidence.map(\.left).sorted()[evidence.count / 2]
        let right = evidence.map(\.right).sorted()[evidence.count / 2]
        guard evidence.allSatisfy({ abs($0.left - left) <= typicalSpace * 2 && abs($0.right - right) <= typicalSpace * 2 }) else {
            return reject("The selected staves have different horizontal extents.")
        }
        let candidates = evidence.flatMap(\.boundaries).sorted()
        var clusters: [[Double]] = []
        for x in candidates {
            if let previous = clusters.last, let first = previous.first, x - first <= tolerance * 2 {
                clusters[clusters.count - 1].append(x)
            } else { clusters.append([x]) }
        }
        var accepted: [Double] = []
        var minimumSupport = staves.count
        var uncertainInteriorBoundary = false
        for cluster in clusters {
            let x = cluster.reduce(0, +) / Double(cluster.count)
            guard x > left + typicalSpace * 4.5 else { continue }
            let supporters = evidence.filter { $0.boundaries.contains { abs($0 - x) <= tolerance } }
            guard supporters.count >= required else { continue }
            // Shared note stems and even time-signature numerals can align
            // across many staves. A bar must also cross an interstaff gap.
            // Interpolate between each staff's measured stroke position to
            // tolerate slight rotation and vertical distortion in a scan.
            let ordered = supporters.sorted { $0.top < $1.top }
            let connected = zip(ordered, ordered.dropFirst()).contains { upper, lower in
                guard let upperX = upper.boundaries.min(by: { abs($0 - x) < abs($1 - x) }),
                      let lowerX = lower.boundaries.min(by: { abs($0 - x) < abs($1 - x) }) else { return false }
                let start = Int((upper.bottom + typicalSpace).rounded())
                let end = Int((lower.top - typicalSpace).rounded())
                guard end > start else { return false }
                var matches = 0
                for y in start...end {
                    let t = (Double(y) - upper.bottom) / (lower.top - upper.bottom)
                    let center = Int((upperX + (lowerX - upperX) * t).rounded())
                    if (-1...1).contains(where: { black(center + $0, y) }) { matches += 1 }
                }
                return Double(matches) / Double(end - start + 1) >= 0.75
            }
            guard connected else {
                // Ignoring a disconnected but widely shared interior boundary
                // could turn several measures into one. Only the opening
                // clef/key/meter prefix may explain such a shared glyph.
                if !accepted.isEmpty || x > left + typicalSpace * 16 {
                    uncertainInteriorBoundary = true
                }
                continue
            }
            accepted.append(x)
            minimumSupport = min(minimumSupport, supporters.count)
        }
        guard !uncertainInteriorBoundary,
              let last = accepted.last, right - last <= typicalSpace,
              (1...128).contains(accepted.count) else {
            return reject("The closing barline or a complete shared pattern is uncertain.")
        }
        let boundaries = [left] + accepted
        guard zip(boundaries, boundaries.dropFirst()).allSatisfy({ $1 - $0 >= typicalSpace * 2.5 }) else {
            return reject("Very narrow measures or extra vertical notation need a manual count.")
        }
        return Suggestion(barCount: accepted.count, boundaryFractions: boundaries.map { $0 / Double(width) },
            supportingStaffCount: minimumSupport, selectedStaffCount: staves.count)
    }
}
