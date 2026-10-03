import Foundation

/// Recognition evidence describes the source glyph; export always copies the
/// printed pixels. In particular, ambiguous fast-OCR "I" is never re-engraved.
struct ScoreEndingTextEvidence: Codable, Equatable {
    var mode: String
    var text: String
    var confidence: Float
    var bounds: [Double]
}

struct ScoreEndingMember: Codable, Equatable {
    enum Role: String, Codable { case first, second }
    var sourcePageIndex: Int
    var sourceSystemIndex: Int
    var anchorStaffID: Int
    /// Normalized source-copy bounds in the recorded display coordinates.
    var bounds: [Double]
    var role: Role
    var evidence: [ScoreEndingTextEvidence]
}

/// Kept separate from navigation instructions and destination symbols so a
/// rescan of those categories cannot silently remove paired-ending evidence.
struct ScoreSharedEnding: Codable, Equatable {
    var sourcePageIndex: Int
    var anchorStaffID: Int
    var systemIndex: Int
    var bounds: [Double]
    /// Both source members are retained on each page-local copy, including a
    /// cross-page pair. Changes to either source invalidate both halves.
    var members: [ScoreEndingMember]
    var localCounterparts: [ScoreEndingLocalCounterpart]? = nil

    var pairPageIndices: [Int] { Array(Set(members.map(\.sourcePageIndex))).sorted() }
    var pairID: String {
        members.map { member in
            "\(member.role.rawValue):\(member.sourcePageIndex):\(member.sourceSystemIndex):\(member.anchorStaffID):"
                + member.bounds.map { String($0) }.joined(separator: ",")
        }.joined(separator: "|")
    }
    var label: String {
        let local = members.filter { $0.sourcePageIndex == sourcePageIndex && $0.anchorStaffID == anchorStaffID && $0.sourceSystemIndex == systemIndex }
        return local.count == 2 ? "Printed first and second endings" : "Printed paired ending"
    }

    func isValid(on page: ScorePageAnalysis) -> Bool {
        guard sourcePageIndex == page.pageIndex, members.count == 2, members.map(\.role) == [.first, .second],
              Self.validBounds(bounds), members.allSatisfy({ $0.sourcePageIndex >= 0 && $0.sourceSystemIndex >= 0
                  && Self.validBounds($0.bounds) }),
              page.staves.contains(where: { $0.id == anchorStaffID }) else { return false }
        let local = members.filter { $0.sourcePageIndex == page.pageIndex
            && $0.sourceSystemIndex == systemIndex && $0.anchorStaffID == anchorStaffID }
        guard !local.isEmpty else { return false }
        let expected = Self.union(local.map(\.bounds))
        return zip(bounds, expected).allSatisfy { abs($0 - $1) < 1e-9 }
    }

    var sourceMarking: ScoreSourceMarking {
        ScoreSourceMarking(topFraction: bounds[1], bottomFraction: bounds[3],
            leftFraction: bounds[0], rightFraction: 1 - bounds[2])
    }
    static func validBounds(_ b: [Double]) -> Bool {
        b.count == 4 && b.allSatisfy(\.isFinite) && b[0] >= 0 && b[1] >= 0
            && b[0] < b[2] && b[1] < b[3] && b[2] <= 1 && b[3] <= 1
    }
    static func union(_ rectangles: [[Double]]) -> [Double] {
        [rectangles.map { $0[0] }.min()!, rectangles.map { $0[1] }.min()!,
         rectangles.map { $0[2] }.max()!, rectangles.map { $0[3] }.max()!]
    }
}
