from pathlib import Path
import shutil,json,hashlib
P=Path('.build/brahms-remaining-2026-10-03/upper-review');C=P/'candidate-v1/Core';shutil.copytree(P/'Core',C,dirs_exist_ok=True)
p=C/'Detection/NativeScorePageAnalyzer.swift';s=p.read_text();needle='                        var upperCoreShift = localShift, lowerCoreShift = localShift\n';assert s.count(needle)==1
extra='''                        // A damaged core can be part of a longer original barline.
                        // Certify that context on the undilated physical stroke;
                        // do not reduce the ordinary core/junction thresholds.
                        func longerPhysicalBarline(_ failed: Int, _ failedShift: Double) -> Bool {
                            guard physicalStrokes.count == 1 else { return false }
                            let stroke = physicalStrokes[0]
                            let columns = stroke.left..<stroke.right
                            guard !columns.isEmpty else { return false }
                            func occupied(_ row: Int) -> Bool {
                                row >= 0 && row < height && columns.contains { original[row * width + $0] }
                            }
                            func junction(_ staff: Int, _ lineIndex: Int, _ shift: Double) -> Bool {
                                let center = Int((lines[staff][lineIndex] + shift).rounded())
                                let radius = max(2, Int((spaces[staff] * 0.18).rounded()))
                                let lower = lineIndex == 0 ? 0 : -radius
                                let upper = lineIndex == 4 ? 0 : radius
                                return (-1...1).contains { rounding in
                                    columns.contains { column in
                                        (lower...upper).allSatisfy { delta in
                                            let y = center + rounding + delta
                                            return y >= 0 && y < height && original[y * width + column]
                                        }
                                    }
                                }
                            }
                            func narrowCore(_ staff: Int, _ shift: Double) -> Bool {
                                let top = max(0, Int((lines[staff][0] + shift).rounded()))
                                let bottom = min(height, Int((lines[staff][4] + shift).rounded()) + 1)
                                guard top < bottom else { return false }
                                let count = (top..<bottom).filter(occupied).count
                                return Double(count) >= Double(bottom-top) * 0.88
                                    && (0..<5).allSatisfy { junction(staff, $0, shift) }
                            }
                            guard junction(failed, 0, failedShift), junction(failed, 4, failedShift) else { return false }
                            let flankLength = max(8, Int((spaces[failed] * 3).rounded()))
                            let flankGap = max(3, Int((spaces[failed] * 0.5).rounded()))
                            let flankRanges = [max(0,clearLeft-flankGap-flankLength)..<max(0,clearLeft-flankGap),
                                               min(width,clearRight+flankGap)..<min(width,clearRight+flankGap+flankLength)]
                            let midpoint = Double(clearLeft+clearRight)/2
                            guard lines[failed].allSatisfy({ line in
                                flankRanges.contains { flank in
                                    guard flank.count >= flankLength else { return false }
                                    let count = flank.filter { column in
                                        let row = Int((line + failedShift + slope * (Double(column)-midpoint)).rounded())
                                        return (-1...1).contains { delta in
                                            let y = row+delta
                                            return y >= 0 && y < height && original[y * width + column]
                                        }
                                    }.count
                                    return Double(count) >= Double(flank.count) * 0.80
                                }
                            }) else { return false }
                            for direction in [-1,1] {
                                let donors = (1...3).map { failed + direction * $0 }
                                guard donors.allSatisfy({ lines.indices.contains($0) }) else { continue }
                                var shifts: [Int: Double] = [failed: failedShift]
                                var valid = true
                                for donor in donors {
                                    if isCancelled() { return false }
                                    if narrowCore(donor, localShift) { shifts[donor] = localShift }
                                    else if let offset = localCoreShift(donor), narrowCore(donor, localShift + offset) {
                                        shifts[donor] = localShift + offset
                                    } else { valid = false; break }
                                }
                                if !valid { continue }
                                let group = ([failed]+donors).sorted()
                                for offset in 0..<(group.count-1) {
                                    let a = group[offset], b = group[offset+1]
                                    let top = Int((lines[a][4]+shifts[a]!).rounded())
                                    let bottom = Int((lines[b][0]+shifts[b]!).rounded())
                                    guard top < bottom, (top...bottom).allSatisfy(occupied) else { valid = false; break }
                                }
                                if valid { return true }
                            }
                            return false
                        }
'''
s=s.replace(needle,extra+needle)
old='''                            guard connectorProof(index, upperCoreShift),
                                  connectorProof(index + 1, lowerCoreShift) else { continue }'''
new='''                            guard (connectorProof(index, upperCoreShift) || longerPhysicalBarline(index, upperCoreShift)),
                                  (connectorProof(index + 1, lowerCoreShift) || longerPhysicalBarline(index + 1, lowerCoreShift)) else { continue }'''
assert s.count(old)==1;s=s.replace(old,new);p.write_text(s)
files={str(q.relative_to(C)):hashlib.sha256(q.read_bytes()).hexdigest() for q in C.rglob('*.swift')}
(P/'candidate-v1/source-hashes.json').write_text(json.dumps({'hypothesisSHA256':hashlib.sha256((P/'hypothesis-v1.md').read_bytes()).hexdigest(),'Core':files},indent=2)+'\n');print(files['Detection/NativeScorePageAnalyzer.swift'])
