import Foundation

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
