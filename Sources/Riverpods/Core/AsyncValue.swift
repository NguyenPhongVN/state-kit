import Foundation

/// Represents the lifecycle state of an asynchronous operation in a Provider.
///
/// `AsyncValue<T>` is similar to Result and Optional types but with additional states
/// for async operations. It handles loading, success, error, and refreshing states,
/// optionally preserving previous data during state transitions.
///
/// **State Transitions:**
/// ```
/// Initial: .loading(nil)
///     ↓
/// Success: .data(value)
///     ↓
/// Refresh: .refreshing(value)
///     ↓
/// Final: .data(newValue) or .error(error, previousData: value)
/// ```
///
/// **Thread Safety:**
/// `AsyncValue` is `Sendable` and can be safely shared across async contexts.
///
/// **Example Usage:**
/// ```swift
/// @FutureProvider
/// func fetchUserProvider() async -> User {
///     return try await API.getUser()
/// }
///
/// struct UserView: View {
///     @Watch(fetchUserProvider) var userState
///
///     var body: some View {
///         userState.when(
///             data: { user in Text(user.name) },
///             error: { error, _ in Text("Error: \(error.localizedDescription)") },
///             loading: { _ in ProgressView() }
///         )
///     }
/// }
/// ```
public enum AsyncValue<T: Sendable>: Sendable {

    // MARK: - Cases

    /// The asynchronous operation completed successfully with a value.
    /// - Parameter T: The resulting value from the operation
    case data(T)

    /// An error occurred during the asynchronous operation.
    /// - Parameters:
    ///   - Error: The thrown error
    ///   - previousData: Optional previously cached data before the error occurred
    case error(Error, previousData: T? = nil)

    /// The asynchronous operation is in progress.
    /// - Parameter previousData: Optional previously cached data from a prior successful load
    case loading(previousData: T? = nil)

    /// The operation is refreshing existing data (has previous data while loading new data).
    /// This state is useful for implementing refresh-while-showing-old-data UX patterns.
    /// - Parameter T: The current/previous value being refreshed
    case refreshing(T)

    // MARK: - Computed Properties

    /// The current value if available, regardless of loading state.
    ///
    /// Returns the value from `.data` or `.refreshing` states, or the previous data
    /// from `.loading` or `.error` states if available.
    ///
    /// **Example:**
    /// ```swift
    /// let state: AsyncValue<String> = .loading(previousData: "cached")
    /// print(state.value) // prints "cached"
    /// ```
    public var value: T? {
        switch self {
        case .data(let t), .refreshing(let t):
            return t
        case .loading(let prev):
            return prev
        case .error(_, let prev):
            return prev
        }
    }

    /// The error if the operation failed, nil otherwise.
    ///
    /// **Example:**
    /// ```swift
    /// let state: AsyncValue<String> = .error(NetworkError.timeout)
    /// if let error = state.error {
    ///     print("Failed with: \(error)")
    /// }
    /// ```
    public var error: Error? {
        if case .error(let e, _) = self { return e }
        return nil
    }

    /// Whether the operation is currently loading or refreshing.
    ///
    /// Returns `true` for both `.loading` and `.refreshing` states.
    ///
    /// **Example:**
    /// ```swift
    /// if userState.isLoading {
    ///     showLoadingIndicator()
    /// }
    /// ```
    public var isLoading: Bool {
        switch self {
        case .loading, .refreshing:
            return true
        default:
            return false
        }
    }

    /// Whether the operation is currently refreshing existing data.
    ///
    /// Returns `true` only for `.refreshing` state. Use this to differentiate between
    /// initial load and refresh-while-showing-stale-data.
    ///
    /// **Example:**
    /// ```swift
    /// if userState.isRefreshing {
    ///     showSubtleRefreshIndicator()
    /// }
    /// ```
    public var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }

    /// Whether a value is currently available (not in pure loading state without previous data).
    ///
    /// **Example:**
    /// ```swift
    /// if userState.hasValue {
    ///     displayContent()
    /// } else {
    ///     displayEmptyState()
    /// }
    /// ```
    public var hasValue: Bool {
        value != nil
    }

    // MARK: - Pattern Matching & Transformation

    /// Executes different closures based on the current state.
    ///
    /// This is the primary way to handle different AsyncValue states in a type-safe manner.
    /// All branches must return the same type.
    ///
    /// - Parameters:
    ///   - data: Closure executed when the operation succeeded
    ///   - error: Closure executed when the operation failed
    ///   - loading: Closure executed when the operation is in progress
    /// - Returns: The result of executing the appropriate branch
    ///
    /// **Example:**
    /// ```swift
    /// let message = userState.when(
    ///     data: { user in "Welcome, \(user.name)" },
    ///     error: { error, _ in "Error: \(error.localizedDescription)" },
    ///     loading: { _ in "Loading user..." }
    /// )
    /// ```
    public func when<Result>(
        data: (T) -> Result,
        error: (Error, T?) -> Result,
        loading: (T?) -> Result
    ) -> Result {
        switch self {
        case .data(let value):
            return data(value)
        case .refreshing(let value):
            return data(value)
        case .error(let err, let prev):
            return error(err, prev)
        case .loading(let prev):
            return loading(prev)
        }
    }

    /// Transforms the inner value if it exists, preserving the overall state structure.
    ///
    /// Maps over the value in `.data` and `.refreshing` states. In `.error` and `.loading` states,
    /// the previous data is also transformed if present.
    ///
    /// - Parameter transform: A closure that transforms the value
    /// - Returns: A new AsyncValue with the transformed value
    ///
    /// **Example:**
    /// ```swift
    /// let userNameState = userState.map { user in user.name }
    /// // AsyncValue<String> with same state as original
    /// ```
    public func map<U>(_ transform: (T) -> U) -> AsyncValue<U> {
        switch self {
        case .data(let value):
            return .data(transform(value))
        case .refreshing(let value):
            return .refreshing(transform(value))
        case .error(let error, let prev):
            return .error(error, previousData: prev.map(transform))
        case .loading(let prev):
            return .loading(previousData: prev.map(transform))
        }
    }

    /// Wraps an async throwing operation and automatically converts the result to AsyncValue.
    ///
    /// This utility function simplifies creating AsyncValue from async operations by
    /// handling success and error cases automatically.
    ///
    /// - Parameter action: An async throwing closure that produces a value of type T
    /// - Returns: .data(value) on success, or .error(error) on failure
    ///
    /// **Example:**
    /// ```swift
    /// let userState = await AsyncValue.guard {
    ///     try await API.fetchUser()
    /// }
    /// ```
    public static func `guard`(_ action: @escaping () async throws -> T) async -> AsyncValue<T> {
        do {
            return .data(try await action())
        } catch {
            return .error(error)
        }
    }

    /// Extracts the current value or throws an error.
    ///
    /// Attempts to return the value from any state that has one. If in `.error` state,
    /// throws the error. If in `.loading` state without previous data, triggers a fatal error.
    ///
    /// - Returns: The value if available
    /// - Throws: The error if the operation failed
    /// - Note: Triggers fatalError if loading without previous data
    ///
    /// **Example:**
    /// ```swift
    /// do {
    ///     let user = try userState.unwrap()
    ///     print("User: \(user.name)")
    /// } catch {
    ///     print("Failed to get user: \(error)")
    /// }
    /// ```
    public func unwrap() throws -> T {
        switch self {
        case .data(let val), .refreshing(let val):
            return val
        case .error(let err, _):
            throw err
        case .loading(let prev):
            if let prev = prev { return prev }
            fatalError("Attempted to unwrap an AsyncValue in loading state without previous data.")
        }
    }

    /// Updates the current value using a transformation closure.
    ///
    /// Applies the transformation to the existing value while preserving the current state type.
    /// If no value exists, returns the AsyncValue unchanged.
    ///
    /// - Parameter transform: A closure that produces a new value from the current one
    /// - Returns: A new AsyncValue with the transformed value in the same state
    ///
    /// **Example:**
    /// ```swift
    /// // Increment a counter value
    /// let updated = counterState.update { $0 + 1 }
    /// ```
    public func update(_ transform: (T) -> T) -> AsyncValue<T> {
        if let val = value {
            let newVal = transform(val)
            switch self {
            case .data:
                return .data(newVal)
            case .refreshing:
                return .refreshing(newVal)
            case .error(let err, _):
                return .error(err, previousData: newVal)
            case .loading:
                return .loading(previousData: newVal)
            }
        }
        return self
    }
}
