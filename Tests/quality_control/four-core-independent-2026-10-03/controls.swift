import Foundation
import CoreGraphics
import ImageIO
@main enum FourCoreMusicalControls {
 static let w=720,h=500,spine=500
 static let lines=[[103,112,120,128,136],[178,186,194,202,210],[270,278,287,295,303],[344,352,361,369,377]]
 static func image(_ a:[UInt8])->CGImage{CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:w,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),provider:CGDataProvider(data:Data(a) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!}
 static func save(_ a:[UInt8],_ p:URL){let sink=CGImageDestinationCreateWithURL(p as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(sink,image(a),nil);precondition(CGImageDestinationFinalize(sink))}
 static func main() throws {
  let out=URL(fileURLWithPath:CommandLine.arguments[1]),dir=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
  let profile=ScoreExtractionProfile(parts:(0..<4).map{.init(id:"staff\($0)",name:"Physical staff view \($0)",staffCount:1)},cropMode:"compact")
  var results:[[String:Any]]=[]
  for kind in ["filledOuter","hollowOuter","filledTiedOuter","hollowTiedOuter","filledFirstSpace","hollowFirstSpace"] {for damaged in [false,true] {
   var ink=[UInt8](repeating:255,count:w*h),owners=[UInt8](repeating:0,count:w*h)
   func mark(_ x:Int,_ y:Int,_ owner:UInt8=0){guard x>=0,x<w,y>=0,y<h else{return};ink[y*w+x]=0;owners[y*w+x] |= owner}
   func rect(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ owner:UInt8=0){for y in y0..<y1{for x in x0..<x1{mark(x,y,owner)}}}
   func head(_ cx:Double,_ cy:Double,_ hollow:Bool,_ owner:UInt8){for y in Int(cy-7)...Int(cy+7){for x in Int(cx-9)...Int(cx+9){let dx=Double(x)+0.5-cx,dy=Double(y)+0.5-cy;let a = -Double.pi/6,c=cos(a),s=sin(a),u=dx*c+dy*s,v = -dx*s+dy*c;let outer=u*u/49+v*v/16<=1;let inner=u*u/25+v*v/4<1;if outer && (!hollow || !inner){mark(x,y,owner)}}}}
   for (i,staff) in lines.enumerated(){for y in staff{rect(40,y,650,y+1)};let x=150+i*50;rect(x,staff[0]-14,x+2,staff[0]+23,UInt8(1<<i));head(Double(x-4),Double(staff[0]+22),false,UInt8(1<<i))}
   rect(40,lines[0][0],43,lines[3][4]+1)
   // One physical corridor runs through four cores. The upper two views own
   // a source-authored cross-staff chord; its stem coincides with continuing
   // structural ink through two additional staves. Donor continuity alone
   // must not erase the musical part of that shared physical corridor.
   rect(spine,lines[0][0],spine+2,lines[3][4]+1)
   let top=lines[0][0]+(kind.contains("FirstSpace") ? 8 : 0),last=lines[1][4]
   rect(spine,top,spine+2,last+1,3)
   let hollow=kind.hasPrefix("hollow")
   head(Double(spine+5),Double(top),hollow,3);head(Double(spine-5),Double(last),hollow,3)
   if kind.contains("Tied") {
    for x in (spine+6)...(spine+75){let t=Double(x-spine-6)/69;let y=Double(top)-5-8*4*t*(1-t);mark(x,Int(y.rounded()),3);mark(x,Int(y.rounded())+1,3)}
   }
   if damaged {
    // Exact five missing native source rows motivated by p28:113..<117 and
    //122..<123. Erasing applies to both source and owner masks, not the oracle
    // after analysis; outer junctions and all three other cores stay intact.
    for y in [113,114,115,116,122]{for x in spine..<(spine+2){ink[y*w+x]=255;owners[y*w+x]=0}}
   }
   let id=kind+(damaged ? "-fiveMissingRows":"-intact")
   save(ink,dir.appendingPathComponent(id+".png"));var envelopes:[[Int]]=[]
   for owner in 0..<4{var mask=[UInt8](repeating:255,count:w*h),x0=w,y0=h,x1=0,y1=0;for y in 0..<h{for x in 0..<w where owners[y*w+x] & UInt8(1<<owner) != 0{mask[y*w+x]=0;x0=min(x0,x);y0=min(y0,y);x1=max(x1,x+1);y1=max(y1,y+1)}};save(mask,dir.appendingPathComponent(id+"-owner\(owner).png"));envelopes.append([x0,y0,x1,y1])}
   for scale in [0.5,1.0,1.5] {
    let width=Int(Double(w)*scale),height=Int(Double(h)*scale);let ctx=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray:1,alpha:1);ctx.fill(CGRect(x:0,y:0,width:width,height:height));ctx.interpolationQuality = .high;ctx.draw(image(ink),in:CGRect(x:0,y:0,width:width,height:height))
    let staves=lines.enumerated().map{i,ys in StaffBandCandidate(id:i,staffLineFractions:ys.map{Double($0)/Double(h)},topFraction:Double(ys[0]-24)/Double(h),bottomFraction:Double(ys[4]+24)/Double(h),confidence:1,warnings:[])}
    let components=NativeScorePageAnalyzer.notationComponents(image:ctx.makeImage()!,candidates:staves,skewDegrees:0)!
    let page=ScorePageAnalysis(pageIndex:0,pageWidth:Double(w),pageHeight:Double(h),imageWidth:width,imageHeight:height,staves:staves.map(ScoreObservedStaff.init),warnings:[],inkComponents:components)
    let plan=ScoreExtractionPlanner.plan(pages:[page],profile:profile);var targets:[[String:Any]]=[]
    for owner in 0..<4 {let b=plan.bands.first{$0.partID=="staff\(owner)"}!;let crop=[b.topFraction*Double(h),b.bottomFraction*Double(h)];var total=0,lost=0;for y in 0..<h{for x in 0..<w where owners[y*w+x] & UInt8(1<<owner) != 0{total+=1;if Double(y)<crop[0]-1e-9 || Double(y+1)>crop[1]+1e-9{lost+=1}}};targets.append(["owner":owner,"sourceEnvelope":envelopes[owner],"sourcePixels":total,"lostPixels":lost,"crop":crop])}
    results.append(["id":id,"kind":kind,"damaged":damaged,"scale":scale,"targets":targets,"components":try JSONSerialization.jsonObject(with:JSONEncoder().encode(components)),"bands":try JSONSerialization.jsonObject(with:JSONEncoder().encode(plan.bands))])
   }
  }}
  try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:out)
 }
}
