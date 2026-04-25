import Foundation
// MARK: - Interop

public extension AsyncPhase {

    /// Converts this `AsyncPhase` to an `AsyncSequencePhase`.
    ///
    /// | `AsyncPhase` | `AsyncSequencePhase` |
    /// |---|---|
    /// | `.idle` | `.idle` |
    /// | `.loading` | `.loading` |
    /// | `.success(v)` | `.value(v)` — treated as a single-element emission |
    /// | `.failure(e)` | `.failure(e)` |
    ///
    /// Note: the resulting sequence has no `.finished` terminal; the single
    /// success value appears as `.value` rather than a completed stream.
    /// This conversion is useful when you want to adapt a one-shot async
    /// result into UI that already consumes `AsyncSequencePhase`.
    func asSequencePhase() -> AsyncSequencePhase<Value> {
        switch self {
            case .idle:            return .idle
            case .loading:         return .loading
            case .success(let v): return .value(v)
            case .failure(let e): return .failure(e)
        }
    }
}

// MARK: - Interop

public extension AsyncSequencePhase {

    /// Converts this `AsyncSequencePhase` to an `AsyncPhase`.
    ///
    /// | `AsyncSequencePhase` | `AsyncPhase` |
    /// |---|---|
    /// | `.idle` | `.idle` |
    /// | `.loading` | `.loading` |
    /// | `.value(e)` | `.success(e)` — latest emission treated as the result |
    /// | `.finished` | `.idle` — stream exhausted, no single-result equivalent |
    /// | `.failure(e)` | `.failure(e)` |
    ///
    /// `.finished` maps to `.idle` because `AsyncPhase` has no terminal-without-value
    /// concept; use `asPublisherPhase()` if you need `.finished` to be preserved.
    func asAsyncPhase() -> AsyncPhase<Element> {
        switch self {
            case .idle:            return .idle
            case .loading:         return .loading
            case .value(let v):   return .success(v)
            case .finished:        return .idle
            case .failure(let e): return .failure(e)
        }
    }

    /// Converts this `AsyncSequencePhase` to a `PublisherPhase`.
    ///
    /// | `AsyncSequencePhase` | `PublisherPhase` |
    /// |---|---|
    /// | `.idle` | `.idle` |
    /// | `.loading` | `.idle` — no loading concept in `PublisherPhase` |
    /// | `.value(e)` | `.value(e)` |
    /// | `.finished` | `.finished` |
    /// | `.failure(e)` | `.failure(e)` |
    func asPublisherPhase() -> PublisherPhase<Element> {
        switch self {
            case .idle:            return .idle
            case .loading:         return .idle
            case .value(let v):   return .value(v)
            case .finished:        return .finished
            case .failure(let e): return .failure(e)
        }
    }
}
