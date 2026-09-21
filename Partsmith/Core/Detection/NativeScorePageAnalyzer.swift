import CoreGraphics
import Foundation
import PDFKit

/// Native offline PDF rendering shared by the app and batch inventory. Fractions
/// describe the supplied image; unrectified PDF pages map directly to PDF points.
enum NativeScorePageAnalyzer {
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
                                   isCancelled: () -> Bool = { false }) -> [ScoreInkComponent]? {
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
            let thickness = max(1, Int((spaces[index] * 0.09).rounded()))
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
                        guard throughBothCores else { continue }
                        // Cutting only at the midpoint leaves long connector
                        // tails that spuriously enlarge both crops. Remove the
                        // inter-staff structure while retaining horizontal ink
                        // branching into it (a slur or dynamic may touch a barline).
                        // Staff positions describe the page center. Applying the
                        // same tilt here avoids rejecting true edge barlines or
                        // leaving connector tails on skewed source pages.
                        let localStart = min(height, max(0, Int((Double(start) + localShift).rounded())))
                        let localEnd = max(0, min(height, Int((Double(end) + localShift).rounded())))
                        guard localStart < localEnd else { continue }
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
        return result.sorted {
            if $0.bounds[1] != $1.bounds[1] { return $0.bounds[1] < $1.bounds[1] }
            return $0.bounds[0] < $1.bounds[0]
        }
    }
}
