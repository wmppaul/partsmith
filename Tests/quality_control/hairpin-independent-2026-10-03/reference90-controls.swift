import Foundation
import CoreGraphics
@main enum HairpinControls {
 static func main()throws {
  let out=URL(fileURLWithPath:CommandLine.arguments[1]);var results:[[String:Any]]=[]
  let kinds=["diminuendo","crescendo","singleRule","parallelRules","textIslands","solidTriangle","doubleCurves","truncatedWedge","betweenStaves","tinyFooterWedge"]
  for kind in kinds {for scale in [0.5,1.0,1.5] {for tilt in [-1.5,0.0,1.5] {
   let w=720,h=600;var pixels=[UInt8](repeating:255,count:w*h),owned=[Bool](repeating:false,count:w*h)
   func set(_ x:Int,_ y:Int,_ isOwned:Bool=false) {guard x>=0,x<w,y>=0,y<h else{return};pixels[y*w+x]=0;if isOwned{owned[y*w+x]=true}}
   func line(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ isOwned:Bool=false) {
    for x in x0...x1 {let y=Double(y0)+Double(x-x0)*Double(y1-y0)/Double(max(1,x1-x0));for yy in Int(y.rounded())...(Int(y.rounded())+1){set(x,yy,isOwned)}}
   }
   for top in [200,350] {for dy in [0,12,24,36,48] {line(40,top+dy,680,top+dy)}}
   for y in 350..<387 {for x in 150..<153{set(x,y,true)}}
   for y in 379..<387 {for x in 140..<154{set(x,y,true)}}
   let positive=["diminuendo","crescendo"].contains(kind)
   switch kind {
    case "diminuendo":line(390,438,500,448,true);line(390,458,500,448,true)
    case "crescendo":line(390,448,500,438,true);line(390,448,500,458,true)
    case "singleRule":line(390,445,500,445)
    case "parallelRules":line(390,438,500,438);line(390,450,500,450)
    case "textIslands":for x in stride(from:390,to:500,by:11){for y in 438..<450 {set(x,y);set(x+6,y)};line(x,438,x+6,438);line(x,449,x+6,449)}
    case "solidTriangle":for x in 390...500{let gap=Int((10.0*Double(500-x)/110).rounded());for y in (448-gap)...(448+gap){set(x,y)}}
    case "doubleCurves":for x in 390...500 {let t=Double(x-390)/110;let curve=8*sin(.pi*t);set(x,Int((438+10*t+curve).rounded()));set(x,Int((458-10*t+curve).rounded()))}
    case "truncatedWedge":line(390,438,500,446);line(390,458,500,450)
    case "betweenStaves":line(390,288,500,298);line(390,308,500,298)
    default:line(390,438,408,448);line(390,458,408,448)
   }
   var rotated=[UInt8](repeating:255,count:w*h),target=[Bool](repeating:false,count:w*h)
   for x in 0..<w {let shift=Int((tan(tilt * .pi / 180)*(Double(x)-360)).rounded());for y in 0..<h where y+shift>=0 && y+shift<h {rotated[(y+shift)*w+x]=pixels[y*w+x];target[(y+shift)*w+x]=owned[y*w+x]}}
   let original=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:w,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:.init(rawValue:0),provider:CGDataProvider(data:Data(rotated) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
   let aw=Int(Double(w)*scale),ah=Int(Double(h)*scale)
   let c=CGContext(data:nil,width:aw,height:ah,bitsPerComponent:8,bytesPerRow:aw,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
   c.setFillColor(gray:1,alpha:1);c.fill(CGRect(x:0,y:0,width:aw,height:ah));c.interpolationQuality = .high;c.draw(original,in:CGRect(x:0,y:0,width:aw,height:ah));let image=c.makeImage()!
   let staves=[200,350].enumerated().map{i,y in StaffBandCandidate(id:i,staffLineFractions:(0..<5).map{Double(y+$0*12)/Double(h)},topFraction:Double(y-36)/Double(h),bottomFraction:Double(y+84)/Double(h),confidence:1,warnings:[])}
   let a=BaselineAnalyzer.notationComponents(image:image,candidates:staves,skewDegrees:tilt)!,b=NativeScorePageAnalyzer.notationComponents(image:image,candidates:staves,skewDegrees:tilt)!
   let profile=ScoreExtractionProfile(parts:[.init(id:"upper",name:"Upper",staffCount:1),.init(id:"lower",name:"Lower",staffCount:1)],cropMode:"compact")
   func plan(_ ink:[ScoreInkComponent])->ScoreExtractionPlan {ScoreExtractionPlanner.plan(pages:[.init(pageIndex:0,pageWidth:Double(w),pageHeight:Double(h),imageWidth:aw,imageHeight:ah,staves:staves.map(ScoreObservedStaff.init),warnings:[],analysisSkewDegrees:tilt,inkComponents:ink)],profile:profile)}
   let before=plan(a),after=plan(b),bc=before.bands[1],ac=after.bands[1]
   let positions=target.indices.filter{target[$0]},top=Double(positions.map{$0/w}.min()!),bottom=Double(positions.map{$0/w}.max()!+1)
   let kept=ac.topFraction*Double(h)<=top && ac.bottomFraction*Double(h)>=bottom
   let extras=b.count-a.count
   results.append(["kind":kind,"scale":scale,"tilt":tilt,"positive":positive,"added":extras,"preservedTarget":kept,"before":[bc.topFraction*Double(h),bc.bottomFraction*Double(h)],"after":[ac.topFraction*Double(h),ac.bottomFraction*Double(h)],"negativeUnchanged":positive || before==after,"upperUnchanged":before.bands[0]==after.bands[0]])
  }}}
  try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:out)
  print("\(results.count) controls; positive misses \(results.filter{$0["positive"] as? Bool==true && $0["preservedTarget"] as? Bool != true}.count); changed negatives \(results.filter{$0["negativeUnchanged"] as? Bool != true}.count)")
 }
}
