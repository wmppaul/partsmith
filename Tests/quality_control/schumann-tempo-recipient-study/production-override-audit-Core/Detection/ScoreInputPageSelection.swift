import Foundation

/// Printed page numbers in the picker are one-based; extraction retains the
/// original zero-based PDF indices, including gaps in a selection.
enum ScoreInputPageSelection {
    static func parse(_ text: String, pageCount: Int) -> Set<Int>? {
        guard pageCount >= 0 else { return nil }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        if text.isEmpty { return [] }
        var pages = Set<Int>()
        for item in text.split(separator: ",", omittingEmptySubsequences: false) {
            let ends = item.split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard (1...2).contains(ends.count),
                  ends.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
                  let first = Int(ends[0]), let last = Int(ends.last!),
                  first >= 1, first <= last, last <= pageCount else { return nil }
            pages.formUnion((first - 1)..<last)
        }
        return pages
    }

    static func formatted(_ pages: Set<Int>) -> String {
        let sorted = pages.sorted()
        guard var first = sorted.first else { return "" }
        var last = first
        var ranges: [String] = []
        func appendRange() {
            ranges.append(first == last ? "\(first + 1)" : "\(first + 1)-\(last + 1)")
        }
        for page in sorted.dropFirst() {
            if page == last + 1 { last = page }
            else { appendRange(); first = page; last = page }
        }
        appendRange()
        return ranges.joined(separator: ", ")
    }
}
