import CoreGraphics
import Foundation
import ImageIO
import PDFKit
@main enum Tests {
 typealias D=ScoreSharedEndingDetector
 static var checks=0
 static func check(_ x:@autoclosure()->Bool,_ name:String){checks+=1;if !x(){fatalError("FAIL: \(name)")};print("PASS: \(name)")}
 struct Report:Decodable{var pages:[D.PageResult];var pairs:[D.Pair]}
 struct Inventory:Decodable{var pages:[ScorePageAnalysis]}
 static func read<T:Decodable>(_ t:T.Type,_ p:String)throws->T {try JSONDecoder().decode(t,from:Data(contentsOf:URL(fileURLWithPath:p)))}
 static func image(_ p:String)->CGImage {let s=CGImageSourceCreateWithURL(URL(fileURLWithPath:p) as CFURL,nil)!;return CGImageSourceCreateImageAtIndex(s,0,nil)!}
 static func main() throws {
  let a=try read(Report.self,"Tests/quality_control/native-ending-brackets-v1/kv498-native-final.json"),b=try read(Report.self,"Tests/quality_control/native-ending-brackets-v1/brahms-native-final.json")
  check(a.pages.count+b.pages.count==68,"Every source page evaluated")
  check(a.pairs.count==1 && b.pairs.count==4,"All five independently known pairs; no additional accepted pair")
  check(b.pairs.map{$0.first.pageIndex}==[5,31,35,36],"Known Brahms repeat sources, all four pairs")
  for p in a.pairs+b.pairs {
   var first=p.first;let second=p.second;let gap=first.systemIndex==second.systemIndex ? 0:1
   check(D.pairable(first,second,systemGap:gap),"Source positive \(first.pageIndex)-\(first.systemIndex)")
   first.closedRight=false;check(!D.pairable(first,second,systemGap:gap),"Open first bracket rejected")
   first=p.first;first.evidence=[.init(mode:"accurate",text:"I",confidence:1,bounds:[])];check(first.role==nil,"Accurate Roman-I prose alone does not become numeral1")
   first.evidence=[.init(mode:"fast",text:"I",confidence:0.5,bounds:[])];check(first.role=="first","Literal ambiguous I retained for conditional pair evaluation")
   first.evidence=[.init(mode:"fast",text:"I",confidence:0.49,bounds:[])];check(first.role==nil,"Low confidence ambiguous I rejected")
   first.evidence=[.init(mode:"accurate",text:"1",confidence:1,bounds:[]),.init(mode:"accurate",text:"2",confidence:1,bounds:[])];check(first.role==nil,"Conflicting numeral evidence rejected")
   check(!D.pairable(p.first,second,systemGap:2),"Distant system cannot validate an ending")
  }
  let page=a.pages.first{$0.pageIndex==24}!
  check(D.pairs(in:[page]).count==1,"Paired selection positive")
  var bad=page;bad.ownershipVerified=false;check(D.pairs(in:[bad]).isEmpty,"Unverified staff ownership cannot supply a pair")
  bad=page;bad.systemIndices=[];check(D.pairs(in:[bad]).isEmpty,"Unknown system cannot supply a pair")
  bad=page;bad.candidates.append(a.pairs[0].first);check(D.pairs(in:[bad]).isEmpty,"Two first endings cannot share one second ending")
  bad=page;bad.candidates.append(a.pairs[0].second);check(D.pairs(in:[bad]).isEmpty,"One first ending cannot validate two seconds")
  var crossFirst=b.pairs[0].first,crossSecond=b.pairs[0].second
  crossFirst.pageIndex=0;crossFirst.systemIndex=0;crossSecond.pageIndex=9;crossSecond.systemIndex=0
  let firstPage=D.PageResult(pageIndex:0,ownershipVerified:true,systemIndices:[0],geometryProposalCount:0,mergedProposalCount:0,candidates:[crossFirst])
  var secondPage=D.PageResult(pageIndex:9,ownershipVerified:true,systemIndices:[0],geometryProposalCount:0,mergedProposalCount:0,candidates:[crossSecond])
  check(D.pairs(in:[firstPage,secondPage]).isEmpty,"Unsupplied PDF pages block cross-page pairing")
  crossSecond.pageIndex=2;secondPage.pageIndex=2;secondPage.candidates=[crossSecond]
  let uncertainPage=D.PageResult(pageIndex:1,ownershipVerified:false,systemIndices:[],geometryProposalCount:0,mergedProposalCount:0,candidates:[])
  check(D.pairs(in:[firstPage,uncertainPage,secondPage]).isEmpty,"Unresolved intermediate page blocks pairing")
  let blankPage=D.PageResult(pageIndex:1,ownershipVerified:true,systemIndices:[],geometryProposalCount:0,mergedProposalCount:0,candidates:[])
  check(D.pairs(in:[firstPage,blankPage,secondPage]).count==1,"Explicit verified blank page preserves musical system adjacency")
  var cancellationCalls=0
  check(D.pairs(in:[page],isCancelled:{cancellationCalls+=1;return cancellationCalls>=3}).isEmpty,"Cancellation after pair traversal returns no partial result")
  check(a.pages.first{$0.pageIndex==6}!.candidates.count==1 && !a.pairs.contains{$0.first.pageIndex==6 || $0.second.pageIndex==6},"Actual Mozart beam misread2 rejected as unpaired")
  check(b.pages.first{$0.pageIndex==29}!.candidates.count==1 && !b.pairs.contains{$0.first.pageIndex==29 || $0.second.pageIndex==29},"Actual Brahms beam misread2 rejected as unpaired")
  check(D.pairs(in:[page,page]).isEmpty,"Duplicate page identity rejected")
  check(D.pairs(in:[page],isCancelled:{true}).isEmpty,"Canceled pair selection emits no partial output")
  var other=a.pairs[0].second;other.anchorStaffID+=1
  check(!D.pairable(a.pairs[0].first,other,systemGap:0),"Same-system pair requires identical verified anchor")
  let blank=D.Raster(width:10,height:10,pixels:[UInt8](repeating:255,count:100))
  check(D.proposals(raster:blank,space:2,top:0,bottom:10).isEmpty,"Blank source produces no line/hook proposal")
  check(D.proposals(raster:blank,space:.nan,top:0,bottom:10).isEmpty,"Nonfinite staff space rejected")
  let staffJSON="{\"id\":0,\"staffLineFractions\":[0.478260869565,0.565217391304,0.652173913043,0.739130434783,0.826086956522],\"topFraction\":0.4,\"bottomFraction\":0.9,\"confidence\":1,\"warnings\":[]}"
  let staff=try JSONDecoder().decode(ScoreObservedStaff.self,from:Data(staffJSON.utf8))
  let syntheticPage=ScorePageAnalysis(pageIndex:0,pageWidth:620,pageHeight:230,imageWidth:620,imageHeight:230,staves:[staff],warnings:[])
  let syntheticProfile=ScoreExtractionProfile(parts:[ScorePartDefinition(id:"one",name:"One",staffCount:1)])
  check(D.systems(page:syntheticPage,profile:syntheticProfile,isCancelled:{false})?.count == 1,"Synthetic ownership positive")
  var unresolved=syntheticProfile;unresolved.requiresSystemAssignment=true
  check(D.systems(page:syntheticPage,profile:unresolved,isCancelled:{false})==nil,"Public ownership rejects unresolved profile")
  var invalid=syntheticPage;invalid.staves.append(invalid.staves[0]);check(D.systems(page:invalid,profile:syntheticProfile,isCancelled:{false})==nil,"Duplicate physical staff rejected")
  invalid=syntheticPage;invalid.staves[0].staffLineFractions[0] = .nan;check(D.systems(page:invalid,profile:syntheticProfile,isCancelled:{false})==nil,"Invalid staff lines rejected before recognition")
  let stable=JSONEncoder();stable.outputFormatting=[.sortedKeys]
  for (name,report) in [("Mozart",a),("Brahms",b)] {
   let recomputed = D.pairs(in:report.pages)
   let actual = try stable.encode(recomputed), expected = try stable.encode(report.pairs)
   check(actual==expected,"\(name) complete page roster preserves every reviewed pair and literal evidence")
  }
  if !CommandLine.arguments.contains("--vision") {
   print("\(checks) ending controls passed; native Vision image controls require --vision")
   return
  }
  for name in ["shifted-prose","unpaired-roman-i","prose-in-number-cell"] {
   let original=image("Tests/extraction/shared-ending-fixtures/negative-\(name).png")
   let r=D.Raster(image:original)!
   let values=r.pixels+[UInt8](repeating:255,count:r.width*(230-r.height))
   let provider=CGDataProvider(data:Data(values) as CFData)!
   let im=CGImage(width:r.width,height:230,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:r.width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
   var errors:[Error]=[]
   let result=D.analyze(in:im,page:syntheticPage,profile:syntheticProfile,observedFailure:{errors.append($0)})
   check(errors.isEmpty,"\(name) OCR completed, not silent failure")
   check(result.ownershipVerified,"\(name) uses verified system")
   check(D.pairs(in:[result]).isEmpty,"\(name) does not create an ending pair")
   let enc=JSONEncoder();enc.outputFormatting=[.prettyPrinted,.sortedKeys];try enc.encode(result).write(to:URL(fileURLWithPath:".build/shared-ending-tests/negative-\(name).json"))
  }
  print("\(checks) ending controls passed")
 }
}
