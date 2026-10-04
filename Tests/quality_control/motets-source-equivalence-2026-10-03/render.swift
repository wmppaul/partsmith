import Foundation
import PDFKit
import ImageIO

@main enum CompareSources {
 static func main()throws {
  let out=CommandLine.arguments[1]
  let paths=["sample_scores/lightly_skewed/07_brahms_2_motets_op74_imslp_101579.pdf","sample_scores/medium_skewed/07_brahms_2_motets_op74_imslp_101580.pdf"]
  var scores:[[String:Any]]=[]
  for (sourceIndex,path) in paths.enumerated(){
   let pdf=PDFDocument(url:URL(fileURLWithPath:path))!
   let label=sourceIndex==0 ? "101579" : "101580"
   try FileManager.default.createDirectory(atPath:out+"/"+label,withIntermediateDirectories:true)
   var pages:[[String:Any]]=[]
   for i in 0..<pdf.pageCount {
    let page=pdf.page(at:i)!
    var boxes:[String:[Double]]=[:]
    for (key,box) in [("media",PDFDisplayBox.mediaBox),("crop",.cropBox),("bleed",.bleedBox),("trim",.trimBox),("art",.artBox)]{
     let r=page.bounds(for:box);boxes[key]=[r.minX,r.minY,r.width,r.height]
    }
    guard let image=NativeScorePageAnalyzer.render(page),image.width==1800 else{fatalError("Native render failed or did not reach requested width")}
    let output=out+"/"+label+String(format:"/page-%02d.png",i+1)
    let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output)as CFURL,"public.png"as CFString,1,nil)!
    CGImageDestinationAddImage(destination,image,nil)
    guard CGImageDestinationFinalize(destination)else{fatalError("Cannot save original render")}
    pages.append(["physicalPage":i+1,"boxes":boxes,"rotation":page.rotation,"imageWidth":image.width,"imageHeight":image.height,"path":output])
    print(label,"page",i+1);fflush(stdout)
   }
   scores.append(["source":path,"pageCount":pdf.pageCount,"pages":pages])
  }
  try JSONSerialization.data(withJSONObject:scores,options:[.sortedKeys,.prettyPrinted]).write(to:URL(fileURLWithPath:out+"/native-pages.json"))
 }
}
