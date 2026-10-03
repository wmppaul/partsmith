import Foundation
import CoreGraphics
import ImageIO

@main enum AlternativeProbe {
    static func staff(_ id:Int,_ top:Double,_ height:Double,_ space:Double)->ScoreObservedStaff {
        ScoreObservedStaff(StaffBandCandidate(id:id,staffLineFractions:(0..<5).map{(top+Double($0)*space)/height},
            topFraction:(top-space)/height,bottomFraction:(top+5*space)/height,confidence:1,warnings:[]))
    }
    static func main() throws {
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        let decoder=JSONDecoder()
        let legacy=Data("{\"bounds\":[0.1,0.2,0.3,0.4],\"staffIDs\":[0]}".utf8)
        let ordinary=try decoder.decode(ScoreInkComponent.self,from:legacy)
        precondition(ordinary.isOwnershipAlternative == nil)
        precondition(try! encoder.encode(ordinary) == legacy)
        var flagged=ordinary;flagged.isOwnershipAlternative=true
        let flaggedRoundtrip=try decoder.decode(ScoreInkComponent.self,from:encoder.encode(flagged))
        precondition(flaggedRoundtrip==flagged && flaggedRoundtrip.isOwnershipAlternative == true)
        var falseFlag=ordinary;falseFlag.isOwnershipAlternative=false
        precondition(try! decoder.decode(ScoreInkComponent.self,from:encoder.encode(falseFlag)) == falseFlag)
        let profile=ScoreExtractionProfile(parts:[.init(id:"one",name:"One",staffCount:1)],cropMode:"compact")
        let components:[ScoreInkComponent]=[
            .init(bounds:[0.1,0.20,0.15,0.25],staffIDs:[0]),
            .init(bounds:[0.1,0.26,0.15,0.275],staffIDs:[]),
            .init(bounds:[0.1,0.287,0.15,0.3],staffIDs:[]),
            .init(bounds:[0.1,0.311,0.15,0.324],staffIDs:[]),
            .init(bounds:[0.1,0.60,0.15,0.64],staffIDs:[1])]
        let page=ScorePageAnalysis(pageIndex:0,pageWidth:1000,pageHeight:1000,imageWidth:1000,imageHeight:1000,
            staves:[staff(0,200,1000,10),staff(1,600,1000,10)],warnings:[],inkComponents:components)
        let baseline=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
        var controls:[[String:Any]]=[]
        for choice in ["untagged","false","alternative","ownerlessAlternative","sharedAlternative"] {
            var test=page
            var supplement=ScoreInkComponent(bounds:[0.1,0.27,0.15,0.64],staffIDs:[1])
            switch choice {
            case "false":supplement.isOwnershipAlternative=false
            case "alternative":supplement.isOwnershipAlternative=true
            case "ownerlessAlternative":supplement.isOwnershipAlternative=true;supplement.staffIDs=[]
            case "sharedAlternative":supplement.isOwnershipAlternative=true;supplement.staffIDs=[0,1]
            default:break
            }
            test.inkComponents!.append(supplement)
            let plan=ScoreExtractionPlanner.plan(pages:[test],profile:profile)
            precondition(plan.canApply)
            let first=plan.bands[0],last=plan.bands[1]
            if choice=="untagged" || choice=="false" { precondition(first.bottomFraction < baseline.bands[0].bottomFraction) }
            else { precondition(first.bottomFraction >= baseline.bands[0].bottomFraction) }
            if choice=="alternative" { precondition(first.topFraction==baseline.bands[0].topFraction && first.bottomFraction==baseline.bands[0].bottomFraction) }
            if choice=="ownerlessAlternative" { precondition(plan.bands==baseline.bands) }
            if choice=="sharedAlternative" { precondition(first.bottomFraction > baseline.bands[0].bottomFraction && !first.warnings.isEmpty) }
            let decoded=try decoder.decode(ScorePageAnalysis.self,from:encoder.encode(test))
            precondition(decoded==test && ScoreExtractionPlanner.plan(pages:[decoded],profile:profile)==plan)
            controls.append(["choice":choice,"upperTop":first.topFraction,"upperBottom":first.bottomFraction,
                "lowerTop":last.topFraction,"lowerBottom":last.bottomFraction,"canApply":true,"codecAndReplanExact":true])
        }
        let imageSource=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[2]) as CFURL,nil)!
        let image=CGImageSourceCreateImageAtIndex(imageSource,0,nil)!
        var candidates:[StaffBandCandidate]=[]
        for (i,top) in [180,330].enumerated() {
            let lines:[Double]=(0..<5).map{Double(top+$0*12)/760}
            candidates.append(StaffBandCandidate(id:i,staffLineFractions:lines,topFraction:Double(top-12)/760,
                bottomFraction:Double(top+60)/760,confidence:1,warnings:[]))
        }
        var totalChecks=0
        let native=NativeScorePageAnalyzer.notationComponents(image:image,candidates:candidates,skewDegrees:0,isCancelled:{totalChecks+=1;return false})!
        precondition(native.contains{$0.isOwnershipAlternative==true})
        var cancellation:[[String:Any]]=[]
        for threshold in [1,2,100,totalChecks/2,totalChecks-1,totalChecks] {
            var checks=0
            let result=NativeScorePageAnalyzer.notationComponents(image:image,candidates:candidates,skewDegrees:0,
                isCancelled:{checks+=1;return checks>=threshold})
            precondition(result==nil)
            cancellation.append(["requestedAtCallback":threshold,"actualChecks":checks,"returnedNil":true])
        }
        let result:[String:Any]=["verdict":"PASS","legacyFieldAbsentIsOrdinary":true,"legacyJSONReencodingExact":true,
            "trueAndFalseOptionalFlagsRoundtrip":true,"baselineUpperBottom":baseline.bands[0].bottomFraction,
            "apiControls":controls,"nativeAlternativeCount":native.filter{$0.isOwnershipAlternative==true}.count,
            "nativeCancellationCheckCount":totalChecks,"cancelControls":cancellation]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
        print(result)
    }
}
