from pathlib import Path
import shutil,hashlib,json
r=Path('.build/residual9-boundary-2026-10-03/agent-probe');d=Path('Tests/quality_control/residual9-boundary-source');base=Path('.build/residual9-endpoint-ownership-2026-10-03')
names=['StaffBandDetector.swift','ScoreExtractionPlanner.swift','ScoreSharedEnding.swift','ScoreSharedEndingDetector.swift','ScoreLocalEndingPreservation.swift','NativeScorePageAnalyzer.swift']
for n in names:shutil.copy2(Path('Partsmith/Core/Detection')/n,r/n)
shutil.copy2('Tests/quality_control/residual9-endpoint-ownership/source-guards.json',d/'source-guards.json')
assert hashlib.sha256((d/'source-guards.json').read_bytes()).hexdigest()=='e097a2b80032e18b85606f4f02c13e24870162857a02bf95f6b58786f2cdbe0c'
p=r/'NativeScorePageAnalyzer.swift';s=p.read_text()
s=s.replace('        let original = ink','        let original = ink\n        Trace.saveMask(original, width: width, height: height)')
s=s.replace('                    let left = connector.left, x = connector.right','''                    let left = connector.left, x = connector.right
                    let watched = Trace.watched(index: index, column: left, width: width)
                    func probe(_ event: String, _ fields: [String: Any]) {
                        if watched { Trace.emit(event, fields.merging(["staffPair": [ordered[index].id, ordered[index+1].id], "connector": [left,x]]) { old,_ in old }) }
                    }
                    probe("gap", ["rasterSize":[width,height],"space":space,"start":start,"end":end,"supportOccupancy":Array(occupancy[left..<x]),"directOccupancy":Array(directOccupancy[max(0,left-2)..<min(width,x+2)]),"strokes":connector.strokes])''')
s=s.replace('                    if Double(max(1, x - left - supportHalo)) < maximumWidth {','''                    probe("width", ["physicalStrokes":physicalStrokes.map{[$0.left,$0.right]},"mergedPair":mergedPair,"physicalWidth":max(1,x-left-supportHalo),"maximumWidth":maximumWidth])
                    if Double(max(1, x - left - supportHalo)) < maximumWidth {''')
s=s.replace('                        let throughBothCores = [index, index + 1].allSatisfy { staffIndex in','''                        func coreInfo(_ staffIndex:Int, _ shift:Double)->[String:Any] {
                            let top=max(0,Int((lines[staffIndex][0]+shift).rounded())),bottom=min(height,Int((lines[staffIndex][4]+shift).rounded())+1)
                            let missing=(top..<bottom).filter { y in !(clearLeft..<clearRight).contains { original[y*width+$0] } }
                            return ["staff":ordered[staffIndex].id,"top":top,"bottom":bottom,"rows":bottom-top,"supported":bottom-top-missing.count,"fraction":Double(bottom-top-missing.count)/Double(bottom-top),"missingRows":missing,"shift":shift]
                        }
                        probe("global-cores",["clearColumns":[clearLeft,clearRight],"slope":slope,"localShift":localShift,"cores":[coreInfo(index,localShift),coreInfo(index+1,localShift)]])
                        let throughBothCores = [index, index + 1].allSatisfy { staffIndex in''')
s=s.replace('                            var bestScore = -1.0','''                            var bestScore = -1.0
                            var shiftRecords:[[String:Any]]=[]''')
s=s.replace('                                var weakest = 1.0\n                                for line in lines[staffIndex] {','''                                var weakest = 1.0
                                var fractions:[Double]=[]
                                for line in lines[staffIndex] {''',1)
s=s.replace('                                    total += bestFlank','''                                    total += bestFlank
                                    fractions.append(bestFlank)''',1)
s=s.replace('                                guard weakest >= 0.80 else { continue }','''                                shiftRecords.append(["shift":shift,"fractions":fractions,"weakest":weakest,"sum":total])
                                guard weakest >= 0.80 else { continue }''',1)
s=s.replace('                            if let bestShift, Double(abs(bestShift)) + 2 < staffSpace { return Double(bestShift) }','''                            probe("local-shift",["staff":ordered[staffIndex].id,"staffSpace":staffSpace,"radius":radius,"flankLength":flankLength,"flanks":flanks.map{[$0.lowerBound,$0.upperBound]},"candidates":shiftRecords,"acceptedBest":bestShift as Any? ?? NSNull()])
                            if let bestShift, Double(abs(bestShift)) + 2 < staffSpace { probe("local-return",["staff":ordered[staffIndex].id,"shift":bestShift]); return Double(bestShift) }''')
s=s.replace('                                var scores: [Int: Double] = [:]','''                                var scores: [Int: Double] = [:]
                                var traceCandidates:[[String:Any]]=[]''')
s=s.replace('                                    var weakest = 1.0\n                                    for line in lines[staffIndex] {','''                                    var weakest = 1.0
                                    var lineFractions:[Double]=[]
                                    for line in lines[staffIndex] {''')
s=s.replace('                                        weakest = min(weakest, fraction); score += fraction','''                                        weakest = min(weakest, fraction); score += fraction; lineFractions.append(fraction)''')
s=s.replace('                                    if weakest >= 0.80 { next.insert(shift); scores[shift] = score }','''                                    traceCandidates.append(["shift":shift,"fractions":lineFractions,"weakest":weakest,"sum":score])
                                    if weakest >= 0.80 { next.insert(shift); scores[shift] = score }''')
s=s.replace('                                guard !next.isEmpty else { return nil }','''                                probe("tracker-segment",["staff":ordered[staffIndex].id,"segment":segment,"count":count,"center":center,"begin":begin,"flankLength":flankLength,"reachableBefore":reachable.sorted(),"reachableAfter":next.sorted(),"candidates":traceCandidates])
                                guard !next.isEmpty else { probe("tracker-failed",["staff":ordered[staffIndex].id,"segment":segment,"center":center]); return nil }''')
s=s.replace('                            return result.map(Double.init)','''                            probe("tracker-return",["staff":ordered[staffIndex].id,"shift":result as Any? ?? NSNull()])
                            return result.map(Double.init)''')
s=s.replace('                            guard let upper = localCoreShift(index), let lower = localCoreShift(index + 1) else { continue }','''                            let upperProbe = localCoreShift(index), lowerProbe = localCoreShift(index + 1)
                            guard let upper = upperProbe, let lower = lowerProbe else { probe("reject",["reason":"local-shift/tracker unavailable","upper":upperProbe as Any? ?? NSNull(),"lower":lowerProbe as Any? ?? NSNull()]); continue }''')
s=s.replace('                            guard localCoresSupported else { continue }','''                            probe("translated-cores",["cores":[coreInfo(index,upperCoreShift),coreInfo(index+1,lowerCoreShift)],"supported":localCoresSupported])
                            guard localCoresSupported else { probe("reject",["reason":"translated core <88%"]); continue }''')
s=s.replace('                            guard allJunctionsIntact else { continue }','''                            probe("junctions",["allIntact":allJunctionsIntact])
                            guard allJunctionsIntact else { probe("reject",["reason":"missing line junction"]); continue }''')
s=s.replace('                        guard localStart < localEnd else { continue }','''                        guard localStart < localEnd else { continue }
                        probe("accepted",["clearRows":[localStart,localEnd],"upperCoreShift":upperCoreShift,"lowerCoreShift":lowerCoreShift])''')
p.write_text(s)
files=[Path('Partsmith/Core/Detection')/n for n in names]+[base/'baseline-actual.json',base/'actual.swift',Path('sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf'),d/'source-guards.json']+[base/'rasters'/f'page-{p}.png' for p in [24,28,29,31,35]]
(d/'frozen-inputs.json').write_text(json.dumps([{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files],indent=2)+'\n')
