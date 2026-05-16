import Foundation

// MARK: - ProviderRef Protocol

/// A reference providing access to interact with other providers and manage their lifecycle.
///
/// `ProviderRef` is passed to provider creation closures, enabling dependency tracking,
/// reactive updates, and side effect management. It's the primary API for communicating
/// between providers and controlling when providers compute or dispose their values.
///
/// **Thread Safety:**
/// ProviderRef is confined to the MainActor and should only be accessed from the main thread.
///
/// **Lifecycle Management:**
/// You can register callbacks for various lifecycle events:
/// - `onDispose`: When the provider is destroyed or recomputed
/// - `onCancel`: When all listeners stop watching
/// - `onResume`: When watchers return after cancellation
/// - `onAddListener`/`onRemoveListener`: When listeners are added or removed
///
/// **Example: Provider with Dependency Tracking**
/// ```swift
/// @Provider
/// func userDetailsProvider(ref: ProviderRef) -> User {
///     let userId = ref.watch(selectedUserIdProvider)  // Creates dependency
///     let user = ref.watch(userCacheProvider)         // Multiple dependencies supported
///
///     ref.onDispose {
///         print("User details computed for ID: \(userId)")
///     }
///
///     return user.filter { $0.id == userId }.first ?? User.unknown
/// }
/// ```
///
/// **Example: Side Effect Management**
/// ```swift
/// @Notifier
/// class AuthNotifier extends AsyncNotifier<AuthState> {
///     @override
///     Future<AuthState> build() async {
///         ref.onDispose(() {
///             cancelOutstandingRequests()
///         })
///
///         ref.listen(tokenRefreshProvider, fireImmediately: false) { prev, next in
///             // Token refreshed, update auth state
///         }
///
///         return await loadAuthState()
///     }
/// }
/// ```
///
/// - Important: Do not escape the ProviderRef beyond the scope of the provider creation.
@MainActor
public protocol ProviderRef: AnyObject {

    // MARK: - Watching & Reading

    /// Reads a provider's value and creates a reactive dependency.
    ///
    /// The provider will automatically recompute whenever the watched provider's value changes.
    /// This creates a dependency relationship: if the watched provider updates, this provider
    /// will be invalidated and recomputed.
    ///
    /// - Parameter provider: The provider whose value to read
    /// - Returns: The current value of the provider
    ///
    /// **Dependency Example:**
    /// ```swift
    /// @Provider
    /// func userFullNameProvider(ref: ProviderRef) -> String {
    ///     let user = ref.watch(currentUserProvider)  // Creates dependency
    ///     // If currentUserProvider changes, this provider recomputes
    ///     return "\(user.firstName) \(user.lastName)"
    /// }
    /// ```
    ///
    /// - Note: Each watch call creates a separate dependency. Multiple watches are supported.
    func watch<P: ProviderProtocol>(_ provider: P) -> P.State

    /// Reads a provider's value without creating a dependency.
    ///
    /// This is a one-time read that doesn't establish a reactive relationship.
    /// Changes to the read provider won't trigger recomputation of the current provider.
    /// Useful for optional configuration or one-off lookups.
    ///
    /// - Parameter provider: The provider whose value to read
    /// - Returns: The current value of the provider
    ///
    /// **Example: Conditional Dependency**
    /// ```swift
    /// @Provider
    /// func dataProvider(ref: ProviderRef) -> Data {
    ///     let userId = ref.watch(userIdProvider)  // Creates dependency
    ///     let useCache = ref.read(cacheSettingProvider)  // One-time read
    ///
    ///     if useCache {
    ///         return ref.read(userCacheProvider)
    ///     } else {
    ///         return ref.watch(userDataProvider)  // Dynamic dependency
    ///     }
    /// }
    /// ```
    ///
    /// - Warning: Overusing `read` can lead to stale data. Prefer `watch` for reactive values.
    func read<P: ProviderProtocol>(_ provider: P) -> P.State

    // MARK: - Listeners

    /// Registers a listener to react to a provider's value changes.
    ///
    /// The listener is called whenever the watched provider's value changes,
    /// enabling side effects without modifying the provider's computed value.
    ///
    /// - Parameters:
    ///   - provider: The provider to listen to
    ///   - fireImmediately: Whether to call the listener immediately with the current value
    ///   - listener: Called with (previousValue, newValue) on every change
    ///
    /// **Example: Tracking Changes**
    /// ```swift
    /// @Provider
    /// func userTrackerProvider(ref: ProviderRef) -> Void {
    ///     ref.listen(currentUserProvider, fireImmediately: false) { prevUser, newUser in
    ///         if prevUser?.id != newUser.id {
    ///             analytics.trackUserSwitch(from: prevUser?.name, to: newUser.name)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// **Example: Initialization**
    /// ```swift
    /// @Provider
    /// func initializeProvider(ref: ProviderRef) -> Void {
    ///     ref.listen(configProvider, fireImmediately: true) { _, config in
    ///         setupEnvironment(with: config)
    ///     }
    /// }
    /// ```
    func listen<P: ProviderProtocol>(
        _ provider: P,
        fireImmediately: Bool,
        listener: @escaping (P.State?, P.State) -> Void
    )

    // MARK: - Lifecycle Callbacks

    /// Registers a cleanup function called when the provider is disposed or recomputed.
    ///
    /// Use for cleaning up resources like timers, observers, or network requests
    /// that were set up during the provider's computation.
    ///
    /// - Parameter cleanup: Function called on disposal
    ///
    /// **Example: Resource Cleanup**
    /// ```swift
    /// @Provider
    /// func timerProvider(ref: ProviderRef) -> Timer {
    ///     let timer = Timer(...)
    ///     timer.start()
    ///
    ///     ref.onDispose {
    ///         timer.invalidate()  // Clean up the timer
    ///     }
    ///
    ///     return timer
    /// }
    /// ```
    func onDispose(_ cleanup: @escaping () -> Void)

    /// Registers a callback when all listeners stop watching this provider.
    ///
    /// Called when the last view or listener unsubscribes. Useful for pausing expensive
    /// operations when the provider is no longer needed.
    ///
    /// - Parameter callback: Function called when all listeners are removed
    ///
    /// **Example: Pause Background Operation**
    /// ```swift
    /// @Notifier
    /// class LocationNotifier extends AsyncNotifier<Location> {
    ///     var locationManager: LocationManager?
    ///
    ///     @override
    ///     Future<Location> build() async {
    ///         locationManager = LocationManager()
    ///
    ///         ref.onCancel(() {
    ///             print("No listeners, pausing location updates")
    ///             locationManager?.stopUpdating()
    ///         })
    ///
    ///         return await locationManager!.currentLocation
    ///     }
    /// }
    /// ```
    func onCancel(_ callback: @escaping () -> Void)

    /// Registers a callback when a canceled provider is watched again.
    ///
    /// Called when listeners return after `onCancel`. Pairs with `onCancel`
    /// to resume paused operations.
    ///
    /// - Parameter callback: Function called when listening resumes
    ///
    /// **Example: Resume Background Operation**
    /// ```swift
    /// ref.onResume {
    ///     print("Listener returned, resuming location updates")
    ///     locationManager?.startUpdating()
    /// }
    /// ```
    func onResume(_ callback: @escaping () -> Void)

    /// Registers a callback when the first listener is added to this provider.
    ///
    /// Useful for initializing shared resources that should only exist while needed.
    ///
    /// - Parameter callback: Function called when first listener is added
    func onAddListener(_ callback: @escaping () -> Void)

    /// Registers a callback when a listener is removed from this provider.
    ///
    /// Useful for tracking listener count or cleaning up when specific listeners leave.
    ///
    /// - Parameter callback: Function called when a listener is removed
    func onRemoveListener(_ callback: @escaping () -> Void)

    // MARK: - Lifecycle Control

    /// Prevents this provider from being automatically disposed when unused.
    ///
    /// By default, providers with `autoDispose: true` are removed from memory when
    /// no longer listened to. `keepAlive()` overrides this, keeping the provider in memory
    /// as long as the returned link exists.
    ///
    /// - Returns: A KeepAliveLink that, when closed, allows the provider to be disposed again
    ///
    /// **Example: Cache Important Data**
    /// ```swift
    /// @Provider
    /// func importantDataProvider(ref: ProviderRef) -> ImportantData {
    ///     let link = ref.keepAlive()  // Keep this provider alive
    ///     // link will automatically close when the provider is disposed
    ///
    ///     ref.onDispose {
    ///         link.close()  // Allow disposal
    ///     }
    ///
    ///     return fetchImportantData()
    /// }
    /// ```
    ///
    /// **Example: Manual Control**
    /// ```swift
    /// var cacheLink: KeepAliveLink?
    ///
    /// func enableDataCache() {
    ///     cacheLink = container.read(dataProvider.select((ref) => ref.keepAlive()))
    /// }
    ///
    /// func disableDataCache() {
    ///     cacheLink?.close()
    ///     cacheLink = nil
    /// }
    /// ```
    ///
    /// - Returns: A link that can be closed to allow automatic disposal
    @discardableResult
    func keepAlive() -> KeepAliveLink

    /// Forces this provider to recompute its value on the next access.
    ///
    /// Invalidates the cached value and triggers recomputation of this provider
    /// and any providers that depend on it. Useful for refresh operations or
    /// forcing updates after external data changes.
    ///
    /// - Note: Automatically called when watched providers change.
    ///
    /// **Example: Manual Refresh**
    /// ```swift
    /// @Notifier
    /// class UserNotifier extends AsyncNotifier<User> {
    ///     Future<User> refreshUser() async {
    ///         ref.invalidate()  // Force refresh on next access
    ///         return await build()
    ///     }
    /// }
    /// ```
    func invalidate()
}

// MARK: - KeepAliveLink

/// A handle to control the keep-alive status of a provider.
///
/// `KeepAliveLink` is returned by `ProviderRef.keepAlive()` and can be closed
/// to allow an `autoDispose` provider to be disposed when no longer needed.
///
/// **Lifecycle:**
/// - Created: When `ref.keepAlive()` is called
/// - Active: Prevents automatic disposal while held
/// - Closed: Calling `close()` allows disposal again
///
/// **Example: Conditional Caching**
/// ```swift
/// @Provider
/// func userCacheProvider(ref: ProviderRef) -> User {
///     let shouldCache = ref.read(cacheSettingProvider)
///
///     var link: KeepAliveLink? = nil
///     if shouldCache {
///         link = ref.keepAlive()
///     }
///
///     ref.onDispose {
///         link?.close()
///     }
///
///     return fetchUser()
/// }
/// ```
///
/// - Note: Closing an already-closed link is safe and has no effect.
public final class KeepAliveLink: Sendable {

    // MARK: - Properties

    /// The closure to call when this link is closed.
    private let _onClose: @MainActor () -> Void

    // MARK: - Initialization

    /// Initializes a KeepAliveLink with a close handler.
    ///
    /// - Parameter onClose: Called when `close()` is invoked
    ///
    /// - Note: This is typically created internally by the framework.
    init(onClose: @escaping @MainActor () -> Void) {
        self._onClose = onClose
    }

    // MARK: - Methods

    /// Closes this keep-alive link and allows the provider to be disposed if no longer needed.
    ///
    /// Safe to call multiple times. Subsequent calls have no effect.
    ///
    /// **Example:**
    /// ```swift
    /// let link = ref.keepAlive()
    /// // ... some time later ...
    /// link.close()  // Provider can now be disposed
    /// ```
    @MainActor
    public func close() {
        _onClose()
    }
}
