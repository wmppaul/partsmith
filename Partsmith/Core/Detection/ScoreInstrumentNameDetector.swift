import CoreGraphics
import Foundation
import Vision

/// One deliberate click produces one editable instrument suggestion. All
/// coordinates refer to the displayed raster, with a top-left origin.
struct ScoreInstrumentNamePick: Identifiable, Equatable {
    let id: UUID
    let name: String
    let suggestedStaffCount: Int
    let pageIndex: Int
}

enum ScoreInstrumentNameDetector {
    struct Candidate: Equatable {
        var text: String
        var bounds: CGRect
        var confidence: Float
    }

    /// The image is an immutable snapshot of the page the user actually clicked,
    /// including any rectification. Vision executes entirely on this Mac.
    static func recognize(in image: CGImage, at point: CGPoint,
                          isCancelled: () -> Bool = { false }) -> Candidate? {
        guard validPoint(point), !isCancelled() else { return nil }
        let candidates = recognizeCandidates(in: image, region: labelSearchRegion(in: image, around: point))
        guard !isCancelled(), let first = selectCandidate(from: candidates, at: point) else { return nil }
        // Staff clefs or time signatures can join a label's OCR line. A second
        // small pass over just its letter words avoids keeping that music and
        // gives small scanned labels a cleaner recognition context.
        let refinedRegion = first.bounds.insetBy(dx: -0.002, dy: -0.002)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let refined = recognizeCandidates(in: image, region: refinedRegion)
        guard !isCancelled() else { return nil }
        return selectCandidate(from: refined, at: point) ?? first
    }

    private static func recognizeCandidates(in image: CGImage, region: CGRect) -> [Candidate] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.003
        request.regionOfInterest = CGRect(x: region.minX, y: 1 - region.maxY,
                                          width: region.width, height: region.height)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).flatMap { observation -> [Candidate] in
            guard let recognized = observation.topCandidates(1).first else { return [] }
            var groups: [[(String, CGRect)]] = [[]]
            for word in recognized.string.split(whereSeparator: \.isWhitespace) {
                let letters = word.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
                let digits = word.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
                // Mixed letter/digit blobs are generally adjacent music, not
                // label text. Separate them without inventing a replacement.
                let isLabelWord = (letters > 0 && digits == 0) || (letters == 0 && digits == word.count)
                guard isLabelWord else { groups.append([]); continue }
                let wordBox = try? recognized.boundingBox(for: word.startIndex..<word.endIndex)
                let bounds = wordBox?.boundingBox ?? observation.boundingBox
                // Vision returns observation/word bounds relative to its ROI.
                let topDownBounds = CGRect(x: region.minX + bounds.minX * region.width,
                    y: region.minY + (1 - bounds.maxY) * region.height,
                    width: bounds.width * region.width, height: bounds.height * region.height)
                groups[groups.count - 1].append((String(word), topDownBounds))
            }
            return groups.filter { !$0.isEmpty }.map { words in
                Candidate(text: words.map { $0.0 }.joined(separator: " "),
                    bounds: words.reduce(CGRect.null) { $0.union($1.1) }, confidence: recognized.confidence)
            }
        }
    }

    /// Printed labels sit just before the staff. Long horizontal ink runs give
    /// a local right boundary so a clef is not read as part of the label. This
    /// only narrows the OCR region; it never changes the score or its crops.
    private static func labelSearchRegion(in image: CGImage, around point: CGPoint) -> CGRect {
        let region = searchRegion(around: point)
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return region }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return region }
        let startX = min(width - 1, max(0, Int((point.x + 0.005) * CGFloat(width))))
        let minimumRun = max(24, Int(CGFloat(width) * 0.12))
        var starts: [Int] = []
        let firstRow = max(0, Int(region.minY * CGFloat(height)))
        let lastRow = min(height - 1, Int(region.maxY * CGFloat(height)))
        for y in firstRow...lastRow {
            var run = 0
            for x in startX..<width {
                run = pixels[y * width + x] < 160 ? run + 1 : 0
                if run >= minimumRun {
                    let beginning = x - run + 1
                    if beginning == startX && startX > 0 && pixels[y * width + startX - 1] < 160 { continue }
                    starts.append(beginning)
                    break
                }
            }
        }
        let tolerance = max(2, Int(CGFloat(width) * 0.006))
        guard let staffStart = starts.sorted().first(where: { start in
            starts.filter { $0 >= start && $0 <= start + tolerance }.count >= 3
        }) else { return region }
        let right = CGFloat(staffStart - 2) / CGFloat(width)
        guard right > point.x + 0.002, right < region.maxX else { return region }
        return CGRect(x: region.minX, y: region.minY, width: right - region.minX, height: region.height)
    }

    static func searchRegion(around point: CGPoint) -> CGRect {
        CGRect(x: point.x - 0.30, y: point.y - 0.055, width: 0.60, height: 0.11)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    /// Select only text under or immediately beside the click. A blank-margin
    /// click must not silently choose the nearest title, tempo, or other staff.
    static func selectCandidate(from candidates: [Candidate], at point: CGPoint) -> Candidate? {
        guard validPoint(point) else { return nil }
        return candidates.compactMap { candidate -> (Candidate, CGFloat)? in
            let bounds = candidate.bounds
            let name = candidate.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard candidate.confidence.isFinite, candidate.confidence >= 0.25,
                  !bounds.isNull, !bounds.isEmpty,
                  [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY].allSatisfy(\.isFinite),
                  bounds.minX >= 0, bounds.minY >= 0, bounds.maxX <= 1, bounds.maxY <= 1,
                  name.unicodeScalars.filter({ CharacterSet.letters.contains($0) }).count >= 2 else { return nil }
            let dx = max(bounds.minX - point.x, point.x - bounds.maxX, 0)
            let dy = max(bounds.minY - point.y, point.y - bounds.maxY, 0)
            guard dx <= 0.018, dy <= min(0.008, max(0.003, bounds.height * 0.65)) else { return nil }
            let centerDistance = abs(point.y - bounds.midY) / max(bounds.height, 0.003)
            let score = dx * 100 + dy * 200 + centerDistance * 0.03 - CGFloat(candidate.confidence) * 0.005
            return (Candidate(text: name, bounds: bounds, confidence: candidate.confidence), score)
        }.min { $0.1 < $1.1 }?.0
    }

    /// A convenience default, not a claim about the score's actual grouping.
    /// The instrument row remains editable before whole-score Auto runs.
    static func suggestedStaffCount(for name: String) -> Int {
        let words = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter }).map(String.init)
        let grandStaffNames: Set<String> = ["piano", "pianoforte", "fortepiano", "klavier", "clavier", "harpsichord", "cembalo", "clavecin"]
        return words.contains(where: grandStaffNames.contains) ? 2 : 1
    }

    private static func validPoint(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite && (0...1).contains(point.x) && (0...1).contains(point.y)
    }
}
