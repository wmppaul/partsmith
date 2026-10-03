from pathlib import Path
import shutil
r=Path('.build/stem-ownership-2026-10-03');shutil.copytree(r/'witness/Core',r/'witness-v2/Core',dirs_exist_ok=True)
s=(r/'witness/Core/Detection/NativeScorePageAnalyzer.swift').read_text()
s=s.replace('''                                            let attached = (0..<headThickness).allSatisfy { dy in''','''                                            var offStaffRows = 0
                                            let attached = (0..<headThickness).allSatisfy { dy in''')
s=s.replace('''                                                for flankSide in [-1, 1] {''','''                                                var sameHorizontalLine = false
                                                for flankSide in [-1, 1] {''')
s=s.replace('''if sampled >= outsideEnd - outsideStart && Double(supported) >= Double(sampled) * 0.70 { return false }''','''if sampled >= outsideEnd - outsideStart && Double(supported) >= Double(sampled) * 0.70 { sameHorizontalLine = true }''')
s=s.replace('''                                                var actualLeft = lo, actualRight = hi + 1''','''                                                if !sameHorizontalLine { offStaffRows += 1 }
                                                var actualLeft = lo, actualRight = hi + 1''')
s=s.replace('''                                            if attached { return true }''','''                                            guard attached, offStaffRows >= max(1, Int((staffSpace * 0.15).rounded())) else { continue }
                                            // A compact patch inside an accidental is not a
                                            // complete notehead witness. Follow every attached
                                            // off-spine analysis component to its actual end.
                                            // The physical vertical spine remains excluded;
                                            // never cross to a nearby disconnected stem.
                                            var visited = Set<Int>()
                                            var completeBodies = true
                                            var sawBody = false
                                            let seedLo = min(xs.min()!, nominalCenter)
                                            let seedHi = max(xs.max()!, nominalCenter)
                                            for yy in row..<(row + headThickness) {
                                                for xx in seedLo...seedHi where xx < stroke.left || xx >= stroke.right {
                                                    let seed = yy * width + xx
                                                    guard ink[seed], !visited.contains(seed) else { continue }
                                                    var queue = [seed], next = 0
                                                    visited.insert(seed)
                                                    var minX = xx, maxX = xx, minY = yy, maxY = yy
                                                    while next < queue.count {
                                                        let item = queue[next]; next += 1
                                                        let py = item / width, px = item % width
                                                        minX = min(minX, px); maxX = max(maxX, px)
                                                        minY = min(minY, py); maxY = max(maxY, py)
                                                        if Double(maxX - minX + 1) > staffSpace * 2.1 || Double(maxY - minY + 1) > staffSpace * 0.95 {
                                                            completeBodies = false
                                                            break
                                                        }
                                                        for dy in -1...1 { for dx in -1...1 {
                                                            let nx = px + dx, ny = py + dy
                                                            guard nx >= 0, nx < width, ny >= 0, ny < height,
                                                                  nx < stroke.left || nx >= stroke.right else { continue }
                                                            let neighbor = ny * width + nx
                                                            if ink[neighbor] && visited.insert(neighbor).inserted { queue.append(neighbor) }
                                                        } }
                                                    }
                                                    sawBody = true
                                                    if !completeBodies { break }
                                                }
                                                if !completeBodies { break }
                                            }
                                            if sawBody && completeBodies { return true }''')
(r/'witness-v2/Core/Detection/NativeScorePageAnalyzer.swift').write_text(s);(r/'source-witness-v2.swift').write_text(s)
s=(r/'build-actual.sh').read_text().replace('/candidate/Core','/witness-v2/Core').replace('"$root/actual"','"$root/witness-v2-actual"');(r/'build-witness-v2-actual.sh').write_text(s)
