import StateKit

/// Shared marker protocol for atoms whose value is an `AsyncPhase`.
///
/// This lets APIs such as `@SKTask` accept both `SKTaskAtom` and
/// `SKThrowingTaskAtom` while still rejecting non-async atoms at compile time.
public protocol SKAsyncPhaseAtom: SKAtom where Value == AsyncPhase<TaskSuccess> {
    associatedtype TaskSuccess
}
