// MARK: - AsyncSequencePhase

/// Models the current state of an `AsyncSequence` being consumed by
/// `useAsyncSequence`.
///
/// Unlike `AsyncPhase` (which models a single result), `AsyncSequencePhase`
/// models a stream: the phase transitions through multiple `.value` states
/// before eventually reaching `.finished` or `.failure`.
public enum AsyncSequencePhase<Element> {
    /// Iteration has not started yet.
    case idle
    /// Waiting for the next element (first or subsequent).
    case loading
    /// The sequence yielded a new element.
    case value(Element)
    /// The sequence terminated normally (iterator returned `nil`).
    case finished
    /// The sequence threw an error.
    case failure(Error)
}

// MARK: - Equatable

/// Conditional `Equatable` conformance.
/// `.failure` cases are considered equal regardless of the underlying error
/// because `Error` does not conform to `Equatable`.
extension AsyncSequencePhase: Equatable where Element: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):                       return true
        case (.loading, .loading):                 return true
        case (.value(let l), .value(let r)):       return l == r
        case (.finished, .finished):               return true
        case (.failure, .failure):                 return true
        default:                                   return false
        }
    }
}

// MARK: - Hashable

extension AsyncSequencePhase: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .idle:            hasher.combine(0)
        case .loading:         hasher.combine(1)
        case .value(let v):   hasher.combine(2); hasher.combine(v)
        case .finished:        hasher.combine(3)
        case .failure:         hasher.combine(4)
        }
    }
}

// MARK: - Sendable

extension AsyncSequencePhase: Sendable where Element: Sendable {}

// MARK: - Accessors

public extension AsyncSequencePhase {

    /// The associated element if the phase is `.value`, otherwise `nil`.
    var element: Element? {
        guard case .value(let v) = self else { return nil }
        return v
    }

    /// The associated error if the phase is `.failure`, otherwise `nil`.
    var error: Error? {
        guard case .failure(let e) = self else { return nil }
        return e
    }

    /// `true` when the phase is `.idle`.
    var isIdle: Bool {
        guard case .idle = self else { return false }
        return true
    }

    /// `true` when the phase is `.loading`.
    var isLoading: Bool {
        guard case .loading = self else { return false }
        return true
    }

    /// `true` when the phase is `.value`.
    var isValue: Bool {
        guard case .value = self else { return false }
        return true
    }

    /// `true` when the phase is `.finished`.
    var isFinished: Bool {
        guard case .finished = self else { return false }
        return true
    }

    /// `true` when the phase is `.failure`.
    var isFailure: Bool {
        guard case .failure = self else { return false }
        return true
    }

    /// `true` when iteration is in progress — either waiting for the first
    /// element (`.loading`) or has already emitted at least one (`.value`).
    var isActive: Bool {
        isLoading || isValue
    }
}

// MARK: - Transformations

public extension AsyncSequencePhase {

    /// Returns a new phase by applying `transform` to the emitted element.
    /// All other cases pass through unchanged.
    ///
    /// ```swift
    /// let namePhase: AsyncSequencePhase<String> = phase.map { $0.name }
    /// ```
    func map<T>(_ transform: (Element) -> T) -> AsyncSequencePhase<T> {
        switch self {
        case .idle:            return .idle
        case .loading:         return .loading
        case .value(let v):   return .value(transform(v))
        case .finished:        return .finished
        case .failure(let e): return .failure(e)
        }
    }

    /// Returns a new phase by applying `transform` to the emitted element and
    /// flattening the result. All other cases pass through unchanged.
    ///
    /// ```swift
    /// let child = phase.flatMap { item in
    ///     item.isValid ? .value(item.detail) : .idle
    /// }
    /// ```
    func flatMap<T>(_ transform: (Element) -> AsyncSequencePhase<T>) -> AsyncSequencePhase<T> {
        switch self {
        case .idle:            return .idle
        case .loading:         return .loading
        case .value(let v):   return transform(v)
        case .finished:        return .finished
        case .failure(let e): return .failure(e)
        }
    }

    /// Returns a new phase by applying `transform` to the failure error.
    /// All other cases pass through unchanged.
    ///
    /// ```swift
    /// let typed = phase.mapError { AppError.stream($0) }
    /// ```
    func mapError(_ transform: (Error) -> Error) -> AsyncSequencePhase<Element> {
        guard case .failure(let e) = self else { return self }
        return .failure(transform(e))
    }

    /// Returns `.value(replacement)` when the phase is `.failure`.
    /// All other cases pass through unchanged.
    ///
    /// ```swift
    /// let safe = phase.replaceError(with: .placeholder)
    /// ```
    func replaceError(with replacement: Element) -> AsyncSequencePhase<Element> {
        guard case .failure = self else { return self }
        return .value(replacement)
    }

    /// Returns `.idle` when the phase is `.failure`, silently discarding the
    /// error and resetting to the initial state.
    func ignoreError() -> AsyncSequencePhase<Element> {
        guard case .failure = self else { return self }
        return .idle
    }

    /// Unwraps `.value(wrapped?)`, returning `.loading` when the wrapped
    /// value is `nil` (indicating the stream is active but no usable element
    /// has arrived yet). All other cases pass through unchanged.
    ///
    /// ```swift
    /// let phase: AsyncSequencePhase<String?> = ...
    /// let nonNil: AsyncSequencePhase<String> = phase.compactMap()
    /// ```
    func compactMap<T>() -> AsyncSequencePhase<T> where Element == T? {
        switch self {
        case .idle:                   return .idle
        case .loading:                return .loading
        case .value(.none):          return .loading
        case .value(.some(let v)):   return .value(v)
        case .finished:               return .finished
        case .failure(let e):        return .failure(e)
        }
    }

    /// Returns the emitted element if available, otherwise returns
    /// `defaultValue`.
    ///
    /// ```swift
    /// let latest = phase.elementOrDefault(.empty)
    /// ```
    func elementOrDefault(_ defaultValue: Element) -> Element {
        element ?? defaultValue
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
