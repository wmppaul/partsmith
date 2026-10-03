from pathlib import Path
import shutil,hashlib,json
p=Path('.build/p31-spine-provenance-2026-10-03'); core=p/'Core';shutil.copytree('Partsmith/Core',core)
s=(core/'Detection/NativeScorePageAnalyzer.swift').read_text().replace('enum NativeScorePageAnalyzer','enum ProbeNativeScorePageAnalyzer')
s=s.replace('        let original = ink','        let original = ink\n        Trace.saveMask(original,width:width,height:height,phase:"original")')
s=s.replace('        var preservedMusicalConnection = false','        Trace.saveMask(ink,width:width,height:height,phase:"staff-erased")\n        var preservedMusicalConnection = false')
s=s.replace('                        // Local page curl can move all five','                        if index == 0 && clearLeft > 1600 { Trace.emit("connector",["left":left,"right":x,"clear":[clearLeft,clearRight],"cores":throughBothCores,"start":start,"end":end,"space":space,"localShift":localShift]) }\n                        // Local page curl can move all five')
s=s.replace('                                guard weakest >= 0.80 else { continue }','                                if index == 0 && clearLeft > 1600 { Trace.emit("local-fit",["staff":staffIndex,"shift":shift,"weakest":weakest,"total":total]) }\n                                guard weakest >= 0.80 else { continue }')
s=s.replace('                                    guard support.filter({ $0 >= 0.80 }).count >= (segment == 0 ? 5 : 3) else { continue }','                                    if index == 0 && clearLeft > 1600 { Trace.emit("trace-window",["staff":staffIndex,"segment":segment,"count":count,"center":center,"shift":shift,"support":support,"predecessors":predecessors.keys.sorted()]) }\n                                    guard support.filter({ $0 >= 0.80 }).count >= (segment == 0 ? 5 : 3) else { continue }')
s=s.replace('                                guard !next.isEmpty else { return nil }','                                guard !next.isEmpty else { if index == 0 && clearLeft > 1600 { Trace.emit("trace-empty",["staff":staffIndex,"segment":segment,"center":center,"previousShifts":reachable.keys.sorted()]) };return nil }')
s=s.replace('guard let upper = localCoreShift(index), let lower = localCoreShift(index + 1) else { continue }','guard let upper = localCoreShift(index), let lower = localCoreShift(index + 1) else { if index == 0 && clearLeft > 1600 {Trace.emit("rejected-local-trace",["left":left,"right":x])};continue }')
s=s.replace('        struct Run { var left: Int; var right: Int; var y: Int }','        Trace.saveMask(ink,width:width,height:height,phase:"separated")\n        struct Run { var left: Int; var right: Int; var y: Int }')
(p/'ProbeNativeScorePageAnalyzer.swift').write_text(s)
old=Path('.build/brahms-remaining-2026-10-03/upper-review/main.swift').read_text()
old=old.replace('.build/brahms-remaining-2026-10-03/upper-review','.build/p31-spine-provenance-2026-10-03').replace('for pn in [28,31]','for pn in [31]')
(p/'main.swift').write_text(old)
files={str(f.relative_to(core)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(core.rglob('*.swift'))}
(p/'source-hashes.json').write_text(json.dumps(files,indent=2)+'\n')
