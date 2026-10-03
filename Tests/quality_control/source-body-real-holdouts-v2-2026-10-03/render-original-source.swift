import Foundation
import PDFKit
import CoreGraphics
import ImageIO
@main enum SourceRenderer {
 static func main() throws {
  let args=CommandLine.arguments
  let doc=PDFDocument(url:URL(fileURLWithPath:args[1]))!
  let indices=args[3].split(separator:",").map{Int($0)!}
  for i in indices {
   let page=doc.page(at:i-1)!,bounds=page.bounds(for:.mediaBox)
   let scale=min(1800/bounds.width,2600/bounds.height)
   let w=Int((bounds.width*scale).rounded()),h=Int((bounds.height*scale).rounded())
   let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
   ctx.setFillColor(gray:1,alpha:1);ctx.fill(CGRect(x:0,y:0,width:w,height:h));ctx.scaleBy(x:CGFloat(w)/bounds.width,y:CGFloat(h)/bounds.height);ctx.translateBy(x:-bounds.minX,y:-bounds.minY);page.draw(with:.mediaBox,to:ctx)
   let image=ctx.makeImage()!;let url=URL(fileURLWithPath:args[2]+String(format:"-p%03d.png",i));let dest=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest)); print(i,w,h,bounds.width,bounds.height)
  }
 }
}
