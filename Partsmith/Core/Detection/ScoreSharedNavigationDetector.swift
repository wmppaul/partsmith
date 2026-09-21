import CoreGraphics
import Foundation
import Vision

/// Experimental recognition of printed jump/finish instructions. Recognized
/// text only locates original source pixels; it is never engraved as new text.
/// System ownership is resolved independently of the OCR window's anchor.
enum ScoreSharedNavigationDetector {
    struct TextLine {
        var text: String
        /// Top-down normalized source-image rectangle.
        var bounds: CGRect
        var confidence: Float
    }

    struct OCRRegion {
        var bounds: CGRect
        var beforeStaffID: Int?
        var afterStaffID: Int?
    }

    enum Kind: Equatable { case daCapo, dalSegno, fine }

    private struct Owner {
        var staff: ScoreObservedStaff
        var system: Int
        var first: Bool
        var last: Bool
        var distance: Double
        var centerDistance: Double
        var space: Double
    }

    static func detect(in image: CGImage, page: ScorePageAnalysis,
                       profile: ScoreExtractionProfile,
                       observedText: ((OCRRegion, [TextLine]) -> Void)? = nil,
                       isCancelled: () -> Bool = { false }) -> [ScoreSharedNavigation] {
        guard image.width > 0, image.height > 0, !isCancelled() else { return [] }
        // Recognition must not turn an uncertain roster into shared ownership.
        // Existing recognition metadata does not participate in this validation.
        var geometry = page
        geometry.sharedHeadings = nil
        geometry.sharedNavigation = nil
        let plan = ScoreExtractionPlanner.plan(pages: [geometry], profile: profile, isCancelled: isCancelled)
        guard plan.canApply, !isCancelled(), let raster = recognitionRaster(image) else { return [] }
        var lines: [TextLine] = []
        for region in regions(for: geometry.staves) {
            guard !isCancelled() else { return [] }
            let top = floor(region.bounds.minY * Double(raster.height))
            let bottom = ceil(region.bounds.maxY * Double(raster.height))
            let rect = CGRect(x: 0, y: top, width: Double(raster.width), height: bottom - top)
            guard let crop = raster.cropping(to: rect), crop.height > 5 else { continue }
            let found: [TextLine] = autoreleasepool {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en-US"]
                request.minimumTextHeight = 0.012
                request.customWords = ["Da Capo", "Dal Segno", "D.C.", "D.S.", "Fine", "Coda", "Capo", "Segno", "sin", "poi"]
                do { try VNImageRequestHandler(cgImage: crop, options: [:]).perform([request]) }
                catch { return [] }
                return (request.results ?? []).compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let b = observation.boundingBox
                    return TextLine(text: candidate.string,
                        bounds: CGRect(x: b.minX, y: (rect.minY + (1 - b.maxY) * rect.height) / Double(raster.height),
                                       width: b.width, height: b.height * rect.height / Double(raster.height)),
                        confidence: candidate.confidence)
                }
            }
            guard !isCancelled() else { return [] }
            observedText?(region, found)
            lines += found
        }
        return select(from: lines, page: geometry, plan: plan, isCancelled: isCancelled)
    }

    /// The same gap windows as the source-verified scratch prototype. A window
    /// before staff N may contain a direction belonging to the preceding system.
    static func regions(for staves: [ScoreObservedStaff]) -> [OCRRegion] {
        guard staves.allSatisfy(validStaff) else { return [] }
        let ordered = staves.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
        var result: [OCRRegion] = []
        for (index, staff) in ordered.enumerated() {
            let lines = staff.staffLineFractions, space = (lines[4] - lines[0]) / 4
            let previous = index > 0 ? ordered[index - 1] : nil
            let top = max(0, previous.map { $0.staffLineFractions[4] - space * 2 } ?? (lines[0] - space * 16))
            let bottom = min(1, lines[0] - space * 0.1)
            if bottom > top {
                result.append(OCRRegion(bounds: CGRect(x: 0, y: top, width: 1, height: bottom - top),
                    beforeStaffID: staff.id, afterStaffID: previous?.id))
            }
        }
        if let last = ordered.last {
            let lines = last.staffLineFractions, space = (lines[4] - lines[0]) / 4
            let top = max(0, lines[4] - space * 2), bottom = min(1, lines[4] + space * 16)
            if bottom > top {
                result.append(OCRRegion(bounds: CGRect(x: 0, y: top, width: 1, height: bottom - top),
                    beforeStaffID: nil, afterStaffID: last.id))
            }
        }
        return result
    }

    static func select(from lines: [TextLine], page: ScorePageAnalysis, plan: ScoreExtractionPlan,
                       isCancelled: () -> Bool = { false }) -> [ScoreSharedNavigation] {
        guard plan.canApply, page.pageWidth.isFinite, page.pageWidth > 0,
              page.pageHeight.isFinite, page.pageHeight > 0, page.staves.allSatisfy(validStaff),
              !isCancelled() else { return [] }
        let bands = plan.bands.filter { $0.pageIndex == page.pageIndex && $0.kind == "music" }
        let ownership = Dictionary(grouping: bands.flatMap { band in band.candidateIDs.map { ($0, band.systemIndex) } }, by: { $0.0 })
        guard page.staves.allSatisfy({ ownership[$0.id]?.count == 1 }) else { return [] }
        let grouped = Dictionary(grouping: page.staves, by: { ownership[$0.id]![0].1 })
        var found: [(ScoreSharedNavigation, Kind, Double)] = []
        for line in lines {
            guard !isCancelled() else { return [] }
            let r = line.bounds
            guard let kind = navigationKind(line.text), line.confidence.isFinite, line.confidence >= 0.65,
                  !r.isEmpty, !r.isNull, [r.minX, r.minY, r.maxX, r.maxY].allSatisfy(\.isFinite),
                  r.minX >= 0, r.minY >= 0, r.maxX <= 1, r.maxY <= 1 else { continue }
            var owners: [Owner] = []
            for staff in page.staves {
                let ys = staff.staffLineFractions, system = ownership[staff.id]![0].1
                let systemStaves = grouped[system]!.sorted { $0.staffLineFractions[0] < $1.staffLineFractions[0] }
                owners.append(Owner(staff: staff, system: system,
                    first: systemStaves.first?.id == staff.id, last: systemStaves.last?.id == staff.id,
                    distance: max(ys[0] - r.maxY, r.minY - ys[4], 0),
                    centerDistance: abs(r.midY - (ys[0] + ys[4]) / 2), space: (ys[4] - ys[0]) / 4))
            }
            owners.sort { $0.distance == $1.distance ? $0.centerDistance < $1.centerDistance : $0.distance < $1.distance }
            guard let owner = owners.first, owner.distance <= owner.space * 8,
                  r.height >= owner.space * 0.6, r.height <= owner.space * 7 else { continue }
            // A close alternative system must stay unresolved, even when OCR
            // happened to put the line in one system's search window.
            if let other = owners.first(where: { $0.system != owner.system }),
               other.distance - owner.distance < owner.space * 0.75 { continue }
            let isBelow = r.minY >= owner.staff.staffLineFractions[4]
            let isAbove = r.maxY <= owner.staff.staffLineFractions[0]
            guard (isBelow && owner.last) || (isAbove && owner.first) else { continue }
            if kind == .fine && r.minX < 0.5 { continue }
            // Padding is in physical staff spaces on both axes. It retains
            // caps, dots and symbols omitted by an OCR word envelope.
            let padX = owner.space * page.pageHeight / page.pageWidth
            let box = r.insetBy(dx: -padX, dy: -owner.space).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            let candidate = ScoreSharedNavigation(anchorStaffID: owner.staff.id,
                bounds: [box.minX, box.minY, box.maxX, box.maxY], recognizedText: line.text, isBelow: isBelow)
            // Overlapping search windows can return the same sentence twice.
            // Separate text columns must not be joined through intervening ink.
            if let index = found.firstIndex(where: { previous in
                let b = previous.0.bounds
                let overlap = min(b[2], box.maxX) - max(b[0], box.minX)
                return previous.0.anchorStaffID == candidate.anchorStaffID && previous.0.isBelow == isBelow
                    && previous.1 == kind && abs((b[1] + b[3]) / 2 - box.midY) < owner.space
                    && overlap >= min(b[2] - b[0], box.width) * 0.5
            }) {
                let b = found[index].0.bounds
                found[index].0.bounds = [min(b[0], box.minX), min(b[1], box.minY), max(b[2], box.maxX), max(b[3], box.maxY)]
            } else { found.append((candidate, kind, owner.space)) }
        }
        return isCancelled() ? [] : found.map(\.0)
    }

    static func navigationKind(_ text: String) -> Kind? {
        let value = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "’", with: "'").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard value.count <= 180 else { return nil }
        func matches(_ pattern: String) -> Bool { value.range(of: pattern, options: .regularExpression) != nil }
        // Exact Capo/Segno anchors; allow a single vowel OCR confusion only in
        // the short preposition, as independently observed on old engraving.
        if matches(#"^d[auo]\s*capo\b"#) || matches(#"^d\s*[.·]\s*c\s*(?:[.·]|(?=\s|$))"#)
            || matches(#"^d\s*c\s+al\s+(?:fine|coda)\b"#) { return .daCapo }
        if matches(#"^d[ae]l\s*segno\b"#) || matches(#"^d\s*[.·]\s*s\s*(?:[.·]|(?=\s|$))"#)
            || matches(#"^d\s*s\s+al\s+(?:fine|coda)\b"#) { return .dalSegno }
        if matches(#"^fine\s*[.!]?$"#) { return .fine }
        return nil
    }

    private static func validStaff(_ staff: ScoreObservedStaff) -> Bool {
        let lines = staff.staffLineFractions
        return lines.count == 5 && lines.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
            && zip(lines, lines.dropFirst()).allSatisfy { $0 < $1 }
    }

    private static func recognitionRaster(_ image: CGImage) -> CGImage? {
        let scale = min(2400 / Double(image.width), 3500 / Double(image.height))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        if width == image.width, height == image.height { return image }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
