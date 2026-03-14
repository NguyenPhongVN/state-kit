// MARK: - PublisherPhase

/// Represents the latest event emitted by a Combine publisher.
///
/// `usePublisher` stores the most recent publisher event in a `StateSignal`
/// so SwiftUI can re-render when new values arrive.
public enum PublisherPhase<Output> {
    /// No subscription has started yet.
    case idle
    /// The publisher emitted a value.
    case value(Output)
    /// The publisher finished successfully.
    case finished
    /// The publisher completed with an error.
    case failure(Error)
}
