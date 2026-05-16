import Foundation

// MARK: - ProviderObserver

/// A protocol for observing provider lifecycle events in a ProviderContainer.
///
/// `ProviderObserver` allows monitoring of provider creation, updates, and disposal
/// across an entire container. This is useful for logging, analytics, debugging,
/// performance monitoring, and external system synchronization.
///
/// **Key Characteristics:**
/// - **Lifecycle tracking**: Observe creation, update, and disposal events
/// - **All providers**: Single observer can monitor all providers in a container
/// - **Optional methods**: Implement only the events you care about
/// - **Reference-counted**: Retained by the container while observing
/// - **Global scope**: Sees all providers, not just specific ones
///
/// **Thread Safety:**
/// Confined to the MainActor. All callbacks execute on the main thread.
/// Safe to update UI or perform other main-thread operations.
///
/// **When to Use:**
/// - Logging: Track provider lifecycle for debugging
/// - Analytics: Measure update frequency and performance metrics
/// - Performance monitoring: Identify problematic provider patterns
/// - External sync: Synchronize provider state with databases or APIs
/// - Testing: Verify provider behavior in unit tests
/// - Caching: Coordinate with external caching systems
/// - Debugging: Inspect provider state during development
///
/// **Lifecycle Events:**
///
/// | Event | Fired When | Parameters |
/// |-------|-----------|-----------|
/// | didAddProvider | Provider element first created | provider, initial value |
/// | didUpdateProvider | Provider value changes | provider, old value, new value |
/// | didDisposeProvider | Provider element disposed | provider |
///
/// **Example: Debug Observer for Development**
/// ```swift
/// class DebugObserver: ProviderObserver {
///     func didAddProvider<P: ProviderProtocol>(
///         _ provider: P,
///         value: P.State,
///         container: ProviderContainer
///     ) {
///         print("[Provider] Created: \\(type(of: provider))")
///         print("  Initial value: \\(value)")
///     }
///
///     func didUpdateProvider<P: ProviderProtocol>(
///         _ provider: P,
///         oldValue: P.State,
///         newValue: P.State,
///         container: ProviderContainer
///     ) {
///         print("[Provider] Updated: \\(type(of: provider))")
///         print("  Old: \\(oldValue)")
///         print("  New: \\(newValue)")
///     }
///
///     func didDisposeProvider<P: ProviderProtocol>(
///         _ provider: P,
///         container: ProviderContainer
///     ) {
///         print("[Provider] Disposed: \\(type(of: provider))")
///     }
/// }
///
/// // Usage
/// let observer = DebugObserver()
/// container.addObserver(observer)
/// ```
///
/// **Example: Analytics Observer**
/// ```swift
/// class AnalyticsObserver: ProviderObserver {
///     func didUpdateProvider<P: ProviderProtocol>(
///         _ provider: P,
///         oldValue: P.State,
///         newValue: P.State,
///         container: ProviderContainer
///     ) {
///         let providerName = String(describing: type(of: provider))
///         analytics.track(
///             event: "provider_updated",
///             properties: [
///                 "provider": providerName,
///                 "type": P.State.self
///             ]
///         )
///     }
/// }
/// ```
///
/// **Example: Performance Monitor**
/// ```swift
/// class PerformanceObserver: ProviderObserver {
///     private var updateCounts: [String: Int] = [:]
///
///     func didUpdateProvider<P: ProviderProtocol>(
///         _ provider: P,
///         oldValue: P.State,
///         newValue: P.State,
///         container: ProviderContainer
///     ) {
///         let name = String(describing: type(of: provider))
///         updateCounts[name, default: 0] += 1
///
///         // Alert if a provider updates too frequently
///         if updateCounts[name]! > 100 {
///             print("⚠️ Provider \\(name) updated more than 100 times")
///         }
///     }
/// }
/// ```
///
/// **Example: Testing Observer**
/// ```swift
/// class TestObserver: ProviderObserver {
///     var updateCount = 0
///     var lastUpdate: (provider: String, new: Any)?
///
///     func didUpdateProvider<P: ProviderProtocol>(
///         _ provider: P,
///         oldValue: P.State,
///         newValue: P.State,
///         container: ProviderContainer
///     ) {
///         updateCount += 1
///         lastUpdate = (String(describing: type(of: provider)), newValue)
///     }
/// }
///
/// // Usage in tests
/// let observer = TestObserver()
/// container.addObserver(observer)
/// container.refresh(someProvider)
/// assert(observer.updateCount == 1)
/// ```
///
/// - Important: Observers are reference-counted by the container
/// - Note: Default implementations provided; implement only what you need
/// - Warning: Avoid heavy operations in callbacks; they run on main thread
@MainActor
public protocol ProviderObserver: AnyObject {

    /// Called when a provider element is first created and initialized.
    ///
    /// Fired when a provider is accessed for the first time and its element
    /// is created. The initial computed value is provided. This is useful for
    /// tracking which providers are being used in your application.
    ///
    /// **When Called:**
    /// - On first access to the provider (read, watch, refresh, listen)
    /// - Only once per provider per container
    /// - After providerCreate() computes the initial value
    /// - Before any dependents are notified
    ///
    /// **Parameters:**
    /// - provider: The provider type instance (read-only)
    /// - value: The initial computed value
    /// - container: The ProviderContainer managing the provider
    ///
    /// **Use Cases:**
    /// - Log provider creation for debugging
    /// - Track which providers are accessed during app lifecycle
    /// - Initialize external resources (database connections, etc.)
    /// - Validate initial state
    /// - Analytics: Track feature usage by provider access
    ///
    /// **Example: Track Created Providers**
    /// ```swift
    /// func didAddProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     value: P.State,
    ///     container: ProviderContainer
    /// ) {
    ///     let providerType = String(describing: type(of: provider))
    ///     createdProviders.insert(providerType)
    ///     print("Created provider: \\(providerType)")
    /// }
    /// ```
    ///
    /// **Example: Initialize External Resources**
    /// ```swift
    /// func didAddProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     value: P.State,
    ///     container: ProviderContainer
    /// ) {
    ///     if let value = value as? DatabaseRecord {
    ///         database.addListener(for: value.id)
    ///     }
    /// }
    /// ```
    func didAddProvider<P: ProviderProtocol>(
        _ provider: P,
        value: P.State,
        container: ProviderContainer
    )

    /// Called when a provider's value changes after recomputation.
    ///
    /// Fired whenever a provider recomputes and its state value changes.
    /// Both the old and new values are provided for comparison. This is useful
    /// for tracking state mutations and understanding application behavior.
    ///
    /// **When Called:**
    /// - After providerCreate() recomputes the value
    /// - Only when the new value differs from the old value
    /// - Before dependents are invalidated
    /// - Can fire multiple times per provider lifetime
    /// - Includes both user-triggered and automatic updates
    ///
    /// **Parameters:**
    /// - provider: The provider type instance
    /// - oldValue: The previous state value
    /// - newValue: The newly computed state value
    /// - container: The ProviderContainer managing the provider
    ///
    /// **Use Cases:**
    /// - Log state transitions for debugging
    /// - Update external caches with new values
    /// - Trigger side effects based on value changes
    /// - Measure update frequency and performance
    /// - Analytics: Track state mutations
    /// - Implement undo/redo systems
    /// - Sync state to persistent storage
    ///
    /// **Example: Log State Transitions**
    /// ```swift
    /// func didUpdateProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     oldValue: P.State,
    ///     newValue: P.State,
    ///     container: ProviderContainer
    /// ) {
    ///     let name = String(describing: type(of: provider))
    ///     logger.info("Provider \\(name) changed", metadata: [
    ///         "old": "\\(oldValue)",
    ///         "new": "\\(newValue)"
    ///     ])
    /// }
    /// ```
    ///
    /// **Example: Sync to Persistence Layer**
    /// ```swift
    /// func didUpdateProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     oldValue: P.State,
    ///     newValue: P.State,
    ///     container: ProviderContainer
    /// ) {
    ///     if let userProvider = provider as? AnyProvider<User>,
    ///        let user = newValue as? User {
    ///         userDatabase.save(user)
    ///     }
    /// }
    /// ```
    ///
    /// **Example: Performance Tracking**
    /// ```swift
    /// func didUpdateProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     oldValue: P.State,
    ///     newValue: P.State,
    ///     container: ProviderContainer
    /// ) {
    ///     let name = String(describing: type(of: provider))
    ///     metrics.increment("provider.updates", tags: ["provider": name])
    /// }
    /// ```
    func didUpdateProvider<P: ProviderProtocol>(
        _ provider: P,
        oldValue: P.State,
        newValue: P.State,
        container: ProviderContainer
    )

    /// Called when a provider element is disposed and its resources are cleaned up.
    ///
    /// Fired when a provider is disposed due to auto-disposal, manual cleanup,
    /// or container deallocation. This is the last event in the provider's lifecycle.
    /// Use this to clean up any external resources or monitoring associated with
    /// the provider.
    ///
    /// **When Called:**
    /// - When checkAutoDispose() determines the provider should be disposed
    /// - When all listeners stop watching and cache time expires
    /// - When provider has no dependents and auto-disposal is enabled
    /// - Before the element is removed from the elements dictionary
    /// - Can fire multiple times in the app's lifetime (if provider is recreated)
    ///
    /// **Parameters:**
    /// - provider: The provider type instance (last reference)
    /// - container: The ProviderContainer managing the provider
    ///
    /// **Use Cases:**
    /// - Log provider disposal for debugging
    /// - Clean up external resources (API clients, timers, listeners)
    /// - Disconnect from databases or realtime services
    /// - Stop monitoring external changes
    /// - Analytics: Track provider lifetime
    /// - Finalize any pending operations
    ///
    /// **Example: Log Disposal**
    /// ```swift
    /// func didDisposeProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     container: ProviderContainer
    /// ) {
    ///     let name = String(describing: type(of: provider))
    ///     logger.debug("Provider disposed: \\(name)")
    /// }
    /// ```
    ///
    /// **Example: Clean Up External Resources**
    /// ```swift
    /// func didDisposeProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     container: ProviderContainer
    /// ) {
    ///     if let apiProvider = provider as? AnyProvider<APIClient>,
    ///        let client = try? container.read(apiProvider) {
    ///         client.disconnect()
    ///     }
    /// }
    /// ```
    ///
    /// **Example: Stop Real-Time Listeners**
    /// ```swift
    /// func didDisposeProvider<P: ProviderProtocol>(
    ///     _ provider: P,
    ///     container: ProviderContainer
    /// ) {
    ///     let name = String(describing: type(of: provider))
    ///     realTimeService.removeListener(for: name)
    /// }
    /// ```
    func didDisposeProvider<P: ProviderProtocol>(
        _ provider: P,
        container: ProviderContainer
    )
}

// MARK: - Default Implementations

/// Default empty implementations for ProviderObserver.
///
/// All methods have default empty implementations, allowing observers
/// to implement only the events they care about.
extension ProviderObserver {
    /// Default empty implementation of didAddProvider.
    ///
    /// Override this method to respond to provider creation events.
    public func didAddProvider<P: ProviderProtocol>(
        _ provider: P,
        value: P.State,
        container: ProviderContainer
    ) {}

    /// Default empty implementation of didUpdateProvider.
    ///
    /// Override this method to respond to provider update events.
    public func didUpdateProvider<P: ProviderProtocol>(
        _ provider: P,
        oldValue: P.State,
        newValue: P.State,
        container: ProviderContainer
    ) {}

    /// Default empty implementation of didDisposeProvider.
    ///
    /// Override this method to respond to provider disposal events.
    public func didDisposeProvider<P: ProviderProtocol>(
        _ provider: P,
        container: ProviderContainer
    ) {}
}
