import SwiftUI

// MARK: - Read Property Wrapper

/// A property wrapper for reading a provider's value without reactive tracking.
///
/// `Read` provides one-time, non-reactive access to a provider's current value.
/// Use `Read` when you need a value but don't want the view to automatically rebuild
/// if that provider changes. This is useful for:
/// - Configuration values that don't change
/// - Values read only at specific moments (button taps, navigation)
/// - Accessing dependent values conditionally
/// - Reducing unnecessary view rebuilds
///
/// **Key Characteristics:**
/// - **Non-reactive**: View does NOT rebuild when the provider changes
/// - **One-time read**: Returns current value at time of access
/// - **Efficient**: Avoids listener overhead for non-reactive access
/// - **Conditional**: Safe for conditional access patterns
/// - **Type-safe**: Compiler enforces provider type safety
///
/// **Thread Safety:**
/// Confined to the MainActor. Must be used in SwiftUI views.
///
/// **Comparison: Read vs Watch**
/// | Aspect | Read | Watch |
/// |--------|------|-------|
/// | Reactive | ❌ No | ✅ Yes |
/// | Rebuilds on change | ❌ No | ✅ Yes |
/// | Listener overhead | ❌ No | ✅ Yes |
/// | Use for | Config, actions | UI state, derived values |
/// | Performance | Better | Slightly more overhead |
///
/// **When to Use Read:**
/// - Configuration values (settings, feature flags)
/// - Values accessed conditionally
/// - One-off value reads (in button handlers)
/// - Temporary state in callbacks
/// - Avoiding unnecessary rebuilds
///
/// **When to Use Watch:**
/// - UI state that affects rendering
/// - Derived values used in body
/// - Data displayed to user
/// - State that should update view
///
/// **Example: Configuration Values**
/// ```swift
/// struct SettingsView: View {
///     @Read(apiBaseURLProvider) var apiURL
///     @Read(isDebugModeProvider) var isDebugMode
///
///     var body: some View {
///         VStack {
///             Text("API: \\(apiURL)")  // Doesn't rebuild if URL changes
///             if isDebugMode {
///                 DebugPanel()  // Doesn't rebuild if debug mode changes
///             }
///         }
///     }
/// }
/// ```
///
/// **Example: Reading in Actions**
/// ```swift
/// struct ActionView: View {
///     @Read(userProvider) var currentUser
///
///     var body: some View {
///         Button("Log Out") {
///             // Read user only when button tapped
///             analytics.logOut(userId: currentUser.id)
///             logout()
///         }
///     }
/// }
/// ```
///
/// **Example: Conditional Dependencies**
/// ```swift
/// struct ConditionalView: View {
///     @Watch(userTypeProvider) var userType  // This needs to be reactive
///     @Read(adminSettingsProvider) var adminSettings  // Not reactive
///
///     var body: some View {
///         if userType == .admin {
///             AdminPanel(settings: adminSettings)  // adminSettings doesn't need reactivity
///         } else {
///             UserPanel()
///         }
///     }
/// }
/// ```
///
/// **Example: Performance Optimization**
/// ```swift
/// struct ListItemView: View {
///     @Read(configProvider) var config  // Read config once
///     @Watch(itemProvider) var item       // Watch item for changes
///
///     var body: some View {
///         HStack {
///             Text(item.name)
///             if config.showDetails {  // Config doesn't rebuild view
///                 Text(item.details)
///             }
///         }
///     }
/// }
/// ```
///
/// - Important: Must be used within a ProviderScope
/// - Note: Views do NOT rebuild when Read providers change
/// - Warning: If you need reactivity, use @Watch instead
@MainActor
@propertyWrapper
public struct Read<P: ProviderProtocol>: DynamicProperty {

    // MARK: - Properties

    /// The provider container from the SwiftUI environment
    ///
    /// Automatically provided by ProviderScope via environment injection.
    @Environment(\.providerContainer) private var container

    /// The provider being read
    private let provider: P

    // MARK: - Initialization

    /// Creates a Read property wrapper for a provider.
    ///
    /// - Parameter provider: The provider whose value to read
    ///
    /// **Usage:**
    /// ```swift
    /// @Read(configProvider) var config
    /// ```
    public init(_ provider: P) {
        self.provider = provider
    }

    // MARK: - Value Access

    /// The current value of the provider.
    ///
    /// Reading this value reads from the container but does NOT establish
    /// a reactive dependency. The view will not rebuild if this provider changes.
    ///
    /// **Behavior:**
    /// - Returns the current cached value
    /// - Does not register the view as a listener
    /// - Multiple accesses return the same value (within the same render)
    /// - No automatic rebuilds on provider changes
    ///
    /// **Example:**
    /// ```swift
    /// let currentConfig = wrappedValue
    /// // config is now read, view will not rebuild if it changes
    /// ```
    public var wrappedValue: P.State {
        container.read(provider)
    }
}
