import SwiftUI
import Observation
import StateKit

// MARK: - Watch Property Wrapper

/// A property wrapper for reactively watching a provider's value.
///
/// `Watch` establishes a reactive dependency on a provider. The view automatically
/// rebuilds whenever the watched provider's value changes. Use `Watch` when:
/// - The value affects what is rendered
/// - You need automatic updates
/// - The provider is a dependency of your view
/// - Changes should trigger view rebuilds
///
/// **Key Characteristics:**
/// - **Reactive**: View rebuilds automatically when provider changes
/// - **Dependency tracking**: Establishes provider dependency
/// - **Automatic cleanup**: Listeners removed when view is destroyed
/// - **Type-safe**: Compiler enforces provider type safety
/// - **Efficient**: Only rebuilds when actual value changes
///
/// **Thread Safety:**
/// Confined to the MainActor. Must be used in SwiftUI views.
///
/// **Lifecycle:**
/// 1. Created: Property wrapper instantiated
/// 2. Setup: First render registers as listener
/// 3. Updated: Provider changes trigger view rebuild
/// 4. Cleanup: View destroyed, listener automatically removed
///
/// **Example: Reactive UI State**
/// ```swift
/// struct CounterView: View {
///     @Watch(counterProvider) var count
///     @Watch(counterProvider.notifier) var controller
///
///     var body: some View {
///         VStack {
///             Text("Count: \\(count)")  // Rebuilds when count changes
///
///             Button("Increment") {
///                 controller.state += 1
///             }
///         }
///     }
/// }
/// ```
///
/// **Example: User Data**
/// ```swift
/// struct UserProfileView: View {
///     @Watch(userProvider) var user  // Rebuilds when user changes
///
///     var body: some View {
///         VStack {
///             Text(user.name)
///             Text(user.email)
///         }
///     }
/// }
/// ```
///
/// **Example: Async Data**
/// ```swift
/// struct DataView: View {
///     @Watch(dataProvider) var dataState
///
///     var body: some View {
///         switch dataState {
///         case .loading():
///             ProgressView()  // Shows while loading
///         case .data(let data):
///             List(data) { item in
///                 Text(item.name)
///             }
///         case .error(let error, _):
///             Text("Error: \\(error.localizedDescription)")
///         case .refreshing(let data):
///             List(data) { item in
///                 Text(item.name)
///             }
///         }
///     }
/// }
/// ```
///
/// **Example: Multiple Watches**
/// ```swift
/// struct DashboardView: View {
///     @Watch(currentUserProvider) var user
///     @Watch(userSettingsProvider) var settings
///     @Watch(notificationsProvider) var notifications
///
///     var body: some View {
///         VStack {
///             UserCard(user)                      // Rebuilds if user changes
///             SettingsPanel(settings)             // Rebuilds if settings change
///             NotificationBadge(notifications)    // Rebuilds if notifications change
///         }
///     }
/// }
/// ```
///
/// - Important: Must be used within a ProviderScope
/// - Note: Views WILL rebuild when Watch providers change
/// - Warning: For non-reactive access, use @Read instead
@MainActor
@propertyWrapper
public struct Watch<P: ProviderProtocol>: DynamicProperty {

    // MARK: - Properties

    /// The provider container from the SwiftUI environment
    @Environment(\.providerContainer) private var container

    /// The listener managing this watch's lifecycle
    ///
    /// Automatically registers/unregisters the view as a listener
    /// when the provider or container changes.
    @State private var listener = ProviderListener<P>()

    /// The provider being watched
    private let provider: P

    // MARK: - Initialization

    /// Creates a Watch property wrapper for a provider.
    ///
    /// - Parameter provider: The provider to watch reactively
    ///
    /// **Usage:**
    /// ```swift
    /// @Watch(userProvider) var user
    /// ```
    public init(_ provider: P) {
        self.provider = provider
    }

    // MARK: - Value Access

    /// The current value of the provider.
    ///
    /// Reading this value:
    /// - Returns the provider's current cached value
    /// - Establishes this view as a reactive listener
    /// - Triggers view rebuild when the value changes
    /// - Tracks this as a dependency of the view
    ///
    /// **Behavior:**
    /// - First access registers the view as a listener
    /// - Subsequent provider changes cause automatic view rebuild
    /// - Only rebuilds if actual value changes (not just provider recomputation)
    /// - Listener automatically removed when view is destroyed
    public var wrappedValue: P.State {
        container.watch(provider)
    }

    // MARK: - Update Hook

    /// Called by SwiftUI when the view needs to update listeners.
    ///
    /// This is called by the DynamicProperty protocol to allow the watch
    /// to register/unregister itself when the provider or container changes.
    nonisolated public func update() {
        MainActor.assumeIsolated {
            listener.setup(container: container, provider: provider)
        }
    }
}

// MARK: - ProviderListener

/// Internal helper managing the lifecycle of a provider listener in SwiftUI.
///
/// `ProviderListener` is responsible for:
/// - Registering the view as a listener when Watch is set up
/// - Handling provider or container changes
/// - Cleaning up listeners when the view is destroyed
/// - Avoiding duplicate listener registrations
///
/// **Thread Safety:**
/// Confined to the MainActor.
///
/// **Lifecycle:**
/// 1. Created: SwiftUI creates listener when Watch is first used
/// 2. Setup: First render calls setup() to register listener
/// 3. Updates: Provider/container changes trigger cleanup and re-setup
/// 4. Deinit: View destroyed, listener automatically unregistered
///
/// - Note: This is an internal implementation detail of Watch. Do not use directly.
@MainActor
final class ProviderListener<P: ProviderProtocol> {

    // MARK: - Properties

    /// The container this listener is registered with
    private var container: ProviderContainer?

    /// The provider this listener is watching
    private var provider: P?

    // MARK: - Initialization

    /// Creates a new provider listener (initially inactive).
    init() {}

    // MARK: - Setup

    /// Sets up or updates the listener for a provider in a container.
    ///
    /// - Parameters:
    ///   - container: The container managing the provider
    ///   - provider: The provider to listen to
    ///
    /// **Behavior:**
    /// - If already watching the same provider in the same container, does nothing
    /// - Otherwise, cleans up the old listener and registers a new one
    /// - Ensures each view only registers once per provider/container pair
    func setup(container: ProviderContainer, provider: P) {
        // Avoid duplicate registrations
        if self.container === container && self.provider == provider {
            return
        }

        // Cleanup previous listener
        cleanup()

        // Register new listener
        self.container = container
        self.provider = provider
        _ = container.addListener(for: provider)
    }

    // MARK: - Cleanup

    /// Removes the listener from its container.
    ///
    /// Called when:
    /// - Provider or container changes
    /// - View is destroyed (via deinit)
    private func cleanup() {
        if let container = container, let provider = provider {
            container.removeListener(for: provider)
        }
    }

    /// Automatically cleans up when the listener is destroyed.
    ///
    /// Ensures the view is unregistered as a listener when the Watch
    /// property wrapper is removed from the view.
    deinit {
        if let container = container, let provider = provider {
            Task { @MainActor in
                container.removeListener(for: provider)
            }
        }
    }
}

// MARK: - Hook Bridge

/// Accesses a Riverpod provider from within a StateKit atom or hook.
///
/// `useRiverpod` bridges the gap between Riverpods and StateKit's atom system,
/// allowing you to use Riverpod providers within StateKit hooks. This enables
/// sharing state and logic between both reactive systems.
///
/// **Thread Safety:**
/// Confined to the MainActor. Must be called from within a hook context.
///
/// **Lifecycle:**
/// - Registers the hook as a listener when called
/// - Watches provider changes and notifies on updates
/// - Automatically cleans up listener when hook is destroyed
///
/// **Use Cases:**
/// - Using Riverpod providers in atom-based code
/// - Sharing complex provider logic with atoms
/// - Accessing async providers from hooks
/// - Bridging feature boundaries between systems
///
/// **Example: Use Provider in Atom**
/// ```swift
/// @Atom
/// func userGreetingAtom(context: SKAtomContext) -> String {
///     let user = useRiverpod(userProvider)  // Bridge to riverpod
///     return "Hello, \\(user.name)"
/// }
/// ```
///
/// **Example: Watch Async Provider in Hook**
/// ```swift
/// @Atom
/// func processedDataAtom(context: SKAtomContext) -> ProcessedData? {
///     switch useRiverpod(dataProvider) {
///     case .data(let data):
///         return processData(data)
///     case .loading(), .refreshing:
///         return nil
///     case .error:
///         return nil
///     }
/// }
/// ```
///
/// **Example: Combine Multiple Providers**
/// ```swift
/// @Atom
/// func combinedAtom(context: SKAtomContext) -> CombinedValue {
///     let user = useRiverpod(userProvider)
///     let settings = useRiverpod(settingsProvider)
///     return CombinedValue(user: user, settings: settings)
/// }
/// ```
///
/// - Parameter provider: The Riverpod provider to access
/// - Returns: The current value of the provider
/// - Important: Must be called from within a hook/atom context
/// - Note: Automatically manages listener lifecycle
@MainActor
public func useRiverpod<P: ProviderProtocol>(_ provider: P) -> P.State {
    let container = useEnvironment(\.providerContainer)

    // Register listener and clean up when hook is destroyed
    useEffect(updateStrategy: .preserved(by: ProviderID(provider))) {
        _ = container.addListener(for: provider)
        return { container.removeListener(for: provider) }
    }

    return container.watch(provider)
}

// MARK: - ProviderContainer Environment Key

/// The SwiftUI environment key for accessing the ProviderContainer.
///
/// This key is used internally to inject the ProviderContainer into the
/// environment so that @Watch and @Read property wrappers can access it.
private struct ProviderContainerKey: EnvironmentKey {

    /// The default container to use if no ProviderScope is present.
    ///
    /// Returns the shared global container, allowing providers to work
    /// even without an explicit ProviderScope (with a warning in debug builds).
    static var defaultValue: ProviderContainer {
        MainActor.assumeIsolated { .shared }
    }
}

// MARK: - EnvironmentValues Extension

/// Extension adding provider container access to SwiftUI's EnvironmentValues.
public extension EnvironmentValues {

    /// Accesses the ProviderContainer from the SwiftUI environment.
    ///
    /// This environment variable is set by `ProviderScope` and provides
    /// the container for all `@Watch` and `@Read` property wrappers
    /// in the view hierarchy.
    ///
    /// **Getting:**
    /// - Returns the ProviderContainer from the nearest ProviderScope
    /// - Falls back to the shared global container if no scope is present
    ///
    /// **Setting:**
    /// - Changes the container for this view and descendants
    /// - Useful for programmatically changing containers
    ///
    /// **Usage:**
    /// ```swift
    /// struct MyView: View {
    ///     @Environment(\.providerContainer) var container
    ///
    ///     var body: some View {
    ///         // container is now available
    ///     }
    /// }
    /// ```
    ///
    /// **Internal Usage (for library developers):**
    /// ```swift
    /// @Environment(\.providerContainer) private var container
    /// let value = container.read(someProvider)
    /// ```
    ///
    /// - Note: Usually accessed internally by @Watch and @Read
    /// - Warning: Avoid direct container access; use @Watch/@Read instead
    var providerContainer: ProviderContainer {
        get { self[ProviderContainerKey.self] }
        set { self[ProviderContainerKey.self] = newValue }
    }
}
