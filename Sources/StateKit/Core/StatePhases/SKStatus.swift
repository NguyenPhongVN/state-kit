import Foundation

// Case-only status mirrors of the phase types, for consumers that need the
// lifecycle state without associated values (e.g. badges, simple switches).
// MARK: - SKStatus
public enum SKStatus: Equatable, Hashable, Sendable {
    /// No async work has started yet.
    case idle
    /// Async work is currently in flight.
    case loading
    /// Async work completed successfully.
    case success
    /// Async work completed with an error.
    case failure
}

// MARK: - SKStatus Conveniences

// `SKStatus` mirrors the lifecycle of `AsyncSequencePhase`/`PublisherPhase`
// without associated values (the phase types themselves live in SKPhaseView):
// idle/loading/success/failure. The former `AsyncSequenceStatus`/`PublisherStatus`
// MARK: headers named types that do not exist and were removed (spec 012).
