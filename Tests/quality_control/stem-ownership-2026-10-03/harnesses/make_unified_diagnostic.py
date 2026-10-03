from pathlib import Path
import shutil
r=Path('.build/stem-ownership-2026-10-03');shutil.copytree(r/'candidate/Core',r/'unified-diagnostic/Core',dirs_exist_ok=True)
s=(r/'candidate/Core/Detection/NativeScorePageAnalyzer.swift').read_text()
s=s.replace('''        let detected = StaffBandDetector.detect(in: image, isCancelled: isCancelled)''','''        fputs("STAGE page \\(pageIndex + 1)\\n", stderr)
        let detected = StaffBandDetector.detect(in: image, isCancelled: isCancelled)''')
s=s.replace('''guard let upper = localCoreShift(index), let lower = localCoreShift(index + 1) else { continue }''','''guard let upper = localCoreShift(index), let lower = localCoreShift(index + 1) else {
                                if throughBothCores { fputs("STAGE reject-local-geometry \\(index) \\(clearLeft) \\(clearRight)\\n", stderr) }
                                continue
                            }''')
s=s.replace('''guard localCoresSupported else { continue }''','''guard localCoresSupported else {
                                if throughBothCores { fputs("STAGE reject-local-core \\(index) \\(clearLeft) \\(clearRight)\\n", stderr) }
                                continue
                            }''')
s=s.replace('''guard allJunctionsIntact else { continue }''','''guard allJunctionsIntact else {
                                if throughBothCores { fputs("STAGE reject-junction \\(index) \\(clearLeft) \\(clearRight)\\n", stderr) }
                                continue
                            }
                            if throughBothCores { fputs("STAGE nominal-local-pass \\(index) \\(clearLeft) \\(clearRight)\\n", stderr) }''')
(r/'unified-diagnostic/Core/Detection/NativeScorePageAnalyzer.swift').write_text(s)
s=(r/'build-actual.sh').read_text().replace('/candidate/Core','/unified-diagnostic/Core').replace('"$root/actual"','"$root/unified-diagnostic-actual"')
(r/'build-unified-diagnostic.sh').write_text(s)
