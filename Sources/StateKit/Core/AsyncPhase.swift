/// Asynchronous state used by `useAsync`.
///
/// This models the typical lifecycle of an async operation:
/// - `idle`:     the operation has not started yet.
/// - `loading`:  the operation is currently running.
/// - `success`:  the operation finished successfully and produced a value.
/// - `failure`:  the operation failed with an error.
public enum AsyncPhase<Value> {
    /// The async operation has not started yet.
    case idle
    /// The async operation is currently running.
    case loading
    /// The async operation finished successfully with a value.
    case success(Value)
    /// The async operation failed with an error.
    case failure(Error)
}


// MARK: - AsyncPhase — Equatable

/// Conditional `Equatable` conformance for `AsyncPhase`.
///
/// `.failure` cases are considered equal regardless of the underlying error.
extension AsyncPhase: Equatable where Value: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):                       return true
        case (.loading, .loading):                 return true
        case (.success(let l), .success(let r)):   return l == r
        case (.failure, .failure):                 return true
        default:                                   return false
        }
    }
}

// MARK: - AsyncPhase — Hashable

extension AsyncPhase: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .idle:            hasher.combine(0)
        case .loading:         hasher.combine(1)
        case .success(let v): hasher.combine(2); hasher.combine(v)
        case .failure:        hasher.combine(3)
        }
    }
}

// MARK: - Sendable

extension AsyncPhase: Sendable where Value: Sendable {}

// MARK: - Accessors

public extension AsyncPhase {

    /// The associated value if the phase is `.success`, otherwise `nil`.
    var value: Value? {
        guard case .success(let v) = self else { return nil }
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

    /// `true` when the phase is `.success`.
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }

    /// `true` when the phase is `.failure`.
    var isFailure: Bool {
        guard case .failure = self else { return false }
        return true
    }
}

// MARK: - Transformations

public extension AsyncPhase {

    /// Returns a new phase by applying `transform` to the success value.
    /// All other cases pass through unchanged.
    ///
    /// ```swift
    /// let namePhase: AsyncPhase<String> = userPhase.map { $0.name }
    /// ```
    func map<T>(_ transform: (Value) -> T) -> AsyncPhase<T> {
        switch self {
        case .idle:            return .idle
        case .loading:         return .loading
        case .success(let v): return .success(transform(v))
        case .failure(let e): return .failure(e)
        }
    }

    /// Returns a new phase by applying `transform` to the success value and
    /// flattening the result. All other cases pass through unchanged.
    ///
    /// ```swift
    /// let child = userPhase.flatMap { user in
    ///     user.isActive ? .success(user.profile) : .idle
    /// }
    /// ```
    func flatMap<T>(_ transform: (Value) -> AsyncPhase<T>) -> AsyncPhase<T> {
        switch self {
        case .idle:            return .idle
        case .loading:         return .loading
        case .success(let v): return transform(v)
        case .failure(let e): return .failure(e)
        }
    }

    /// Returns a new phase by applying `transform` to the failure error.
    /// All other cases pass through unchanged.
    ///
    /// ```swift
    /// let typed = phase.mapError { AppError.wrapped($0) }
    /// ```
    func mapError(_ transform: (Error) -> Error) -> AsyncPhase<Value> {
        guard case .failure(let e) = self else { return self }
        return .failure(transform(e))
    }

    /// Returns `.success(replacement)` when the phase is `.failure`.
    /// All other cases pass through unchanged.
    ///
    /// ```swift
    /// let safe = phase.replaceError(with: [])
    /// ```
    func replaceError(with replacement: Value) -> AsyncPhase<Value> {
        guard case .failure = self else { return self }
        return .success(replacement)
    }

    /// Returns `.idle` when the phase is `.failure`, silently discarding the
    /// error and resetting to the initial state.
    func ignoreError() -> AsyncPhase<Value> {
        guard case .failure = self else { return self }
        return .idle
    }

    /// Unwraps `.success(wrapped?)`, returning `.idle` when the wrapped value
    /// is `nil`. All other cases pass through unchanged.
    ///
    /// ```swift
    /// let phase: AsyncPhase<User?> = ...
    /// let nonNil: AsyncPhase<User> = phase.compactMap()
    /// ```
    func compactMap<T>() -> AsyncPhase<T> where Value == T? {
        switch self {
        case .idle:                   return .idle
        case .loading:                return .loading
        case .success(.none):        return .idle
        case .success(.some(let v)): return .success(v)
        case .failure(let e):        return .failure(e)
        }
    }

    /// Returns the success value if available, otherwise returns
    /// `defaultValue`.
    ///
    /// ```swift
    /// let items = phase.valueOrDefault([])
    /// ```
    func valueOrDefault(_ defaultValue: Value) -> Value {
        value ?? defaultValue
    }
}

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
    func asSequencePhase() -> AsyncSequencePhase<Value> {
        switch self {
        case .idle:            return .idle
        case .loading:         return .loading
        case .success(let v): return .value(v)
        case .failure(let e): return .failure(e)
        }
    }
}
