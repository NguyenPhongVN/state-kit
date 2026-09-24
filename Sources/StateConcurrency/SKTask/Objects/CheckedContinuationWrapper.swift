import Foundation

/// A type-safe wrapper around `CheckedContinuation` that supports typed throws.
///
/// `CheckedContinuationWrapper` provides a convenient way to work with continuations when
/// using Swift's typed throws feature. It wraps a `CheckedContinuation<Result<T, E>, Never>`
/// and provides methods to resume with typed results or errors.
///
/// This is an internal implementation detail used by `withCheckedThrowingContinuation_`.
///
/// - Parameters:
///   - T: The success value type.
///   - E: The specific error type that can be thrown.
struct CheckedContinuationWrapper<T, E>: Sendable where E: Error {
    private let wrapped: CheckedContinuation<Result<T, E>, Never>
    
    init(continuation: CheckedContinuation<Result<T, E>, Never>) {
        self.wrapped = continuation
    }
    
    /// Resumes the continuation with a result.
    ///
    /// - Parameter result: The result to resume with (success or failure).
    func resume(with result: sending Result<T, E>) {
        wrapped.resume(with: .success(result))
    }
    
    /// Resumes the continuation with a result, type-erasing the error.
    ///
    /// This overload is available when `E` is `any Error`, allowing you to resume
    /// with a result containing a specific error type.
    ///
    /// - Parameter result: The result to resume with.
    func resume<Er>(with result: sending Result<T, Er>) where E == any Error, Er: Error {
        resume(with: result.mapError { $0 as E })
    }
    
    /// Resumes the continuation by returning a success value.
    ///
    /// - Parameter value: The value to return.
    func resume(returning value: sending T) {
        resume(with: .success(value))
    }
    
    /// Resumes the continuation when the success type is `Void`.
    ///
    /// This is a convenience method for resuming without a value.
    func resume() where T == () {
        resume(with: .success(()))
    }
    
    /// Resumes the continuation by throwing an error.
    ///
    /// - Parameter error: The error to throw.
    func resume(throwing error: E) {
        resume(with: .failure(error))
    }
    
    /// Resumes the continuation by throwing an error, type-erasing it.
    ///
    /// This overload is available when `E` is `any Error`, allowing you to throw
    /// a specific error type.
    ///
    /// - Parameter error: The error to throw.
    func resume<Er>(throwing error: Er) where E == any Error, Er: Error {
        resume(with: .failure(error as E))
    }
}

/// Suspends the current task and calls the given closure with a checked continuation for typed throws.
///
/// This function is similar to Swift's `withCheckedThrowingContinuation`, but supports typed throws,
/// allowing you to specify the exact error type that can be thrown. This provides better type safety
/// and enables compile-time verification of error handling.
///
/// ## Usage Example:
/// ```swift
/// enum NetworkError: Error {
///     case timeout
///     case invalidResponse
/// }
///
/// func fetchData() async throws(NetworkError) -> String {
///     try await withCheckedThrowingContinuation_ { continuation in
///         URLSession.shared.dataTask(with: url) { data, response, error in
///             if let error = error {
///                 continuation.resume(throwing: .timeout)
///             } else if let data = data {
///                 continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
///             } else {
///                 continuation.resume(throwing: .invalidResponse)
///             }
///         }.resume()
///     }
/// }
/// ```
///
/// - Parameters:
///   - isolation: The actor to which the continuation is isolated.
///   - function: The name of the calling function (used for debugging).
///   - body: A closure that receives a `CheckedContinuationWrapper` and must resume it exactly once.
/// - Returns: The value passed to the continuation's `resume(returning:)` method.
/// - Throws: The error of type `E` passed to the continuation's `resume(throwing:)` method.
func withCheckedThrowingContinuation_<T: Sendable, E>(
    isolation: isolated (any Actor)? = #isolation,
    function: String = #function,
    _ body: (CheckedContinuationWrapper<T, E>) -> Void
) async throws(E) -> sending T where E: Error {
    try await withCheckedContinuation(isolation: isolation, function: function) { (continuation: CheckedContinuation<Result<T, E>, Never>) in
        body(.init(continuation: continuation))
    }.get()
}

/// Suspends the current task and calls the given closure with a checked continuation for typed throws (Void variant).
///
/// This is a specialized version of `withCheckedThrowingContinuation_` for operations that don't return a value.
///
/// ## Usage Example:
/// ```swift
/// enum SetupError: Error {
///     case configurationFailed
/// }
///
/// func setup() async throws(SetupError) {
///     try await withCheckedThrowingContinuation_ { continuation in
///         performSetup { success in
///             if success {
///                 continuation.resume()
///             } else {
///                 continuation.resume(throwing: .configurationFailed)
///             }
///         }
///     }
/// }
/// ```
///
/// - Parameters:
///   - isolation: The actor to which the continuation is isolated.
///   - function: The name of the calling function (used for debugging).
///   - body: A closure that receives a `CheckedContinuationWrapper` and must resume it exactly once.
/// - Throws: The error of type `E` passed to the continuation's `resume(throwing:)` method.
func withCheckedThrowingContinuation_<E>(
    isolation: isolated (any Actor)? = #isolation,
    function: String = #function,
    _ body: (CheckedContinuationWrapper<Void, E>) -> Void
) async throws(E) where E: Error {
    try await withCheckedContinuation(isolation: isolation, function: function) { (continuation: CheckedContinuation<Result<Void, E>, Never>) in
        body(.init(continuation: continuation))
    }.get()
}
