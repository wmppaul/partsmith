    struct EndpointNoteheadWitness: Codable {
        var center: [Double]
        var radii: [Double]
        var angleDegrees: Double
        var hollow: Bool
        var attachmentRows: Int
        var outlineSupport: [Double]
        var surroundingWhite: Double
    }

    /// Source-derived positive evidence. Observed horizontal line bands are
    /// occlusions; they cannot provide the body contour or its stem attachment.
    static func sourceNoteheadEndpoint(original: [Bool], width: Int, height: Int,
        strokeLeft: Int, strokeRight: Int, staffSpace: Double,
        staffLinesAtSpine: [Double], skewSlope: Double, upper: Bool,
        isCancelled: () -> Bool = { false }) -> EndpointNoteheadWitness? {
        guard width > 0, height > 0, width <= Int.max / height,
              original.count == width * height, strokeLeft >= 0,
              strokeRight > strokeLeft, strokeRight <= width,
              staffSpace.isFinite, staffSpace >= 3,
              staffSpace < Double(min(width, height)) / 4,
              skewSlope.isFinite, abs(skewSlope) < 1,
              staffLinesAtSpine.count == 5,
              staffLinesAtSpine.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < Double(height) }),
              !isCancelled() else { return nil }
        let spine = Double(strokeLeft + strokeRight) / 2
        let inward = upper ? 1.0 : -1.0
        struct LineRun { var x: Double; var center: Double; var halfWidth: Double }
        struct LineTrace { var left: LineRun; var right: LineRun }
        func originalInk(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && y >= 0 && x < width && y < height && original[y * width + x]
        }
        // Recover actual row thickness from independent horizontal flanks. A
        // localized thick patch next to the spine cannot establish a staff line.
        func flank(_ expected: Double, _ side: Int) -> LineRun? {
            let a = spine + Double(side) * staffSpace * 1.5
            let b = spine + Double(side) * staffSpace * 4
            let x0 = max(0, Int(ceil(min(a,b)))), x1 = min(width-1, Int(floor(max(a,b))))
            guard x1 > x0, Double(x1-x0+1) >= staffSpace * 1.5 else { return nil }
            let rows0 = max(0, Int(floor(expected-staffSpace*0.75)))
            let rows1 = min(height-1, Int(ceil(expected+staffSpace*0.75)))
            guard rows1 >= rows0 else { return nil }
            var support: [Double] = []
            for row in rows0...rows1 {
                var ink = 0, count = 0
                for x in x0...x1 {
                    let yy = Double(row) + skewSlope * (Double(x)+0.5-spine)
                    guard yy >= 0, yy < Double(height) else { continue }
                    count += 1
                    if originalInk(x, Int(yy.rounded())) { ink += 1 }
                }
                support.append(count > 0 ? Double(ink)/Double(count) : 0)
            }
            guard let peak = support.indices.max(by: { support[$0] < support[$1] }), support[peak] >= 0.7 else { return nil }
            var lo=peak, hi=peak
            while lo > 0 && support[lo-1] >= 0.6 { lo -= 1 }
            while hi+1 < support.count && support[hi+1] >= 0.6 { hi += 1 }
            let xCenter = Double(x0+x1+1)/2
            let centerAtSpine = Double(rows0) + Double(lo+hi)/2 + 0.5
            return LineRun(x:xCenter, center:centerAtSpine+skewSlope*(xCenter-spine), halfWidth:Double(hi-lo+1)/2)
        }
        var lines: [LineTrace] = []
        for expected in staffLinesAtSpine {
            if isCancelled() { return nil }
            let l=flank(expected,-1), r=flank(expected,1)
            guard l != nil || r != nil else { return nil }
            let left = l ?? LineRun(x:r!.x-staffSpace*5.5, center:r!.center-skewSlope*staffSpace*5.5, halfWidth:r!.halfWidth)
            let right = r ?? LineRun(x:l!.x+staffSpace*5.5, center:l!.center+skewSlope*staffSpace*5.5, halfWidth:l!.halfWidth)
            lines.append(LineTrace(left:left,right:right))
        }
        func lineCenter(_ line: LineTrace, _ x: Double) -> Double {
            let t=(x-line.left.x)/(line.right.x-line.left.x)
            return line.left.center+t*(line.right.center-line.left.center)
        }
        let measuredLines=lines.map{lineCenter($0,spine)}
        for i in 1..<measuredLines.count {
            let gap=measuredLines[i]-measuredLines[i-1]
            guard gap >= staffSpace*0.65 && gap <= staffSpace*1.35 else { return nil }
        }
        func staffPixel(_ x: Int, _ y: Int) -> Bool {
            lines.contains { line in
                let t=min(1,max(0,(Double(x)+0.5-line.left.x)/(line.right.x-line.left.x)))
                let half=line.left.halfWidth+t*(line.right.halfWidth-line.left.halfWidth)
                return abs(Double(y)+0.5-lineCenter(line,Double(x)+0.5)) <= half
            }
        }
        func physicalSpine(_ y: Int) -> Bool {
            y >= 0 && y < height && (strokeLeft..<strokeRight).contains { original[y * width + $0] }
        }
        let boundary=measuredLines[upper ? 0 : 4]
        let yA=boundary-inward*staffSpace*0.5, yB=boundary+inward*staffSpace*1.5
        let seedY0=max(1,Int(floor(min(yA,yB)))), seedY1=min(height-2,Int(ceil(max(yA,yB))))
        let seedX0=max(1,upper ? strokeRight : Int(floor(spine-staffSpace*2)))
        let seedX1=min(width-2,upper ? Int(ceil(spine+staffSpace*2)) : strokeLeft-1)
        guard seedX0 <= seedX1 && seedY0 <= seedY1 else { return nil }
        struct Proposal { var x: Double; var y: Double; var cavity: Bool }
        var proposals: [Proposal] = []
        let maxInterior=max(1,Int(floor(staffSpace*0.7)))
        var radii: [Int:Int] = [:]
        for y in seedY0...seedY1 {
            if isCancelled() { return nil }
            for x in seedX0...seedX1 where originalInk(x,y) && !staffPixel(x,y) {
                var radius=0
                for r in 1...maxInterior {
                    guard x-r >= 0, x+r < width, y-r >= 0, y+r < height else { break }
                    let solid = (x-r...x+r).allSatisfy { originalInk($0,y-r) && originalInk($0,y+r) }
                        && (y-r...y+r).allSatisfy { originalInk(x-r,$0) && originalInk(x+r,$0) }
                    if !solid { break }; radius=r
                }
                if radius >= 1 { radii[y*width+x]=radius }
            }
        }
        // Preserve all distinct local maxima; no extent threshold selects a
        // particular score or note size within the fixed compact search region.
        for key in radii.keys.sorted() {
            let x=key%width, y=key/width, r=radii[key]!
            if (-1...1).allSatisfy({ dy in (-1...1).allSatisfy { dx in (radii[(y+dy)*width+x+dx] ?? 0) <= r } }) {
                proposals.append(Proposal(x:Double(x)+0.5,y:Double(y)+0.5,cavity:false))
            }
        }
        // Hollow seeds must be closed in the untouched source, not closed by
        // staff-line erasure, clipping, or a fitted model.
        let boxX0=max(0,seedX0-Int(ceil(staffSpace))), boxX1=min(width-1,seedX1+Int(ceil(staffSpace)))
        let boxY0=max(0,seedY0-Int(ceil(staffSpace))), boxY1=min(height-1,seedY1+Int(ceil(staffSpace)))
        var visited=Set<Int>()
        for y in seedY0...seedY1 { for x in seedX0...seedX1 where !originalInk(x,y) {
            let seed=y*width+x
            guard visited.insert(seed).inserted else { continue }
            var queue=[seed], at=0, escaped=false, sx=0.0, sy=0.0
            while at < queue.count {
                if at % 128 == 0 && isCancelled() { return nil }
                let key=queue[at];at += 1
                let px=key%width, py=key/width
                sx += Double(px)+0.5;sy += Double(py)+0.5
                if px == boxX0 || px == boxX1 || py == boxY0 || py == boxY1 { escaped=true }
                for (nx,ny) in [(px-1,py),(px+1,py),(px,py-1),(px,py+1)] {
                    guard nx >= boxX0,nx <= boxX1,ny >= boxY0,ny <= boxY1,!originalInk(nx,ny) else { continue }
                    let next=ny*width+nx
                    if visited.insert(next).inserted { queue.append(next) }
                }
            }
            if !escaped && queue.count >= 2 {
                let cx=sx/Double(queue.count),cy=sy/Double(queue.count)
                if cx >= Double(seedX0),cx <= Double(seedX1+1),cy >= Double(seedY0),cy <= Double(seedY1+1),
                   !originalInk(Int(cx),Int(cy)), !staffPixel(Int(cx),Int(cy)) {
                    proposals.append(Proposal(x:cx,y:cy,cavity:true))
                }
            }
        } }
        struct Ellipse { var cx: Double; var cy: Double; var rx: Double; var ry: Double; var angle: Double }
        func fit(_ points: [(Double,Double)], _ seed: Proposal) -> Ellipse? {
            var matrix=Array(repeating:Array(repeating:0.0,count:6),count:5)
            for p in points {
                let x=(p.0-seed.x)/staffSpace,y=(p.1-seed.y)/staffSpace
                let row=[x*x,x*y,y*y,x,y]
                for i in 0..<5 { for j in 0..<5 { matrix[i][j] += row[i]*row[j] };matrix[i][5] += row[i] }
            }
            for col in 0..<5 {
                let pivot=(col..<5).max{abs(matrix[$0][col]) < abs(matrix[$1][col])}!
                guard abs(matrix[pivot][col]) > 1e-8 else { return nil }
                matrix.swapAt(col,pivot)
                let divisor=matrix[col][col]
                for j in col...5 { matrix[col][j] /= divisor }
                for i in 0..<5 where i != col {
                    let factor=matrix[i][col]
                    for j in col...5 { matrix[i][j] -= factor*matrix[col][j] }
                }
            }
            let a=matrix[0][5],b=matrix[1][5]/2,c=matrix[2][5],d=matrix[3][5],e=matrix[4][5]
            let determinant=a*c-b*b
            guard determinant > 1e-8,a > 0,c > 0 else { return nil }
            let x = -(c*d-b*e)/(2*determinant), y = -(-b*d+a*e)/(2*determinant)
            let k=1+a*x*x+2*b*x*y+c*y*y
            let disc=sqrt((a-c)*(a-c)+4*b*b)
            let low=(a+c-disc)/2,high=(a+c+disc)/2
            guard low > 0,high > 0,k > 0 else { return nil }
            let rx=sqrt(k/low)*staffSpace,ry=sqrt(k/high)*staffSpace
            let cx=seed.x+x*staffSpace,cy=seed.y+y*staffSpace
            let angle=0.5*atan2(2*b,a-c)+Double.pi/2
            guard [cx,cy,rx,ry,angle].allSatisfy({$0.isFinite}),
                  2*rx >= staffSpace*0.75,2*rx <= staffSpace*2,
                  2*ry >= staffSpace*0.35,2*ry <= staffSpace*1.25 else { return nil }
            return Ellipse(cx:cx,cy:cy,rx:rx,ry:ry,angle:angle)
        }
        for proposal in proposals {
            if isCancelled() { return nil }
            var points: [(Double,Double)] = [], valid=Array(repeating:false,count:32)
            var quadrants=Array(repeating:0,count:4)
            for direction in 0..<32 {
                let theta=Double(direction)*2*Double.pi/32,dx=cos(theta),dy=sin(theta)
                var wall = !proposal.cavity, lastInk=0.0
                for step in 1...max(1,Int(ceil(staffSpace*4))) {
                    let r=Double(step)*0.5,px=proposal.x+dx*r,py=proposal.y+dy*r
                    guard px >= 0,py >= 0,px < Double(width),py < Double(height) else { break }
                    let x=Int(px),y=Int(py)
                    if originalInk(x,y) { wall=true;lastInk=r;continue }
                    if !wall { continue }
                    let radius=(lastInk+r)/2,bx=proposal.x+dx*radius,by=proposal.y+dy*radius
                    let ix=Int(bx),iy=Int(by)
                    if !staffPixel(ix,iy) && (ix < strokeLeft || ix >= strokeRight) {
                        points.append((bx,by));valid[direction]=true
                        quadrants[(dx < 0 ? 0 : 1)+(dy < 0 ? 0 : 2)] += 1
                    }
                    break
                }
            }
            guard points.count >= 20,quadrants.allSatisfy({$0 > 0}) else { continue }
            var missing=0,longest=0
            for i in 0..<64 { missing=valid[i%32] ? 0 : missing+1;longest=max(longest,missing) }
            guard longest < 11,let ellipse=fit(points,proposal) else { continue }
            let cx=ellipse.cx,cy=ellipse.cy,rx=ellipse.rx,ry=ellipse.ry,angle=ellipse.angle
            guard upper ? cx > spine : cx < spine else { continue }
            let displacement=(cy-boundary)*inward
            guard displacement >= -staffSpace*0.5, displacement <= staffSpace*1.5 else { continue }
            let c=cos(angle),s=sin(angle)
            func normalized(_ x: Double,_ y: Double) -> Double {
                let dx=x-cx,dy=y-cy,u=dx*c+dy*s,v = -dx*s+dy*c
                return u*u/(rx*rx)+v*v/(ry*ry)
            }
            let errors=points.map{p -> Double in
                let norm=sqrt(normalized(p.0,p.1))
                return abs(1-1/max(norm,1e-12))*hypot(p.0-cx,p.1-cy)
            }.sorted()
            guard errors[Int(ceil(Double(errors.count)*0.9))-1] <= 1.25 else { continue }
            let hx=sqrt(rx*rx*c*c+ry*ry*s*s),hy=sqrt(rx*rx*s*s+ry*ry*c*c)
            let x0=Int(floor(cx-1.5*hx)),x1=Int(ceil(cx+1.5*hx))
            let y0=Int(floor(cy-1.5*hy)),y1=Int(ceil(cy+1.5*hy))
            guard x0 >= 0,y0 >= 0,x1 < width,y1 < height else { continue }
            func q(_ x: Int,_ y: Int) -> Double { normalized(Double(x)+0.5,Double(y)+0.5) }
            var inwardRows=0,outwardRows=0,sampledRows=0
            let start=max(1,Int(ceil(hy+staffSpace*0.2))),length=max(3,Int(ceil(staffSpace)))
            for distance in start..<(start+length) {
                let innerY=Int((cy+inward*Double(distance)).rounded())
                let outerY=Int((cy-inward*Double(distance)).rounded())
                if innerY >= 0 && innerY < height { sampledRows += 1;if physicalSpine(innerY) { inwardRows += 1 } }
                if physicalSpine(outerY) { outwardRows += 1 }
            }
            guard sampledRows >= 3,Double(inwardRows) >= Double(sampledRows)*0.8,
                  Double(outwardRows) < Double(length)*0.8 else { continue }
            var outline = Array(repeating: 0, count: 4), outlineInk = outline
            var surround = outline, surroundInk = outline
            var innerCount = 0, innerInk = 0, whiteSeeds: [Int] = []
            for y in y0...y1 { for x in x0...x1 {
                guard x < strokeLeft || x >= strokeRight else { continue }
                guard !staffPixel(x, y) else { continue }
                let norm = q(x, y)
                let quadrant = (Double(x) + 0.5 < cx ? 0 : 1) + (Double(y) + 0.5 < cy ? 0 : 2)
                let black = original[y * width + x]
                if norm >= 0.55 && norm <= 1.05 {
                    outline[quadrant] += 1
                    if black { outlineInk[quadrant] += 1 }
                }
                if norm >= 1.35 && norm <= 2.10 {
                    surround[quadrant] += 1
                    if black { surroundInk[quadrant] += 1 }
                }
                if norm <= 0.30 {
                    innerCount += 1
                    if black { innerInk += 1 } else { whiteSeeds.append(y * width + x) }
                }
            } }
            guard outline.indices.allSatisfy({ outline[$0] >= 2 && Double(outlineInk[$0]) >= Double(outline[$0]) * 0.55 }),
                  innerCount >= 4 else { continue }
            let surroundCount = surround.reduce(0, +), outsideInk = surroundInk.reduce(0, +)
            guard surroundCount >= 8, Double(outsideInk) <= Double(surroundCount) * 0.2,
                  surround.indices.allSatisfy({ surround[$0] >= 1 && Double(surroundInk[$0]) <= Double(surround[$0]) * 0.4 }) else { continue }
            let filled = Double(innerInk) >= Double(innerCount) * 0.8
            var hollow = false
            if !filled && Double(innerCount - innerInk) >= Double(innerCount) * 0.6 {
                // White pixels must form a genuine bounded source
                // cavity. Staff intersections can split a hollow
                // head's cavity; either enclosed piece is evidence.
                var visited = Set<Int>()
                for seed in whiteSeeds where !visited.contains(seed) {
                    var queue = [seed], at = 0, escaped = false
                    visited.insert(seed)
                    while at < queue.count {
                        if at % 128 == 0 && isCancelled() { return nil }
                        let item = queue[at]; at += 1
                        let y = item / width, x = item % width
                        if x <= x0 || x >= x1 || y <= y0 || y >= y1 || q(x, y) > 1.25 { escaped = true }
                        for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] {
                            guard nx >= x0, nx <= x1, ny >= y0, ny <= y1 else { continue }
                            let next = ny * width + nx
                            if !original[next] && visited.insert(next).inserted { queue.append(next) }
                        }
                    }
                    if !escaped && queue.count >= 2 { hollow = true; break }
                }
            }
            guard filled || hollow else { continue }
            // A staff line cannot stand in for a real attachment.
            // Require direct, unbroken original ink from this
            // spine into the fitted oval on two non-staff rows.
            let bodyColumn = upper ? strokeRight + max(1, Int((staffSpace * 0.15).rounded())) : strokeLeft - 1 - max(1, Int((staffSpace * 0.15).rounded()))
            let spineColumn = upper ? strokeRight - 1 : strokeLeft
            guard bodyColumn >= 0, bodyColumn < width else { continue }
            var attachedRows = 0
            for y in max(0, Int(floor(cy - hy)))...min(height - 1, Int(ceil(cy + hy))) {
                guard q(bodyColumn, y) <= 1.05, !staffPixel(bodyColumn, y), !staffPixel(spineColumn, y) else { continue }
                if (min(bodyColumn, spineColumn)...max(bodyColumn, spineColumn)).allSatisfy({ original[y * width + $0] }) { attachedRows += 1 }
            }
            guard attachedRows >= 2 else { continue }
            return EndpointNoteheadWitness(center: [cx, cy], radii: [rx, ry], angleDegrees: angle * 180 / .pi,
                hollow: hollow, attachmentRows: attachedRows,
                outlineSupport: outline.indices.map { Double(outlineInk[$0]) / Double(outline[$0]) },
                surroundingWhite: 1 - Double(outsideInk) / Double(surroundCount))
        }
        return nil
    }
