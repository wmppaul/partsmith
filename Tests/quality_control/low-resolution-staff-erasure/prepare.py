from pathlib import Path
out=Path('.build/qc-low-resolution-preservation')
f=Path('Tests/quality_control/residual11-curved-harmonic-audit/all-fixtures.swift').read_text()
f=f.replace('import PDFKit','import PDFKit\nimport ImageIO\nimport UniformTypeIdentifiers')
f=f.replace('static var targetImage:CGImage!', 'static var inputImage:CGImage!\n    static var targetImage:CGImage!')
f=f.replace('static func measure(original:[Bool],ink:[Bool],width:Int,height:Int) {','static func measure(original:[Bool],ink:[Bool],width:Int,height:Int,phase:String="final") {')
f=f.replace('row["targetMaskForegroundPixels"]=targetCount;', 'if phase != "final" { row[phase+"TargetPixelsAbsent"]=missing; row[phase+"StemRowsAbsent"]=stemMissingRows.sorted(); return }\n        var rasterPoints:[[Int]]=[]\n        for y in 0..<height { for x in 0..<width where raw[y*width+x]<190 && original[y*width+x] {rasterPoints.append([x,y])} }\n        row["sourceRasterTargetBounds"]=[Double(rasterPoints.map{$0[0]}.min()!)/Double(width), Double(rasterPoints.map{$0[1]}.min()!)/Double(height), Double(rasterPoints.map{$0[0]}.max()!+1)/Double(width),Double(rasterPoints.map{$0[1]}.max()!+1)/Double(height)]\n        row["targetMaskForegroundPixels"]=targetCount;')
f=f.replace('row["planCanApply"]=plan.canApply','row["planCanApply"]=plan.canApply\n        row["components"]=components.map { ["bounds":$0.bounds,"staffIDs":$0.staffIDs] as [String:Any] }')
f=f.replace('return (NativeScorePageAnalyzer.notationComponents(image: analysisImage,', 'Probe.inputImage=analysisImage\n        return (NativeScorePageAnalyzer.notationComponents(image: analysisImage,')
f=f.replace('let name=CommandLine.arguments.dropFirst().first ?? "unknown"','let name=CommandLine.arguments.dropFirst().first ?? "unknown"')
f=f.replace('.build/qc-harmonic-independent/','.build/qc-low-resolution-preservation/')
(out/'fixtures.swift').write_text(f)
s=Path('Tests/quality_control/residual11-curved-harmonic-audit/direct-analyzer-tracked-alias.swift').read_text()
pos='        if lines.count > 1 {'
s=s.replace(pos,'        Probe.measure(original: original, ink: ink, width: width, height: height, phase: "afterStaffErasure")\n'+pos)
(out/'baseline.swift').write_text(s)
(out/'single-row.swift').write_text(s.replace('let thickness = max(1, Int((spaces[index] * 0.09).rounded()))','let thickness = max(0, Int((spaces[index] * 0.09).rounded()))'))
# Diagnostic ablation, not a production proposal: retaining all staff-line pixels.
(out/'no-erase.swift').write_text(s.replace('ink[(y + dy) * width + x] = false','ink[(y + dy) * width + x] = original[(y + dy) * width + x]'))
