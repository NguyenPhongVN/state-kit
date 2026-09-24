import SwiftUI

// MARK: - ErrorBoundary

/// Renders a view subtree whose construction may throw, falling back when it
/// does.
///
/// SwiftUI view builders cannot `throw`, so data-dependent rendering usually
/// forces booleans and placeholder views at every level. `ErrorBoundary`
/// restores the React ErrorBoundary shape for the synchronous case: evaluate
/// the content, and if it throws, render a fallback that receives the error.
///
/// ```swift
/// ErrorBoundary {
///     try ProfileView(profile: try decodeProfile())
/// } fallback: { error in
///     ContentUnavailableView("Something went wrong", systemImage: "exclamationmark.triangle")
/// }
/// ```
///
/// **Contract:** the boundary catches synchronous errors thrown by its own
/// content closure — it is not a process-crash catcher. `onError` is invoked
/// once per render pass in which the content throws (use it for logging or
/// analytics). If the fallback closure itself throws, that error propagates.
public struct ErrorBoundary<Content: View, Fallback: View>: View {

    private let content: () throws -> Content
    private let fallback: (Error) -> Fallback
    private let onError: ((Error) -> Void)?

    /// Creates an error boundary around a throwing content builder.
    ///
    /// - Parameters:
    ///   - onError: Invoked when the content throws (per render pass).
    ///   - content: The view subtree to render on success.
    ///   - fallback: The view rendered with the caught error on failure.
    public init(
        onError: ((Error) -> Void)? = nil,
        @ViewBuilder content: @escaping () throws -> Content,
        @ViewBuilder fallback: @escaping (Error) -> Fallback
    ) {
        self.content = content
        self.fallback = fallback
        self.onError = onError
    }

    public var body: some View {
        switch resolve(onError: onError) {
        case .content(let content):
            content
        case .fallback(let error):
            fallback(error)
        }
    }

    // MARK: - Resolution (internal, testable)

    /// The outcome of evaluating the content closure.
    enum Resolution {
        case content(Content)
        case fallback(Error)
    }

    /// Evaluates the content closure, reporting thrown errors through the
    /// supplied `onError` hook (when provided).
    func resolve(onError: ((Error) -> Void)?) -> Resolution {
        do {
            return .content(try content())
        } catch {
            onError?(error)
            return .fallback(error)
        }
    }
}
