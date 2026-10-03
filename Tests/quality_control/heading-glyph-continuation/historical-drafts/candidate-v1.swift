import CoreGraphics
import Foundation
import Vision

/// A conservative first pass for printed movement/tempo headings. OCR locates
/// source pixels; it never supplies newly engraved text or instrument identity.
/// Rehearsal letters, endings, and staff-local expressions require separate review.
enum ScoreSharedHeadingDetector {
    struct TextLine {
        var text: String
        var bounds: CGRect
        var confidence: Float
    }

    static func detect(in image: CGImage, page: ScorePageAnalysis,
                       profile: ScoreExtractionProfile,
                       observedText: ((Int, [TextLine]) -> Void)? = nil,
                       observedFailure: ((Int, Error) -> Void)? = nil,
                       isCancelled: () -> Bool = { false }) -> [ScoreSharedHeading] {
        guard image.width > 0, image.height > 0, !isCancelled() else { return [] }
        // Reuse the planner's complete geometry/cadence validation. An unknown
        // system assignment must not make a local instruction a global heading.
        let plan = ScoreExtractionPlanner.plan(pages: [page], profile: profile, isCancelled: isCancelled)
        guard plan.canApply, !plan.bands.isEmpty else { return [] }
        let anchors = Dictionary(grouping: plan.bands, by: \.systemIndex).values.compactMap {
            $0.flatMap(\.candidateIDs).min()
        }.sorted()
        let ordered = page.staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
        var result: [ScoreSharedHeading] = []
        var fallbackAnchors: [(ScoreObservedStaff, Double)] = []
        for anchor in anchors {
            guard !isCancelled(), let position = ordered.firstIndex(where: { $0.id == anchor }) else { break }
            let staff = ordered[position], lines = staff.staffLineFractions
            let space = (lines[4] - lines[0]) / 4
            let previousBottom = position > 0 ? ordered[position - 1].staffLineFractions[4] : 0
            let top = max(previousBottom + (position > 0 ? space : 0), lines[0] - 12 * space)
            let bottom = lines[0] - space * 0.3
            guard bottom > top else { continue }
            let rect = CGRect(x: 0, y: floor(top * Double(image.height)), width: Double(image.width),
                              height: ceil((bottom - top) * Double(image.height)))
            guard let crop = image.cropping(to: rect), crop.height > 5 else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.03
            request.customWords = vocabulary
            do { try VNImageRequestHandler(cgImage: crop, options: [:]).perform([request]) }
            catch { observedFailure?(anchor, error); continue }
            guard !isCancelled() else { return [] }
            let height = Double(image.height)
            let text: [TextLine] = (request.results ?? []).compactMap { observation -> TextLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let b = observation.boundingBox
                let bounds = CGRect(x: b.minX, y: (rect.minY + (1 - b.maxY) * rect.height) / height,
                                    width: b.width, height: b.height * rect.height / height)
                return TextLine(text: candidate.string, bounds: bounds,
                    confidence: candidate.confidence)
            }
            observedText?(anchor, text)
            let selected = select(from: text, anchor: staff, previousStaffBottom: previousBottom,
                imageSize: CGSize(width: image.width, height: image.height))
            result += selected
            if selected.isEmpty { fallbackAnchors.append((staff, previousBottom)) }
        }
        // Isolated narrow strips and full-page OCR fail on different scan
        // features. A single full-page fallback recovers headings omitted by
        // regional segmentation, retaining the same semantic/spatial gates.
        if !fallbackAnchors.isEmpty, !isCancelled() {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.003
            request.customWords = vocabulary
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                let text: [TextLine] = (request.results ?? []).compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let b = observation.boundingBox
                    return TextLine(text: candidate.string,
                        bounds: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height),
                        confidence: candidate.confidence)
                }
                observedText?(-1, text)
                for (staff, previousBottom) in fallbackAnchors {
                    result += select(from: text, anchor: staff, previousStaffBottom: previousBottom,
                        imageSize: CGSize(width: image.width, height: image.height))
                }
            } catch {
                // Keep any supported headings for interactive callers, while
                // batch diagnostics can distinguish OCR failure from no match.
                observedFailure?(-1, error)
            }
        }
        guard !isCancelled() else { return [] }
        // Keep the recognized system identity before any reviewed assignments
        // can move its source or recipients. Overlapping lines of one heading
        // must travel as one source block; measuring after joining also covers
        // original ink in the newly enclosed corners and inter-line space.
        let bound = result.map { heading in
            var item = heading
            if let anchor = page.staves.first(where: { $0.id == heading.anchorStaffID }) {
                item.bounds = continuedGlyphBounds(in: image, bounds: heading.bounds,
                    anchor: anchor, isCancelled: isCancelled)
            }
            item.recognitionBinding = ScoreExtractionPlanner.headingRecognitionBinding(
                page: page, plan: plan, anchorStaffID: heading.anchorStaffID)
            return item
        }
        var measured: [ScoreSharedHeading] = []
        for heading in ScoreSharedHeading.coalesced(bound) {
            guard !isCancelled() else { return [] }
            var item = heading
            item.inkBounds = measuredInkBounds(in: image, bounds: heading.bounds)
            measured.append(item)
        }
        guard !isCancelled() else { return [] }
        return measured
    }

    /// Follow a clipped glyph across a horizontal OCR edge. Only a complete,
    /// text-sized connected component can justify expansion. Components cut by
    /// the vertical search limits (staff/clef/stem fragments) and shallow slurs
    /// cannot pull the source box sideways. Existing source edges never shrink.
    static func continuedGlyphBounds(in image: CGImage, bounds: [Double],
                                     anchor: ScoreObservedStaff,
                                     isCancelled: () -> Bool = { false }) -> [Double] {
        guard ScoreSharedEnding.validBounds(bounds), anchor.staffLineFractions.count == 5,
              anchor.staffLineFractions.allSatisfy(\.isFinite), image.width > 0, image.height > 0,
              !isCancelled() else { return bounds }
        let width = image.width, height = image.height
        let lines = anchor.staffLineFractions
        let space = (lines[4] - lines[0]) * Double(height) / 4
        guard space >= 2, zip(lines, lines.dropFirst()).allSatisfy({ $0 < $1 }) else { return bounds }
        let left = bounds[0] * Double(width), right = bounds[2] * Double(width)
        let reach = max(2, Int(ceil(1.5 * space)))
        let x0 = max(0, Int(floor(left)) - reach), x1 = min(width, Int(ceil(right)) + reach)
        let y0 = max(0, Int(floor(bounds[1] * Double(height))))
        let bottom = min(bounds[3] * Double(height), lines[0] * Double(height) - 0.3 * space)
        let y1 = min(height, Int(ceil(bottom)))
        guard x1 > x0, y1 > y0 else { return bounds }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return bounds }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return bounds }
        let rw = x1 - x0, rh = y1 - y0
        var visited = [Bool](repeating: false, count: rw * rh)
        var expandedLeft = left, expandedRight = right
        for sy in 0..<rh {
            if isCancelled() { return bounds }
            for sx in 0..<rw {
                let start = sy * rw + sx
                guard !visited[start], pixels[(sy + y0) * width + sx + x0] < 224 else { continue }
                var queue = [start], cursor = 0
                visited[start] = true
                var minX = sx, maxX = sx, minY = sy, maxY = sy
                while cursor < queue.count {
                    let index = queue[cursor]; cursor += 1
                    let x = index % rw, y = index / rw
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                    for dy in -1...1 { for dx in -1...1 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < rw, ny >= 0, ny < rh else { continue }
                        let next = ny * rw + nx
                        if !visited[next], pixels[(ny + y0) * width + nx + x0] < 224 {
                            visited[next] = true; queue.append(next)
                        }
                    } }
                }
                let cw = Double(maxX - minX + 1), ch = Double(maxY - minY + 1)
                // A clipped component has unknown extent. Do not infer a
                // complete letter by stopping at the search window itself.
                guard minX > 0, maxX < rw - 1, minY > 0, maxY < rh - 1,
                      ch >= 0.8 * space, ch <= 5.5 * space,
                      cw >= 0.4 * space, cw <= 8 * ch else { continue }
                let a = Double(x0 + minX), b = Double(x0 + maxX + 1)
                if a < left, b >= left + 0.4 * space, left - a <= Double(reach) {
                    expandedLeft = min(expandedLeft, max(0, a - 1))
                }
                if b > right, a <= right - 0.4 * space, b - right <= Double(reach) {
                    expandedRight = max(expandedRight, min(Double(width), b + 1))
                }
            }
        }
        guard !isCancelled() else { return bounds }
        return [expandedLeft / Double(width), bounds[1], expandedRight / Double(width), bounds[3]]
    }

    /// Measure all original raster ink inside the padded source copy.
    /// Never use OCR word bounds to decide that a glyph is already retained:
    /// OCR can miss cap serifs, dots and parentheses. Failed/empty measurements
    /// provide no suppression evidence and leave the existing padded copy.
    static func measuredInkBounds(in image: CGImage, bounds: [Double]) -> [Double]? {
        guard bounds.count == 4, bounds.allSatisfy(\.isFinite),
              bounds[0] >= 0, bounds[1] >= 0, bounds[0] < bounds[2], bounds[1] < bounds[3],
              bounds[2] <= 1, bounds[3] <= 1, image.width > 0, image.height > 0 else { return nil }
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let x0 = max(0, Int(floor(bounds[0] * Double(width))))
        let x1 = min(width, Int(ceil(bounds[2] * Double(width))))
        let y0 = max(0, Int(floor(bounds[1] * Double(height))))
        let y1 = min(height, Int(ceil(bounds[3] * Double(height))))
        guard x1 > x0, y1 > y0 else { return nil }
        var left = width, top = height, right = 0, bottom = 0
        for y in y0..<y1 {
            for x in x0..<x1 where pixels[y * width + x] < 255 {
                left = min(left, x); top = min(top, y)
                right = max(right, x + 1); bottom = max(bottom, y + 1)
            }
        }
        guard right > left, bottom > top else { return nil }
        // The duplicate copy itself is clipped to these padded bounds. Measure
        // all nonwhite source pixels with a guard, capped at that exact copy;
        // ink outside it was never supplied by the copy being suppressed.
        return [max(bounds[0], Double(max(0, left - 1)) / Double(width)),
                max(bounds[1], Double(max(0, top - 1)) / Double(height)),
                min(bounds[2], Double(min(width, right + 1)) / Double(width)),
                min(bounds[3], Double(min(height, bottom + 1)) / Double(height))]
    }

    static func select(from lines: [TextLine], anchor: ScoreObservedStaff,
                       previousStaffBottom: Double, imageSize: CGSize) -> [ScoreSharedHeading] {
        guard anchor.staffLineFractions.count == 5, imageSize.width > 0, imageSize.height > 0 else { return [] }
        let top = anchor.staffLineFractions[0]
        let space = (anchor.staffLineFractions[4] - top) / 4
        guard space > 0, space.isFinite else { return [] }
        let valid = lines.filter {
            let b = $0.bounds
            return $0.confidence >= 0.8 && $0.confidence.isFinite && !b.isEmpty && !b.isNull
                && [b.minX, b.minY, b.maxX, b.maxY].allSatisfy(\.isFinite)
                && b.minX >= 0 && b.maxX <= 1 && b.minY >= 0 && b.maxY <= top
                && b.minY >= max(0, top - 12 * space)
                && b.midY > (previousStaffBottom + top) / 2
        }.sorted { $0.bounds.minX < $1.bounds.minX }
        // Vision sometimes separates "Doppio" and "Movimento". Join only
        // adjacent words on the same baseline, before classifying the phrase.
        var rows: [TextLine] = []
        for line in valid {
            if let i = rows.lastIndex(where: {
                abs($0.bounds.midY - line.bounds.midY) < min($0.bounds.height, line.bounds.height) * 0.45
                    && line.bounds.minX >= $0.bounds.maxX - 1 / imageSize.width
                    && (line.bounds.minX - $0.bounds.maxX) * imageSize.width < max($0.bounds.height, line.bounds.height) * imageSize.height * 2
            }) {
                rows[i].text += " " + line.text
                rows[i].bounds = rows[i].bounds.union(line.bounds)
                rows[i].confidence = min(rows[i].confidence, line.confidence)
            } else { rows.append(line) }
        }
        return rows.filter { isHeading($0.text) }.map {
            // Vision's word envelope can omit dots, cap serifs and the tops
            // of parentheses in old engraving. Keep a full staff space above
            // the observed word; extra lower padding would collect the nearby
            // staff or instrument-specific technique text unnecessarily.
            let above = max(2 / imageSize.height, space)
            let below = max(2 / imageSize.height, space * 0.3)
            var box = $0.bounds.insetBy(dx: -max(2 / imageSize.width, space * 0.3), dy: 0)
            box.origin.y -= above
            box.size.height += above + below
            let b = box.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            return ScoreSharedHeading(anchorStaffID: anchor.id,
                bounds: [b.minX, b.minY, b.maxX, b.maxY], recognizedText: $0.text)
        }
    }

    private static let vocabulary = ["Allegro", "Allegretto", "Adagio", "Andante", "Andantino",
        "Presto", "Prestissimo", "Largo", "Larghetto", "Lento", "Moderato", "Vivace",
        "Grave", "Maestoso", "Agitato", "Scherzo", "Trio", "Coda", "Doppio", "Movimento", "Variazioni", "Menuetto"]

    static func isHeading(_ text: String) -> Bool {
        let words = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard !words.isEmpty else { return false }
        let tempo = vocabulary.prefix(16).map { $0.lowercased() }
        // Modifiers alone (poco, molto, dolce, etc.) cannot trigger copying.
        // Permit a single OCR letter error only for long tempo words; short
        // navigation labels must be exact apart from the common capital T/I.
        func matches(_ word: String, _ target: String) -> Bool {
            word == target || (target.count >= 6 && editDistance(word, target) == 1)
        }
        if words.count <= 10, words.prefix(3).contains(where: { word in tempo.contains { matches(word, $0) } }) { return true }
        if words == ["trio"] || words == ["irio"] || words == ["coda"] || words == ["menuetto"] { return true }
        return words.count == 2 && matches(words[0], "doppio") && matches(words[1], "movimento")
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let left = Array(a), right = Array(b)
        guard abs(left.count - right.count) <= 1 else { return 2 }
        var row = Array(0...right.count)
        for (i, x) in left.enumerated() {
            var next = [i + 1]
            for (j, y) in right.enumerated() {
                next.append(min(next[j] + 1, row[j + 1] + 1, row[j] + (x == y ? 0 : 1)))
            }
            row = next
        }
        return row.last!
    }
}
