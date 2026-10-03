from pathlib import Path
import shutil
r=Path('.build/stem-ownership-2026-10-03')
shutil.copytree(r/'baseline/Core',r/'witness/Core',dirs_exist_ok=True)
s=(r/'baseline/Core/Detection/NativeScorePageAnalyzer.swift').read_text()
p=Path('Tests/quality_control/residual9-endpoint-ownership/endpoint-head-v2-rejected.patch').read_text()
block='\n'.join(line[1:] for line in p.splitlines() if line.startswith('+') and not line.startswith('+++'))+'\n'
block=block.replace('// Scratch: a compact head at an actual stroke endpoint','// Scratch: an off-staff body at an actual stroke endpoint')
needle='''                                                guard (lo...hi).allSatisfy({ original[y * width + $0] }) else { return false }
'''
replacement=needle+'''                                                // Source-provenance veto: a detached compact
                                                // staff fragment is still part of its horizontal
                                                // line. At this row, look for the same source line
                                                // beyond the entire possible head, on either side.
                                                // Only directly attached rows with no such line
                                                // continuation can witness a musical body.
                                                let outsideStart = max(3, Int((staffSpace * 1.5).rounded()))
                                                let outsideEnd = max(outsideStart + 2, Int((staffSpace * 4).rounded()))
                                                for flankSide in [-1, 1] {
                                                    for rowShift in -1...1 {
                                                        var sampled = 0, supported = 0
                                                        for dx in outsideStart...outsideEnd {
                                                            let xx = nominalCenter + flankSide * dx
                                                            guard xx >= 0, xx < width else { continue }
                                                            let yy = y + rowShift + Int((slope * Double(xx - nominalCenter)).rounded())
                                                            guard yy >= 0, yy < height else { continue }
                                                            sampled += 1
                                                            if original[yy * width + xx] { supported += 1 }
                                                        }
                                                        if sampled >= outsideEnd - outsideStart && Double(supported) >= Double(sampled) * 0.70 { return false }
                                                    }
                                                }
'''
assert needle in block
block=block.replace(needle,replacement)
needle='''                        // Cutting only at the midpoint leaves long connector'''
assert needle in s
s=s.replace(needle,block+needle)
(r/'witness/Core/Detection/NativeScorePageAnalyzer.swift').write_text(s)
(r/'source-witness-v1.swift').write_text(s)
