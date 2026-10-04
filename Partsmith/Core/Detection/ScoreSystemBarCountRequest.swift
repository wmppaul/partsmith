import Combine
import CoreGraphics
import Foundation

/// Owns one background suggestion. Cancelling or starting another selection
/// discards the old response; this worker never writes a saved assignment.
final class ScoreSystemBarCountRequest: ObservableObject {
    struct Response {
        var id: UUID
        var suggestion: ScoreSystemBarCounter.Suggestion?
    }
    typealias Counter = (CGImage, [ScoreObservedStaff], Double, @escaping () -> Bool) -> ScoreSystemBarCounter.Suggestion?
    @Published private(set) var response: Response?
    @Published private(set) var isCounting = false
    private var activeID: UUID?
    private var operation: BlockOperation?
    private let counter: Counter
    private let queue: OperationQueue = {
        let value = OperationQueue()
        value.name = "Partsmith.systemBarCount"
        value.qualityOfService = .userInitiated
        value.maxConcurrentOperationCount = 1
        return value
    }()

    init(counter: @escaping Counter = { image, staves, skew, cancelled in
        ScoreSystemBarCounter.suggest(in: image, staves: staves, skewDegrees: skew, isCancelled: cancelled)
    }) { self.counter = counter }

    @discardableResult
    func start(image: CGImage, staves: [ScoreObservedStaff], skewDegrees: Double) -> UUID {
        cancel()
        let id = UUID(), counter = self.counter
        activeID = id
        isCounting = true
        let task = BlockOperation()
        operation = task
        task.addExecutionBlock { [weak self, weak task] in
            guard let task, !task.isCancelled else { return }
            let result = counter(image, staves, skewDegrees, { task.isCancelled })
            guard !task.isCancelled else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.activeID == id else { return }
                self.operation = nil
                self.activeID = nil
                self.isCounting = false
                self.response = Response(id: id, suggestion: result)
            }
        }
        queue.addOperation(task)
        return id
    }

    func cancel() {
        activeID = nil
        operation?.cancel()
        operation = nil
        isCounting = false
        response = nil
    }

    deinit { operation?.cancel() }
}
