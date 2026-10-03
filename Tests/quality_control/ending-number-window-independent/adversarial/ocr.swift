import Foundation
import CoreGraphics
import ImageIO
import Vision
@main enum Probe {
 static func main() throws {
 let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,nil)!,im=CGImageSourceCreateImageAtIndex(src,0,nil)!
 for rect in [CGRect(x:204,y:141,width:35,height:25),CGRect(x:204,y:141,width:53,height:25)] {
 let crop=im.cropping(to:rect)!, w=crop.width*4+120,h=crop.height*4+120
 let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
 c.setFillColor(gray:1,alpha:1);c.fill(CGRect(x:0,y:0,width:w,height:h));c.interpolationQuality = .high;c.draw(crop,in:CGRect(x:60,y:60,width:crop.width*4,height:crop.height*4))
 for accurate in [true,false] {let r=VNRecognizeTextRequest();r.recognitionLevel=accurate ? .accurate:.fast;r.usesLanguageCorrection=false;r.minimumTextHeight=0.06;r.recognitionLanguages=["en-US"];try VNImageRequestHandler(cgImage:c.makeImage()!,options:[:]).perform([r]);print(rect,accurate,r.results?.map{$0.topCandidates(3).map{($0.string,$0.confidence)}} ?? [])}
 }
 }
}
