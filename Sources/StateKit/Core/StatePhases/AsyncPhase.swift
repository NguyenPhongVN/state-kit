/// Asynchronous state used by `useAsync`.
///
/// This models the typical lifecycle of an async operation:
/// - `idle`:     the operation has not started yet.
/// - `loading`:  the operation is currently running.
/// - `success`:  the operation finished successfully and produced a value.
/// - `failure`:  the operation failed with an error.
///
/// `AsyncPhase` is designed for one-shot async work such as loading a user,
/// submitting a form, or refreshing a single resource. If you need to model
/// a stream of values over time, use `AsyncSequencePhase` instead.
///
/// Typical usage:
///
/// ```swift
/// let phase = useAsync(updateStrategy: .preserved(by: userID)) {
///     try await api.fetchUser(id: userID)
/// }
///
/// switch phase {
/// case .idle, .loading:
///     ProgressView()
/// case .success(let user):
///     Text(user.name)
/// case .failure(let error):
///     Text(error.localizedDescription)
/// }
/// ```
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
/// `.failure` cases are considered equal regardless of the underlying error,
/// because `Error` does not conform to `Equatable`.
///
/// If your tests need to assert the actual error details, compare
/// `phase.error` or `phase.error?.localizedDescription` separately.
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

/// Conditional `Hashable` conformance for `AsyncPhase`.
///
/// As with `Equatable`, `.failure` hashes only by case identity, not by the
/// underlying error payload.
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

    /// The phase kind without its associated payload.
    ///
    /// This is useful when call sites care only about control flow and do not
    /// want to pattern-match associated values:
    ///
    /// ```swift
    /// if phase.status == .loading {
    ///     showLoadingIndicator = true
    /// }
    /// ```
    var status: SKStatus {
        switch self {
        case .idle:            return .idle
        case .loading:         return .loading
        case .success:         return .success
        case .failure:         return .failure
        }
    }

    /// The associated value if the phase is `.success`, otherwise `nil`.
    ///
    /// ```swift
    /// let userName = phase.value?.name
    /// ```
    var value: Value? {
        guard case .success(let v) = self else { return nil }
        return v
    }

    /// Alias for `value`, provided for readability at call sites where
    /// success extraction is clearer than generic "value" access.
    ///
    /// ```swift
    /// #expect(phase.successValue == expectedUser)
    /// ```
    var successValue: Value? {
        value
    }

    /// The associated error if the phase is `.failure`, otherwise `nil`.
    ///
    /// ```swift
    /// let message = phase.error?.localizedDescription
    /// ```
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

    /// `true` when the operation is in flight.
    ///
    /// This is a semantic alias for `isLoading`, useful at call sites that
    /// read more naturally in terms of "pending" work than raw enum cases.
    var isPending: Bool {
        isLoading
    }

    /// `true` when the operation has reached a terminal state.
    ///
    /// Terminal states are `.success` and `.failure`. Non-terminal states are
    /// `.idle` and `.loading`.
    var isTerminal: Bool {
        isSuccess || isFailure
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
    /// This is useful when a fallback value is acceptable and you want to
    /// recover from failure while still ending up in a successful phase.
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
    ///
    /// This is useful when you want to clear an error and return to the
    /// pre-request state, for example before letting the user retry manually.
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
    /// Useful in rendering code where a fallback value is cheaper than
    /// pattern-matching:
    ///
    /// ```swift
    /// let rows = phase.valueOrDefault([])
    /// ```
    ///
    func valueOrDefault(_ defaultValue: Value) -> Value {
        value ?? defaultValue
    }
}

