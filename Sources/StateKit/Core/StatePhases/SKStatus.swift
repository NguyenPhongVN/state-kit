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
