import Foundation

/// A unique identifier for each Provider instance.
///
/// `ProviderID` serves as a unique key to identify and cache provider states across the application.
/// It combines the provider's instance hash with an optional debug name for better diagnostics.
///
/// **Thread Safety:**
/// ProviderID is thread-safe (@unchecked Sendable) and can be safely shared across threads.
/// It's marked as Sendable because the identifier and debugName are immutable after initialization.
///
/// **Example:**
/// ```swift
/// @Provider
/// func userNameProvider(ref: ProviderRef) -> String {
///     let user = ref.watch(currentUserProvider)
///     return user.name
/// }
///
/// // The framework automatically creates a ProviderID for userNameProvider
/// let providerId = ProviderID(userNameProvider)
/// ```
///
/// - Note: Typically created automatically by the framework. Manual creation is rarely needed.
public struct ProviderID: Hashable, @unchecked Sendable, CustomStringConvertible {

    // MARK: - Properties

    /// The unique hash or identifier that distinguishes this provider from others
    private let identifier: AnyHashable

    /// Optional debug name for improved readability in logs and debugging sessions
    private let debugName: String?

    // MARK: - Initializers

    /// Creates a ProviderID from a provider instance.
    ///
    /// This initializer automatically extracts the provider's unique identity and debug name.
    ///
    /// - Parameter provider: The provider instance to create an ID for
    ///
    /// **Example:**
    /// ```swift
    /// let id = ProviderID(myProvider)
    /// ```
    public init<P: ProviderProtocol>(_ provider: P) {
        self.identifier = AnyHashable(provider)
        self.debugName = provider.name
    }

    /// Creates a ProviderID with explicit identifier and optional name.
    ///
    /// Use this initializer when you need precise control over the provider's identity,
    /// such as for testing or manual provider registration.
    ///
    /// - Parameters:
    ///   - identifier: A unique hashable value that identifies this provider
    ///   - name: Optional debug name for better diagnostics (e.g., "userProvider", "postsFamilyProvider")
    ///
    /// **Example:**
    /// ```swift
    /// let customId = ProviderID(identifier: UUID(), name: "customProvider")
    /// ```
    public init(identifier: AnyHashable, name: String? = nil) {
        self.identifier = identifier
        self.debugName = name
    }

    // MARK: - CustomStringConvertible

    /// A human-readable string representation of this provider ID.
    ///
    /// Returns the debug name if available, otherwise returns a generic description
    /// including the identifier hash.
    ///
    /// **Example Output:**
    /// - With debug name: "userProvider"
    /// - Without debug name: "Provider(12345-abc)"
    public var description: String {
        debugName ?? "Provider(\(identifier))"
    }
}
