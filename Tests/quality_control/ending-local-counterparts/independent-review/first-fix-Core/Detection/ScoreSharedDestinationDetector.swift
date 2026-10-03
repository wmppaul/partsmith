import CoreGraphics
import Foundation

/// Experimental source-linked repeat-symbol recognition. A matching printed
/// glyph must first be found inside a recognized navigation sentence. These
/// pixels are analysis evidence only; exports copy the original source region.
enum ScoreSharedDestinationDetector {
    struct Template {
        var sourcePageIndex: Int
        var sourceBounds: [Double]
        var pixels: [Double]
    }

    struct Match {
        var anchorStaffID: Int
        var bounds: [Double]
        var correlation: Double
        var templatePageIndex: Int
        var templateBounds: [Double]
    }

    struct GrayRaster {
        var width: Int
        var height: Int
        var pixels: [UInt8]

        init?(image: CGImage) {
            let scale = min(2400 / Double(image.width), 3500 / Double(image.height))
            let w = max(1, Int(Double(image.width) * scale)), h = max(1, Int(Double(image.height) * scale))
            guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
            width = w; height = h; pixels = Array(UnsafeBufferPointer(start: bytes, count: w * h))
        }

        init(width: Int, height: Int, pixels: [UInt8]) {
            self.width = width; self.height = height; self.pixels = pixels
        }

        func crop(_ rect: CGRect) -> (GrayRaster, CGRect)? {
            let x0 = max(0, Int(floor(rect.minX))), y0 = max(0, Int(floor(rect.minY)))
            let x1 = min(width, Int(ceil(rect.maxX))), y1 = min(height, Int(ceil(rect.maxY)))
            guard x1 > x0, y1 > y0 else { return nil }
            var result: [UInt8] = []; result.reserveCapacity((x1 - x0) * (y1 - y0))
            for y in y0..<y1 { result.append(contentsOf: pixels[(y * width + x0)..<(y * width + x1)]) }
            return (GrayRaster(width: x1 - x0, height: y1 - y0, pixels: result),
                    CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
        }

        /// The template is normalized in analysis only, retaining its source
        /// rectangle separately. Fractional sampling avoids rounded-size ties.
        func normalizedPatch(_ rect: CGRect) -> [Double]? {
            guard !rect.isEmpty, rect.minX >= 0, rect.minY >= 0,
                  rect.maxX <= Double(width), rect.maxY <= Double(height) else { return nil }
            var result: [Double] = []; result.reserveCapacity(8000)
            for y in 0..<100 {
                let fy = max(0, min(Double(height - 1), rect.minY + (Double(y) + 0.5) * rect.height / 100 - 0.5))
                let y0 = Int(floor(fy)), y1 = min(height - 1, y0 + 1), ty = fy - Double(y0)
                for x in 0..<80 {
                    let fx = max(0, min(Double(width - 1), rect.minX + (Double(x) + 0.5) * rect.width / 80 - 0.5))
                    let x0 = Int(floor(fx)), x1 = min(width - 1, x0 + 1), tx = fx - Double(x0)
                    let a = Double(pixels[y0 * width + x0]) * (1 - tx) + Double(pixels[y0 * width + x1]) * tx
                    let b = Double(pixels[y1 * width + x0]) * (1 - tx) + Double(pixels[y1 * width + x1]) * tx
                    result.append(1 - (a * (1 - ty) + b * ty) / 255)
                }
            }
            return result
        }
    }

    struct Hole {
        var left: Int; var top: Int; var right: Int; var bottom: Int; var area: Int
        var cx: Double { Double(left + right) / 2 }
        var cy: Double { Double(top + bottom) / 2 }
    }

    struct Candidate {
        var center: CGPoint
        var symbolBox: CGRect
        var staffSpace: Double
    }

    private struct System {
        var first: ScoreObservedStaff
        var previous: ScoreObservedStaff?
    }

    static func templates(in image: CGImage, page: ScorePageAnalysis, profile: ScoreExtractionProfile,
                          isCancelled: () -> Bool = { false }) -> [Template] {
        guard !isCancelled(), systems(page: page, profile: profile, isCancelled: isCancelled) != nil,
              let raster = GrayRaster(image: image) else { return [] }
        var result: [Template] = []
        for navigation in page.sharedNavigation ?? [] {
            guard !isCancelled() else { return [] }
            // Empty text is reserved for source glyphs found by this detector;
            // they cannot be fed back as a new independent instruction template.
            guard !navigation.recognizedText.isEmpty,
                  validBounds(navigation.bounds),
                  let staff = page.staves.first(where: { $0.id == navigation.anchorStaffID }) else { continue }
            let region = pixelRect(navigation.bounds, raster: raster)
            guard let (crop, actualRegion) = raster.crop(region) else { continue }
            let space = staffSpace(staff) * Double(raster.height)
            let found = candidates(in: crop, staffSpace: space, isCancelled: isCancelled)
            // Multiple glyph-like objects in a sentence are unresolved. Never
            // choose a convenient symbol and imply an unverified repeat target.
            guard found.count == 1, let glyph = found.first,
                  let patch = crop.normalizedPatch(glyph.symbolBox) else { continue }
            let box = glyph.symbolBox.offsetBy(dx: actualRegion.minX, dy: actualRegion.minY)
            result.append(Template(sourcePageIndex: page.pageIndex,
                sourceBounds: normalizedBounds(box, raster: raster), pixels: patch))
        }
        return isCancelled() ? [] : result
    }

    static func detect(in image: CGImage, page: ScorePageAnalysis, profile: ScoreExtractionProfile,
                       templates: [Template], observedMatches: (([Match]) -> Void)? = nil,
                       isCancelled: () -> Bool = { false }) -> [ScoreSharedNavigation] {
        guard !templates.isEmpty, !isCancelled(), let raster = GrayRaster(image: image),
              let systems = systems(page: page, profile: profile, isCancelled: isCancelled) else { return [] }
        var result: [ScoreSharedNavigation] = [], matches: [Match] = []
        let instructions = (page.sharedNavigation ?? []).filter { !$0.recognizedText.isEmpty && validBounds($0.bounds) }
            .map { pixelRect($0.bounds, raster: raster) }
        for system in systems {
            guard !isCancelled() else { return [] }
            let top = system.first.staffLineFractions[0] * Double(raster.height)
            let space = staffSpace(system.first) * Double(raster.height)
            let previous = system.previous.map { $0.staffLineFractions[4] * Double(raster.height) + space * 0.12 } ?? 0
            let start = max(0, top - space * 16, previous), end = top - space * 0.12
            guard end > start,
                  let (crop, region) = raster.crop(CGRect(x: 0, y: start, width: Double(raster.width), height: end - start)) else { continue }
            for glyph in candidates(in: crop, staffSpace: space, isCancelled: isCancelled) {
                guard !isCancelled() else { return [] }
                let box = glyph.symbolBox.offsetBy(dx: region.minX, dy: region.minY)
                // The inline symbol may fall in the next system's search gap;
                // its existing instruction ownership wins over that proximity.
                guard instructions.allSatisfy({ !$0.intersects(box) }) else { continue }
                guard let match = bestTemplateMatch(in: raster, box: box, templates: templates, isCancelled: isCancelled),
                      match.score >= 0.70 else { continue }
                // Keep a generous source envelope. The alignment search may
                // not shrink exported content to a tighter best-match window.
                let padded = box.insetBy(dx: -space * 0.25, dy: -space * 0.25)
                    .intersection(CGRect(x: 0, y: 0, width: raster.width, height: raster.height))
                let bounds = normalizedBounds(padded, raster: raster)
                matches.append(Match(anchorStaffID: system.first.id, bounds: bounds, correlation: match.score,
                    templatePageIndex: match.template.sourcePageIndex, templateBounds: match.template.sourceBounds))
                result.append(ScoreSharedNavigation(anchorStaffID: system.first.id, bounds: bounds,
                    recognizedText: "", isBelow: false))
            }
        }
        guard !isCancelled() else { return [] }
        observedMatches?(matches)
        return result
    }

    static func bestTemplateMatch(in raster: GrayRaster, box: CGRect, templates: [Template],
                                  isCancelled: () -> Bool = { false }) -> (score: Double, template: Template)? {
        var best = -2.0
        var source: Template?
        for sx in [0.9, 1.0, 1.1] {
            for sy in [0.9, 1.0, 1.1] {
                for ox in [-0.05, 0.0, 0.05] {
                    for oy in [-0.05, 0.0, 0.05] {
                        guard !isCancelled() else { return nil }
                        let test = CGRect(x: box.midX + ox * box.width - sx * box.width / 2,
                            y: box.midY + oy * box.height - sy * box.height / 2,
                            width: sx * box.width, height: sy * box.height)
                        guard let patch = raster.normalizedPatch(test) else { continue }
                        for template in templates {
                            let score = correlation(template.pixels, patch)
                            if score > best { best = score; source = template }
                        }
                    }
                }
            }
        }
        return source.map { (best, $0) }
    }

    static func correlation(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let meanA = a.reduce(0, +) / Double(a.count), meanB = b.reduce(0, +) / Double(b.count)
        var aa = 0.0, bb = 0.0, ab = 0.0
        for i in a.indices {
            let x = a[i] - meanA, y = b[i] - meanB
            aa += x * x; bb += y * y; ab += x * y
        }
        let denominator = sqrt(aa * bb)
        return denominator > 0 ? ab / denominator : 0
    }

    /// Three closed white regions are sufficient for a candidate: one quadrant
    /// may be broken or joined in a scan. Source-template matching is mandatory;
    /// even joined beams can pass this deliberately recall-oriented stage.
    static func candidates(in raster: GrayRaster, staffSpace space: Double,
                           isCancelled: () -> Bool = { false }) -> [Candidate] {
        guard space.isFinite, space > 0, !isCancelled() else { return [] }
        let holes = whiteComponents(raster, isCancelled: isCancelled).filter { b in
            b.left > 0 && b.top > 0 && b.right < raster.width && b.bottom < raster.height
                && Double(b.area) >= max(2, space * space * 0.015)
                && Double(b.right - b.left) >= space * 0.06 && Double(b.right - b.left) <= space * 1.1
                && Double(b.bottom - b.top) >= space * 0.1 && Double(b.bottom - b.top) <= space * 1.4
        }
        var result: [Candidate] = []
        for seed in holes.indices {
            guard !isCancelled() else { return [] }
            let near = holes.indices.filter { $0 > seed && abs(holes[$0].cx - holes[seed].cx) <= space * 2
                && abs(holes[$0].cy - holes[seed].cy) <= space * 3 }
            guard near.count >= 2, near.count <= 16 else { continue }
            for j in 0..<(near.count - 1) {
                for k in (j + 1)..<near.count {
                    let group = [holes[seed], holes[near[j]], holes[near[k]]]
                    guard group.map(\.area).max()! <= group.map(\.area).min()! * 5 else { continue }
                    for pair in [(0, 1, 2), (0, 2, 1), (1, 2, 0)] {
                        let first = group[pair.0], second = group[pair.1], third = group[pair.2]
                        let left = first.cx < second.cx ? first : second, right = first.cx < second.cx ? second : first
                        let dx = right.cx - left.cx, dy = abs(third.cy - (left.cy + right.cy) / 2)
                        guard dx >= space * 0.2, dx <= space * 1.7, dy >= space * 0.35, dy <= space * 2.6,
                              dx / dy >= 0.16, dx / dy <= 1.7, abs(left.cy - right.cy) <= dy * 0.3,
                              third.cx >= left.cx - dx * 0.4, third.cx <= right.cx + dx * 0.4,
                              left.right < right.left else { continue }
                        let x0 = group.map(\.left).min()!, x1 = group.map(\.right).max()!
                        let cx = Double(left.right + right.left) / 2
                        let gapA: Int, gapB: Int
                        if third.cy > (left.cy + right.cy) / 2 {
                            gapA = max(left.bottom, right.bottom); gapB = third.top
                        } else { gapA = third.bottom; gapB = min(left.top, right.top) }
                        guard gapA < gapB else { continue }
                        let cy = Double(gapA + gapB) / 2
                        let vy0 = max(left.top, right.top), vy1 = min(left.bottom, right.bottom)
                        guard vy1 > vy0, x1 > x0 else { continue }
                        let vertical = (vy0..<vy1).filter { raster.pixels[$0 * raster.width + Int(cx)] < 175 }.count
                        let horizontal = (x0..<x1).filter { raster.pixels[Int(cy) * raster.width + $0] < 175 }.count
                        guard Double(vertical) / Double(vy1 - vy0) >= 0.85,
                              Double(horizontal) / Double(x1 - x0) >= 0.9,
                              !result.contains(where: { abs($0.center.x - cx) < space * 0.5 && abs($0.center.y - cy) < space * 0.5 }) else { continue }
                        result.append(Candidate(center: CGPoint(x: cx, y: cy),
                            symbolBox: CGRect(x: cx - space * 1.6, y: cy - space * 2,
                                              width: space * 3.2, height: space * 4), staffSpace: space))
                    }
                }
            }
        }
        return result
    }

    /// Run-length components avoid allocating one queue element per white page
    /// pixel. Four-connectivity keeps diagonal antialias gaps from merging holes.
    private static func whiteComponents(_ raster: GrayRaster, isCancelled: () -> Bool) -> [Hole] {
        struct Run { var left: Int; var right: Int; var node: Int }
        var parents: [Int] = [], boxes: [Hole] = [], previous: [Run] = []
        func root(_ n: Int) -> Int {
            var i = n
            while parents[i] != i { parents[i] = parents[parents[i]]; i = parents[i] }
            return i
        }
        for y in 0..<raster.height {
            if isCancelled() { return [] }
            var current: [Run] = [], x = 0, pi = 0
            while x < raster.width {
                while x < raster.width && raster.pixels[y * raster.width + x] < 175 { x += 1 }
                let left = x
                while x < raster.width && raster.pixels[y * raster.width + x] >= 175 { x += 1 }
                guard x > left else { continue }
                let node = parents.count; parents.append(node)
                boxes.append(Hole(left: left, top: y, right: x, bottom: y + 1, area: x - left))
                while pi < previous.count && previous[pi].right <= left { pi += 1 }
                var k = pi
                while k < previous.count && previous[k].left < x {
                    let a = root(previous[k].node), b = root(node)
                    if a != b { parents[b] = a }
                    k += 1
                }
                current.append(Run(left: left, right: x, node: node))
            }
            previous = current
        }
        var result: [Int: Hole] = [:]
        for i in boxes.indices {
            let r = root(i), b = boxes[i]
            if let a = result[r] {
                result[r] = Hole(left: min(a.left, b.left), top: min(a.top, b.top),
                    right: max(a.right, b.right), bottom: max(a.bottom, b.bottom), area: a.area + b.area)
            } else { result[r] = b }
        }
        return result.values.sorted { $0.top == $1.top ? $0.left < $1.left : $0.top < $1.top }
    }

    private static func systems(page: ScorePageAnalysis, profile: ScoreExtractionProfile,
                                isCancelled: () -> Bool) -> [System]? {
        guard page.pageWidth.isFinite, page.pageWidth > 0, page.pageHeight.isFinite, page.pageHeight > 0,
              !page.staves.isEmpty, page.staves.allSatisfy({ s in
                  let ys = s.staffLineFractions
                  return ys.count == 5 && ys.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
                      && zip(ys, ys.dropFirst()).allSatisfy { $0 < $1 }
              }) else { return nil }
        var geometry = page; geometry.sharedHeadings = nil; geometry.sharedNavigation = nil
        let plan = ScoreExtractionPlanner.plan(pages: [geometry], profile: profile, isCancelled: isCancelled)
        guard plan.canApply, !isCancelled() else { return nil }
        let bands = plan.bands.filter { $0.pageIndex == page.pageIndex && $0.kind == "music" }
        let owners = bands.flatMap(\.candidateIDs)
        guard owners.count == Set(owners).count, Set(owners) == Set(page.staves.map(\.id)) else { return nil }
        let grouped = Dictionary(grouping: bands, by: \.systemIndex)
        let ordered = page.staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
        return grouped.keys.sorted().compactMap { system in
            let ids = Set(grouped[system]!.flatMap(\.candidateIDs))
            guard let index = ordered.firstIndex(where: { ids.contains($0.id) }) else { return nil }
            return System(first: ordered[index], previous: index > 0 ? ordered[index - 1] : nil)
        }
    }

    private static func staffSpace(_ staff: ScoreObservedStaff) -> Double {
        (staff.staffLineFractions[4] - staff.staffLineFractions[0]) / 4
    }
    private static func validBounds(_ b: [Double]) -> Bool {
        b.count == 4 && b.allSatisfy(\.isFinite) && b[0] >= 0 && b[1] >= 0 && b[2] <= 1 && b[3] <= 1 && b[0] < b[2] && b[1] < b[3]
    }
    private static func pixelRect(_ b: [Double], raster: GrayRaster) -> CGRect {
        CGRect(x: b[0] * Double(raster.width), y: b[1] * Double(raster.height),
               width: (b[2] - b[0]) * Double(raster.width), height: (b[3] - b[1]) * Double(raster.height))
    }
    private static func normalizedBounds(_ r: CGRect, raster: GrayRaster) -> [Double] {
        [r.minX / Double(raster.width), r.minY / Double(raster.height),
         r.maxX / Double(raster.width), r.maxY / Double(raster.height)]
    }
}
