import CoreGraphics
import Foundation
import Vision

/// A crop of the printed source, never a transcription of its title. The OCR
/// text only identifies its bounds; exports keep the original printed pixels.
struct ScoreSourceHeaderCandidate: Equatable {
    var selection: SourceHeaderSelection
    var recognizedLines: [String]
}

enum ScoreSourceHeaderDetector {
    struct TextLine: Equatable {
        var text: String
        /// Normalized image coordinates with a top-left origin.
        var bounds: CGRect
        var confidence: Float
    }

    /// Supply the displayed (possibly rectified) raster and, when available,
    /// the staff geometry already found during score extraction.
    static func detect(in image: CGImage, pageIndex: Int,
                       staves: [ScoreObservedStaff]? = nil,
                       isCancelled: () -> Bool = { false }) -> ScoreSourceHeaderCandidate? {
        guard pageIndex >= 0, image.width > 0, image.height > 0, !isCancelled() else { return nil }
        let observed = staves ?? StaffBandDetector.detect(in: image, isCancelled: isCancelled)
            .candidates.map(ScoreObservedStaff.init)
        guard !isCancelled(), let first = observed.min(by: { ($0.staffLineFractions.first ?? 1) < ($1.staffLineFractions.first ?? 1) }),
              let firstLine = first.staffLineFractions.first, firstLine.isFinite,
              firstLine > 0.025, firstLine < 0.8 else { return nil }
        let height = min(image.height, max(1, Int((firstLine * Double(image.height)).rounded(.down))))
        guard let headerImage = image.cropping(to: CGRect(x: 0, y: 0, width: image.width, height: height)) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.003
        do {
            try VNImageRequestHandler(cgImage: headerImage, options: [:]).perform([request])
        } catch {
            return nil
        }
        guard !isCancelled() else { return nil }
        let fraction = CGFloat(height) / CGFloat(image.height)
        let lines = (request.results ?? []).compactMap { observation -> TextLine? in
            guard let result = observation.topCandidates(1).first else { return nil }
            let rect = observation.boundingBox
            return TextLine(text: result.string,
                bounds: CGRect(x: rect.minX, y: (1 - rect.maxY) * fraction,
                               width: rect.width, height: rect.height * fraction),
                confidence: result.confidence)
        }
        return select(from: lines, firstStaff: first, pageIndex: pageIndex,
                      imageSize: CGSize(width: image.width, height: image.height))
    }

    /// Kept separate from Vision so layout decisions can be exercised with
    /// adversarial labels, running page numbers, and notation directions.
    static func select(from lines: [TextLine], firstStaff: ScoreObservedStaff,
                       pageIndex: Int, imageSize: CGSize) -> ScoreSourceHeaderCandidate? {
        guard pageIndex >= 0, imageSize.width > 0, imageSize.height > 0,
              firstStaff.staffLineFractions.count == 5,
              firstStaff.staffLineFractions.allSatisfy(\.isFinite) else { return nil }
        let staffTop = firstStaff.staffLineFractions[0]
        let space = (firstStaff.staffLineFractions[4] - staffTop) / 4
        guard staffTop > 0, staffTop < 1, space > 0, space < 0.04 else { return nil }
        let safeBottom = staffTop - space * 2.2
        let valid = lines.filter { line in
            let r = line.bounds
            return line.confidence.isFinite && line.confidence >= 0.25 && !r.isEmpty && !r.isNull
                && [r.minX, r.minY, r.maxX, r.maxY].allSatisfy(\.isFinite)
                && r.minX >= 0 && r.minY >= 0 && r.maxX <= 1 && r.maxY <= 1
        }
        let eligible = valid.filter {
            $0.bounds.maxY <= safeBottom && isHeaderText($0.text) && !isMusicDirection($0.text)
        }
        // An ordinary running title or a lone composer credit should not make
        // a continuation page look like the score's opening header.
        let titles = eligible.filter {
            let letters = $0.text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            return letters >= 3 && $0.bounds.height >= max(space * 2.1, 0.008)
                && $0.bounds.midX >= 0.25 && $0.bounds.midX <= 0.75
                && $0.bounds.width >= 0.06
        }
        guard let title = titles.max(by: { $0.bounds.height < $1.bounds.height }) else { return nil }
        let topLimit = max(0, title.bounds.minY - max(0.035, title.bounds.height * 1.5))
        let selected = eligible.filter { $0.bounds.maxY >= topLimit }
        var box = selected.reduce(CGRect.null) { $0.union($1.bounds) }
        guard !box.isNull, box.width >= 0.08, box.height >= 0.012 else { return nil }
        let contentBottom = box.maxY
        let horizontalPad = max(3 / imageSize.width, 0.004)
        let verticalPad = max(2 / imageSize.height, min(0.003, space * 0.6))
        box = box.insetBy(dx: -horizontalPad, dy: -verticalPad)
        // Keep the source page's centered title and right-aligned composer in
        // those positions. Tight trimming to the title's left edge would shift
        // centered titles left when the crop is fitted across the part page.
        let sideMargin = max(0, min(box.minX, 1 - box.maxX))
        box.origin.x = sideMargin
        box.size.width = 1 - sideMargin * 2
        // A composer's second line can almost touch a tempo direction (Notte e
        // giorno). Protect the notation while retaining the complete credit.
        let firstNotationTop = valid.filter {
            $0.bounds.minY >= contentBottom - 1 / imageSize.height
                && (isMusicDirection($0.text) || $0.bounds.maxY > safeBottom)
        }.map(\.bounds.minY).min()
        let bottomLimit = min(safeBottom, firstNotationTop.map { $0 - 1 / imageSize.height } ?? safeBottom)
        box = box.intersection(CGRect(x: 0, y: 0, width: 1, height: max(0, bottomLimit)))
        guard !box.isEmpty, selected.allSatisfy({ box.contains($0.bounds) }), box.height >= 0.02 else { return nil }
        return ScoreSourceHeaderCandidate(selection: SourceHeaderSelection(pageIndex: pageIndex,
            topFraction: box.minY, bottomFraction: box.maxY,
            leftFraction: box.minX, rightFraction: 1 - box.maxX),
            recognizedLines: selected.sorted { lhs, rhs in
                abs(lhs.bounds.midY - rhs.bounds.midY) < space ? lhs.bounds.minX < rhs.bounds.minX : lhs.bounds.midY < rhs.bounds.midY
            }.map(\.text))
    }

    private static func isHeaderText(_ text: String) -> Bool {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        guard !["http", "www.", "imslp.org", "downloaded", "scanned by"].contains(where: folded.contains) else { return false }
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if letters >= 2 { return true }
        // Life dates and publication years are part of a printed credit; short
        // numeric folios (including '(249) 1') are not.
        return text.range(of: #"\b(?:1[5-9]|20)\d{2}\b"#, options: .regularExpression) != nil
    }

    private static func isMusicDirection(_ text: String) -> Bool {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = folded.split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard let first = words.first else { return false }
        if first == "a", words.dropFirst().first == "tempo" { return true }
        if first == "con", let next = words.dropFirst().first,
           ["brio", "moto", "anima", "fuoco", "espressione"].contains(next) { return true }
        let directions: Set<String> = ["allegro", "allegretto", "adagio", "andante", "andantino", "presto", "prestissimo", "largo", "larghetto", "lento", "moderato", "vivace", "grave", "maestoso", "molto", "sostenuto", "scherzo", "sotto", "dolce", "espressivo", "ritardando", "ritenuto", "tempo", "poco"]
        return directions.contains(first)
    }
}
