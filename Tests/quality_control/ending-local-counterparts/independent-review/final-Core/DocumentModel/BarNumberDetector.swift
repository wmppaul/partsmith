import CoreGraphics
import Foundation
import PDFKit
import Vision

enum BarNumberDetector {
    struct Detection {
        var value: Int
        var confidence: Double
        var method: BarNumberDetectionMethod
    }

    private struct OCRCandidate {
        var value: Int
        var confidence: Double
        var bounds: CGRect
        var usesFlippedY: Bool
    }

    private static let digitRegex = try! NSRegularExpression(pattern: #"(?<![/\d])\d{1,3}(?![/\d])"#)

    static func detect(
        band: BandModel,
        systemBands: [BandModel],
        pdfDocument: PDFDocument,
        rectification: PageRectification?,
        sourcePageCache: SourcePageRenderCache
    ) -> Detection? {
        guard let page = pdfDocument.page(at: band.pageIndex) else { return nil }
        guard let pageBounds = sourcePageCache.pageBounds(for: band.pageIndex) else { return nil }

        let bandRect = band.cropRect(in: pageBounds)
        let systemRect = systemRect(for: band, systemBands: systemBands, pageBounds: pageBounds)
        let candidateRects = searchRects(for: bandRect, systemRect: systemRect, pageBounds: pageBounds)

        if let detection = detectFromPDFText(page: page, candidateRects: candidateRects) {
            return detection
        }

        guard let detectionImage = sourcePageCache.imageForDetection(
            pageIndex: band.pageIndex,
            rectification: rectification
        ) else {
            return nil
        }

        return detectFromOCR(
            image: detectionImage.image,
            pageBounds: detectionImage.pageBounds,
            systemRect: systemRect
        )
    }

    private static func systemRect(for band: BandModel, systemBands: [BandModel], pageBounds: CGRect) -> CGRect {
        let relevantBands = systemBands.isEmpty ? [band] : systemBands
        return relevantBands.reduce(CGRect.null) { partialRect, systemBand in
            let rect = systemBand.cropRect(in: pageBounds)
            if partialRect.isNull {
                return rect
            }
            return partialRect.union(rect)
        }
    }

    private static func searchRects(for bandRect: CGRect, systemRect: CGRect, pageBounds: CGRect) -> [CGRect] {
        let bandWidth = bandRect.width
        let bandHeight = bandRect.height
        let systemHeight = systemRect.height
        let leftSearchX = pageBounds.minX
        let systemSearchWidth = pageBounds.width * 0.42
        let verticalPadding = max(pageBounds.height * 0.035, systemHeight * 0.22)
        let upperSystemHeight = min(pageBounds.height * 0.20, max(systemHeight * 0.45, bandHeight * 1.35))

        let rawRects = [
            CGRect(
                x: leftSearchX,
                y: systemRect.minY - verticalPadding,
                width: systemSearchWidth,
                height: systemHeight + verticalPadding * 2
            ),
            CGRect(
                x: leftSearchX,
                y: systemRect.maxY - upperSystemHeight,
                width: pageBounds.width * 0.32,
                height: upperSystemHeight + verticalPadding
            ),
            CGRect(
                x: leftSearchX,
                y: bandRect.minY - verticalPadding,
                width: pageBounds.width * 0.35,
                height: bandRect.height + verticalPadding * 2
            ),
            CGRect(
                x: max(pageBounds.minX, bandRect.minX - pageBounds.width * 0.08),
                y: bandRect.maxY - bandHeight * 1.35,
                width: min(pageBounds.width * 0.35, bandWidth * 0.24),
                height: min(pageBounds.height * 0.20, bandHeight * 1.75)
            ),
            CGRect(
                x: leftSearchX,
                y: systemRect.maxY - pageBounds.height * 0.18,
                width: pageBounds.width * 0.28,
                height: pageBounds.height * 0.22
            )
        ]

        return rawRects.compactMap { rect in
            let clippedRect = rect.intersection(pageBounds)
            guard clippedRect.isNull == false, clippedRect.isEmpty == false else { return nil }
            return clippedRect
        }
    }

    private static func detectFromPDFText(page: PDFPage, candidateRects: [CGRect]) -> Detection? {
        for rect in candidateRects {
            guard let selection = page.selection(for: rect),
                  let string = selection.string,
                  let value = firstIntegerToken(in: string)
            else {
                continue
            }

            return Detection(value: value, confidence: 0.99, method: .pdfText)
        }

        return nil
    }

    private static func detectFromOCR(
        image: CGImage,
        pageBounds: CGRect,
        systemRect: CGRect
    ) -> Detection? {
        let systemSearchRect = ocrSearchRect(for: systemRect, pageBounds: pageBounds)
        let roiRects = [
            nil,
            normalizedVisionRect(fromPageRect: systemSearchRect, in: pageBounds, flippedY: false),
            normalizedVisionRect(fromPageRect: systemSearchRect, in: pageBounds, flippedY: true)
        ]
        let candidates = roiRects.flatMap { roi in
            performOCRCandidates(
                image: image,
                pageBounds: pageBounds,
                regionOfInterest: roi
            )
        }

        guard let bestCandidate = bestOCRCandidate(
            from: candidates,
            systemRect: systemRect,
            pageBounds: pageBounds
        ) else {
            return nil
        }

        return Detection(
            value: bestCandidate.value,
            confidence: bestCandidate.confidence,
            method: .ocr
        )
    }

    private static func performOCRCandidates(
        image: CGImage,
        pageBounds: CGRect,
        regionOfInterest: CGRect?
    ) -> [OCRCandidate] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.006
        if let regionOfInterest {
            request.regionOfInterest = regionOfInterest
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        return (request.results ?? []).flatMap { textObservation -> [OCRCandidate] in
            guard let recognizedText = textObservation.topCandidates(1).first else { return [] }
            return ocrCandidates(
                from: recognizedText,
                observation: textObservation,
                pageBounds: pageBounds
            )
        }
    }

    private static func ocrCandidates(
        from recognizedText: VNRecognizedText,
        observation: VNRecognizedTextObservation,
        pageBounds: CGRect
    ) -> [OCRCandidate] {
        integerTokenRanges(in: recognizedText.string).flatMap { tokenRange, value -> [OCRCandidate] in
            let tokenBounds: CGRect
            do {
                tokenBounds = try recognizedText.boundingBox(for: tokenRange)?.boundingBox ?? observation.boundingBox
            } catch {
                tokenBounds = observation.boundingBox
            }
            let normalBounds = pageRect(fromNormalizedVisionRect: tokenBounds, in: pageBounds, flippedY: false)
            let flippedBounds = pageRect(fromNormalizedVisionRect: tokenBounds, in: pageBounds, flippedY: true)

            return [
                OCRCandidate(
                    value: value,
                    confidence: Double(recognizedText.confidence),
                    bounds: normalBounds,
                    usesFlippedY: false
                ),
                OCRCandidate(
                    value: value,
                    confidence: Double(recognizedText.confidence) * 0.94,
                    bounds: flippedBounds,
                    usesFlippedY: true
                )
            ]
        }
    }

    private static func bestOCRCandidate(
        from candidates: [OCRCandidate],
        systemRect: CGRect,
        pageBounds: CGRect
    ) -> OCRCandidate? {
        candidates
            .compactMap { candidate -> (candidate: OCRCandidate, score: Double)? in
                guard let score = ocrCandidateScore(
                    candidate,
                    systemRect: systemRect,
                    pageBounds: pageBounds
                ) else {
                    return nil
                }
                return (candidate, score)
            }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.001 {
                    return lhs.score > rhs.score
                }

                if abs(lhs.candidate.bounds.minX - rhs.candidate.bounds.minX) > pageBounds.width * 0.01 {
                    return lhs.candidate.bounds.minX < rhs.candidate.bounds.minX
                }

                return lhs.candidate.confidence > rhs.candidate.confidence
            }
            .first?
            .candidate
    }

    private static func ocrCandidateScore(
        _ candidate: OCRCandidate,
        systemRect: CGRect,
        pageBounds: CGRect
    ) -> Double? {
        guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }
        guard candidate.bounds.isNull == false, candidate.bounds.isEmpty == false else { return nil }

        let center = CGPoint(x: candidate.bounds.midX, y: candidate.bounds.midY)
        let leftSearchLimit = pageBounds.minX + pageBounds.width * 0.46
        guard center.x <= leftSearchLimit else { return nil }

        let verticalPadding = max(pageBounds.height * 0.025, systemRect.height * 0.18)
        let verticalLimit = max(pageBounds.height * 0.11, systemRect.height * 0.58)
        let verticalDistance: CGFloat
        if center.y < systemRect.minY - verticalPadding {
            verticalDistance = systemRect.minY - verticalPadding - center.y
        } else if center.y > systemRect.maxY + verticalPadding {
            verticalDistance = center.y - systemRect.maxY - verticalPadding
        } else {
            verticalDistance = 0
        }
        guard verticalDistance <= verticalLimit else {
            return nil
        }

        let normalizedLeftness = 1 - clamped(
            Double((center.x - pageBounds.minX) / max(pageBounds.width * 0.46, 1))
        )
        let normalizedVerticalFit = 1 - clamped(Double(verticalDistance / max(verticalLimit, 1)))
        let normalizedStartFit = 1 - clamped(
            Double(abs(center.x - systemRect.minX) / max(pageBounds.width * 0.30, 1))
        )
        let orientationPenalty = candidate.usesFlippedY ? 0.04 : 0

        return clamped(candidate.confidence) * 0.42 +
            normalizedVerticalFit * 0.34 +
            normalizedLeftness * 0.16 +
            normalizedStartFit * 0.08 -
            orientationPenalty
    }

    private static func pageRect(fromNormalizedVisionRect rect: CGRect, in pageBounds: CGRect, flippedY: Bool) -> CGRect {
        let minY = flippedY ? 1 - rect.maxY : rect.minY
        return CGRect(
            x: pageBounds.minX + rect.minX * pageBounds.width,
            y: pageBounds.minY + minY * pageBounds.height,
            width: rect.width * pageBounds.width,
            height: rect.height * pageBounds.height
        )
    }

    private static func ocrSearchRect(for systemRect: CGRect, pageBounds: CGRect) -> CGRect {
        let verticalPadding = max(pageBounds.height * 0.045, systemRect.height * 0.24)
        return CGRect(
            x: pageBounds.minX,
            y: systemRect.minY - verticalPadding,
            width: pageBounds.width * 0.50,
            height: systemRect.height + verticalPadding * 2
        ).intersection(pageBounds)
    }

    private static func normalizedVisionRect(fromPageRect rect: CGRect, in pageBounds: CGRect, flippedY: Bool) -> CGRect? {
        guard rect.isNull == false, rect.isEmpty == false else { return nil }
        guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }

        let minX = (rect.minX - pageBounds.minX) / pageBounds.width
        let maxX = (rect.maxX - pageBounds.minX) / pageBounds.width
        let minY = (rect.minY - pageBounds.minY) / pageBounds.height
        let maxY = (rect.maxY - pageBounds.minY) / pageBounds.height
        let normalizedY = flippedY ? 1 - maxY : minY

        let normalizedRect = CGRect(
            x: minX,
            y: normalizedY,
            width: maxX - minX,
            height: maxY - minY
        )

        guard normalizedRect.minX < 1, normalizedRect.maxX > 0, normalizedRect.minY < 1, normalizedRect.maxY > 0 else {
            return nil
        }

        return CGRect(
            x: max(0, normalizedRect.minX),
            y: max(0, normalizedRect.minY),
            width: min(1, normalizedRect.maxX) - max(0, normalizedRect.minX),
            height: min(1, normalizedRect.maxY) - max(0, normalizedRect.minY)
        )
    }

    private static func integerTokenRanges(in string: String) -> [(Range<String.Index>, Int)] {
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return digitRegex.matches(in: string, options: [], range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: string),
                  let value = Int(string[tokenRange]),
                  (1...999).contains(value)
            else {
                return nil
            }

            return (tokenRange, value)
        }
    }

    private static func firstIntegerToken(in string: String) -> Int? {
        integerTokenRanges(in: string).first?.1
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
