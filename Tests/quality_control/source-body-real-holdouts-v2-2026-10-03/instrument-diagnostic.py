from pathlib import Path
import shutil
root=Path('.build/source-body-real-holdouts-v2-2026-10-03')
report=Path('Tests/quality_control/source-body-real-holdouts-v2-2026-10-03')
source=Path('.build/source-body-provenance-v2-2026-10-03/candidate-v2/Core')
core=root/'diagnostic-Core'
shutil.copytree(source,core,dirs_exist_ok=True)
p=core/'Detection/NativeScorePageAnalyzer.swift';s=p.read_text();start=s.index('        guard width > 0');end=s.index('\n    static func render',start)
f=s[start:end]
f=f.replace('else { return nil }','else { failed(#line); return nil }').replace('else { continue }','else { failed(#line); continue }')
f=f.replace('        let measuredLines=lines.map{lineCenter($0,spine)}','        let measuredLines=lines.map{lineCenter($0,spine)}\n        auditLines = measuredLines')
f=f.replace('        for proposal in proposals {','        audit["proposals"] = proposals.count\n        audit["cavityProposals"] = proposals.filter { $0.cavity }.count\n        for proposal in proposals {')
prefix='''        var audit: [String: Int] = [:]
        var auditLines: [Double] = []
        func failed(_ line: Int) { audit[String(line), default: 0] += 1 }
        defer {
            let data = try! JSONSerialization.data(withJSONObject: ["guardCounts": audit, "measuredLines": auditLines], options: [.sortedKeys])
            print("AUDIT", String(data: data, encoding: .utf8)!)
        }
'''
p.write_text(s[:start]+prefix+f+s[end:])
probe=(report/'helper-probe.swift').read_text().replace('            let w = NativeScorePageAnalyzer.sourceNoteheadEndpoint','            print("CASE",c.id)\n            let w = NativeScorePageAnalyzer.sourceNoteheadEndpoint')
(root/'diagnostic-probe.swift').write_text(probe)
build=(report/'build-helper.sh').read_text().replace('Tests/quality_control/source-body-real-holdouts-v2-2026-10-03/helper-probe.swift','.build/source-body-real-holdouts-v2-2026-10-03/diagnostic-probe.swift')
(root/'build-diagnostic.sh').write_text(build)
(report/'instrument-diagnostic.py').write_bytes((root/'instrument.py').read_bytes())
