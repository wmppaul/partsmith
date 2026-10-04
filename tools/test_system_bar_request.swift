import AppKit
import Combine
import Foundation

@main enum SystemBarRequestTests {
    static var checks = [String]()
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks.append(message)
        print("PASS: \(message)")
    }
    static func pump(until predicate: () -> Bool, timeout: Double = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
        precondition(predicate(), "Timed out waiting for asynchronous request")
    }
    static func drain(_ seconds: Double = 0.08) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
    }
    static func suggestion(_ count: Int) -> ScoreSystemBarCounter.Suggestion {
        .init(barCount: count, boundaryFractions: [0.1, 0.9], supportingStaffCount: 1, selectedStaffCount: 1)
    }
    static func main() throws {
        setbuf(stdout, nil)
        let context = CGContext(data: nil, width: 40, height: 50, bitsPerComponent: 8, bytesPerRow: 40,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let image = context.makeImage()!
        let staff = ScoreObservedStaff(StaffBandCandidate(id: 7,
            staffLineFractions: [0.1, 0.12, 0.14, 0.16, 0.18], topFraction: 0.08, bottomFraction: 0.2,
            confidence: 1, warnings: []))
        var received = [(UUID, Int?)]()
        var mainThreadResponses = [Bool]()
        let direct = ScoreSystemBarCountRequest { input, staves, skew, cancelled in
            precondition(!Thread.isMainThread && input.width == 40 && input.height == 50)
            precondition(staves.map(\.id) == [7] && skew == 0.4 && !cancelled())
            return suggestion(6)
        }
        let sink = direct.$response.compactMap { $0 }.sink {
            mainThreadResponses.append(Thread.isMainThread)
            received.append(($0.id, $0.suggestion?.barCount))
        }
        let id = direct.start(image: image, staves: [staff], skewDegrees: 0.4)
        check(direct.isCounting && direct.response == nil, "Start synchronously exposes progress and clears old responses")
        pump { direct.response != nil }
        check(received.count == 1 && received[0].0 == id && received[0].1 == 6,
            "Suggestion publishes with the matching request identity")
        check(mainThreadResponses == [true] && !direct.isCounting,
            "The background counter publishes completion on the main thread")
        direct.cancel()
        check(!direct.isCounting && direct.response == nil, "Cancel clears a completed suggestion")
        withExtendedLifetime(sink) {}

        // A counter that deliberately ignores cancellation proves stale results
        // cannot win merely because an old operation takes longer to stop.
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var invocations = [Int](), cancellationSeen = false
        let queued = ScoreSystemBarCountRequest { _, _, skew, cancelled in
            lock.lock(); invocations.append(Int(skew)); lock.unlock()
            if skew == 1 {
                entered.signal(); release.wait()
                lock.lock(); cancellationSeen = cancelled(); lock.unlock()
            }
            return suggestion(Int(skew))
        }
        var queuedResponses = [(UUID, Int?)]()
        let queuedSink = queued.$response.compactMap { $0 }.sink { queuedResponses.append(($0.id, $0.suggestion?.barCount)) }
        let first = queued.start(image: image, staves: [staff], skewDegrees: 1)
        check(entered.wait(timeout: .now() + 5) == .success, "Slow first request starts on its worker")
        let second = queued.start(image: image, staves: [staff], skewDegrees: 2)
        let third = queued.start(image: image, staves: [staff], skewDegrees: 3)
        check(Set([first, second, third]).count == 3 && queued.isCounting,
            "Rapid selection changes allocate separate identities while showing latest progress")
        release.signal()
        pump { queued.response != nil }
        check(queuedResponses.count == 1 && queuedResponses.first?.0 == third && queuedResponses.first?.1 == 3,
            "Only the newest selection publishes after a cancelled slow request")
        lock.lock(); let calls = invocations, sawCancellation = cancellationSeen; lock.unlock()
        check(calls == [1, 3], "A superseded queued request never calls the expensive counter")
        check(sawCancellation, "Running counter receives cooperative cancellation")
        check(!queued.isCounting, "Latest completion clears progress")
        withExtendedLifetime(queuedSink) {}

        let started = DispatchSemaphore(value: 0), finish = DispatchSemaphore(value: 0), ended = DispatchSemaphore(value: 0)
        let cancelled = ScoreSystemBarCountRequest { _, _, _, isCancelled in
            started.signal(); finish.wait()
            precondition(isCancelled())
            ended.signal()
            return suggestion(99)
        }
        var cancelledResponses = 0
        let cancelSink = cancelled.$response.compactMap { $0 }.sink { _ in cancelledResponses += 1 }
        cancelled.start(image: image, staves: [staff], skewDegrees: 0)
        check(started.wait(timeout: .now() + 5) == .success, "Cancellation fixture starts before cancellation")
        cancelled.cancel()
        check(!cancelled.isCounting && cancelled.response == nil, "Manual cancellation clears UI state immediately")
        finish.signal()
        check(ended.wait(timeout: .now() + 5) == .success, "Cancelled counter finishes cooperatively")
        drain()
        check(cancelledResponses == 0 && cancelled.response == nil,
            "Cancelled count cannot arrive later and overwrite a manual value")
        withExtendedLifetime(cancelSink) {}

        let nothing = ScoreSystemBarCountRequest { _, _, _, _ in nil }
        let noneID = nothing.start(image: image, staves: [], skewDegrees: 0)
        pump { nothing.response != nil }
        check(nothing.response?.id == noneID && nothing.response?.suggestion == nil && !nothing.isCounting,
            "No confident count is still a completed response, never a fabricated zero")
        let nilFirst = nothing.response!.id
        let nilNext = nothing.start(image: image, staves: [], skewDegrees: 0)
        check(nothing.response == nil && nilNext != nilFirst, "Retry removes previous abstention before counting")
        pump { nothing.response != nil }
        check(nothing.response?.id == nilNext, "An abstaining worker can be reused for another selection")

        let deinitStarted = DispatchSemaphore(value: 0), deinitFinish = DispatchSemaphore(value: 0), deinitEnded = DispatchSemaphore(value: 0)
        var owner: ScoreSystemBarCountRequest? = ScoreSystemBarCountRequest { _, _, _, isCancelled in
            deinitStarted.signal(); deinitFinish.wait()
            precondition(isCancelled()); deinitEnded.signal()
            return suggestion(8)
        }
        weak var releasedOwner = owner
        owner!.start(image: image, staves: [staff], skewDegrees: 0)
        check(deinitStarted.wait(timeout: .now() + 5) == .success, "Deallocation fixture begins counting")
        owner = nil
        check(releasedOwner == nil, "Closing owner is not retained by an unfinished operation")
        deinitFinish.signal()
        check(deinitEnded.wait(timeout: .now() + 5) == .success, "Owner deallocation cancels its counter")
        drain()

        // Repeated immediate cancellation covers the race between a fast worker
        // finishing and its delivery waiting in the main queue.
        let fast = ScoreSystemBarCountRequest { _, _, _, _ in suggestion(4) }
        var fastResponses = 0
        let fastSink = fast.$response.compactMap { $0 }.sink { _ in fastResponses += 1 }
        for _ in 0..<40 {
            fast.start(image: image, staves: [staff], skewDegrees: 0)
            Thread.sleep(forTimeInterval: 0.001)
            fast.cancel()
            drain(0.003)
        }
        check(fastResponses == 0 && fast.response == nil && !fast.isCounting,
            "Forty cancelled fast results never leak through queued main-thread delivery")
        withExtendedLifetime(fastSink) {}
        let output = URL(fileURLWithPath: ".build/system-bar-request-review")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: ["checks": checks, "count": checks.count], options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("request-results.json"))
        print("PASS: \(checks.count) bar-count request lifecycle checks")
    }
}
