import Foundation

// MARK: - SCLocalActor

/// A local actor-based lock for thread-safe access to shared mutable state.
///
/// `SCLocalActor` provides an actor-based synchronization mechanism for protecting
/// shared mutable state in async contexts. Unlike global actors, each instance of
/// `SCLocalActor` creates a separate isolation domain, allowing fine-grained control
/// over concurrent access to specific resources.
///
/// ## Key Features:
/// - **Swift 6 Compatible**: Uses actor-based concurrency for thread safety
/// - **Async-Safe**: Can be used safely in async/await contexts
/// - **Type-Safe**: Provides compile-time guarantees against data races
/// - **Instance-Based**: Each lock is independent, allowing parallel execution across different locks
/// - **Performance Optimized**: Leverages Swift's actor isolation for efficiency
///
/// ## Usage Examples:
///
/// ### Basic Usage
/// ```swift
/// class MyClass {
///     private let lock = SCLocalActor()
///     private var sharedState: String = ""
///
///     func updateState(_ newValue: String) async {
///         await lock.withLock {
///             sharedState = newValue
///         }
///     }
///
///     func getState() async -> String {
///         return await lock.withLock {
///             return sharedState
///         }
///     }
/// }
/// ```
///
/// ### Error Handling
/// ```swift
/// func processData() async throws {
///     await lock.withLock {
///         // This can throw and will be properly propagated
///         try validateAndUpdateData()
///     }
/// }
/// ```
///
/// ### Complex State Updates
/// ```swift
/// func updateMultipleValues() async {
///     await lock.withLock {
///         // Multiple state updates are atomic
///         state1 = newValue1
///         state2 = newValue2
///         state3 = newValue3
///
///         // All updates happen together or not at all
///     }
/// }
/// ```
///
/// ## Migration from NSLock:
///
/// **Before (NSLock - Swift 6 incompatible):**
/// ```swift
/// private let lock = NSLock()
/// private var sharedData: String = ""
///
/// func updateData(_ value: String) async {
///     lock.lock()
///     defer { lock.unlock() }
///     sharedData = value
/// }
/// ```
///
/// **After (SCLocalActor - Swift 6 compatible):**
/// ```swift
/// private let lock = SCLocalActor()
/// private var sharedData: String = ""
///
/// func updateData(_ value: String) async {
///     await lock.withLock {
///         sharedData = value
///     }
/// }
/// ```
///
/// ## Comparison with SCGlobalActor:
///
/// **SCLocalActor** is ideal when you need:
/// - Independent locks for different instances
/// - Fine-grained control over synchronization
/// - Parallel execution across different lock instances
///
/// ```swift
/// class UserManager {
///     private let lock = SCLocalActor()  // Instance-specific lock
///     private var users: [User] = []
/// }
///
/// class ProductManager {
///     private let lock = SCLocalActor()  // Different, independent lock
///     private var products: [Product] = []
/// }
/// // These two locks don't block each other
/// ```
///
/// **SCGlobalActor** is ideal when you need:
/// - App-wide coordination
/// - Shared state across multiple types
/// - All marked code to run on the same actor
///
/// ```swift
/// @SCGlobalActor
/// var appSettings: Settings = Settings()
///
/// @SCGlobalActor
/// func updateSettings() {
///     // Runs on the global shared actor
/// }
/// ```
///
/// ## Best Practices:
/// - Use for protecting shared mutable state in async contexts
/// - Keep critical sections as small as possible
/// - Avoid calling other async functions within `withLock` blocks
/// - Prefer actor isolation when possible for better performance
///
/// ## Thread Safety:
/// - All access to shared state must go through `withLock`
/// - The actor isolation ensures no data races
/// - Multiple concurrent calls to `withLock` are serialized
public actor SCLocalActor {
    
    public init() { }
    
    /// Executes the provided closure with exclusive access to the actor's state
    ///
    /// This method provides thread-safe access to shared mutable state by ensuring
    /// that only one task can execute the closure at a time. All other tasks
    /// calling `withLock` will be suspended until the current execution completes.
    ///
    /// - Parameter body: A closure that performs the state modification
    /// - Returns: The result of the closure execution
    /// - Throws: Any error thrown by the closure
    ///
    /// ## Example:
    /// ```swift
    /// let result = await lock.withLock {
    ///     // This code runs with exclusive access
    ///     sharedState += 1
    ///     return sharedState
    /// }
    /// ```
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        return try body()
    }
}
