import Foundation
import CoreGraphics
import CryptoKit

@main enum MusicalSpanOwnershipEvaluation {
 struct Owner: Decodable { let owner:Int;let partID:String;let pixels:Int;let envelope:[Int];let maskRawSHA256:String;let allowedWholeNeighborIDs:[Int] }
 struct Candidate: Decodable { let id:Int;let staffLineFractions:[Double];let topFraction:Double;let bottomFraction:Double }
 struct Fixture: Decodable { let id:String;let family:String;let width:Int;let height:Int;let staffLines:[[Int]];let scales:[Double];let sourceRawSHA256:String;let owners:[Owner];let candidates:[Candidate] }
 static func digest(_ bytes:Data)->String { SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined() }
 static func main() throws {
  let base=URL(fileURLWithPath:CommandLine.arguments[1]);let out=URL(fileURLWithPath:CommandLine.arguments[2])
  let fixtures=try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:base.appendingPathComponent("cases.json")))
  var records:[[String:Any]]=[]
  let start=Date()
  for fixture in fixtures {
   let folder=base.appendingPathComponent(fixture.id),w=fixture.width,h=fixture.height
   let profile=ScoreExtractionProfile(parts:fixture.owners.map { .init(id:$0.partID,name:"Physical staff view \($0.owner)",staffCount:1) },cropMode:"compact")
   let bytes=try Data(contentsOf:folder.appendingPathComponent("source.gray"));precondition(bytes.count==w*h && digest(bytes)==fixture.sourceRawSHA256)
   let masks=try fixture.owners.map { owner -> [UInt8] in
    let data=try Data(contentsOf:folder.appendingPathComponent("owner\(owner.owner).mask"));precondition(data.count==w*h && digest(data)==owner.maskRawSHA256)
    let mask=[UInt8](data);precondition(mask.allSatisfy { $0==0 || $0==1 });precondition(mask.reduce(0) { $0+Int($1) }==owner.pixels)
    precondition(mask.indices.allSatisfy { mask[$0]==0 || bytes[$0]==0 });return mask
   }
   let image=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:w,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),provider:CGDataProvider(data:bytes as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
   let staves=fixture.candidates.map { c in
    StaffBandCandidate(id:c.id,staffLineFractions:c.staffLineFractions,topFraction:c.topFraction,bottomFraction:c.bottomFraction,confidence:1,warnings:[])
   }
   for scale in fixture.scales {
    let rw=Int(Double(w)*scale),rh=Int(Double(h)*scale)
    let context=CGContext(data:nil,width:rw,height:rh,bitsPerComponent:8,bytesPerRow:rw,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
    context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:rw,height:rh));context.interpolationQuality = .high
    context.draw(image,in:CGRect(x:0,y:0,width:rw,height:rh))
    let analysisImage = scale == 1 ? image : context.makeImage()!
    let began=Date();let found=NativeScorePageAnalyzer.notationComponents(image:analysisImage,candidates:staves,skewDegrees:0)
    let page=ScorePageAnalysis(pageIndex:0,pageWidth:Double(w),pageHeight:Double(h),imageWidth:rw,imageHeight:rh,staves:staves.map(ScoreObservedStaff.init),warnings:[],inkComponents:found ?? [])
    let plan=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
    var targets:[[String:Any]]=[]
    for (owner,mask) in zip(fixture.owners,masks) {
     let band=plan.bands.first { $0.partID==owner.partID }
     let rect: [Double] = band.map { [$0.leftFraction*Double(w),$0.topFraction*Double(h),(1-$0.rightFraction)*Double(w),$0.bottomFraction*Double(h)] } ?? [0,0,0,0]
     let lost=mask.indices.filter { index in
      guard mask[index] != 0 else{return false}
      let x=Double(index%w),y=Double(index/w)
      return x<rect[0]-1e-9 || y<rect[1]-1e-9 || x+1>rect[2]+1e-9 || y+1>rect[3]+1e-9
     }
     let shift=fixture.id=="original-case176" ? 10 : 0
     let neighbors=fixture.staffLines.enumerated().filter { other,ys in
      other != owner.owner && rect[0]<=40 && rect[2]>=650 && rect[1]<=Double(ys[0]) && rect[3]>=Double(ys[4]+1+shift)
     }.map { $0.offset }
     targets.append(["owner":owner.owner,"partID":owner.partID,"sourcePixels":owner.pixels,"sourceEnvelope":owner.envelope,"sourceMaskSHA256":owner.maskRawSHA256,"crop":rect,"lostPixels":lost.count,"lostPixelIndices":lost,"wholeNeighborCoreIDs":neighbors,"allowedWholeNeighborIDs":owner.allowedWholeNeighborIDs,"spuriousWholeNeighborCoreIDs":neighbors.filter { !owner.allowedWholeNeighborIDs.contains($0) },"candidateIDs":band?.candidateIDs ?? []])
    }
    records.append(["id":fixture.id,"family":fixture.family,"scale":scale,"sourceRawSHA256":fixture.sourceRawSHA256,"sourceShape":[w,h],"analysisShape":[rw,rh],"analysisReturned":found != nil,"canApply":plan.canApply,"bandCount":plan.bands.count,"elapsedSeconds":Date().timeIntervalSince(began),"targets":targets,"components":try JSONSerialization.jsonObject(with:JSONEncoder().encode(found ?? [])),"bands":try JSONSerialization.jsonObject(with:JSONEncoder().encode(plan.bands))])
   }
  }
  let result:[String:Any]=["cases":records,"elapsedSeconds":Date().timeIntervalSince(start),"note":"Original source masks fixed before candidate inspection. Full musical recovery, exact lost pixel sets, and spurious neighbor inclusion are separate metrics. Case176 requires the complete original target, not just nine pixels."]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:out)
  print("Completed \(records.count) source/scale observations; \(Date().timeIntervalSince(start)) seconds")
 }
}
