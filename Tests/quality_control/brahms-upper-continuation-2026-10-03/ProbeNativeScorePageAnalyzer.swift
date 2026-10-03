import CoreGraphics
import Foundation
import PDFKit

/// Native offline PDF rendering shared by the app and batch inventory. Fractions
/// describe the supplied image; unrectified PDF pages map directly to PDF points.
enum ProbeNativeScorePageAnalyzer {
    static func render(_ page: PDFPage, maximumWidth: Int = 1800, maximumHeight: Int = 2600) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = min(CGFloat(maximumWidth) / bounds.width, CGFloat(maximumHeight) / bounds.height)
        let width = max(1, Int((bounds.width * scale).rounded()))
        let height = max(1, Int((bounds.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: CGFloat(width) / bounds.width, y: CGFloat(height) / bounds.height)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    static func analyze(pageIndex: Int, image: CGImage, pageWidth: Double, pageHeight: Double,
                        isCancelled: () -> Bool = { false }) -> ScorePageAnalysis {
        let detected = StaffBandDetector.detect(in: image, isCancelled: isCancelled)
        let ink = notationComponents(image: image, candidates: detected.candidates,
                                     skewDegrees: detected.estimatedSkewDegrees, isCancelled: isCancelled)
        return ScorePageAnalysis(pageIndex: pageIndex, pageWidth: pageWidth, pageHeight: pageHeight,
            imageWidth: image.width, imageHeight: image.height, staves: detected.candidates.map(ScoreObservedStaff.init), warnings: detected.warnings, analysisSkewDegrees: detected.estimatedSkewDegrees,
            inkComponents: ink)
    }

    /// Separate analysis-only staff lines and thin inter-staff barline connectors
    /// before measuring outward notation reach. Original source pixels are never
    /// modified, and components touching more than one staff remain ambiguous.
    static func notationComponents(image: CGImage, candidates: [StaffBandCandidate], skewDegrees: Double,
                                   isCancelled: () -> Bool = { false }, retainMusicalEvidence: Bool = true) -> [ScoreInkComponent]? {
        guard !isCancelled() else { return nil }
        guard !candidates.isEmpty else { return [] }
        let factor = min(1, 1800.0 / Double(image.width), 2600.0 / Double(image.height))
        let width = max(1, Int((Double(image.width) * factor).rounded()))
        let height = max(1, Int((Double(image.height) * factor).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pointer = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let raw = UnsafeBufferPointer(start: pointer, count: width * height)
        var ink = raw.map { $0 < 190 }
        let original = ink
        Trace.saveMask(original,width:width,height:height,phase:retainMusicalEvidence ? "original-musical":"original-structural")
        let ordered = candidates.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
        let lines = ordered.map { $0.staffLineFractions.map { $0 * Double(height) } }
        let spaces = lines.map { ($0[4] - $0[0]) / 4 }
        let slope = tan(skewDegrees * .pi / 180)
        // Braces can sit well inside the page margins, so use the actual start
        // of sustained staff-line ink rather than a page-width heuristic.
        var lineStarts = [Int](repeating: 0, count: lines.count)
        for (index, staff) in lines.enumerated() {
            let requiredRun = max(6, Int((spaces[index] * 4).rounded()))
            var run = 0
            for x in 0..<width {
                var votes = 0
                for line in staff {
                    let y = Int((line + slope * (Double(x) - Double(width) / 2)).rounded())
                    for dy in -1...1 where y + dy >= 0 && y + dy < height {
                        if original[(y + dy) * width + x] { votes += 1; break }
                    }
                }
                run = votes >= 3 ? run + 1 : 0
                if run >= requiredRun { lineStarts[index] = x - run + 1; break }
            }
        }
        for (index, staff) in lines.enumerated() {
            if isCancelled() { return nil }
            // A minimum three-row strip can erase whole notehead attachments
            // when staff spaces are only 3–5 pixels. Use one row at that scale.
            let thickness = max(0, Int((spaces[index] * 0.09).rounded()))
            for line in staff {
                for x in 0..<width {
                    let y = Int((line + slope * (Double(x) - Double(width) / 2)).rounded())
                    let above = min(height - 1, max(0, y - thickness - 1))
                    let below = min(height - 1, max(0, y + thickness + 1))
                    // Crossing stems remain connected; isolated line pixels do not.
                    if original[above * width + x] && original[below * width + x] { continue }
                    for dy in -thickness...thickness where y + dy >= 0 && y + dy < height {
                        ink[(y + dy) * width + x] = false
                    }
                }
            }
        }
        Trace.saveMask(ink,width:width,height:height,phase:retainMusicalEvidence ? "staff-erased-musical":"staff-erased-structural")
        Trace.emit("staff-geometry",["musical":retainMusicalEvidence,"lines":lines,"spaces":spaces,"lineStarts":lineStarts])
        var preservedMusicalConnection = false
        if lines.count > 1 {
            for index in 0..<(lines.count - 1) {
                if isCancelled() { return nil }
                let space = min(spaces[index], spaces[index + 1])
                let start = max(0, Int((lines[index][4] + space * 0.6).rounded()))
                let end = min(height, Int((lines[index + 1][0] - space * 0.6).rounded()))
                guard Double(end - start) >= space else { continue }
                // The support halo tolerates a slanted or interrupted scan
                // stroke. Its pixels are evidence-search padding, not part of
                // the structural stroke's measured width.
                let supportRadius = 2
                let supportHalo = 2 * supportRadius
                var occupancy = [Int](repeating: 0, count: width)
                var directOccupancy = [Int](repeating: 0, count: width)
                for y in start..<end {
                    for x in 0..<width {
                        if original[y * width + x] { directOccupancy[x] += 1 }
                        if (-supportRadius...supportRadius).contains(where: { dx in
                            let column = x + dx
                            return column >= 0 && column < width && original[y * width + column]
                        }) { occupancy[x] += 1 }
                    }
                }
                var connectors: [(left: Int, right: Int, strokes: Int)] = []
                var x = 0
                while x < width {
                    if Double(occupancy[x]) <= Double(end - start) * 0.8 { x += 1; continue }
                    let left = x
                    while x < width && Double(occupancy[x]) > Double(end - start) * 0.8 { x += 1 }
                    // A bracket and its adjacent thin system line, or a double
                    // barline, are one structural connector. Processing the
                    // strokes separately makes each look like a horizontal
                    // notation branch of the other, so neither gets separated.
                    if let previous = connectors.last, previous.strokes == 1,
                       Double(max(1, previous.right - previous.left - supportHalo)) < space * 1.8,
                       Double(max(1, x - left - supportHalo)) < space * 1.8,
                       Double(left - previous.right) <= max(3, space * 0.25),
                       Double(max(1, x - previous.left - supportHalo)) < space * 2.25 {
                        connectors[connectors.count - 1] = (previous.left, x, 2)
                    } else {
                        connectors.append((left, x, 1))
                    }
                }
                for connector in connectors {
                    let left = connector.left, x = connector.right
                    // A pair may be wider than one stroke, but each stroke is
                    // independently thin and almost touches its partner. Never
                    // accumulate a chain of strokes into a wide notation group.
                    // Both staff cores and the near-continuous gap still have
                    // to support the connector; partial-core musical stems do
                    // not qualify just because two of them stand close together.
                    // At the lower resolution of a corrected display raster,
                    // two separated strokes can have overlapping support halos
                    // and appear as one wide run. Recover a pair only from two
                    // distinct, sustained peaks in the undilated source ink.
                    // The 60% peak support classifies the shape; the original
                    // 80% gap continuity and 88% core support still gate removal.
                    var physicalStrokes: [(left: Int, right: Int)] = []
                    var column = max(0, left - supportRadius)
                    let lastColumn = min(width, x + supportRadius)
                    while column < lastColumn {
                        if Double(directOccupancy[column]) < Double(end - start) * 0.60 { column += 1; continue }
                        let strokeLeft = column
                        while column < lastColumn && Double(directOccupancy[column]) >= Double(end - start) * 0.60 { column += 1 }
                        physicalStrokes.append((strokeLeft, column))
                    }
                    let mergedPair = physicalStrokes.count == 2
                        && physicalStrokes.allSatisfy { Double($0.right - $0.left) < space * 1.8 }
                        && Double(physicalStrokes[1].left - physicalStrokes[0].right) <= max(3, space * 0.25) + Double(supportHalo)
                        && Double(physicalStrokes[1].right - physicalStrokes[0].left) < space * 2.25
                    let maximumWidth = space * (connector.strokes == 2 || mergedPair ? 2.25 : 1.8)
                    if Double(max(1, x - left - supportHalo)) < maximumWidth {
                        let clearLeft = max(0, left - supportRadius), clearRight = min(width, x + supportRadius)
                        let localShift = slope * (Double(clearLeft + clearRight) / 2 - Double(width) / 2)
                        let throughBothCores = [index, index + 1].allSatisfy { staffIndex in
                            let coreTop = min(height, max(0, Int((lines[staffIndex][0] + localShift).rounded())))
                            let coreBottom = max(0, min(height, Int((lines[staffIndex][4] + localShift).rounded()) + 1))
                            guard coreTop < coreBottom else { return false }
                            var rows = 0
                            for y in coreTop..<coreBottom {
                                if (clearLeft..<clearRight).contains(where: { original[y * width + $0] }) { rows += 1 }
                            }
                            return Double(rows) >= Double(coreBottom - coreTop) * 0.88
                        }
                        if index == 0 { Trace.emit("connector",["musical":retainMusicalEvidence,"left":left,"right":x,"clear":[clearLeft,clearRight],"physicalStrokes":physicalStrokes.map{[$0.left,$0.right]},"cores":throughBothCores,"start":start,"end":end,"space":space,"localShift":localShift]) }
                        // Local page curl can move all five
                        // staff lines away from their page-center estimates. Only
                        // sustained horizontal ink at every predicted line can
                        // translate the core used for this connector check.
                        // The original 88% core support threshold is unchanged.
                        func connectorProof(_ staffIndex: Int, _ shift: Double) -> Bool {
                            let top = max(0, Int((lines[staffIndex][0] + shift).rounded()))
                            let bottom = min(height, Int((lines[staffIndex][4] + shift).rounded()) + 1)
                            guard top < bottom else { return false }
                            let supported = (top..<bottom).filter { y in
                                (clearLeft..<clearRight).contains { original[y * width + $0] }
                            }.count
                            guard Double(supported) >= Double(bottom - top) * 0.88 else { return false }
                            let radius = max(2, Int((spaces[staffIndex] * 0.18).rounded()))
                            return lines[staffIndex].enumerated().allSatisfy { lineIndex, line in
                                let center = Int((line + shift).rounded())
                                let lower = lineIndex == 0 ? 0 : -radius
                                let upper = lineIndex == 4 ? 0 : radius
                                return (-1...1).contains { rounding in
                                    (clearLeft..<clearRight).contains { column in
                                        (lower...upper).allSatisfy { delta in
                                            let row = center + rounding + delta
                                            return row >= 0 && row < height && original[row * width + column]
                                        }
                                    }
                                }
                            }
                        }
                        func localCoreShift(_ staffIndex: Int) -> Double? {
                            let staffSpace = spaces[staffIndex]
                            let radius = max(1, Int((staffSpace * 0.75).rounded()))
                            let flankLength = max(8, Int((staffSpace * 3).rounded()))
                            let flankGap = max(3, Int((staffSpace * 0.5).rounded()))
                            let flanks = [max(0, clearLeft - flankGap - flankLength)..<max(0, clearLeft - flankGap),
                                          min(width, clearRight + flankGap)..<min(width, clearRight + flankGap + flankLength)]
                            var bestShift: Int? = nil
                            var bestScore = -1.0
                            for shift in -radius...radius {
                                var total = 0.0
                                var weakest = 1.0
                                for line in lines[staffIndex] {
                                    var bestFlank = 0.0
                                    for flank in flanks where flank.count >= flankLength {
                                        var supported = 0
                                        for column in flank {
                                            let y = Int((line + slope * (Double(column) - Double(width) / 2)).rounded()) + shift
                                            if (-1...1).contains(where: { delta in
                                                y + delta >= 0 && y + delta < height && original[(y + delta) * width + column]
                                            }) { supported += 1 }
                                        }
                                        bestFlank = max(bestFlank, Double(supported) / Double(flank.count))
                                    }
                                    weakest = min(weakest, bestFlank)
                                    total += bestFlank
                                }
                                guard weakest >= 0.80 else { continue }
                                if total > bestScore || (total == bestScore && abs(shift) < abs(bestShift ?? radius + 1)) {
                                    bestScore = total
                                    bestShift = shift
                                }
                            }
                            // A local five-line fit can be a one-line ledger alias when
                            // the shift plus the raster matching uncertainty reaches
                            // a staff-space. The support test allows +/-1 row; one
                            // further row covers fractional rounding and line width.
                            // Resolve those fits by tracing the staff identity from
                            // the interior instead of trusting the local pattern.
                            if let bestShift, Double(abs(bestShift)) + 2 < staffSpace { if index == 0 { Trace.emit("local-shift",["staff":staffIndex,"left":left,"right":x,"shift":bestShift]) };return Double(bestShift) }
                            // Ambiguous local fits require a continuous, five-line
                            // path from an interior anchor. This prevents ledger
                            // lines near the connector from replacing the staff.
                            let extendedRadius = max(1, Int((staffSpace * 1.5).rounded()))
                            let midpoint = Double(clearLeft + clearRight) / 2
                            let inward = midpoint >= Double(width) / 2 ? flanks[0] : flanks[1]
                            guard inward.count >= flankLength else { return nil }
                            // Resolve the offset at the connector itself; page curl can
                            // continue beyond the interior evidence window.
                            let target = (inward.lowerBound + inward.upperBound) / 2
                            let anchor = width / 2
                            let step = max(1, Int((staffSpace * 1.5).rounded()))
                            guard abs(target - anchor) >= step else { return nil }
                            let count = max(1, Int(ceil(Double(abs(target - anchor)) / Double(step))))
                            let allowedStep = max(1, Int((staffSpace * 0.15).rounded()))
                            let anchorRadius = max(1, Int((staffSpace * 0.5).rounded()))
                            // Keep all five ordered physical line identities in one
                            // state. Brief missing raster evidence carries a line's
                            // identity from its last observation; a missing line is
                            // never substituted with a newly found adjacent ridge.
                            struct TraceState {
                                var score: Double
                                var missingDistance: [Int]
                                var observedRun: [Int]
                            }
                            var reachable = Dictionary(uniqueKeysWithValues:
                                (-anchorRadius...anchorRadius).map {
                                    ($0, TraceState(score: 0, missingDistance: Array(repeating: 0, count: 5), observedRun: Array(repeating: 0, count: 5)))
                                })
                            let maximumMissingDistance = Int((staffSpace * 4).rounded())
                            let minimumObservedRun = max(2, Int((staffSpace * 0.5).rounded()))
                            for segment in 0...count {
                                let center = anchor + Int((Double(target - anchor) * Double(segment) / Double(count)).rounded())
                                let begin = center - flankLength / 2
                                guard begin >= 0, begin + flankLength <= width else { return nil }
                                var next: [Int: TraceState] = [:]
                                for shift in -extendedRadius...extendedRadius {
                                    let predecessors = reachable.filter {
                                        abs($0.key - shift) <= (segment == 0 ? 0 : allowedStep)
                                    }
                                    guard !predecessors.isEmpty else { continue }
                                    var support: [Double] = []
                                    for line in lines[staffIndex] {
                                        var supported = 0
                                        for column in begin..<(begin + flankLength) {
                                            let y = Int((line + slope * (Double(column) - Double(width) / 2)).rounded()) + shift
                                            if (-1...1).contains(where: { delta in
                                                y + delta >= 0 && y + delta < height && original[(y + delta) * width + column]
                                            }) { supported += 1 }
                                        }
                                        support.append(Double(supported) / Double(flankLength))
                                    }
                                    // Establish every line at the interior anchor.
                                    // After that, measure actual gaps along each
                                    // ordered line instead of treating a partly
                                    // broken window as wholly missing evidence.
                                    guard support.filter({ $0 >= 0.80 }).count >= (segment == 0 ? 5 : 3) else { continue }
                                    for (previousShift, state) in predecessors.sorted(by: { $0.key < $1.key }) {
                                        var distance = state.missingDistance
                                        var observedRun = state.observedRun
                                        var valid = true
                                        if segment > 0 {
                                            let previousCenter = anchor + Int((Double(target - anchor) * Double(segment - 1) / Double(count)).rounded())
                                            let length = abs(center - previousCenter)
                                            let direction = center >= previousCenter ? 1 : -1
                                            for offset in 1...max(1, length) {
                                                let column = previousCenter + direction * offset
                                                let displacement = Double(previousShift) + Double(shift - previousShift) * Double(offset) / Double(max(1, length))
                                                for lineIndex in 0..<5 {
                                                    let y = Int((lines[staffIndex][lineIndex] + slope * (Double(column) - Double(width) / 2) + displacement).rounded())
                                                    let visible = (-1...1).contains { delta in
                                                        y + delta >= 0 && y + delta < height && original[(y + delta) * width + column]
                                                    }
                                                    observedRun[lineIndex] = visible ? observedRun[lineIndex] + 1 : 0
                                                    distance[lineIndex] += 1
                                                    if observedRun[lineIndex] >= minimumObservedRun { distance[lineIndex] = 0 }
                                                    if distance[lineIndex] > maximumMissingDistance { valid = false }
                                                }
                                                if !valid { break }
                                            }
                                        }
                                        guard valid else { continue }
                                        let score = state.score + support.reduce(0, +) - 0.05 * Double(abs(shift - previousShift))
                                        let best = next[shift]
                                        let lessMissing: Bool
                                        if let best {
                                            let worst = distance.max() ?? 0
                                            let bestWorst = best.missingDistance.max() ?? 0
                                            let total = distance.reduce(0, +)
                                            let bestTotal = best.missingDistance.reduce(0, +)
                                            lessMissing = worst != bestWorst ? worst < bestWorst
                                                : total != bestTotal ? total < bestTotal
                                                : distance.lexicographicallyPrecedes(best.missingDistance)
                                        } else { lessMissing = true }
                                        // Stable ties are important: equally scored
                                        // histories can have different remaining
                                        // evidence budgets on a later segment.
                                        if best == nil || score > best!.score || (score == best!.score && lessMissing) {
                                            next[shift] = TraceState(score: score, missingDistance: distance, observedRun: observedRun)
                                        }
                                    }
                                }
                                guard !next.isEmpty else { return nil }
                                reachable = next
                            }
                            let tracedResult = reachable.keys.sorted {
                                if reachable[$0]!.score != reachable[$1]!.score { return reachable[$0]!.score > reachable[$1]!.score }
                                if abs($0) != abs($1) { return abs($0) < abs($1) }
                                return $0 < $1
                            }.first
                            // Keep a previously observed shift when the actual
                            // connector already supports every physical junction.
                            // Refinement is an alternative for a failed proof.
                            if let tracedResult, connectorProof(staffIndex, localShift + Double(tracedResult)) {
                                return Double(tracedResult)
                            }
                            // Keep the tracing windows inside the printed staff.
                            // Continue the five identified lines through the short
                            // inward span to resolve the shift at the actual cut.
                            // Never use blank paper beyond the boundary as a window.
                            let endpoint = (clearLeft + clearRight) / 2
                            let direction = endpoint >= target ? 1 : -1
                            let lastEvidence = direction > 0 ? clearLeft - 1 : clearRight
                            let span = abs(endpoint - target)
                            guard span > 0, (lastEvidence - target) * direction > 0 else { return nil }
                            let drift = min(max(0, Int(floor(staffSpace * 0.49))),
                                allowedStep * max(1, Int(ceil(Double(span) / Double(step)))))
                            let columns = stride(from: target + direction, through: lastEvidence, by: direction)
                            var bestEndpoint: Int? = nil
                            var bestEndpointScore = -Double.infinity
                            for previousShift in reachable.keys.sorted() {
                                let state = reachable[previousShift]!
                                for endShift in (previousShift - drift)...(previousShift + drift) {
                                    guard abs(endShift) <= extendedRadius else { continue }
                                    var support = Array(repeating: 0, count: 5)
                                    var distance = state.missingDistance
                                    var observedRun = state.observedRun
                                    var count = 0
                                    var valid = true
                                    for column in columns {
                                        count += 1
                                        let fraction = Double(abs(column - target)) / Double(span)
                                        let shift = Double(previousShift) + Double(endShift - previousShift) * fraction
                                        for lineIndex in 0..<5 {
                                            let y = Int((lines[staffIndex][lineIndex]
                                                + slope * (Double(column) - Double(width) / 2) + shift).rounded())
                                            let visible = (-1...1).contains { delta in
                                                y + delta >= 0 && y + delta < height && original[(y + delta) * width + column]
                                            }
                                            support[lineIndex] += visible ? 1 : 0
                                            distance[lineIndex] += 1
                                            observedRun[lineIndex] = visible ? observedRun[lineIndex] + 1 : 0
                                            if observedRun[lineIndex] >= max(2, Int((staffSpace * 0.5).rounded())) { distance[lineIndex] = 0 }
                                            if distance[lineIndex] > maximumMissingDistance { valid = false }
                                        }
                                    }
                                    guard valid, count > 0,
                                        support.filter({ Double($0) >= Double(count) * 0.80 }).count >= 3 else { continue }
                                    let score = state.score + Double(support.reduce(0, +)) / Double(count)
                                        - 0.05 * Double(abs(endShift - previousShift))
                                    if score > bestEndpointScore || (score == bestEndpointScore
                                        && (abs(endShift) < abs(bestEndpoint ?? extendedRadius + 1)
                                            || (abs(endShift) == abs(bestEndpoint ?? extendedRadius + 1) && endShift < bestEndpoint!))) {
                                        bestEndpointScore = score
                                        bestEndpoint = endShift
                                    }
                                }
                            }
                            return bestEndpoint.map(Double.init)
                        }
                        var upperCoreShift = localShift, lowerCoreShift = localShift
                        if !throughBothCores {
                            guard let upper = localCoreShift(index), let lower = localCoreShift(index + 1) else { if index == 0 {Trace.emit("rejected-local-trace",["left":left,"right":x])};continue }
                            upperCoreShift += upper
                            lowerCoreShift += lower
                            guard connectorProof(index, upperCoreShift),
                                  connectorProof(index + 1, lowerCoreShift) else { if index == 0 {Trace.emit("rejected-core-junction-proof",["left":left,"right":x,"upperShift":upperCoreShift,"lowerShift":lowerCoreShift,"upperProof":connectorProof(index,upperCoreShift),"lowerProof":connectorProof(index+1,lowerCoreShift)])};continue }
                        }
                        // An off-staff body at an actual stroke endpoint
                        // is music. A tie joining a continuing barline is not an
                        // endpoint and must not veto structural separation.
                        let ownsTerminalHead = retainMusicalEvidence && physicalStrokes.contains { stroke in
                            let staffSpace = space
                            let nominalCenter = (stroke.left + stroke.right) / 2
                            let columnRadius = max(1, Int((staffSpace * 0.35).rounded()))
                            let stemColumns = max(0, nominalCenter - columnRadius)..<min(width, nominalCenter + columnRadius + 1)
                            func occupied(_ y: Int) -> Bool {
                                y >= 0 && y < height && stemColumns.contains { original[y * width + $0] }
                            }
                            return [(index, upperCoreShift, true), (index + 1, lowerCoreShift, false)].contains { staffIndex, shift, upper in
                                guard Double(clearLeft - lineStarts[staffIndex]) > staffSpace else { return false }
                                let boundary = Int((lines[staffIndex][upper ? 0 : 4] + shift).rounded())
                                // A connector that continues beyond this staff's
                                // outer line has no terminal here. Use a run, not
                                // one nearby ink pixel, as continuation evidence.
                                let direction = upper ? -1 : 1
                                let continuationStart = max(2, Int((staffSpace * 0.35).rounded()))
                                let continuationEnd = max(continuationStart + 1, Int((staffSpace * 1.35).rounded()))
                                var continuous = 0
                                for offset in continuationStart...continuationEnd {
                                    continuous = occupied(boundary + direction * offset) ? continuous + 1 : 0
                                    if continuous >= max(2, Int((staffSpace * 0.5).rounded())) { return false }
                                }
                                let inward = upper ? 1 : -1
                                let depth = max(3, Int((staffSpace * 0.95).rounded()))
                                let branchLength = max(2, Int((staffSpace * 0.4).rounded()))
                                let headThickness = max(2, Int((staffSpace * 0.3).rounded()))
                                let sideReach = max(branchLength + 1, Int((staffSpace * 1.2).rounded()))
                                for distance in -1...depth {
                                    let row = boundary + inward * distance
                                    guard row >= 0, row + headThickness < height else { continue }
                                    for side in [-1, 1] {
                                        let near = side < 0 ? stroke.left - 1 : stroke.right
                                        for offset in 0...max(0, sideReach - branchLength) {
                                            let xs = (0..<branchLength).map { near + side * (offset + $0) }
                                            guard xs.allSatisfy({ $0 >= 0 && $0 < width }) else { continue }
                                            // A compact solid patch must connect
                                            // horizontally to the stroke on each
                                            // row. Staff-line remnants and thin
                                            // ties cannot supply its full height.
                                            var offStaffRows = 0
                                            let attached = (0..<headThickness).allSatisfy { dy in
                                                let y = row + dy
                                                let lo = min(xs.min()!, nominalCenter), hi = max(xs.max()!, nominalCenter)
                                                guard (lo...hi).allSatisfy({ original[y * width + $0] }) else { return false }
                                                // Source-provenance veto: a detached compact
                                                // staff fragment is still part of its horizontal
                                                // line. At this row, look for the same source line
                                                // beyond the entire possible head, on either side.
                                                // Only directly attached rows with no such line
                                                // continuation can witness a musical body.
                                                let outsideStart = max(3, Int((staffSpace * 1.5).rounded()))
                                                let outsideEnd = max(outsideStart + 2, Int((staffSpace * 4).rounded()))
                                                var sameHorizontalLine = false
                                                for flankSide in [-1, 1] {
                                                    for rowShift in -1...1 {
                                                        var sampled = 0, supported = 0
                                                        for dx in outsideStart...outsideEnd {
                                                            let xx = nominalCenter + flankSide * dx
                                                            guard xx >= 0, xx < width else { continue }
                                                            let yy = y + rowShift + Int((slope * Double(xx - nominalCenter)).rounded())
                                                            guard yy >= 0, yy < height else { continue }
                                                            sampled += 1
                                                            if original[yy * width + xx] { supported += 1 }
                                                        }
                                                        if sampled >= outsideEnd - outsideStart && Double(supported) >= Double(sampled) * 0.70 { sameHorizontalLine = true }
                                                    }
                                                }
                                                if !sameHorizontalLine { offStaffRows += 1 }
                                                var actualLeft = lo, actualRight = hi + 1
                                                while actualLeft > 0 && original[y * width + actualLeft - 1] { actualLeft -= 1 }
                                                while actualRight < width && original[y * width + actualRight] { actualRight += 1 }
                                                let actualWidth = Double(actualRight - actualLeft)
                                                // A head is bounded in both directions:
                                                // a full horizontal staff line cannot
                                                // certify a compact attachment.
                                                return actualWidth >= staffSpace * 0.9 && actualWidth <= staffSpace * 2.1
                                            }
                                            guard attached, offStaffRows >= max(1, Int((staffSpace * 0.15).rounded())) else { continue }
                                            // A compact patch inside an accidental is not a
                                            // complete notehead witness. Follow every attached
                                            // off-spine analysis component to its actual end.
                                            // The physical vertical spine remains excluded;
                                            // never cross to a nearby disconnected stem.
                                            var visited = Set<Int>()
                                            var completeBodies = true
                                            var sawBody = false
                                            let seedLo = min(xs.min()!, nominalCenter)
                                            let seedHi = max(xs.max()!, nominalCenter)
                                            for yy in row..<(row + headThickness) {
                                                for xx in seedLo...seedHi where xx < stroke.left || xx >= stroke.right {
                                                    let seed = yy * width + xx
                                                    guard ink[seed], !visited.contains(seed) else { continue }
                                                    var queue = [seed], next = 0
                                                    visited.insert(seed)
                                                    var minX = xx, maxX = xx, minY = yy, maxY = yy
                                                    while next < queue.count {
                                                        let item = queue[next]; next += 1
                                                        let py = item / width, px = item % width
                                                        minX = min(minX, px); maxX = max(maxX, px)
                                                        minY = min(minY, py); maxY = max(maxY, py)
                                                        if Double(maxX - minX + 1) > staffSpace * 2.1 || Double(maxY - minY + 1) > staffSpace * 0.95 {
                                                            completeBodies = false
                                                            break
                                                        }
                                                        for dy in -1...1 { for dx in -1...1 {
                                                            let nx = px + dx, ny = py + dy
                                                            guard nx >= 0, nx < width, ny >= 0, ny < height,
                                                                  nx < stroke.left || nx >= stroke.right else { continue }
                                                            let neighbor = ny * width + nx
                                                            if ink[neighbor] && visited.insert(neighbor).inserted { queue.append(neighbor) }
                                                        } }
                                                    }
                                                    sawBody = true
                                                    if !completeBodies { break }
                                                }
                                                if !completeBodies { break }
                                            }
                                            if sawBody && completeBodies { return true }
                                        }
                                    }
                                }
                                return false
                            }
                        }
                        if index == 0 {Trace.emit("terminal-test",["left":left,"right":x,"ownsTerminalHead":ownsTerminalHead,"musical":retainMusicalEvidence])}
                        if ownsTerminalHead {
                            preservedMusicalConnection = true
                            continue
                        }
                        // Cutting only at the midpoint leaves long connector
                        // tails that spuriously enlarge both crops. Remove the
                        // inter-staff structure while retaining horizontal ink
                        // branching into it (a slur or dynamic may touch a barline).
                        // Staff positions describe the page center. Applying the
                        // same tilt here avoids rejecting true edge barlines or
                        // leaving connector tails on skewed source pages.
                        let localStart = min(height, max(0, Int((Double(start) + upperCoreShift).rounded())))
                        let localEnd = max(0, min(height, Int((Double(end) + lowerCoreShift).rounded())))
                        guard localStart < localEnd else { continue }
                        if index == 0 {Trace.emit("cut",["left":clearLeft,"right":clearRight,"top":localStart,"bottom":localEnd,"musical":retainMusicalEvidence])}
                        for y in localStart..<localEnd {
                            let branchesLeft = (max(0, clearLeft - 2)..<clearLeft).contains { original[y * width + $0] }
                            let branchesRight = (clearRight..<min(width, clearRight + 2)).contains { original[y * width + $0] }
                            if branchesLeft || branchesRight { continue }
                            for column in clearLeft..<clearRight { ink[y * width + column] = false }
                        }
                    }
                }
            }
        }
        Trace.saveMask(ink,width:width,height:height,phase:retainMusicalEvidence ? "separated-musical":"separated-structural")
        struct Run { var left: Int; var right: Int; var y: Int }
        struct Bounds { var left: Int; var top: Int; var right: Int; var bottom: Int; var area: Int }
        var runs: [Run] = [], parents: [Int] = [], previous: [Int] = []
        func root(_ value: Int) -> Int {
            var index = value
            while parents[index] != index {
                parents[index] = parents[parents[index]]
                index = parents[index]
            }
            return index
        }
        for y in 0..<height {
            if isCancelled() { return nil }
            var current: [Int] = [], x = 0, previousOffset = 0
            while x < width {
                if !ink[y * width + x] { x += 1; continue }
                let left = x
                while x < width && ink[y * width + x] { x += 1 }
                let index = runs.count
                runs.append(Run(left: left, right: x, y: y)); parents.append(index); current.append(index)
                while previousOffset < previous.count && runs[previous[previousOffset]].right < left { previousOffset += 1 }
                var offset = previousOffset
                while offset < previous.count && runs[previous[offset]].left <= x {
                    let other = root(previous[offset]), own = root(index)
                    if other != own { parents[other] = own }
                    offset += 1
                }
            }
            previous = current
        }
        var boxes: [Int: Bounds] = [:]
        for (index, run) in runs.enumerated() {
            if index % 4096 == 0 && isCancelled() { return nil }
            let key = root(index)
            if var box = boxes[key] {
                box.left = min(box.left, run.left); box.right = max(box.right, run.right)
                box.top = min(box.top, run.y); box.bottom = max(box.bottom, run.y + 1)
                box.area += run.right - run.left
                boxes[key] = box
            } else {
                boxes[key] = Bounds(left: run.left, top: run.y, right: run.right, bottom: run.y + 1, area: run.right - run.left)
            }
        }
        let typicalSpace = spaces.sorted()[spaces.count / 2]
        var result: [ScoreInkComponent] = []
        for box in boxes.values where box.area >= 2 {
            let boxHeight = Double(box.bottom - box.top), boxWidth = Double(box.right - box.left)
            let owners = lines.indices.filter {
                Double(box.top) <= lines[$0][4]
                    && Double(box.bottom) >= lines[$0][0]
            }
            // Thin, multi-staff vertical connectors and braces strictly left of
            // the staff-line starts are not target-note ownership evidence. A
            // single staff's long thin stem is kept, even at the page's left edge.
            if owners.count > 1 && boxHeight > 8 * typicalSpace {
                let outsideStaff = owners.allSatisfy { Double(box.right) < Double(lineStarts[$0]) - spaces[$0] * 0.25 }
                if boxWidth < 0.6 * typicalSpace || (boxWidth < 1.8 * typicalSpace && outsideStaff) { continue }
            }
            // Keep interior components too. A low dynamic close to the following
            // staff can lie within its padding envelope, yet belong to the
            // preceding part; omitting it here makes later review impossible.
            result.append(ScoreInkComponent(bounds: [Double(box.left) / Double(width), Double(box.top) / Double(height),
                Double(box.right) / Double(width), Double(box.bottom) / Double(height)], staffIDs: owners.map { ordered[$0].id }))
        }
        if retainMusicalEvidence && preservedMusicalConnection {
            // Keep the local components as ordinary attribution evidence.
            // A musical connection is an additional outward-preservation
            // hypothesis, never competing evidence that can reassign an old
            // fragment or suppress its detached notation chain in the planner.
            // Both interpretations come from the same untouched source.
            guard let localComponents = notationComponents(image: image, candidates: candidates,
                skewDegrees: skewDegrees, isCancelled: isCancelled, retainMusicalEvidence: false) else { return nil }
            struct ComponentIdentity: Hashable {
                var staffIDs: [Int]
                var bounds: [Double]
            }
            guard !isCancelled() else { return nil }
            let musicalInterpretation = result
            result = localComponents
            var identities = Set(localComponents.map { ComponentIdentity(staffIDs: $0.staffIDs, bounds: $0.bounds) })
            for (componentIndex, component) in musicalInterpretation.enumerated() {
                if componentIndex % 4096 == 0 && isCancelled() { return nil }
                if identities.insert(ComponentIdentity(staffIDs: component.staffIDs, bounds: component.bounds)).inserted {
                    var alternative = component
                    alternative.isOwnershipAlternative = true
                    result.append(alternative)
                }
            }
        }
        result.sort {
            if $0.bounds[1] != $1.bounds[1] { return $0.bounds[1] < $1.bounds[1] }
            return $0.bounds[0] < $1.bounds[0]
        }
        guard !isCancelled() else { return nil }
        return result
    }
}
