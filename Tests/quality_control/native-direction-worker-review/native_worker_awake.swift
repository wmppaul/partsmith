import AppKit
import Combine
import CryptoKit
import Foundation
import Darwin
import PDFKit
struct WorkerCase:Codable {var id:String;var source:String;var sourceSHA256:String;var profile:String;var baselineInventory:String;var baselineManifest:String;var rectifications:[PageRectification]}
struct WorkerProgress:Codable {var elapsedSeconds:Double;var phase:String;var completed:Int;var total:Int;var onMainThread:Bool}
struct WorkerIssue:Codable {var pageIndex:Int;var message:String}
struct WorkerReference:Codable {var pageIndex:Int;var anchorStaffID:Int;var bounds:[Double];var correlation:Double;var templatePageIndex:Int;var templateBounds:[Double]}
struct WorkerSummary:Codable {
 var id:String;var sourceSHA256:String;var elapsedSeconds:Double;var heartbeatCount:Int;var heartbeatMaxIntervalSeconds:Double;var progress:[WorkerProgress]
 var awakeElapsedSeconds:Double;var continuousElapsedSeconds:Double;var heartbeatMaxAwakeIntervalSeconds:Double;var completionOnMainThread:Bool;var planCanApply:Bool;var bandCount:Int;var autoSkipped:[Int];var issues:[WorkerIssue];var references:[WorkerReference];var projectUnchanged:Bool;var progressCleared:Bool
}
struct WorkerInventory:Codable {var source:String;var sourceSHA256:String;var rectifications:[PageRectification];var pages:[ScorePageAnalysis]}
struct CancelSummary:Codable {var requestedAtPhase:String;var cancelCallSeconds:Double;var progressClearedSynchronously:Bool;var supersededCompletionCalls:Int;var replacementElapsedSeconds:Double;var replacementPageIndices:[Int];var replacementBandCount:Int;var staleDirectionProgressAfterCancel:Int;var sourceAndProjectUnchanged:Bool;var progress:[WorkerProgress]}
@main enum Worker {
 static let out=URL(fileURLWithPath:".build/qc-native-app-worker-awake-v2")
 static func write<T:Encodable>(_ x:T,_ name:String)throws {let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes];try e.encode(x).write(to:out.appendingPathComponent(name),options:.atomic)}
 static func read<T:Decodable>(_ t:T.Type,_ path:String)throws->T {try JSONDecoder().decode(t,from:Data(contentsOf:URL(fileURLWithPath:path)))}
 static func fail(_ message:String)->NSError{NSError(domain:"NativeWorkerQA",code:1,userInfo:[NSLocalizedDescriptionKey:message])}
 static func document(_ c:WorkerCase)throws->(PartsmithDocument,ScoreExtractionProfile) {
  let data=try Data(contentsOf:URL(fileURLWithPath:c.source)),hash=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
  guard hash==c.sourceSHA256 else{throw fail("Source hash changed")}
  let doc=PartsmithDocument(sourcePDFData:data),profile=try read(ScoreExtractionProfile.self,c.profile)
  doc.project.pageCount=doc.pdfDocument!.pageCount;doc.project.pageRectifications=c.rectifications
  doc.saveScoreProfile(profile)
  return(doc,profile)
 }
 static func run(_ c:WorkerCase)throws {
  let (doc,profile)=try document(c),original=doc.project,start=Date()
  let awakeStart=clock_gettime_nsec_np(CLOCK_UPTIME_RAW),continuousStart=clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
  var lastAwake=awakeStart,maxAwakeInterval=0.0
  var progress:[WorkerProgress]=[],done=false,review:ScoreDetectionReview?,completionMain=false,ticks=0,maxTick=0.0,lastTick=Date()
  let timer=Timer.scheduledTimer(withTimeInterval:0.05,repeats:true){_ in let now=Date();let awakeNow=clock_gettime_nsec_np(CLOCK_UPTIME_RAW);maxAwakeInterval=max(maxAwakeInterval,Double(awakeNow-lastAwake)/1e9);lastAwake=awakeNow;ticks+=1;maxTick=max(maxTick,now.timeIntervalSince(lastTick));lastTick=now}
  let observer=doc.$scoreDetectionProgress.sink { value in
   guard let value else{return};let p=WorkerProgress(elapsedSeconds:Date().timeIntervalSince(start),phase:value.directionPhase?.rawValue ?? "staves",completed:value.completedPages,total:value.totalPages,onMainThread:Thread.isMainThread)
   progress.append(p);print("\(c.id) \(p.phase) \(p.completed)/\(p.total) @\(String(format:"%.3f",p.elapsedSeconds))s");fflush(stdout)
  }
  defer {timer.invalidate();observer.cancel()}
  doc.detectScore(profile:profile,copySharedDirections:true){value in review=value;completionMain=Thread.isMainThread;done=true}
  let deadline=Date().addingTimeInterval(1200)
  while !done && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  guard done,let review else{throw fail("No final review for \(c.id)")}
  let summary=WorkerSummary(id:c.id,sourceSHA256:c.sourceSHA256,elapsedSeconds:Date().timeIntervalSince(start),heartbeatCount:ticks,heartbeatMaxIntervalSeconds:maxTick,progress:progress,awakeElapsedSeconds:Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)-awakeStart)/1e9,continuousElapsedSeconds:Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)-continuousStart)/1e9,heartbeatMaxAwakeIntervalSeconds:maxAwakeInterval,completionOnMainThread:completionMain,planCanApply:review.plan.canApply,bandCount:review.plan.bands.count,autoSkipped:review.autoSkippedPageIndices.sorted(),issues:review.directionIssues.map{.init(pageIndex:$0.pageIndex,message:$0.message)},references:review.directionReferences.map{.init(pageIndex:$0.pageIndex,anchorStaffID:$0.match.anchorStaffID,bounds:$0.match.bounds,correlation:$0.match.correlation,templatePageIndex:$0.match.templatePageIndex,templateBounds:$0.match.templateBounds)},projectUnchanged:doc.project==original,progressCleared:doc.scoreDetectionProgress==nil)
  try write(summary,"\(c.id)-summary.json");try write(WorkerInventory(source:c.source,sourceSHA256:c.sourceSHA256,rectifications:review.rectifications,pages:review.analyses),"\(c.id)-inventory.json");try write(review.plan,"\(c.id)-plan.json")
  print("DONE \(c.id) \(summary.elapsedSeconds)s, \(summary.bandCount)bands, issues \(summary.issues.count), max heartbeat \(maxTick)");fflush(stdout)
 }
 static func cancellation(_ c:WorkerCase)throws {
  let (doc,profile)=try document(c),original=doc.project,start=Date()
  var events:[WorkerProgress]=[],trigger=false,oldCalls=0,replacementDone=false,replacement:ScoreDetectionReview?,cancelled=false,stale=0
  let observer=doc.$scoreDetectionProgress.sink { p in
   guard let p else{return};events.append(.init(elapsedSeconds:Date().timeIntervalSince(start),phase:p.directionPhase?.rawValue ?? "staves",completed:p.completedPages,total:p.totalPages,onMainThread:Thread.isMainThread))
   if cancelled && p.directionPhase != nil {stale+=1}
   if p.directionPhase == .headings && p.completedPages>=1 {trigger=true}
  }
  defer{observer.cancel()}
  doc.detectScore(profile:profile,copySharedDirections:true){_ in oldCalls+=1}
  let deadline=Date().addingTimeInterval(600)
  while !trigger && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.005))}
  guard trigger else{throw fail("Cancel target phase never reached")}
  let before=Date();doc.cancelScoreDetection();let call=Date().timeIntervalSince(before),cleared=doc.scoreDetectionProgress==nil;cancelled=true
  let replacementStart=Date()
  doc.detectScore(profile:profile,pageIndices:[1],copySharedDirections:false){r in replacement=r;replacementDone=true}
  let nextDeadline=Date().addingTimeInterval(90)
  while !replacementDone && Date()<nextDeadline {RunLoop.main.run(until:Date().addingTimeInterval(0.005))}
  guard let replacement,replacementDone else{throw fail("Replacement did not finish after cancellation")}
  let elapsed=Date().timeIntervalSince(replacementStart)
  RunLoop.main.run(until:Date().addingTimeInterval(0.5))
  try write(CancelSummary(requestedAtPhase:"headings after first completed page",cancelCallSeconds:call,progressClearedSynchronously:cleared,supersededCompletionCalls:oldCalls,replacementElapsedSeconds:elapsed,replacementPageIndices:replacement.analyses.map(\.pageIndex),replacementBandCount:replacement.plan.bands.count,staleDirectionProgressAfterCancel:stale,sourceAndProjectUnchanged:doc.project==original,progress:events),"brahms-cancel.json")
  print("CANCEL control: call \(call)s; replacement \(elapsed)s; old callbacks \(oldCalls); stale \(stale)");fflush(stdout)
 }
 static func main()throws {
  let cases=try read([WorkerCase].self,".build/qc-native-app-worker-v1/config.json")
  let args=Array(CommandLine.arguments.dropFirst())
  if args==["cancel"]{try cancellation(cases.first{$0.id=="brahms"}!)}
  else {for c in cases where args.isEmpty || args.contains(c.id){try run(c)}}
 }
}
