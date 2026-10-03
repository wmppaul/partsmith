import Foundation
import CoreGraphics
import ImageIO

@main enum IndependentGlyphReview {
 static let width=512,height=384
 static let original=[160.0/512,70.0/384,340.0/512,150.0/384]
 static var checks:[[String:Any]]=[]
 static var observations:[[String:Any]]=[]
 static let output=URL(fileURLWithPath:"Tests/quality_control/heading-glyph-independent")
 static func same(_ a:[Double],_ b:[Double])->Bool {a.count==b.count && zip(a,b).allSatisfy{$0.bitPattern==$1.bitPattern}}
 static func retained(_ a:[Double],_ b:[Double])->Bool {a[0]<=b[0] && a[1]<=b[1] && a[2]>=b[2] && a[3]>=b[3]}
 static func check(_ name:String,_ value:Bool,_ detail:[String:Any]=[:]) {checks.append(detail.merging(["name":name,"passed":value]){old,_ in old})}
 static func anchor(_ lines:[Double]=[170,180,190,200,210])->ScoreObservedStaff {ScoreObservedStaff(StaffBandCandidate(id:0,staffLineFractions:lines.map{$0/384},topFraction:0.4,bottomFraction:0.6,confidence:1,warnings:[]))}
 static func bitmap(_ pixels:[UInt8])->CGImage {CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.none.rawValue),provider:CGDataProvider(data:Data(pixels) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!}
 static func image(_ draw:(inout [UInt8])->Void)->CGImage {var p=[UInt8](repeating:255,count:width*height);draw(&p);return bitmap(p)}
 static func rect(_ p:inout[UInt8],_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ gray:UInt8=0) {for yy in max(0,y)..<min(height,y+h) {for xx in max(0,x)..<min(width,x+w) {p[yy*width+xx]=gray}}}
 static func line(_ p:inout[UInt8],_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ gray:UInt8=0) {let n=max(abs(x1-x0),abs(y1-y0));for i in 0...n {let x=x0+(x1-x0)*i/max(1,n),y=y0+(y1-y0)*i/max(1,n);rect(&p,x-1,y-1,3,3,gray)}}
 static func glyph(_ p:inout[UInt8],_ x:Int,_ y:Int=92,_ gray:UInt8=0) {line(&p,x,y+32,x+12,y,gray);line(&p,x+12,y,x+24,y+32,gray);line(&p,x+4,y+23,x+20,y+23,gray)}
 static func run(_ image:CGImage,_ bounds:[Double]=original,_ staff:ScoreObservedStaff=anchor(),_ cancel:()->Bool={false})->[Double] {ScoreSharedHeadingDetector.continuedGlyphBounds(in:image,bounds:bounds,anchor:staff,isCancelled:cancel)}
 static func writeImage(_ image:CGImage,_ name:String)throws {let url=output.appendingPathComponent(name+".png");let dest=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))}
 struct Item:Decodable {var number:Int;var `case`:String;var page:Int;var anchorStaffID:Int;var acceptedHeading:ScoreSharedHeading}
 struct Input:Decodable {var inventory:String}
 struct Inventory:Decodable {var pages:[ScorePageAnalysis]}
 static func main()throws {
  let staff=anchor()
  // Independent subset cuts across two real letter contours, both directions.
  for side in ["left","right"] {for cut in [2,5,8,11] {for gray:UInt8 in [0,128,210] {
   let x=side=="left" ? 160-cut:340+cut-25
   let im=image{glyph(&$0,x,92,gray)};let got=run(im)
   let full=side=="left" ? got[0]*512<=Double(x-1):got[2]*512>=Double(x+26)
   check("\(side) letter cut\(cut) gray\(gray) complete",full,["actual":got]);check("\(side) cut\(cut) gray\(gray) retains original",retained(got,original));check("\(side) cut\(cut) gray\(gray) vertical edges exact",got[1]==original[1] && got[3]==original[3])
  }}}
  let both=image{glyph(&$0,152);glyph(&$0,323)};let changed=run(both)
  check("both independent clipped letters recovered",changed[0]*512<=151 && changed[2]*512>=349,["actual":changed]);check("both recovered bounds valid",ScoreSharedEnding.validBounds(changed));check("isolated recovered letters stable",same(run(both,changed),changed))
  let full=image{glyph(&$0,180);rect(&$0,250,86,3,37);rect(&$0,241,119,12,6);rect(&$0,258,120,3,3);rect(&$0,270,105,11,2);rect(&$0,270,111,11,2);rect(&$0,292,95,3,29);rect(&$0,309,123,3,3)}
  check("complete metronome note/dot/equality/digits/punctuation bounds preserved",same(run(full),original))
  let rejects:[(String,(inout[UInt8])->Void)]=[
   ("blank",{_ in}),
   ("detached external letter",{glyph(&$0,125)}),
   ("shallow long beam",{rect(&$0,140,125,50,4)}),
   ("vertical stem leaves bottom",{rect(&$0,153,100,10,90)}),
   ("vertical fragment leaves top",{rect(&$0,153,45,10,65)}),
   ("component exceeds horizontal search",{rect(&$0,130,90,49,30)}),
   ("short detached punctuation",{rect(&$0,157,117,7,4)}),
   ("staff at first-staff cutoff",{rect(&$0,140,167,220,2)})]
  for (name,draw) in rejects {check(name+" does not expand",same(run(image(draw)),original))}
  for (name,bad) in [("empty",[Double]()),("three",[0.1,0.2,0.3]),("NaN",[Double.nan,0.2,0.6,0.4]),("infinity",[0.2,0.2,Double.infinity,0.4]),("negative",[-0.01,0.2,0.6,0.4]),("beyond image",[0.2,0.2,1.01,0.4]),("reversed",[0.6,0.2,0.2,0.4]),("zero height",[0.2,0.3,0.6,0.3])] {check("invalid bounds "+name+" unchanged",same(run(both,bad),bad))}
  for (name,lines) in [("none",[Double]()),("four",[170,180,190,200]),("unordered",[170,180,175,200,210]),("duplicates",[170,180,180,200,210]),("NaN",[170,180,Double.nan,200,210]),("infinite",[170,180,190,200,Double.infinity]),("negative",[-1,180,190,200,210]),("beyond",[170,180,190,200,385]),("tiny",[170,171,172,173,174])] {check("invalid anchor "+name+" unchanged",same(run(both,original,anchor(lines)),original))}
  for edge in [0.0,1.0] {let box=edge==0 ? [0.0,original[1],original[2],original[3]]:[original[0],original[1],1.0,original[3]];let got=run(both,box);check("page edge \(edge) valid and retains original",retained(got,box) && ScoreSharedEnding.validBounds(got))}
  var totalCalls=0;_ = run(both,original,staff,{totalCalls+=1;return false})
  for stop in 1...totalCalls {var calls=0;let result=run(both,original,staff,{calls+=1;return calls>=stop});check("cancel call\(stop) discards all expansion",same(result,original))}
  // Exercise cancellation inside a >4096-pixel flood fill after an earlier
  // component has already proposed an expansion.
  let large=image{p in rect(&p,154,78,15,10);rect(&p,151,101,182,43)}
  var largeCalls=0;_ = run(large,original,staff,{largeCalls+=1;return false})
  for stop in 1...largeCalls {var calls=0;let result=run(large,original,staff,{calls+=1;return calls>=stop});check("large flood cancel call\(stop) discards all expansion",same(result,original))}
  // Full source-equation preservation does not imply semantic glyph recognition.
  let impostors:[(String,(inout[UInt8])->Void)]=[
    ("complete notehead with stem",{rect(&$0,151,119,14,7);rect(&$0,162,89,3,34)}),
    ("curved slur inside box",{line(&$0,151,117,158,100);line(&$0,158,100,169,107)}),
    ("small complete sharp",{rect(&$0,153,97,2,27);rect(&$0,160,93,2,28);rect(&$0,150,102,17,3);rect(&$0,150,115,17,3)})]
  for (name,draw) in impostors {let im=image(draw),got=run(im);observations.append(["name":name,"bounds":got,"expanded":got != original]);try writeImage(im,name.replacingOccurrences(of:" ",with:"-"))}
  // Same row range, disconnected interleaved components. Tests repeated use, no moving oracle.
  let chain=image{p in glyph(&p,152);rect(&p,145,76,16,9)}
  let one=run(chain),two=run(chain,one);observations.append(["name":"repeated disconnected continuation","once":one,"twice":two,"idempotent":one==two]);try writeImage(chain,"disconnected-chain")
  let fringe=image{p in glyph(&p,155);rect(&p,151,121,5,3,238)};let fg=run(fringe);observations.append(["name":"faint238 continuation attached to dark glyph","bounds":fg,"faintExtentRetained":fg[0]*512<=151]);try writeImage(fringe,"faint-fringe")
  let decoder=JSONDecoder();let items=try decoder.decode([Item].self,from:Data(contentsOf:URL(fileURLWithPath:"Tests/quality_control/accepted-heading-source-review/index.json")));let inputs=try decoder.decode([String:Input].self,from:Data(contentsOf:URL(fileURLWithPath:"Tests/quality_control/accepted-heading-source-review/inputs.json")))
  var sourceResults:[[String:Any]]=[]
  for item in items {let inv=try decoder.decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:inputs[item.case]!.inventory)));let page=inv.pages.first{$0.pageIndex==item.page-1}!,anchor=page.staves.first{$0.id==item.anchorStaffID}!;let path=".build/accepted-heading-source-review/\(item.case)-p\(item.page).png";let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!,im=CGImageSourceCreateImageAtIndex(src,0,nil)!;let before=item.acceptedHeading.bounds;let after=run(im,before,anchor);sourceResults.append(["number":item.number,"before":before,"after":after,"changed":before != after,"originalRetained":retained(after,before),"rasterSize":[im.width,im.height]])}
  let result:[String:Any]=["checks":checks,"count":checks.count,"failures":checks.filter{$0["passed"] as? Bool != true}.count,"observations":observations,"sourceResults":sourceResults]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("results.json"))
  print("\(checks.count) controls, \(checks.filter{$0["passed"] as? Bool != true}.count) failures, \(sourceResults.count) original regions")
  if checks.contains(where:{$0["passed"] as? Bool != true}) {exit(1)}
 }
}
