import SwiftUI
import Observation

// MARK: - ProviderScope

/// A SwiftUI view that provides a ProviderContainer to its content and descendants.
///
/// `ProviderScope` is the main entry point for using Riverpods providers in SwiftUI.
/// It establishes the provider context for all views in its subtree, enabling:
/// - `@Watch` property wrappers to work
/// - `@Read` property wrappers to function
/// - Provider overrides for testing and debugging
/// - Isolated provider containers for scoped state management
///
/// **Key Features:**
/// - **Scoped**: Providers are scoped to the ProviderScope and its descendants
/// - **Testable**: Can provide overrides for specific providers in tests
/// - **Composable**: Can nest multiple ProviderScopes for different scopes
/// - **Automatic**: Uses shared container by default, custom container when needed
/// - **Type-safe**: Generic over the content view type
///
/// **Thread Safety:**
/// Must be used in a SwiftUI view hierarchy. The ProviderContainer is confined to
/// the MainActor and all provider access happens on the main thread.
///
/// **Lifecycle:**
/// - Created: ProviderScope added to view hierarchy
/// - Active: Container available to all descendants via environment
/// - Cleanup: When ProviderScope is removed, listeners are cleaned up
///
/// **Use Cases:**
/// 1. **App Root**: Wrap your entire app for shared provider state
/// 2. **Feature Scope**: Wrap specific features for isolated state
/// 3. **Testing**: Provide overrides for deterministic test state
/// 4. **Debugging**: Use overrides to test error states
///
/// **Example: App Root**
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ProviderScope {
///                 ContentView()
///             }
///         }
///     }
/// }
/// ```
///
/// **Example: Feature Scope with Overrides (Testing)**
/// ```swift
/// struct FeatureViewPreview: PreviewProvider {
///     static var previews: some View {
///         let mockUser = User(id: 1, name: "Test User")
///         let override = userProvider.overrideWith(mockUser)
///
///         ProviderScope(overrides: [override]) {
///             FeatureView()
///         }
///     }
/// }
/// ```
///
/// **Example: Nested Scopes**
/// ```swift
/// ProviderScope {  // Global scope with shared container
///     VStack {
///         GlobalView()
///
///         ProviderScope(overrides: [...]) {  // Isolated scope for feature
///             FeatureView()
///         }
///     }
/// }
/// ```
///
/// **Example: Custom Container**
/// ```swift
/// let testContainer = ProviderContainer()
///
/// ProviderScope(container: testContainer) {
///     TestView()
/// }
/// ```
///
/// **When to Use Overrides:**
/// - Testing: Replace providers with mock/test data
/// - Previews: Provide sample data for SwiftUI previews
/// - Debugging: Test error states or edge cases
/// - A/B Testing: Swap implementations at runtime
///
/// **Override Pattern:**
/// ```swift
/// @Provider
/// func userProvider(ref: ProviderRef) -> User {
///     return try await fetchUser()
/// }
///
/// // In tests or previews
/// let testUser = User(id: 1, name: "Test")
/// let override = userProvider.overrideWith(testUser)
///
/// ProviderScope(overrides: [override]) {
///     ContentView()
/// }
/// ```
///
/// - Important: ProviderScope must wrap views that use @Watch and @Read
/// - Note: Without a ProviderScope, providers cannot be accessed
/// - Warning: Each ProviderScope creates its own listener tracking; nest carefully
public struct ProviderScope<Content: View>: View {

    // MARK: - Properties

    /// The provider container managing all providers in this scope
    let container: ProviderContainer

    /// The view content to display within this scope
    let content: Content

    // MARK: - Initialization

    /// Creates a ProviderScope with optional provider overrides.
    ///
    /// Use this initializer for testing, previews, or debugging where you need
    /// to override specific providers with test/mock values.
    ///
    /// **Behavior:**
    /// - If no overrides provided: Uses the shared global container
    /// - If overrides provided: Creates a new isolated container with those overrides
    ///
    /// - Parameters:
    ///   - overrides: An array of provider overrides to apply (default: empty)
    ///   - content: The view content to display in this scope
    ///
    /// **Example: Without Overrides (Use Shared Container)**
    /// ```swift
    /// ProviderScope {
    ///     ContentView()  // Uses shared global container
    /// }
    /// ```
    ///
    /// **Example: With Test Overrides**
    /// ```swift
    /// ProviderScope(overrides: [
    ///     userProvider.overrideWith(testUser),
    ///     settingsProvider.overrideWith(testSettings)
    /// ]) {
    ///     SettingsView()
    /// }
    /// ```
    ///
    /// **Example: Provider Override Pattern**
    /// ```swift
    /// @Provider
    /// func apiProvider(ref: ProviderRef) -> APIClient {
    ///     return RealAPIClient()
    /// }
    ///
    /// // In tests
    /// let mockAPI = MockAPIClient()
    /// let override = apiProvider.overrideWith(mockAPI)
    ///
    /// ProviderScope(overrides: [override]) {
    ///     MyView()
    /// }
    /// ```
    ///
    /// - Note: Creating a new container has memory cost; reuse shared container when possible
    public init(overrides: [ProviderOverride] = [], @ViewBuilder content: () -> Content) {
        if overrides.isEmpty {
            self.container = .shared
        } else {
            self.container = ProviderContainer(overrides: overrides)
        }
        self.content = content()
    }

    /// Creates a ProviderScope with a specific container.
    ///
    /// Use this when you need fine-grained control over the container,
    /// or when reusing a previously created container.
    ///
    /// - Parameters:
    ///   - container: The ProviderContainer to use for this scope
    ///   - content: The view content to display in this scope
    ///
    /// **Example: Reuse Container Across Scopes**
    /// ```swift
    /// let sharedTestContainer = ProviderContainer(overrides: [...])
    ///
    /// ProviderScope(container: sharedTestContainer) {
    ///     View1()
    /// }
    ///
    /// ProviderScope(container: sharedTestContainer) {
    ///     View2()
    /// }
    /// ```
    ///
    /// **Example: Dynamic Container**
    /// ```swift
    /// @State var container = ProviderContainer()
    ///
    /// ProviderScope(container: container) {
    ///     ContentView()
    /// }
    /// ```
    public init(container: ProviderContainer, @ViewBuilder content: () -> Content) {
        self.container = container
        self.content = content()
    }

    // MARK: - Body

    /// Renders the content with the provider container in the environment.
    ///
    /// Injects the ProviderContainer into the SwiftUI environment so that
    /// child views can access it via `@Watch` and `@Read` property wrappers.
    public var body: some View {
        content
            .environment(\.providerContainer, container)
    }
}
