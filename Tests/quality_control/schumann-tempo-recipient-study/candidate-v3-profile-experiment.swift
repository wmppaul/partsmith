import CoreGraphics
import Foundation
import Vision

/// A conservative first pass for printed movement/tempo headings. OCR locates
/// source pixels; it never supplies newly engraved text or instrument identity.
/// Rehearsal letters, endings, and staff-local expressions require separate review.
enum SchumannHeadingCandidate {
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
        let preserved=ScoreSharedHeadingDetector.detect(in:image,page:page,profile:profile,isCancelled:isCancelled)
        let grouped = Dictionary(grouping: plan.bands, by: \.systemIndex)
        let allowInterstaff=profile.parts.count==2 && profile.parts.contains{$0.hasLyrics==true && $0.staffCount==1} && profile.parts.contains{$0.staffCount==2}
        var systemAnchor: [Int:Int] = [:]
        // First staff of each actual instrument only. Interior grand-staff
        // expressions are outside this candidate's shared-tempo scope.
        for bands in grouped.values {
            guard let first = bands.flatMap(\.candidateIDs).min() else { continue }
            for band in bands { if let id=band.candidateIDs.min(), allowInterstaff || id==first { systemAnchor[id]=first } }
        }
        let anchors=systemAnchor.keys.sorted()
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
            result += selected.map { item in var h=item; h.anchorStaffID=systemAnchor[item.anchorStaffID] ?? item.anchorStaffID; return h }
            fallbackAnchors.append((staff, previousBottom))
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
                        imageSize: CGSize(width: image.width, height: image.height)).map { item in var h=item; h.anchorStaffID=systemAnchor[item.anchorStaffID] ?? item.anchorStaffID; return h }
                }
            } catch {
                // Keep any supported headings for interactive callers, while
                // batch diagnostics can distinguish OCR failure from no match.
                observedFailure?(-1, error)
            }
        }
        guard !isCancelled() else { return [] }
        // Regional and whole-page segmentation complement each other, including
        // when one region found only half of a multi-line direction.
        var unique: [ScoreSharedHeading] = []
        for heading in result {
            if let i=unique.firstIndex(where: { h in
                h.anchorStaffID==heading.anchorStaffID &&
                min(h.bounds[2],heading.bounds[2])>max(h.bounds[0],heading.bounds[0]) &&
                min(h.bounds[3],heading.bounds[3])>max(h.bounds[1],heading.bounds[1])
            }) {
                unique[i].bounds=[min(unique[i].bounds[0],heading.bounds[0]),min(unique[i].bounds[1],heading.bounds[1]),max(unique[i].bounds[2],heading.bounds[2]),max(unique[i].bounds[3],heading.bounds[3])]
                if heading.recognizedText.count>unique[i].recognizedText.count {unique[i].recognizedText=heading.recognizedText}
            } else { unique.append(heading) }
        }
        var measured: [ScoreSharedHeading] = []
        for heading in unique {
            guard !isCancelled() else { return [] }
            var item = heading
            item.inkBounds = measuredInkBounds(in: image, bounds: heading.bounds)
            measured.append(item)
        }
        guard !isCancelled() else { return [] }
        // When two instruments already retain complete tempo labels at the same
        // score position, keep their local wording rather than cross-copying
        // two different indications (for example Noch schneller / Presto).
        var locallyComplete: [Int:Set<String>] = [:]
        for (i,h) in measured.enumerated() {
            guard let ink=h.inkBounds else {continue}
            let owners=plan.bands.filter { band in
                band.candidateIDs.contains(h.anchorStaffID) || grouped[band.systemIndex]?.contains(where:{$0.candidateIDs.contains(h.anchorStaffID)})==true
            }.filter { band in band.leftFraction<=ink[0] && band.topFraction<=ink[1] && 1-band.rightFraction>=ink[2] && band.bottomFraction>=ink[3] }
            locallyComplete[i]=Set(owners.map(\.partID))
        }
        var redundant=Set<Int>()
        for i in measured.indices { for j in measured.indices where j>i {
            let a=measured[i],b=measured[j]
            guard a.anchorStaffID==b.anchorStaffID,
                abs(a.bounds[0]-b.bounds[0])*Double(image.width) < 1.5*Double(image.height)*((ordered.first{$0.id==a.anchorStaffID}!.staffLineFractions[4]-ordered.first{$0.id==a.anchorStaffID}!.staffLineFractions[0])/4),
                min(a.bounds[3],b.bounds[3])<=max(a.bounds[1],b.bounds[1]),
                let ao=locallyComplete[i],let bo=locallyComplete[j],!ao.isEmpty,!bo.isEmpty,ao.isDisjoint(with:bo),
                ao.union(bo)==Set(profile.parts.map(\.id)) else {continue}
            redundant.insert(i);redundant.insert(j)
        }}
        let additions=measured.enumerated().filter{!redundant.contains($0.offset)}.map(\.element).filter { h in
            // Existing source copies have already passed preservation review.
            // Do not change their crop boxes on a second OCR segmentation.
            !preserved.contains { old in
                old.anchorStaffID==h.anchorStaffID &&
                min(old.bounds[2],h.bounds[2])>max(old.bounds[0],h.bounds[0]) &&
                min(old.bounds[3],h.bounds[3])>max(old.bounds[1],h.bounds[1])
            }
        }
        return preserved+additions
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
        var accepted = rows.filter { isHeading($0.text) }
        for i in accepted.indices {
            for companion in rows where normalized(companion.text)=="a tempo" {
                let a=accepted[i].bounds,b=companion.bounds
                if abs(a.minX-b.minX) <= max(a.height,b.height) * imageSize.height / imageSize.width,
                   b.minY >= a.minY, b.minY-a.maxY <= max(a.height,b.height)*0.7 {
                    accepted[i].text += " / " + companion.text
                    accepted[i].bounds = a.union(b)
                }
            }
        }
        return accepted.map {
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

    private static func normalized(_ text:String)->String {
        text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))
            .split(whereSeparator:{!$0.isLetter}).joined(separator:" ")
    }

    private static let vocabulary = ["Allegro", "Allegretto", "Adagio", "Andante", "Andantino",
        "Presto", "Prestissimo", "Largo", "Larghetto", "Lento", "Moderato", "Vivace",
        "Grave", "Maestoso", "Agitato", "Scherzo", "Trio", "Coda", "Doppio", "Movimento", "Variazioni", "Menuetto", "Innig", "lebhaft", "Leidenschaft", "Langsam", "langsamer", "Ausdruck", "Fröhlich", "schnell", "Schneller", "Lebhafter", "rascher"]

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
        let germanPhrases: Set<String> = ["innig", "iunig", "lunig", "innig lebhaft", "mit leidenschaft", "ziemlich schnell", "langsam mit innigem ausdruck", "frohlich innig", "etwas langsamer", "nach und nach rascher", "lebhafter", "schneller", "noch schneller", "langsamer", "tempo wie das erste lied"]
        if germanPhrases.contains(words.joined(separator:" ")) { return true }
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
