import Foundation
import ImageIO
import Vision
struct Candidate: Codable { let id:String;let numberImage:String }
struct Envelope: Decodable { let candidates:[Candidate] }
struct Line: Codable { let text:String;let alternatives:[String];let confidence:Float;let bounds:[Double] }
struct Result: Codable { let id:String;let lines:[Line] }
@main enum Probe {
 static func main() throws {
  let decoder=JSONDecoder(), input=CommandLine.arguments[1],output=CommandLine.arguments[2]
  let candidates=try decoder.decode(Envelope.self,from:Data(contentsOf:URL(fileURLWithPath:input))).candidates
  var results:[Result]=[]
  for c in candidates {
   let result:Result = try autoreleasepool {
    guard let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:c.numberImage) as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(src,0,nil) else { throw NSError(domain:"EndingOCR",code:1) }
    let request=VNRecognizeTextRequest();request.recognitionLevel = CommandLine.arguments.contains("--fast") ? .fast : .accurate;request.usesLanguageCorrection=false;request.minimumTextHeight=0.06;request.recognitionLanguages=["en-US"]
    try VNImageRequestHandler(cgImage:image,options:[:]).perform([request])
    let lines=(request.results ?? []).compactMap { o -> Line? in
     guard let t=o.topCandidates(1).first else{return nil};let b=o.boundingBox
     return Line(text:t.string,alternatives:o.topCandidates(3).map(\.string),confidence:t.confidence,bounds:[b.minX,1-b.maxY,b.maxX,1-b.minY])
    }
    return Result(id:c.id,lines:lines)
   }
   results.append(result);if !result.lines.isEmpty{print(c.id,result.lines.map(\.text));fflush(stdout)}
  }
  let enc=JSONEncoder();enc.outputFormatting=[.prettyPrinted,.sortedKeys];try enc.encode(results).write(to:URL(fileURLWithPath:output));print("Recognized \(results.count) candidates")
 }
}
