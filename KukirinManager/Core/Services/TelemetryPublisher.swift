import Foundation

@MainActor
final class TelemetryPublisher {
    private var continuation: AsyncStream<TelemetrySnapshot>.Continuation?
    private(set) var stream: AsyncStream<TelemetrySnapshot>!

    init() {
        stream = AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }

    func publish(_ snapshot: TelemetrySnapshot) {
        continuation?.yield(snapshot)
    }

    func finish() {
        continuation?.finish()
    }
}
