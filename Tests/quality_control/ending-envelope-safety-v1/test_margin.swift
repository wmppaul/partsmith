import Foundation
@main enum Tests {
 typealias D=ScoreSharedEndingDetector
 struct Report:Codable {var pages:[D.PageResult];var pairs:[D.Pair]}
 struct Guard:Decodable {var guardRect:[Double];var pageNumber:Int;var systemNumber:Int}
 static var n=0
 static func check(_ b:Bool,_ s:String){n+=1;precondition(b,s);print("PASS: \(s)")}
 static func read<T:Decodable>(_ t:T.Type,_ p:String)throws->T{try JSONDecoder().decode(t,from:Data(contentsOf:URL(fileURLWithPath:p)))}
 static func contains(_ a:[Double],_ b:[Double])->Bool{a.count==4 && a[0]<=b[0]+1e-8 && a[1]<=b[1]+1e-8 && a[2]>=b[2]-1e-8 && a[3]>=b[3]-1e-8}
 static func union(_ r:[[Double]])->[Double]{[r.map{$0[0]}.min()!,r.map{$0[1]}.min()!,r.map{$0[2]}.max()!,r.map{$0[3]}.max()!]}
 static func identities(_ pairs:[D.Pair])throws->Data {
  var x=pairs
  for i in x.indices{x[i].first.copyBounds=[];x[i].second.copyBounds=[]}
  let e=JSONEncoder();e.outputFormatting=[.sortedKeys];return try e.encode(x)
 }
 static func main()throws {
  let a=try read(Report.self,"Tests/quality_control/native-ending-brackets-v1/kv498-native-final.json")
  let b=try read(Report.self,"Tests/quality_control/native-ending-brackets-v1/brahms-native-final.json")
  check(a.pages.count+b.pages.count==68,"Complete68-page frozen recognition roster")
  var changed=0
  for (score,r) in [("kv498",a),("brahms",b)] {
   var pages=r.pages
   for p in pages.indices{for c in pages[p].candidates.indices{
    let old=pages[p].candidates[c];let proposed=D.copyBounds(for:old)
    check(contains(proposed,old.copyBounds),"Candidate preserves old copy \(score)-\(old.pageIndex)-\(old.systemIndex)-\(c)")
    pages[p].candidates[c].copyBounds=proposed;changed+=1
   }}
   let pairs=D.pairs(in:pages)
   check(try identities(pairs)==identities(r.pairs),"\(score) all pair identities and literal recognition evidence unchanged")
   let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
   try encoder.encode(Report(pages:pages,pairs:pairs)).write(to:URL(fileURLWithPath:".build/qc-ending-envelope-safety/\(score)-native-margin.json"))
   if score=="brahms"{
    let guards=try read([Guard].self,"Tests/quality_control/native-ending-brackets-v1/native-guard-comparison.json")
    for g in guards{
     let groups=pairs.flatMap{p->[[Double]] in
      let members=[p.first,p.second].filter{$0.pageIndex==g.pageNumber-1 && $0.systemIndex==g.systemNumber-1}
      return members.isEmpty ? []:[union(members.map(\.copyBounds))]
     }
     check(groups.contains{contains($0,g.guardRect)},"Fixed Brahms guard p\(g.pageNumber)s\(g.systemNumber) contained in actual pair source row")
    }
   }else{
    check(contains(union([pairs[0].first.copyBounds,pairs[0].second.copyBounds]),[55.5,349.5,256.5,361.5]),"Immutable Mozart pair envelope retained")
   }
  }
  check(changed==13,"All13 numeric candidates evaluated; no OCR rerun")
  var c=a.pairs[0].first;c.bounds=[50,50,100,65];c.staffSpace=4;c.pageWidth=200;c.pageHeight=200;c.rightHookBottom=nil
  check(D.copyBounds(for:c)==[46,46,104,69],"One interline allowance on each side")
  c.rightHookBottom=75;check(D.copyBounds(for:c)==[46,46,104,79],"Measured closed hook retained plus interline allowance")
  c.bounds=[1,1,199,199];check(D.copyBounds(for:c)==[0,0,200,200],"Physical page bounds respected")
  c.staffSpace = .nan;check(D.copyBounds(for:c).isEmpty,"Invalid staff space rejected")
  c.staffSpace=4;c.bounds=[50,50,10,10];check(D.copyBounds(for:c).isEmpty,"Inverted geometry rejected")
  c.bounds=[50,50,100,65];c.rightHookBottom = .nan;check(D.copyBounds(for:c).isEmpty,"Invalid hook geometry rejected")
  print("\(n) candidate-margin controls passed")
 }
}
