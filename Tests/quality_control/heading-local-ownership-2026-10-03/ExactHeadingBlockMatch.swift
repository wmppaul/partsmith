import CoreGraphics
import Foundation

/// Experimental conservative gate, not installed in Partsmith. Matching OCR
/// words alone cannot establish equality of every printed heading symbol.
/// Compare the whole supplied source block; only white exterior padding and
/// integer translation are immaterial. Font/scan differences remain unknown.
enum ExactHeadingBlockMatch {
    struct InkBlock: Equatable {
        var width: Int
        var height: Int
        var pixels: [UInt8]
    }

    static func block(_ image: CGImage) -> InkBlock? {
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var left = width, top = height, right = 0, bottom = 0
        for y in 0..<height { for x in 0..<width where pixels[y * width + x] < 255 {
            left = min(left, x); right = max(right, x + 1)
            top = min(top, y); bottom = max(bottom, y + 1)
        } }
        guard left < right, top < bottom else { return nil }
        var ink: [UInt8] = []
        ink.reserveCapacity((right - left) * (bottom - top))
        for y in top..<bottom { for x in left..<right { ink.append(pixels[y * width + x]) } }
        return InkBlock(width: right - left, height: bottom - top, pixels: ink)
    }

    static func equivalent(_ global: CGImage, _ local: CGImage,
                           globalText: String, localText: String) -> Bool {
        func normalized(_ value: String) -> String {
            value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                .lowercased(with: Locale(identifier: "en_US_POSIX"))
        }
        let expected = normalized(globalText)
        guard !expected.isEmpty, expected == normalized(localText),
              let a = block(global), let b = block(local) else { return false }
        return a == b
    }
}
