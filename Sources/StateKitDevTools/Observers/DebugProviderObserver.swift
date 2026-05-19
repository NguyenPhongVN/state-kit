import Foundation
import Riverpods

/// A lightweight observer that logs provider lifecycle events to the console.
///
/// Provides timestamped, formatted output for provider creation, updates, and disposal.
/// Designed for use during development to understand provider behavior.
///
/// **Usage:**
/// ```swift
/// let container = ProviderContainer(observers: [DebugProviderObserver()])
/// ```
///
/// **Filtering by Provider:**
/// ```swift
/// let observer = DebugProviderObserver { provider in
///     provider.name?.hasPrefix("auth") == true
/// }
/// ```
///
/// - Note: Uses `print()` for output. Consider a dedicated logger in production.
@MainActor
public final class DebugProviderObserver: ProviderObserver {

    /// Optional filter: only log providers matching this predicate.
    public let filter: ((any ProviderProtocol) -> Bool)?

    /// Creates a debug provider observer.
    ///
    /// - Parameter filter: Optional filter to limit which providers are logged.
    public init(filter: ((any ProviderProtocol) -> Bool)? = nil) {
        self.filter = filter
    }

    private func shouldLog<P: ProviderProtocol>(_ provider: P) -> Bool {
        filter.map { $0(provider) } ?? true
    }

    public func didAddProvider<P: ProviderProtocol>(
        _ provider: P,
        value: P.State,
        container: ProviderContainer
    ) {
        guard shouldLog(provider) else { return }
        print("[StateKit] [+] \(provider.name ?? String(describing: P.self))")
        print("  value: \(value)")
    }

    public func didUpdateProvider<P: ProviderProtocol>(
        _ provider: P,
        oldValue: P.State,
        newValue: P.State,
        container: ProviderContainer
    ) {
        guard shouldLog(provider) else { return }
        print("[StateKit] [↻] \(provider.name ?? String(describing: P.self))")
        print("  old: \(oldValue)")
        print("  new: \(newValue)")
    }

    public func didDisposeProvider<P: ProviderProtocol>(
        _ provider: P,
        container: ProviderContainer
    ) {
        guard shouldLog(provider) else { return }
        print("[StateKit] [-] \(provider.name ?? String(describing: P.self))")
    }
}
