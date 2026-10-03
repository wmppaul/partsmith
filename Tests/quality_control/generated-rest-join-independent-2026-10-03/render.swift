import AppKit
import PDFKit
@main struct Run {
 static func main()throws {
  let args=CommandLine.arguments;let doc=PDFDocument(url:URL(fileURLWithPath:args[1]))!;try FileManager.default.createDirectory(atPath:args[2],withIntermediateDirectories:true)
  var text=""
  for i in 0..<doc.pageCount {
   let page=doc.page(at:i)!,box=page.bounds(for:.mediaBox),scale=2.0
   let ctx=CGContext(data:nil,width:Int(ceil(box.width*scale)),height:Int(ceil(box.height*scale)),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
   ctx.setFillColor(gray:1,alpha:1);ctx.fill(CGRect(x:0,y:0,width:ctx.width,height:ctx.height));ctx.scaleBy(x:scale,y:scale);page.draw(with:.mediaBox,to:ctx)
   let rep=NSBitmapImageRep(cgImage:ctx.makeImage()!);try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:args[2]+"/page-\(i+1).png"));text+="PAGE\(i+1)\n"+(page.string ?? "")+"\n"
  }
  try text.write(toFile:args[2]+"/text.txt",atomically:true,encoding:.utf8)
 }
}
