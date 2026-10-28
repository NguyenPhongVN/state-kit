import Foundation

/// Case-only status mirrors of the phase types, for consumers that need the
/// lifecycle state without associated values (e.g. badges, simple switches).
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

/// Status mirror for `AsyncSequencePhase` (no associated values).
// MARK: - AsyncSequenceStatus

/// Status mirror for `PublisherPhase` (no associated values).
// MARK: - PublisherStatus
