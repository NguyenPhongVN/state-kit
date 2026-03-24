import Combine
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

// MARK: - PublisherPhase — accessors

public extension PublisherPhase {
    
    /// The associated output value, or `nil` if the phase is not `.value`.
    var output: Output? {
        guard case .value(let v) = self else { return nil }
        return v
    }
    
    /// The associated error, or `nil` if the phase is not `.failure`.
    var error: Error? {
        guard case .failure(let e) = self else { return nil }
        return e
    }
    
    /// `true` when the phase is `.idle`.
    var isIdle: Bool {
        guard case .idle = self else { return false }
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
}

// MARK: - PublisherPhase — transformations

public extension PublisherPhase {
    
    /// Returns a new phase by applying `transform` to the associated output
    /// value if the phase is `.value`; passes all other cases through unchanged.
    ///
    /// Equivalent to Combine's `map` operator but lifted into `PublisherPhase`.
    ///
    /// ```swift
    /// let namePhase: PublisherPhase<String> = phase.map { $0.name }
    /// ```
    func map<T>(_ transform: (Output) -> T) -> PublisherPhase<T> {
        switch self {
        case .idle:             return .idle
        case .value(let v):    return .value(transform(v))
        case .finished:        return .finished
        case .failure(let e):  return .failure(e)
        }
    }
    
    /// Returns a new phase by applying `transform` to the output value when
    /// the phase is `.value`, flattening the result.
    ///
    /// ```swift
    /// let childPhase = phase.flatMap { parent in
    ///     parent.isValid ? .value(parent.child) : .idle
    /// }
    /// ```
    func flatMap<T>(_ transform: (Output) -> PublisherPhase<T>) -> PublisherPhase<T> {
        switch self {
        case .idle:             return .idle
        case .value(let v):    return transform(v)
        case .finished:        return .finished
        case .failure(let e):  return .failure(e)
        }
    }
    
    /// Returns a new phase by applying `transform` to the associated error
    /// when the phase is `.failure`; passes all other cases through unchanged.
    ///
    /// ```swift
    /// let mapped = phase.mapError { AppError.network($0) }
    /// ```
    func mapError(_ transform: (Error) -> Error) -> PublisherPhase<Output> {
        switch self {
        case .failure(let e): return .failure(transform(e))
        default:              return self
        }
    }
    
    /// Returns `.value(replacement)` when the phase is `.failure`, passing
    /// all other cases through unchanged.
    ///
    /// ```swift
    /// let safe = phase.replaceError(with: [])
    /// ```
    func replaceError(with replacement: Output) -> PublisherPhase<Output> {
        switch self {
        case .failure: return .value(replacement)
        default:       return self
        }
    }
    
    /// Returns `.idle` when the phase is `.failure`, effectively suppressing
    /// the error and resetting to the initial state.
    func ignoreError() -> PublisherPhase<Output> {
        switch self {
        case .failure: return .idle
        default:       return self
        }
    }
    
    /// Unwraps `.value(wrapped?)` phases, returning `.idle` when the wrapped
    /// value is `nil`.
    ///
    /// ```swift
    /// let nonNil: PublisherPhase<User> = optionalPhase.compactMap()
    /// ```
    func compactMap<T>() -> PublisherPhase<T> where Output == T? {
        switch self {
        case .idle:                    return .idle
        case .value(.none):           return .idle
        case .value(.some(let v)):    return .value(v)
        case .finished:               return .finished
        case .failure(let e):         return .failure(e)
        }
    }

    /// Returns the output value if the phase is `.value`, otherwise returns
    /// `defaultValue`.
    ///
    /// ```swift
    /// let items = phase.valueOrDefault([])
    /// ```
    func valueOrDefault(_ defaultValue: Output) -> Output {
        output ?? defaultValue
    }
}

// MARK: - PublisherPhase — Equatable

/// Conditional `Equatable` conformance for `PublisherPhase`.
///
/// `.failure` cases are considered equal regardless of the underlying error,
/// because `Error` is not itself `Equatable`. If you need error-aware equality,
/// compare `phase.error?.localizedDescription` separately.
extension PublisherPhase: Equatable where Output: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):                       return true
        case (.value(let l), .value(let r)):       return l == r
        case (.finished, .finished):               return true
        case (.failure, .failure):                 return true
        default:                                   return false
        }
    }
}

// MARK: - PublisherPhase — Hashable

extension PublisherPhase: Hashable where Output: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .idle:            hasher.combine(0)
        case .value(let v):   hasher.combine(1); hasher.combine(v)
        case .finished:       hasher.combine(2)
        case .failure:        hasher.combine(3)
        }
    }
}

// MARK: - Sendable

extension PublisherPhase: Sendable where Output: Sendable {}

// MARK: - Interop

public extension PublisherPhase {

    /// Converts this `PublisherPhase` to an `AsyncPhase`.
    ///
    /// | `PublisherPhase` | `AsyncPhase` |
    /// |---|---|
    /// | `.idle` | `.idle` |
    /// | `.value(v)` | `.success(v)` |
    /// | `.finished` | `.idle` — no single-result terminal equivalent |
    /// | `.failure(e)` | `.failure(e)` |
    func asAsyncPhase() -> AsyncPhase<Output> {
        switch self {
        case .idle:            return .idle
        case .value(let v):   return .success(v)
        case .finished:        return .idle
        case .failure(let e): return .failure(e)
        }
    }

    /// Converts this `PublisherPhase` to an `AsyncSequencePhase`.
    ///
    /// | `PublisherPhase` | `AsyncSequencePhase` |
    /// |---|---|
    /// | `.idle` | `.idle` |
    /// | `.value(v)` | `.value(v)` |
    /// | `.finished` | `.finished` |
    /// | `.failure(e)` | `.failure(e)` |
    func asSequencePhase() -> AsyncSequencePhase<Output> {
        switch self {
        case .idle:            return .idle
        case .value(let v):   return .value(v)
        case .finished:        return .finished
        case .failure(let e): return .failure(e)
        }
    }
}

// MARK: - AsyncPhase ↔ PublisherPhase

public extension AsyncPhase {

    /// Converts this `AsyncPhase` to a `PublisherPhase`.
    ///
    /// | `AsyncPhase` | `PublisherPhase` |
    /// |---|---|
    /// | `.idle` | `.idle` |
    /// | `.loading` | `.idle` — no loading concept in `PublisherPhase` |
    /// | `.success(v)` | `.value(v)` |
    /// | `.failure(e)` | `.failure(e)` |
    func asPublisherPhase() -> PublisherPhase<Value> {
        switch self {
        case .idle:            return .idle
        case .loading:         return .idle
        case .success(let v): return .value(v)
        case .failure(let e): return .failure(e)
        }
    }
}

// MARK: - Publisher — hook bridge

public extension Publisher {
    
    /// Subscribes to this publisher inside the current `StateScope` and
    /// returns its latest `PublisherPhase`.
    ///
    /// Shorthand for `usePublisher(updateStrategy:) { self }`. The publisher
    /// is subscribed immediately on the first render. On subsequent renders
    /// the subscription is restarted only when `updateStrategy` changes.
    ///
    /// Must be called inside a `StateScope` closure or a
    /// `StateView.stateBody`.
    ///
    /// ```swift
    /// var stateBody: some View {
    ///     let phase = searchPublisher.asPhase(updateStrategy: .preserved(by: query))
    ///
    ///     switch phase {
    ///     case .idle:           ProgressView()
    ///     case .value(let r):  ResultsList(r)
    ///     case .finished:      EmptyView()
    ///     case .failure(let e): Text(e.localizedDescription)
    ///     }
    /// }
    /// ```
    @MainActor
    func asPhase(updateStrategy: UpdateStrategy? = .once) -> PublisherPhase<Output> {
        usePublisher(updateStrategy: updateStrategy) { self }
    }
}

// MARK: - Publisher — Combine operators

public extension Publisher {
    
    /// Returns a non-failing publisher that maps every event from `self` into
    /// a `PublisherPhase<Output>` value.
    ///
    /// The returned stream:
    /// - Starts with `.idle` before any upstream event.
    /// - Emits `.value(output)` for each value received.
    /// - Emits `.finished` when the upstream completes normally.
    /// - Emits `.failure(error)` and completes when the upstream fails.
    ///
    /// Use this operator to convert any publisher pipeline into a phase
    /// stream **outside** of a `StateScope` — for example when bridging
    /// Combine pipelines into `@Observable` view models.
    ///
    /// ```swift
    /// let phasePublisher = URLSession.shared
    ///     .dataTaskPublisher(for: url)
    ///     .map(\.data)
    ///     .decode(type: User.self, decoder: JSONDecoder())
    ///     .materializeAsPhase()
    ///
    /// phasePublisher.sink { phase in
    ///     switch phase {
    ///     case .value(let user): print(user.name)
    ///     case .failure(let e): print(e)
    ///     default: break
    ///     }
    /// }
    /// ```
    func materializeAsPhase() -> AnyPublisher<PublisherPhase<Output>, Never> {
        self
            .map { PublisherPhase.value($0) }
            .catch { Just(.failure($0)) }
            .prepend(.idle)
            .eraseToAnyPublisher()
    }
}

// MARK: - AnyPublisher factory

public extension PublisherPhase {
    
    /// Returns an `AnyPublisher` that immediately emits this phase value and
    /// completes, without ever failing.
    ///
    /// Useful for building stub publishers in previews or tests:
    ///
    /// ```swift
    /// let preview: AnyPublisher<PublisherPhase<[User]>, Never> =
    ///     PublisherPhase.value([.mock]).asPublisher()
    /// ```
    func asPublisher() -> AnyPublisher<PublisherPhase<Output>, Never> {
        Just(self).eraseToAnyPublisher()
    }
}

