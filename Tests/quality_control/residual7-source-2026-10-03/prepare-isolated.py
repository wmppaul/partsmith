from pathlib import Path
root=Path('.build/residual7-source-2026-10-03/isolated');root.mkdir(exist_ok=True)
s=Path('.build/residual7-geometry-2026-10-03/existing755.swift').read_text().split('    static func main() throws {')[0]
s=s.replace('import PDFKit','import PDFKit\nimport ImageIO')
s=s.replace('        return (NativeScorePageAnalyzer.notationComponents', '''        let output=URL(fileURLWithPath:CommandLine.arguments[1])
        try! FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        for (name,img) in [("source",image),("analysis",analysisImage)] {
            let url=output.appendingPathComponent(name+".png")
            let dest=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!
            CGImageDestinationAddImage(dest,img,nil);precondition(CGImageDestinationFinalize(dest))
        }
        return (NativeScorePageAnalyzer.notationComponents''')
s+='''    static func main() throws {
        let (ink,staves)=fixture(skewDegrees:-1.5,rasterScale:0.4,localBow:-5,harmonicBridge:true)
        let profile=ScoreExtractionProfile(parts:[.init(id:"upper",name:"Upper",staffCount:1),.init(id:"lower",name:"Lower",staffCount:1)],cropMode:"compact")
        let page=ScorePageAnalysis(pageIndex:0,pageWidth:720,pageHeight:600,imageWidth:720,imageHeight:600,staves:staves,warnings:[],analysisSkewDegrees:-1.5,inkComponents:ink)
        let plan=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
        struct Output:Encodable {let page:ScorePageAnalysis;let plan:ScoreExtractionPlan;let sourceEnvelope:[Double]}
        var top=Int.max,bottom=Int.min
        for x in 443..<459 {
            let shift=Int((tan(-1.5 * .pi / 180)*(Double(x)-360)-5).rounded())
            for y in 212..<387 where (450..<453).contains(x)||y<220||y>=379 {top=min(top,y+shift);bottom=max(bottom,y+shift+1)}
        }
        let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys]
        let output=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("result.json")
        try e.encode(Output(page:page,plan:plan,sourceEnvelope:[443,Double(top),459,Double(bottom)])).write(to:output)
    }
}
'''
(root/'fixture.swift').write_text(s)
for variant,core in [('baseline',Path('Partsmith/Core')),('flank',Path('.build/residual7-geometry-2026-10-03/candidate-pixel-runs/Core')),('connector',Path('.build/residual7-geometry-2026-10-03/candidate-connector-target/Core'))]:
 folder=root/variant;folder.mkdir(exist_ok=True)
 s=(core/'Detection/NativeScorePageAnalyzer.swift').read_text()
 s=s.replace('        let original = ink','''        let original = ink
        func probe(_ kind:String,_ fields:[String:Any]) {
            let row:[String:Any]=["kind":kind,"fields":fields]
            let d=try! JSONSerialization.data(withJSONObject:row,options:[.sortedKeys])
            print(String(data:d,encoding:.utf8)!)
        }''')
 s=s.replace('                            if let bestShift, Double(abs(bestShift)) + 2 < staffSpace { return Double(bestShift) }','''                            probe("local-fit",["staff":staffIndex,"connector":[clearLeft,clearRight],"bestShift":bestShift as Any? ?? NSNull(),"space":staffSpace])
                            if let bestShift, Double(abs(bestShift)) + 2 < staffSpace { return Double(bestShift) }''')
 s=s.replace('                                guard !next.isEmpty else { return nil }','''                                probe("tracker",["staff":staffIndex,"connector":[clearLeft,clearRight],"center":center,"states":next.keys.sorted().map { ["shift":$0,"score":next[$0]!.score,"missing":next[$0]!.missingDistance] as [String:Any] }])
                                guard !next.isEmpty else { return nil }''')
 s=s.replace('                            return result.map(Double.init)','''                            probe("tracker-return",["staff":staffIndex,"connector":[clearLeft,clearRight],"shift":result as Any? ?? NSNull()])
                            return result.map(Double.init)''')
 s=s.replace('                            guard localCoresSupported else { continue }','''                            probe("core",["connector":[clearLeft,clearRight],"shifts":[upperCoreShift,lowerCoreShift],"pass":localCoresSupported])
                            guard localCoresSupported else { continue }''')
 s=s.replace('                            guard allJunctionsIntact else { continue }','''                            probe("junction",["connector":[clearLeft,clearRight],"shifts":[upperCoreShift,lowerCoreShift],"pass":allJunctionsIntact])
                            guard allJunctionsIntact else { continue }''')
 s=s.replace('                        for y in localStart..<localEnd {','''                        probe("cut",["connector":[clearLeft,clearRight],"rows":[localStart,localEnd],"throughBothCores":throughBothCores,"shifts":[upperCoreShift,lowerCoreShift]])
                        for y in localStart..<localEnd {''')
 (folder/'NativeScorePageAnalyzer.swift').write_text(s)
 (folder/'original.swift').write_bytes((core/'Detection/NativeScorePageAnalyzer.swift').read_bytes())
