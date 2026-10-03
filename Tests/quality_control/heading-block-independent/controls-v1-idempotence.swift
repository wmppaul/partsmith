import CoreGraphics
import Foundation
import ImageIO

/// Independent acceptance/negative controls. The original source envelope was
/// frozen in schumann-native-output-independent before this grouping change.
@main enum IndependentHeadingControls {
    struct Result: Codable { var id: String; var pass: Bool; var details: String }
    static var results: [Result] = []
    static func check(_ id: String, _ condition: Bool, _ details: String = "") {
        results.append(.init(id: id, pass: condition, details: details))
        if !condition { print("FAIL \(id): \(details)") }
    }
    static func h(_ r: [Double], _ text: String = "Allegro", _ anchor: Int = 0) -> ScoreSharedHeading {
        .init(anchorStaffID: anchor, bounds: r, recognizedText: text)
    }
    static func contains(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == 4 && b.count == 4 && a[0] <= b[0] && a[1] <= b[1] && a[2] >= b[2] && a[3] >= b[3]
    }
    static func sameCopies(_ a: [ScoreSourceMarking], _ b: [ScoreSourceMarking]) -> Bool {
        a.count == b.count && zip(a,b).allSatisfy { x,y in
            x.isBelow == y.isBelow && zip([x.leftFraction,x.topFraction,x.rightFraction,x.bottomFraction],
                [y.leftFraction,y.topFraction,y.rightFraction,y.bottomFraction]).allSatisfy { abs($0-$1) < 1e-12 }
        }
    }
    static func staff(_ id: Int, _ y: Double) -> ScoreObservedStaff {
        .init(StaffBandCandidate(id: id, staffLineFractions: (0..<5).map { y + Double($0) * 0.005 },
            topFraction: y - 0.01, bottomFraction: y + 0.03, confidence: 1, warnings: []))
    }
    static func main() throws {
        let sourceA = h([0.1282812864962117, 0.05113637285723365, 0.23945127346041578, 0.07079755299455603], "SCHERZO")
        let sourceB = h([0.1384917426134493, 0.06218179659656142, 0.287380353345853, 0.08060961565128615], "Molto vivace. d.=138.")
        let fullGuard = [65.9/513, 40.56666666666666/739, 146.1/513, 58.1/739]
        let merged = ScoreSharedHeading.coalesced([sourceA, sourceB])
        check("p26-one-block", merged.count == 1)
        check("p26-independent-full-source-envelope", merged.count == 1 && contains(merged[0].bounds, fullGuard))
        check("p26-both-source-fragments-retained", merged.count == 1 && contains(merged[0].bounds, sourceA.bounds) && contains(merged[0].bounds, sourceB.bounds))
        let reversed = ScoreSharedHeading.coalesced([sourceB, sourceA])
        check("p26-order-independent-geometry", merged.map(\.bounds) == reversed.map(\.bounds))
        check("p26-both-text-labels-retained", merged.first?.recognizedText.contains("SCHERZO") == true && merged.first?.recognizedText.contains("138") == true)

        let a = h([0.1, 0.1, 0.4, 0.4], "Allegro")
        let b = h([0.3, 0.3, 0.6, 0.6], "Vivace")
        let unionCorner = h([0.45, 0.15, 0.55, 0.25], "Coda")
        check("union-must-not-bridge-originally-disjoint-event", ScoreSharedHeading.coalesced([a,b,unionCorner]).count == 2)
        check("union-bridge-order-reversed", ScoreSharedHeading.coalesced([unionCorner,b,a]).count == 2)
        let once = ScoreSharedHeading.coalesced([a,b,unionCorner])
        let twice = ScoreSharedHeading.coalesced(once)
        check("union-bridge-idempotence",twice == once,"first=\(once.map(\.bounds)); second=\(twice.map(\.bounds))")
        let roundtrip = try JSONDecoder().decode([ScoreSharedHeading].self,from:JSONEncoder().encode(once))
        check("union-bridge-survives-codable-roundtrip",ScoreSharedHeading.coalesced(roundtrip) == once)
        var repeated = once
        for _ in 0..<5 { repeated=ScoreSharedHeading.coalesced(repeated) }
        check("union-bridge-five-pipeline-reapplications",repeated == once)
        let chain = h([0.5, 0.5, 0.7, 0.7], "Presto")
        check("true-transitive-overlap-retains-all-fragments", ScoreSharedHeading.coalesced([a,b,chain]).map(\.bounds) == [[0.1,0.1,0.7,0.7]])
        let separate: [(String, ScoreSharedHeading)] = [
            ("x-gap", h([0.41,0.15,0.5,0.3])), ("y-gap", h([0.15,0.41,0.3,0.5])),
            ("x-touch", h([0.4,0.15,0.5,0.3])), ("y-touch", h([0.15,0.4,0.3,0.5])),
            ("corner-touch", h([0.4,0.4,0.5,0.5])), ("anchor-differs", h(a.bounds,"Allegro",6)),
            ("empty-bounds",h([])), ("zero-width",h([0.2,0.2,0.2,0.3])),
            ("outside-page",h([-0.1,0.2,0.3,0.3])), ("nonfinite",h([0.2,.nan,0.3,0.3]))
        ]
        for (name,x) in separate { check("separate-\(name)", ScoreSharedHeading.coalesced([a,x]).count == 2) }
        check("strict-positive-subpixel-overlap", ScoreSharedHeading.coalesced([a,h([0.4-1e-10,0.2,0.5,0.3])]).count == 1)
        check("duplicate-boxes-group", ScoreSharedHeading.coalesced([a,a]).count == 1)
        var measuredA = a; measuredA.inkBounds = [0.12,0.12,0.35,0.35]
        var measuredB = b; measuredB.inkBounds = [0.32,0.32,0.55,0.55]
        check("stale-individual-ink-cleared-on-union", ScoreSharedHeading.coalesced([measuredA,measuredB])[0].inkBounds == nil)
        check("unchanged-single-line-preserves-ink-evidence", ScoreSharedHeading.coalesced([measuredA]) == [measuredA])

        // Newly enclosed union corners may contain original source ink. That ink
        // must be measured too; union of old fragment ink cannot certify it.
        var pixels = [UInt8](repeating: 255, count: 100*100)
        for (x,y,v) in [(15,15,UInt8(0)),(50,50,UInt8(0)),(50,20,UInt8(254))] { pixels[y*100+x] = v }
        let raster = CGImage(width: 100,height: 100,bitsPerComponent: 8,bitsPerPixel: 8,bytesPerRow: 100,
            space: CGColorSpaceCreateDeviceGray(),bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: CGDataProvider(data: Data(pixels) as CFData)!,decode: nil,shouldInterpolate: false,intent: .defaultIntent)!
        let remeasured = ScoreSharedHeadingDetector.measuredInkBounds(in: raster,bounds: [0.1,0.1,0.6,0.6])
        check("union-remeasurement-includes-new-corner-faint-pixel", remeasured == [0.14,0.14,0.52,0.52], String(describing: remeasured))
        let imageURL = URL(fileURLWithPath: "Tests/quality_control/heading-block-independent/source-p26.png")
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(imageURL as CFURL,nil)!,0,nil)!
        let actualInk = ScoreSharedHeadingDetector.measuredInkBounds(in: image,bounds: merged[0].bounds)!
        check("real-p26-union-measurement-includes-complete-frozen-envelope", contains(actualInk,fullGuard), String(describing: actualInk))
        check("real-p26-union-stops-before-first-staff-line", merged[0].bounds[3]*739 < 61)

        typealias L = ScoreSharedHeadingDetector.TextLine
        let anchor = staff(0,0.2)
        func select(_ lines: [L]) -> [ScoreSharedHeading] {
            ScoreSharedHeadingDetector.select(from: lines,anchor: anchor,previousStaffBottom: 0.12,imageSize: CGSize(width:1800,height:2600))
        }
        func line(_ text: String,_ x: Double = 0.15,_ y: Double = 0.175,_ width: Double = 0.15) -> L {
            L(text:text,bounds:CGRect(x:x,y:y,width:width,height:0.012),confidence:1)
        }
        let nearbyMM = select([line("Molto vivace."),line("d.=138.",0.31,0.175,0.065)])
        check("same-baseline-detached-metronome-preserved",nearbyMM.count == 1 && nearbyMM[0].recognizedText.contains("138") && nearbyMM[0].bounds[2] > 0.375)
        check("metronome-alone-not-global-heading",select([line("d.=138.")]).isEmpty)
        for text in ["pizz.","con sordino","marcato","ten.","dolce","poco cresc.","f","p","Mein Herz ist schwer"] {
            check("non-heading-\(text)",select([line(text)]).isEmpty)
        }
        check("lower-recipient-heading-not-shared-upward",select([line("Molto vivace.",0.15,0.28)]).isEmpty)
        check("preceding-system-heading-not-shared-downward",select([line("Allegro.",0.15,0.125)]).isEmpty)
        let mixed = select([line("SCHERZO",0.15,0.160),line("Molto vivace. d.=138.",0.15,0.176,0.25),line("marcato",0.55,0.17)])
        check("accepted-heading-lines-exclude-technique",mixed.count == 2 && !mixed.contains { $0.recognizedText.contains("marcato") }, String(describing:mixed))

        let profile = ScoreExtractionProfile(parts: [.init(id:"v1",name:"Violin I",staffCount:1),.init(id:"v2",name:"Violin II",staffCount:1)],cropMode:"compact")
        var page = ScorePageAnalysis(pageIndex:0,pageWidth:600,pageHeight:800,imageWidth:1800,imageHeight:2400,
            staves:[staff(0,0.20),staff(1,0.28),staff(2,0.5),staff(3,0.58)],warnings:[])
        let blank = ScoreExtractionPlanner.plan(pages:[page],profile:profile)
        let binding = ScoreExtractionPlanner.headingRecognitionBinding(page:page,plan:blank,anchorStaffID:0)!
        var boundA = a; boundA.recognitionBinding = binding
        var boundB = b; boundB.recognitionBinding = binding
        check("identical-binding-may-group",ScoreSharedHeading.coalesced([boundA,boundB]).count == 1)
        check("nil-versus-bound-stays-separate",ScoreSharedHeading.coalesced([a,boundB]).count == 2)
        var changed = binding; changed.systemIndex = 1; boundB.recognitionBinding = changed
        check("different-recognized-system-stays-separate",ScoreSharedHeading.coalesced([boundA,boundB]).count == 2)
        changed = binding; changed.staves[0].staffLineFractions[0] += 0.001; boundB.recognitionBinding = changed
        check("different-source-staff-lines-stays-separate",ScoreSharedHeading.coalesced([boundA,boundB]).count == 2)

        let headerA = h([0.15,0.155,0.32,0.177],"SCHERZO")
        let headerB = h([0.17,0.173,0.38,0.194],"Molto vivace. d.=138.")
        let union = [0.15,0.155,0.38,0.194]
        for useBinding in [false,true] {
            let suffix = useBinding ? "bound" : "legacy"
            page.sharedHeadings = [headerA,headerB].map { x in var n=x; if useBinding { n.recognitionBinding=binding }; return n }
            let auto = ScoreExtractionPlanner.plan(pages:[page],profile:profile)
            let lower = auto.bands.first { $0.partID == "v2" && $0.systemIndex == 0 }!
            check("planner-full-block-\(suffix)",lower.sourceMarkings.count == 1 && contains([lower.sourceMarkings[0].leftFraction,lower.sourceMarkings[0].topFraction,1-lower.sourceMarkings[0].rightFraction,lower.sourceMarkings[0].bottomFraction],union))
            check("planner-all-music-crops-unchanged-\(suffix)",zip(blank.bands,auto.bands).allSatisfy { x,y in x.topFraction == y.topFraction && x.bottomFraction == y.bottomFraction && x.candidateIDs == y.candidateIDs })
            check("planner-other-system-no-copy-\(suffix)",auto.bands.filter { $0.systemIndex == 1 }.allSatisfy { $0.sourceMarkings.isEmpty })
            let materialized = ScoreSystemAssignment.pageOverride(page:page,pagePlan:auto.pages[0],existingOverride:nil)
            let noOp = ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[materialized])
            check("materialized-no-op-retains-all-copies-\(suffix)",noOp.canApply && zip(auto.bands,noOp.bands).allSatisfy { sameCopies($0.sourceMarkings,$1.sourceMarkings) }, "auto=\(auto.bands.map(\.sourceMarkings)); noop=\(noOp.bands.map(\.sourceMarkings))")
            var implicit = materialized
            for s in implicit.systems.indices { for i in implicit.systems[s].bands.indices { implicit.systems[s].bands[i].sourceMarkings=nil } }
            let autoCopies = ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[implicit])
            check("implicit-no-op-retains-all-copies-\(suffix)",autoCopies.canApply && zip(auto.bands,autoCopies.bands).allSatisfy { $0.sourceMarkings == $1.sourceMarkings })
            var fullOwner = implicit
            fullOwner.systems[0].bands[0].rect=[0,0.14*800,600,0.24*800]
            let completeOwner=ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[fullOwner])
            check("complete-original-owner-block-is-not-duplicated-\(suffix)",completeOwner.canApply && completeOwner.bands.first!.sourceMarkings.isEmpty)
            var partialOwner=fullOwner
            partialOwner.systems[0].bands[0].rect=[0,0.14*800,0.36*600,0.24*800]
            let cutMetronome=ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[partialOwner])
            check("owner-missing-right-edge-metronome-keeps-full-copy-\(suffix)",cutMetronome.canApply && cutMetronome.bands.first!.sourceMarkings.count == 1 && sameCopies(cutMetronome.bands.first!.sourceMarkings,lower.sourceMarkings))
            partialOwner=fullOwner
            partialOwner.systems[0].bands[0].rect=[0,0.17*800,600,0.24*800]
            let cutTitle=ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[partialOwner])
            check("owner-with-tempo-but-missing-title-keeps-full-copy-\(suffix)",cutTitle.canApply && cutTitle.bands.first!.sourceMarkings.count == 1 && sameCopies(cutTitle.bands.first!.sourceMarkings,lower.sourceMarkings))
            var empty = implicit; empty.systems[0].bands[1].sourceMarkings=[]
            let removed = ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[empty])
            check("explicit-empty-source-copy-list-remains-empty-\(suffix)",removed.canApply && removed.bands.first { $0.partID == "v2" && $0.systemIndex == 0 }!.sourceMarkings.isEmpty)
            var swapped = implicit
            swapped.systems[0].bands[0].candidateIDs=[1]; swapped.systems[0].bands[0].rect=nil
            swapped.systems[0].bands[1].candidateIDs=[0]; swapped.systems[0].bands[1].rect=nil
            let moved = ScoreExtractionPlanner.plan(pages:[page],profile:profile,overrides:[swapped])
            check("changed-owner-cannot-move-heading-\(suffix)",moved.canApply && moved.bands.allSatisfy { $0.sourceMarkings.isEmpty })
            check("changed-owner-surfaces-review-warning-\(suffix)",moved.bands.contains { $0.warnings.contains { $0.contains("ownership") } })
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(results).write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
        print("\(results.filter(\.pass).count)/\(results.count) independent heading checks passed")
        if results.contains(where: { !$0.pass }) { exit(1) }
    }
}
