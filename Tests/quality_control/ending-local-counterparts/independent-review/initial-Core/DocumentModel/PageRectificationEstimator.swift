import CoreGraphics
import PDFKit

struct PageRectificationEstimate {
    var rectification: PageRectification
    var angleDegrees: Double
}

enum PageRectificationEstimator {
    static func estimate(
        for page: PDFPage,
        pageIndex: Int,
        targetPixelWidth: CGFloat = 1200,
        minimumCorrectionDegrees: Double = 0.12
    ) -> PageRectificationEstimate? {
        guard let image = rasterizedImage(for: page, targetPixelWidth: targetPixelWidth) else { return nil }

        let samples = extractInkSamples(from: image)
        guard let angleDegrees = estimateAngle(samples: samples, imageSize: CGSize(width: image.width, height: image.height)) else {
            return nil
        }

        guard abs(angleDegrees) >= minimumCorrectionDegrees else { return nil }
        guard let rectification = rectification(
            pageIndex: pageIndex,
            angleDegrees: angleDegrees,
            pageSize: CGSize(width: image.width, height: image.height)
        ) else {
            return nil
        }

        return PageRectificationEstimate(rectification: rectification, angleDegrees: angleDegrees)
    }

    private struct InkSample {
        var x: Double
        var y: Double
        var weight: Double
    }

    private static func rasterizedImage(for page: PDFPage, targetPixelWidth: CGFloat) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = targetPixelWidth / max(bounds.width, 1)
        let pixelWidth = max(1, Int((bounds.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((bounds.height * scale).rounded(.up)))

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    private static func extractInkSamples(from image: CGImage, sampleStride: Int = 2) -> [InkSample] {
        guard let provider = image.dataProvider, let data = provider.data else { return [] }
        guard let bytes = CFDataGetBytePtr(data) else { return [] }

        let width = image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow

        let minX = Int(Double(width) * 0.03)
        let maxX = Int(Double(width) * 0.97)
        let minY = Int(Double(height) * 0.03)
        let maxY = Int(Double(height) * 0.97)

        var samples: [InkSample] = []
        samples.reserveCapacity((width / sampleStride) * (height / sampleStride) / 6)

        for rowIndex in Swift.stride(from: minY, to: maxY, by: sampleStride) {
            let row = bytes + rowIndex * bytesPerRow
            let y = Double(height - rowIndex - 1)

            for columnIndex in Swift.stride(from: minX, to: maxX, by: sampleStride) {
                let pixel = row + columnIndex * 4
                let red = Double(pixel[0]) / 255.0
                let green = Double(pixel[1]) / 255.0
                let blue = Double(pixel[2]) / 255.0
                let luma = 0.299 * red + 0.587 * green + 0.114 * blue
                let darkness = max(0.0, 1.0 - luma)

                if darkness > 0.22 {
                    samples.append(
                        InkSample(
                            x: Double(columnIndex),
                            y: y,
                            weight: darkness
                        )
                    )
                }
            }
        }

        return samples
    }

    private static func estimateAngle(samples: [InkSample], imageSize: CGSize) -> Double? {
        guard samples.count > 1_000 else { return nil }

        let centerX = imageSize.width / 2.0
        let centerY = imageSize.height / 2.0

        var bestAngle = 0.0
        var bestScore = -Double.infinity

        var angle = -4.0
        while angle <= 4.0 {
            let score = projectionScore(
                samples: samples,
                angleDegrees: angle,
                centerX: centerX,
                centerY: centerY
            )

            if score > bestScore {
                bestScore = score
                bestAngle = angle
            }

            angle += 0.25
        }

        let coarseBestAngle = bestAngle
        bestScore = -Double.infinity
        angle = coarseBestAngle - 0.35

        while angle <= coarseBestAngle + 0.35 {
            let score = projectionScore(
                samples: samples,
                angleDegrees: angle,
                centerX: centerX,
                centerY: centerY
            )

            if score > bestScore {
                bestScore = score
                bestAngle = angle
            }

            angle += 0.025
        }

        return bestAngle
    }

    private static func projectionScore(
        samples: [InkSample],
        angleDegrees: Double,
        centerX: Double,
        centerY: Double
    ) -> Double {
        let radians = angleDegrees * .pi / 180.0
        let sine = sin(radians)
        let cosine = cos(radians)
        let binSize = 1.5

        var histogram: [Int: Double] = [:]
        histogram.reserveCapacity(4096)
        var totalWeight = 0.0

        for sample in samples {
            let dx = sample.x - centerX
            let dy = sample.y - centerY
            let rotatedY = -sine * dx + cosine * dy
            let bin = Int((rotatedY / binSize).rounded())
            histogram[bin, default: 0.0] += sample.weight
            totalWeight += sample.weight
        }

        guard totalWeight > 0 else { return 0 }
        let energy = histogram.values.reduce(0.0) { partial, value in
            partial + value * value
        }
        return energy / (totalWeight * totalWeight)
    }

    private static func rectification(
        pageIndex: Int,
        angleDegrees: Double,
        pageSize: CGSize
    ) -> PageRectification? {
        let width = pageSize.width
        let height = pageSize.height
        guard width > 0, height > 0 else { return nil }

        let radians = angleDegrees * .pi / 180.0
        let absoluteCosine = abs(cos(radians))
        let absoluteSine = abs(sin(radians))
        let scale = min(
            width / (width * absoluteCosine + height * absoluteSine),
            height / (width * absoluteSine + height * absoluteCosine)
        ) * 0.998

        let halfWidth = width * scale / 2.0
        let halfHeight = height * scale / 2.0
        let centerX = width / 2.0
        let centerY = height / 2.0
        let cosine = cos(radians)
        let sine = sin(radians)

        func point(dx: Double, dy: Double) -> FractionPoint {
            let x = centerX + dx * cosine - dy * sine
            let y = centerY + dx * sine + dy * cosine

            return FractionPoint(
                x: x / width,
                y: 1.0 - (y / height)
            )
        }

        return PageRectification(
            pageIndex: pageIndex,
            topLeft: point(dx: -halfWidth, dy: halfHeight),
            topRight: point(dx: halfWidth, dy: halfHeight),
            bottomRight: point(dx: halfWidth, dy: -halfHeight),
            bottomLeft: point(dx: -halfWidth, dy: -halfHeight)
        ).normalized()
    }
}
