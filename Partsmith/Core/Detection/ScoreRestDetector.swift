import CoreGraphics
import Foundation

/// Recognizes the deliberately narrow case of one or two complete staves containing
/// only centered, hanging full-measure rests. Unknown ink is a failed match.
/// Analysis removes lines only in a temporary raster; the source is unchanged.
enum ScoreRestDetector {
    struct Detection: Equatable {
        var barCount: Int
        var staffLineFractions: [Double]
        var skewDegrees: Double
        var staffLeftFraction: Double
        var staffRightFraction: Double
        var prefixBounds: CGRect
        var suffixBounds: CGRect?
        var restBounds: [CGRect]
        var staffLineGroups: [[Double]]? = nil
        var canExtendThroughFollowingRests = false
        /// Kept for agreement checks between the two hands of a grand staff.
        var boundaryFractions: [Double] = []
    }

    private struct Component {
        var left: Int, top: Int, right: Int, bottom: Int, area: Int
        var width: Double { Double(right - left + 1) }
        var height: Double { Double(bottom - top + 1) }
    }
    private struct Boundary {
        var left: Int, right: Int
        var center: Double { Double(left + right) / 2 }
    }

    static func detect(in image: CGImage, band: CGRect,
                       staffDetection supplied: StaffDetectionResult? = nil,
                       diagnostic: ((String) -> Void)? = nil,
                       isCancelled: () -> Bool = { false }) -> Detection? {
        func reject(_ reason: String) -> Detection? { diagnostic?(reason); return nil }
        guard !isCancelled(), !band.isNull, !band.isEmpty,
              [band.minX, band.minY, band.maxX, band.maxY].allSatisfy(\.isFinite),
              band.minX >= 0, band.minY >= 0, band.maxX <= 1, band.maxY <= 1 else { return reject("Invalid band") }
        let found = supplied ?? StaffBandDetector.detect(in: image, isCancelled: isCancelled)
        let staves = found.candidates.filter {
            $0.staffLineFractions.count == 5 && $0.staffLineFractions[0] >= band.minY
                && $0.staffLineFractions[4] <= band.maxY
        }
        guard (1...2).contains(staves.count) else { return reject("Need one staff or a two-staff group") }
        if staves.count == 2 {
            let ordered = staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
            let middle = (ordered[0].staffLineFractions[4] + ordered[1].staffLineFractions[0]) / 2
            let crops = [CGRect(x: band.minX, y: band.minY, width: band.width, height: middle - band.minY),
                         CGRect(x: band.minX, y: middle, width: band.width, height: band.maxY - middle)]
            var matches: [Detection] = []
            for index in ordered.indices {
                guard let match = detectStaff(in: image, band: crops[index], staff: ordered[index],
                    found: found, diagnostic: diagnostic, isCancelled: isCancelled) else {
                    return reject("Staff \(index + 1) of the group is not entirely whole-bar rests")
                }
                matches.append(match)
            }
            let first = matches[0], second = matches[1]
            let tolerance = (ordered[0].staffLineFractions[4] - ordered[0].staffLineFractions[0])
                * Double(image.height) / Double(image.width) * 0.15
            guard first.barCount == second.barCount,
                  first.boundaryFractions.count == second.boundaryFractions.count,
                  zip(first.boundaryFractions, second.boundaryFractions).allSatisfy({ abs($0 - $1) <= tolerance }) else {
                return reject("The two staves do not agree on measure boundaries")
            }
            let prefixRight = matches.map(\.prefixBounds.maxX).max()!
            let suffixLeft = matches.compactMap(\.suffixBounds?.minX).min()!
            guard prefixRight < suffixLeft,
                  matches.flatMap(\.restBounds).allSatisfy({ $0.minX > prefixRight && $0.maxX < suffixLeft }) else {
                return reject("Grand-staff signature overlaps counted rests")
            }
            diagnostic?("Matched \(first.barCount) complete whole-bar rests on both staves")
            return Detection(barCount: first.barCount, staffLineFractions: first.staffLineFractions,
                skewDegrees: first.skewDegrees, staffLeftFraction: min(first.staffLeftFraction, second.staffLeftFraction),
                staffRightFraction: max(first.staffRightFraction, second.staffRightFraction),
                prefixBounds: CGRect(x: band.minX, y: band.minY, width: prefixRight - band.minX, height: band.height),
                suffixBounds: CGRect(x: suffixLeft, y: band.minY, width: band.maxX - suffixLeft, height: band.height),
                restBounds: matches.flatMap(\.restBounds), staffLineGroups: matches.map(\.staffLineFractions),
                canExtendThroughFollowingRests: matches.allSatisfy(\.canExtendThroughFollowingRests),
                boundaryFractions: first.boundaryFractions)
        }
        return detectStaff(in: image, band: band, staff: staves[0], found: found,
            diagnostic: diagnostic, isCancelled: isCancelled)
    }

    private static func detectStaff(in image: CGImage, band: CGRect, staff: StaffBandCandidate,
                                    found: StaffDetectionResult, diagnostic: ((String) -> Void)?,
                                    isCancelled: () -> Bool) -> Detection? {
        func reject(_ reason: String) -> Detection? { diagnostic?(reason); return nil }
        let factor = min(1, 1800.0 / Double(image.width), 2600.0 / Double(image.height))
        let width = max(1, Int((Double(image.width) * factor).rounded()))
        let height = max(1, Int((Double(image.height) * factor).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return reject("Raster unavailable")
        }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pointer = context.data?.assumingMemoryBound(to: UInt8.self) else { return reject("Raster unavailable") }
        let pixels = UnsafeBufferPointer(start: pointer, count: width * height)
        let lines = staff.staffLineFractions.map { $0 * Double(height) }
        let space = (lines[4] - lines[0]) / 4
        guard space >= 4, space < Double(height) * 0.03, lines.allSatisfy(\.isFinite),
              zip(lines, lines.dropFirst()).allSatisfy({ $0 < $1 }),
              found.estimatedSkewDegrees.isFinite else { return reject("Staff geometry or resolution is uncertain") }
        let slope = tan(found.estimatedSkewDegrees * .pi / 180)
        let left = max(0, Int(ceil(band.minX * Double(width))))
        let right = min(width - 1, Int(floor(band.maxX * Double(width))) - 1)
        let top = max(0, Int(floor(band.minY * Double(height))))
        // Pixel rows are half-open intervals. Including ceil(maxY) itself
        // would inspect one complete row beyond the user's visible crop.
        let bottom = min(height - 1, Int(ceil(band.maxY * Double(height))) - 1)
        guard right > left, bottom > top else { return reject("Empty band") }
        func black(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < width && y >= 0 && y < height && pixels[y * width + x] < 170
        }
        // Follow modest scan curvature without changing the staff-line phase.
        let tile = max(24, Int(space * 5))
        let maxOffset = max(2, Int((space * 0.35).rounded()))
        var offsets = [Double](repeating: 0, count: width)
        var anchors: [(x: Int, offset: Double)] = []
        for x in stride(from: left, through: right, by: tile) {
            if isCancelled() { return nil }
            var bestOffset = 0, bestScore = -1
            let x0 = max(left, x - tile / 2), x1 = min(right, x + tile / 2)
            for offset in -maxOffset...maxOffset {
                var score = 0
                for column in stride(from: x0, through: x1, by: 2) {
                    for line in lines {
                        let y = Int((line + slope * (Double(column) - Double(width) / 2)).rounded()) + offset
                        if black(column, y) { score += 2 }
                        if black(column, y - 1) || black(column, y + 1) { score += 1 }
                    }
                }
                if score > bestScore || (score == bestScore && abs(offset) < abs(bestOffset)) {
                    bestScore = score; bestOffset = offset
                }
            }
            anchors.append((x, Double(bestOffset)))
        }
        var anchorIndex = 0
        for x in left...right {
            while anchorIndex + 1 < anchors.count && anchors[anchorIndex + 1].x < x { anchorIndex += 1 }
            let a = anchors[anchorIndex], b = anchors[min(anchorIndex + 1, anchors.count - 1)]
            let fraction = b.x == a.x ? 0 : Double(x - a.x) / Double(b.x - a.x)
            offsets[x] = a.offset + (b.offset - a.offset) * fraction
        }
        let localHeight = bottom - top + 1
        var ink = [Bool](repeating: false, count: width * localHeight)
        for x in left...right {
            let shift = slope * (Double(x) - Double(width) / 2) + offsets[x]
            for row in 0..<localHeight {
                let y = Int((Double(top + row) + shift).rounded())
                ink[row * width + x] = y >= top && y <= bottom && black(x, y)
            }
        }
        var localLines = lines.map { $0 - Double(top) }
        func value(_ x: Int, _ y: Int) -> Bool {
            x >= left && x <= right && y >= 0 && y < localHeight && ink[y * width + x]
        }
        let radius = max(1, Int((space * 0.22).rounded()))
        var lineSupport: [Int] = []
        for x in left...right {
            let supported = localLines.filter { line in
                (-radius...radius).contains { offset in
                    let y = Int(line.rounded()) + offset
                    guard value(x, y) else { return false }
                    // A piano brace can cross all five expected line heights.
                    // The staff itself must continue horizontally from here.
                    let length = max(4, Int(space * 2))
                    return [-1, 1].contains { direction in
                        (1...length).filter { value(x + direction * $0, y) }.count >= Int(Double(length) * 0.8)
                    }
                }
            }.count
            if supported >= 4 { lineSupport.append(x) }
        }
        guard let staffLeft = lineSupport.first, let staffRight = lineSupport.last,
              Double(staffRight - staffLeft) > space * 12 else { return reject("Staff extent unclear") }
        // Deskew resampling can move the dark center of one line by a pixel
        // relative to the five-line pattern fit. Refine that analysis phase
        // using rows supported across the staff, rather than erasing a wider
        // neighborhood that could hide small noteheads or other notation.
        for index in localLines.indices {
            let expected = Int(localLines[index].rounded())
            let rowSupport = (-maxOffset...maxOffset).map { offset -> (row: Int, count: Int) in
                let row = expected + offset
                return (row, stride(from: staffLeft, through: staffRight, by: 2).filter { value($0, row) }.count)
            }
            if let peak = rowSupport.map(\.count).max(), peak > 0 {
                let strongest = rowSupport.filter { Double($0.count) >= Double(peak) * 0.85 }
                let total = strongest.reduce(0) { $0 + $1.count }
                if total > 0 {
                    localLines[index] = Double(strongest.reduce(0) { $0 + $1.row * $1.count }) / Double(total)
                }
            }
        }
        var columns: [Int] = []
        let coreTop = Int(localLines[0].rounded()), coreBottom = Int(localLines[4].rounded())
        for x in staffLeft...staffRight {
            let count = (coreTop...coreBottom).filter { value(x, $0) }.count
            // Staff-line pixels can make a tall accidental look almost as
            // continuous as a barline after deskew interpolation. A real
            // spanning bar also crosses every space between those lines.
            let crossesEverySpace = zip(localLines, localLines.dropFirst()).allSatisfy { a, b in
                let middle = Int(((a + b) / 2).rounded())
                return (-1...1).contains { value(x, middle + $0) }
            }
            if Double(count) / Double(coreBottom - coreTop + 1) >= 0.79 && crossesEverySpace { columns.append(x) }
        }
        var strokes: [Boundary] = []
        let strokeGap = max(1, Int(space * 0.15))
        for x in columns {
            if let last = strokes.last, x - last.right <= strokeGap + 1 { strokes[strokes.count - 1].right = x }
            else { strokes.append(Boundary(left: x, right: x)) }
        }
        var boundaries: [Boundary] = []
        for stroke in strokes {
            if let last = boundaries.last, Double(stroke.left - last.right) < space * 0.8 {
                boundaries[boundaries.count - 1].right = stroke.right
            } else { boundaries.append(stroke) }
        }
        // A treble-clef stem can resemble a barline, but lies immediately after
        // the true opening edge, within the preserved clef/key prefix.
        boundaries = boundaries.filter { $0.center <= Double(staffLeft) + space * 0.9 || $0.center >= Double(staffLeft) + space * 4.5 }
        guard let first = boundaries.first, let last = boundaries.last,
              first.center - Double(staffLeft) <= space,
              Double(staffRight) - last.center <= space,
              (3...1000).contains(boundaries.count) else { return reject("Complete bar boundaries not found: \(boundaries.count)") }
        for boundary in boundaries.dropFirst().dropLast() where Double(boundary.right - boundary.left) > space * 0.45 {
            return reject("Interior double/thick barline")
        }
        for pair in zip(boundaries, boundaries.dropFirst()) where pair.1.center - pair.0.center < space * 4 {
            return reject("Measure too narrow or extra vertical notation")
        }
        // Erase only the five staff lines and true barline columns in the
        // analysis copy. All remaining substantial ink must be accounted for.
        for x in staffLeft...staffRight {
            for line in localLines {
                let y = Int(line.rounded())
                for offset in -radius...radius where y + offset >= 0 && y + offset < localHeight {
                    ink[(y + offset) * width + x] = false
                }
            }
        }
        for boundary in boundaries {
            for x in max(left, boundary.left - 1)...min(right, boundary.right + 1) {
                for row in max(0, coreTop - radius)...min(localHeight - 1, coreBottom + radius) { ink[row * width + x] = false }
            }
        }
        var components: [Component] = []
        for row in 0..<localHeight {
            if isCancelled() { return nil }
            for x in staffLeft...staffRight where ink[row * width + x] {
                var queue = [row * width + x], head = 0
                ink[row * width + x] = false
                var box = Component(left: x, top: row, right: x, bottom: row, area: 0)
                while head < queue.count {
                    let index = queue[head]; head += 1
                    let px = index % width, py = index / width
                    box.left = min(box.left, px); box.right = max(box.right, px)
                    box.top = min(box.top, py); box.bottom = max(box.bottom, py); box.area += 1
                    for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = px + dx, ny = py + dy
                        if nx >= staffLeft && nx <= staffRight && ny >= 0 && ny < localHeight && ink[ny * width + nx] {
                            ink[ny * width + nx] = false; queue.append(ny * width + nx)
                        }
                    }}
                }
                guard Double(box.area) >= max(2, space * space * 0.035) else { continue }
                let centerY = Double(box.top + box.bottom) / 2
                let onLine = localLines.contains { abs($0 - centerY) < space * 0.28 }
                if onLine && box.width >= space * 0.35 && box.height <= space * 0.22 { continue }
                // Scanned lines sometimes have tiny attached ink spurs. Keep
                // detached dots and larger glyphs: a spur must be both very
                // small and continuously connected to an identified line in
                // the original raster, not just close to its expected row.
                if box.width <= space * 0.3 && box.height <= space * 0.3
                    && Double(box.area) <= space * space * 0.06,
                   let line = localLines.min(by: { abs($0 - centerY) < abs($1 - centerY) }),
                   abs(line - centerY) <= space * 0.5 {
                    let x = (box.left + box.right) / 2
                    let shift = slope * (Double(x) - Double(width) / 2) + offsets[x]
                    let lineRow = Int(line.rounded()), objectRow = Int(centerY.rounded())
                    let attached = (min(lineRow, objectRow)...max(lineRow, objectRow)).allSatisfy { row in
                        black(x, Int((Double(top + row) + shift).rounded()))
                    }
                    if attached { continue }
                }
                let barTail = boundaries.contains { bar in
                    // A scanned connecting bar may drift sideways by a pixel
                    // where it enters the staff. Require physical overlap and
                    // the same narrow stroke width; do not discard adjacent
                    // symbols merely because they are near a barline.
                    let drift = max(1, Int((space * 0.2).rounded()))
                    return box.left <= bar.right && box.right >= bar.left
                        && box.width <= Double(bar.right - bar.left + 3)
                        && box.left >= bar.left - drift && box.right <= bar.right + drift
                        && ((box.top < coreTop - radius && box.bottom >= coreTop - radius - 1)
                            || (box.bottom > coreBottom + radius && box.top <= coreBottom + radius + 1))
                }
                if barTail { continue }
                components.append(box)
            }
        }
        func isRest(_ box: Component) -> Bool {
            let restTop = (Double(box.top) - localLines[0]) / space
            let restBottom = (Double(box.bottom + 1) - localLines[0]) / space
            return box.width >= space * 0.7 && box.width <= space * 2.3
                && box.height >= 1 && box.height <= space * 0.65
                && box.width >= box.height * 1.5
                && Double(box.area) / (box.width * box.height) >= 0.58
                && restTop >= 0.88 && restTop <= 1.48 && restBottom <= 1.92
                && (restTop + restBottom) / 2 <= 1.62
        }
        // A nearby glyph is not automatically a clef/key signature: a first
        // sounding note can sit directly against the signature. Establish a
        // recognizable clef before retaining the body of an opening prefix.
        // G-clef upper and lower curls straddle the staff; an F clef has its
        // characteristic pair of dots beside a larger curved body.
        func openingClefRight(_ body: [Component]) -> Double? {
            let upper = body.filter { Double($0.top) < localLines[0] - space * 0.65
                && Double($0.bottom) > localLines[0] - space * 2.5
                && $0.width >= space * 0.6 && $0.width <= space * 3
                && Double($0.left) < Double(staffLeft) + space * 5 }
            let lower = body.filter { Double($0.bottom) > localLines[4] + space * 0.65
                && Double($0.top) < localLines[4] + space * 2.5
                && $0.width >= space * 0.6 && $0.width <= space * 3
                && Double($0.left) < Double(staffLeft) + space * 5 }
            let curls = upper.flatMap { a in lower.compactMap { b -> Double? in
                guard min(a.right, b.right) >= max(a.left, b.left),
                      Double(max(a.right, b.right) - min(a.left, b.left)) <= space * 3 else { return nil }
                return Double(max(a.right, b.right)) + space * 0.7
            }}
            if let right = curls.min() { return right }
            let dots = body.filter { $0.width >= space * 0.2 && $0.width <= space * 0.65
                && $0.height >= space * 0.2 && $0.height <= space * 0.65 }
            for a in dots {
                let ay = Double(a.top + a.bottom) / 2
                guard abs(ay - (localLines[0] + space * 0.5)) < space * 0.3 else { continue }
                for b in dots {
                    let by = Double(b.top + b.bottom) / 2
                    guard abs(by - (localLines[0] + space * 1.5)) < space * 0.3,
                          abs(Double(a.left + a.right - b.left - b.right) / 2) < space * 0.3,
                          Double(a.right) < Double(staffLeft) + space * 6 else { continue }
                    let curve = body.filter { $0.right < a.left && Double($0.left) > Double(a.left) - space * 3
                        && Double($0.top) >= localLines[0] - space * 0.5
                        && Double($0.bottom) <= localLines[0] + space * 3 }
                    guard curve.contains(where: { $0.width >= space * 0.7 }),
                          curve.contains(where: { Double($0.bottom) > localLines[0] + space * 2 }) else { continue }
                    return Double(max(a.right, b.right)) + space * 0.4
                }
            }
            return nil
        }
        // Orchestral scores align the meter across transposing instruments.
        // A keyless clarinet may therefore have a large blank gap before C.
        // Recognize that specific open-right meter shape instead of treating
        // arbitrary ink after a long gap as another part of the signature.
        func openingCommonTimeRight(_ body: [Component], after clefRight: Double) -> Double? {
            let eligible = body.filter { Double($0.left) > clefRight
                && Double($0.top) >= localLines[1] - space * 0.35
                && Double($0.bottom) <= localLines[3] + space * 0.35 }.sorted { $0.left < $1.left }
            var groups: [[Component]] = []
            for component in eligible {
                if let previous = groups.last, let right = previous.map(\.right).max(),
                   Double(component.left - right) < space * 0.65 {
                    groups[groups.count - 1].append(component)
                } else { groups.append([component]) }
            }
            for group in groups {
                let x0 = group.map(\.left).min()!, x1 = group.map(\.right).max()!
                let y0 = group.map(\.top).min()!, y1 = group.map(\.bottom).max()!
                let glyphWidth = Double(x1 - x0 + 1)
                guard glyphWidth >= space * 1.2, glyphWidth <= space * 2.3,
                      Double(y0) <= localLines[1] + space * 0.4,
                      Double(y1) >= localLines[3] - space * 0.4 else { continue }
                func density(_ left: Double, _ right: Double, _ upper: Double, _ lower: Double) -> Double {
                    var dark = 0, samples = 0
                    for row in Int(ceil(localLines[0] + upper * space))...Int(floor(localLines[0] + lower * space)) {
                        // Measure actual glyph ink, excluding the five staff lines.
                        if localLines.contains(where: { abs(Double(row) - $0) <= Double(radius) }) { continue }
                        for x in Int(ceil(Double(x0) + left * glyphWidth))...Int(floor(Double(x0) + right * glyphWidth)) {
                            let shift = slope * (Double(x) - Double(width) / 2) + offsets[x]
                            if black(x, Int((Double(top + row) + shift).rounded())) { dark += 1 }
                            samples += 1
                        }
                    }
                    return samples > 0 ? Double(dark) / Double(samples) : 0
                }
                guard density(0, 0.4, 1.35, 2.65) > 0.5,
                      density(0.55, 0.78, 2.05, 2.35) < 0.15,
                      density(0.65, 0.95, 1.15, 1.6) > 0.2,
                      density(0.65, 0.95, 2.4, 2.85) > 0.1 else { continue }
                return Double(x1)
            }
            return nil
        }
        func prefixContainsSoundingGlyph(after clefRight: Double, through end: Double) -> Bool {
            let x0 = max(staffLeft, Int(ceil(clefRight))), x1 = min(staffRight, Int(ceil(end)))
            guard x1 > x0 else { return false }
            let w = x1 - x0 + 1
            var bits = [Bool](repeating: false, count: w * localHeight)
            for x in x0...x1 {
                let shift = slope * (Double(x) - Double(width) / 2) + offsets[x]
                func raw(_ row: Int) -> Bool {
                    let y = Int((Double(top + row) + shift).rounded())
                    return y >= top && y <= bottom && black(x, y)
                }
                for row in 0..<localHeight where raw(row) {
                    if let line = localLines.first(where: { abs(Double(row) - $0) <= Double(radius) }) {
                        let y = Int(line.rounded())
                        let crossesLine = raw(y - radius - 1) && raw(y + radius + 1)
                        let shaftLength = max(2, Int(space * 0.8))
                        let continuesIntoLine = [-1, 1].contains { direction in
                            let supported = (1...shaftLength).filter {
                                raw(y + direction * (radius + $0))
                            }.count
                            return Double(supported) >= Double(shaftLength) * 0.85
                        }
                        // A stem may start on a staff line, so also preserve
                        // a sustained vertical stroke approaching one side.
                        guard crossesLine || continuesIntoLine else { continue }
                    }
                    bits[row * w + x - x0] = true
                }
            }
            // Unlike the rest-count mask, keep glyph pixels crossing a staff
            // line when ink continues above and below it. This reconstructs
            // hollow heads and stems that a blanket line erasure would split.
            let clean = bits
            func pixel(_ x: Int, _ y: Int) -> Bool {
                x >= x0 && x <= x1 && y >= 0 && y < localHeight && clean[y * w + x - x0]
            }
            var glyphs: [Component] = []
            for row in 0..<localHeight { for column in 0..<w where bits[row * w + column] {
                var queue = [row * w + column], head = 0
                bits[row * w + column] = false
                var box = Component(left: column + x0, top: row, right: column + x0, bottom: row, area: 0)
                while head < queue.count {
                    let i = queue[head]; head += 1
                    let x = i % w, y = i / w
                    box.left = min(box.left, x + x0); box.right = max(box.right, x + x0)
                    box.top = min(box.top, y); box.bottom = max(box.bottom, y); box.area += 1
                    for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        if nx >= 0 && nx < w && ny >= 0 && ny < localHeight && bits[ny * w + nx] {
                            bits[ny * w + nx] = false; queue.append(ny * w + nx)
                        }
                    }}
                }
                if box.area >= 3 { glyphs.append(box) }
            }}
            func density(_ xa: Double, _ xb: Double, _ ya: Double, _ yb: Double) -> Double {
                let left = Int(ceil(xa)), right = Int(floor(xb)), top = Int(ceil(ya)), bottom = Int(floor(yb))
                guard right >= left, bottom >= top else { return 0 }
                var amount = 0
                for y in top...bottom { for x in left...right where pixel(x, y) { amount += 1 } }
                return Double(amount) / Double((right - left + 1) * (bottom - top + 1))
            }
            func touchesStaffBody(_ glyph: Component) -> Bool {
                Double(glyph.bottom) >= localLines[0] - space * 0.7
                    && Double(glyph.top) <= localLines[4] + space * 0.7
            }
            // A hollow head between two staff lines may lose both horizontal
            // arcs where they coincide with those lines. Its two remaining
            // side arcs still form a single short, wide glyph. Treat the pair
            // as uncertain notation rather than two harmless tiny fragments.
            for (index, a) in glyphs.enumerated() where a.height <= space * 1.3 && touchesStaffBody(a) {
                for b in glyphs.dropFirst(index + 1) where b.height <= space * 1.3 && touchesStaffBody(b) {
                    let combinedWidth = Double(max(a.right, b.right) - min(a.left, b.left) + 1)
                    let combinedHeight = Double(max(a.bottom, b.bottom) - min(a.top, b.top) + 1)
                    let gap = Double(max(a.left, b.left) - min(a.right, b.right) - 1)
                    let centerDifference = abs(Double(a.top + a.bottom - b.top - b.bottom) / 2)
                    if combinedWidth >= space * 0.75 && combinedWidth <= space * 2.5
                        && combinedHeight <= space * 1.3 && gap >= 0 && gap <= space * 1.4
                        && centerDifference <= space * 0.35 {
                        // A scanned flat may leave two pieces of its loop.
                        // Both must sit beside the same taller stem on their
                        // left; an isolated hollow head has no such parent.
                        let hasParent = glyphs.contains { parent in
                            parent.height >= space * 1.5 && Double(parent.right - min(a.right, b.right)) <= space * 0.2
                                && Double(max(a.left, b.left) - parent.right) <= space * 0.4
                                && min(a.top, b.top) >= parent.top
                                && max(a.bottom, b.bottom) <= parent.bottom + Int(space * 0.4)
                        }
                        if !hasParent { return true }
                    }
                }
            }
            // Short isolated horizontal glyphs can be whole notes. Detached
            // flat/meter fragments are allowed only immediately beside the
            // taller parent glyph, not merely anywhere in the prefix.
            for box in glyphs where box.width >= space * 0.75 {
                if box.height <= space * 1.3 && touchesStaffBody(box) {
                    let attachesLeft = glyphs.contains { other in
                        other.height >= space * 1.7 && other.right < box.left
                            && Double(box.left - other.right) <= space * 0.4
                            && box.top >= other.top && box.bottom <= other.bottom + Int(space * 0.3)
                    }
                    if !attachesLeft { return true }
                }
                // A complete note can lie beyond the staff, including a stem
                // pointing farther outward. Check the entire retained region;
                // short ledger strokes at extended staff-line positions are
                // not ordinary tempo-letter fragments.
                if box.height <= space * 1.3 && !touchesStaffBody(box) {
                    for row in box.top...box.bottom {
                        let phase = (Double(row) - localLines[0]) / space
                        guard abs(phase - phase.rounded()) <= 0.25 else { continue }
                        var run = 0
                        for x in box.left...box.right {
                            run = pixel(x, row) ? run + 1 : 0
                            if Double(run) >= space * 1.4 { return true }
                        }
                    }
                }
                // An up-stem note has its head to the left at the bottom;
                // a down-stem note has its head to the right at the top. A
                // flat's loop lies on the other side; C/natural/sharp shapes
                // carry ink at both ends instead of one isolated notehead.
                if box.height >= space * 2 && box.height <= space * 5 {
                    for stemX in box.left...box.right {
                        let upCoverage = density(Double(stemX), Double(stemX), Double(box.top), Double(box.bottom) - space * 0.7)
                        if upCoverage >= 0.78 && Double(stemX - box.left) >= space * 0.6 {
                            let head = density(Double(stemX) - space * 0.8, Double(stemX) - space * 0.2,
                                               Double(box.bottom) - space * 0.8, Double(box.bottom))
                            let tail = density(Double(stemX) - space * 0.8, Double(stemX) - space * 0.2,
                                               Double(box.top), Double(box.top) + space * 0.8)
                            if head > 0.3 && tail < 0.18 { return true }
                        }
                        let downCoverage = density(Double(stemX), Double(stemX), Double(box.top) + space * 0.7, Double(box.bottom))
                        if downCoverage >= 0.78 && Double(box.right - stemX) >= space * 0.6 {
                            let head = density(Double(stemX) + space * 0.2, Double(stemX) + space * 0.8,
                                               Double(box.top), Double(box.top) + space * 0.8)
                            let tail = density(Double(stemX) + space * 0.2, Double(stemX) + space * 0.8,
                                               Double(box.bottom) - space * 0.8, Double(box.bottom))
                            if head > 0.3 && tail < 0.18 { return true }
                        }
                    }
                }
            }
            return false
        }

        var rests: [Component] = []
        var prefixRight = Double(staffLeft) + space * 4.5
        for measure in 0..<(boundaries.count - 1) {
            let a = boundaries[measure], b = boundaries[measure + 1]
            let objects = components.filter { Double($0.right) > a.center && Double($0.left) < b.center }
            var openingBodyRight = Double(staffLeft)
            if measure == 0 {
                // A scanned score's system edge may stand farther from the
                // clef than ordinary inter-glyph spacing. Seed the signature
                // from verified clef geometry, not an arbitrary left margin.
                if let clefRight = openingClefRight(objects) {
                    openingBodyRight = max(openingBodyRight, clefRight - space * 0.7)
                    if let commonTimeRight = openingCommonTimeRight(objects, after: clefRight) {
                        openingBodyRight = max(openingBodyRight, commonTimeRight)
                    }
                }
                let body = objects.filter { Double($0.bottom) >= localLines[0] - space * 0.7
                    && Double($0.top) <= localLines[4] + space * 0.7 }.sorted { $0.left < $1.left }
                for object in body {
                    guard Double(object.left) <= openingBodyRight + space * 1.6 else { break }
                    openingBodyRight = max(openingBodyRight, Double(object.right))
                }
            }
            let candidates = objects.filter { isRest($0) && (measure != 0 || Double($0.left) > openingBodyRight + space * 0.5) }
            guard candidates.count == 1, let rest = candidates.first else {
                return reject("Measure \(measure + 1): \(candidates.count) rests, objects \(objects.map { [Double($0.left), Double($0.top), $0.width, $0.height, Double($0.area)] })")
            }
            let centerX = Double(rest.left + rest.right) / 2
            guard centerX > a.center + space && centerX < b.center - space else { return reject("Rest on a measure edge") }
            let extra = objects.filter { $0.left != rest.left || $0.top != rest.top || $0.right != rest.right || $0.bottom != rest.bottom }
            if measure == 0 {
                let allowedRight = Double(rest.left) - space * 0.7
                guard extra.allSatisfy({ object in
                    let inBody = Double(object.bottom) >= localLines[0] - space * 0.7
                        && Double(object.top) <= localLines[4] + space * 0.7
                    return Double(object.right) < allowedRight
                        && (!inBody || Double(object.right) <= openingBodyRight)
                }) else {
                    return reject("Unknown first-measure ink: \(extra.map { [Double($0.left), Double($0.top), $0.width, $0.height] })")
                }
                let body = extra.filter { Double($0.bottom) >= localLines[0] - space * 0.7
                    && Double($0.top) <= localLines[4] + space * 0.7 }
                if !body.isEmpty {
                    // Include the outside curls when validating the clef, but
                    // ignore isolated tempo words above its musical body.
                    guard let clefRight = openingClefRight(extra) else { return reject("Opening clef is uncertain") }
                    let contextRight = Double(extra.map(\.right).max() ?? staffLeft)
                    guard !prefixContainsSoundingGlyph(after: clefRight, through: contextRight) else {
                        return reject("Possible sounding glyph in opening signature")
                    }
                    let noteHead = body.contains { object in
                        Double(object.left) > clefRight && object.width >= space * 1.25
                            && object.height <= space * 0.85
                            && Double(object.area) / (object.width * object.height) >= 0.5
                    }
                    guard !noteHead else { return reject("Possible sounding note in opening signature") }
                }
                prefixRight = max(Double(staffLeft) + space * 3, Double(extra.map(\.right).max() ?? staffLeft) + space * 0.7)
                guard prefixRight < Double(rest.left) - space * 0.7 else { return reject("Prefix touches first rest") }
            } else if !extra.isEmpty {
                return reject("Measure \(measure + 1): extra ink \(extra.map { [Double($0.left), Double($0.top), $0.width, $0.height, Double($0.area)] })")
            }
            rests.append(rest)
        }
        // Ink outside the counted staff span (other than the left label and
        // right boundary fragments retained verbatim) is not silently omitted.
        let suffixLeft = max(prefixRight, Double(last.left) - space * 0.7)
        let prefix = CGRect(x: band.minX, y: band.minY,
            width: prefixRight / Double(width) - band.minX, height: band.height)
        let suffix = CGRect(x: suffixLeft / Double(width), y: band.minY,
            width: band.maxX - suffixLeft / Double(width), height: band.height)
        let restBounds = rests.map { box -> CGRect in
            let x = Double(box.left + box.right) / 2
            let shift = slope * (x - Double(width) / 2) + offsets[min(width - 1, max(0, Int(x)))]
            return CGRect(x: Double(box.left) / Double(width), y: (Double(top + box.top) + shift) / Double(height),
                          width: box.width / Double(width), height: box.height / Double(height))
        }
        guard !isCancelled() else { return nil }
        let ordinaryClosingBar = Double(last.right - last.left + 1) <= space * 0.45
        let hasClosingInstruction = (min(right, last.right + 2)...right).contains { x in
            (top...bottom).contains { black(x, $0) }
        }
        diagnostic?("Matched \(rests.count) complete whole-bar rests")
        return Detection(barCount: rests.count, staffLineFractions: staff.staffLineFractions,
            skewDegrees: found.estimatedSkewDegrees, staffLeftFraction: Double(staffLeft) / Double(width),
            staffRightFraction: Double(staffRight) / Double(width), prefixBounds: prefix,
            suffixBounds: suffix, restBounds: restBounds,
            canExtendThroughFollowingRests: ordinaryClosingBar && !hasClosingInstruction,
            boundaryFractions: boundaries.map { $0.center / Double(width) })
    }
}
