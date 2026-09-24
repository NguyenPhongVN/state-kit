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
public enum AsyncSequenceStatus {
    /// Iteration has not started yet.
    case idle
    /// Waiting for the next element (first or subsequent).
    case loading
    /// The sequence yielded a new element.
    case value
    /// The sequence terminated normally (iterator returned `nil`).
    case finished
    /// The sequence threw an error.
    case failure
}

/// Status mirror for `PublisherPhase` (no associated values).
// MARK: - PublisherStatus
public enum PublisherStatus {
    /// No subscription has started yet.
    case idle
    /// The publisher emitted a value.
    case value
    /// The publisher finished successfully.
    case finished
    /// The publisher completed with an error.
    case failure
}
