import Foundation
import Combine

// MARK: - Provider Family Overview

/// A "family" is a parameterized set of providers, one per unique argument.
///
/// Families solve the problem of creating dynamic providers based on runtime arguments.
/// Instead of manually creating a provider for each possible value, use a family to
/// automatically generate providers as needed.
///
/// **Example Problem (Without Families):**
/// ```swift
/// // Need provider for user 1
/// let user1Provider = Provider { ... fetch user 1 ... }
/// // Need provider for user 2
/// let user2Provider = Provider { ... fetch user 2 ... }
/// // Need provider for user 3
/// let user3Provider = Provider { ... fetch user 3 ... }
/// // etc... (manual for each user ID)
/// ```
///
/// **Solution (With Families):**
/// ```swift
/// let userProvider = Provider.family { (ref, userId: Int) in
///     return try await fetchUser(userId)
/// }
///
/// // Now automatically generates separate cached providers
/// userProvider(1)  // Cached provider for user 1
/// userProvider(2)  // Cached provider for user 2
/// userProvider(3)  // Cached provider for user 3
/// ```
///
/// **Key Benefits:**
/// - **Dynamic**: Create providers on-demand for any argument
/// - **Cached**: Each unique argument gets its own provider with independent cache
/// - **Efficient**: Only creates providers for arguments actually used
/// - **Type-safe**: Arguments must be Hashable and Sendable
/// - **Zero boilerplate**: No manual provider creation for each value

// MARK: - FamilyMemberID

/// A unique identifier for a specific member of a provider family.
///
/// Combines the family's unique ID with the specific argument to identify
/// a unique provider instance within the family.
struct FamilyMemberID: Hashable {
    /// The unique identifier of the provider family
    let familyID: UUID

    /// The argument used to generate this family member
    let argument: AnyHashable
}

// MARK: - Provider Family

/// Extension adding family support to synchronous Providers.
extension Provider {

    /// Creates a family of read-only providers parameterized by an argument.
    ///
    /// Use this to create a provider that generates different computed values
    /// based on a parameter. Each unique argument gets its own cached provider.
    ///
    /// **Key Characteristics:**
    /// - **Synchronous**: Values computed synchronously (no async/await)
    /// - **Parameterized**: Takes a Hashable & Sendable argument
    /// - **Cached**: Each argument's value is cached independently
    /// - **Type-safe**: Compiler enforces argument type safety
    /// - **Reactive**: Changes to dependencies trigger recomputation
    ///
    /// **Thread Safety:**
    /// Confined to the MainActor.
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - factory: Closure that creates a provider for the given argument
    /// - Returns: A function that takes an argument and returns a Provider
    ///
    /// **Example: User Profile by ID**
    /// ```swift
    /// let userProvider = Provider.family { (ref, userId: Int) in
    ///     let allUsers = ref.watch(allUsersProvider)
    ///     return allUsers.first { $0.id == userId }
    /// }
    ///
    /// // Usage in views
    /// @Watch(userProvider(123)) var user  // Unique provider for user 123
    /// @Watch(userProvider(456)) var other // Different provider for user 456
    /// ```
    ///
    /// **Example: Filtered Lists**
    /// ```swift
    /// let filteredUsersProvider = Provider.family { (ref, isActive: Bool) in
    ///     let allUsers = ref.watch(allUsersProvider)
    ///     return allUsers.filter { $0.isActive == isActive }
    /// }
    ///
    /// @Watch(filteredUsersProvider(true)) var activeUsers
    /// @Watch(filteredUsersProvider(false)) var inactiveUsers
    /// ```
    ///
    /// **Example: Computed Values**
    /// ```swift
    /// let userAgeGroupProvider = Provider.family { (ref, age: Int) in
    ///     switch age {
    ///     case 0..<18: return "Minor"
    ///     case 18..<65: return "Adult"
    ///     default: return "Senior"
    ///     }
    /// }
    ///
    /// @Watch(userAgeGroupProvider(25)) var ageGroup
    /// ```
    ///
    /// **Caching Behavior:**
    /// ```swift
    /// let userProvider = Provider.family { (ref, userId: Int) in
    ///     return fetchUser(userId)
    /// }
    ///
    /// // These are the SAME cached provider (same userId)
    /// let p1 = userProvider(123)
    /// let p2 = userProvider(123)
    /// // p1 and p2 share the same cache
    ///
    /// // These are DIFFERENT cached providers (different userIds)
    /// let p3 = userProvider(456)
    /// // p3 has independent cache from p1/p2
    /// ```
    ///
    /// - Important: Arguments must be Hashable and Sendable
    /// - Note: Each unique argument value gets a unique provider with independent state
    /// - Warning: Be careful with mutable arguments; they must have stable equality
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) -> T
    ) -> (Arg) -> Provider<T> {
        let familyID = UUID()
        return { arg in
            Provider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                factory(ref, arg)
            }
        }
    }
}

// MARK: - StateProvider Family

/// Extension adding family support to mutable StateProviders.
extension StateProvider {

    /// Creates a family of mutable state providers parameterized by an argument.
    ///
    /// Use this to create a family where each argument gets its own mutable state.
    /// This is useful for independent mutable state per item (form per user, settings per tab, etc.).
    ///
    /// **Key Characteristics:**
    /// - **Mutable**: Each member's state can be modified directly
    /// - **Parameterized**: Takes a Hashable & Sendable argument
    /// - **Independent**: Each argument has independent mutable state
    /// - **Type-safe**: Compiler enforces argument type safety
    /// - **Observable**: Changes trigger dependent updates
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - factory: Closure that creates the initial state for the given argument
    /// - Returns: A function that takes an argument and returns a StateProvider
    ///
    /// **Example: Form Per User**
    /// ```swift
    /// let userFormProvider = StateProvider.family { (ref, userId: Int) in
    ///     UserFormState(userId: userId)
    /// }
    ///
    /// // Each user gets independent form state
    /// @Watch(userFormProvider(123).notifier) var form123
    /// @Watch(userFormProvider(456).notifier) var form456
    ///
    /// form123.state.name = "John"
    /// form456.state.name = "Jane"
    /// // Changes are independent
    /// ```
    ///
    /// **Example: Settings Per Tab**
    /// ```swift
    /// let tabSettingsProvider = StateProvider.family { (ref, tabId: String) in
    ///     TabSettings(tabId: tabId)
    /// }
    ///
    /// @Watch(tabSettingsProvider("home").notifier) var homeSettings
    /// @Watch(tabSettingsProvider("profile").notifier) var profileSettings
    /// ```
    ///
    /// - Important: Arguments must be Hashable and Sendable
    /// - Note: Each unique argument gets independent mutable state
    /// - Warning: State mutations are not persisted; use appropriate storage if needed
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) -> T
    ) -> (Arg) -> StateProvider<T> {
        let familyID = UUID()
        return { arg in
            StateProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                factory(ref, arg)
            }
        }
    }
}

// MARK: - NotifierProvider Family

/// Extension adding family support to class-based NotifierProviders.
extension NotifierProvider {

    /// Creates a family of notifier-based providers parameterized by an argument.
    ///
    /// Use this to create a family of complex stateful providers where each argument
    /// gets its own notifier instance with independent state and methods.
    ///
    /// **Key Characteristics:**
    /// - **Class-based**: Each member has its own notifier instance
    /// - **Parameterized**: Takes a Hashable & Sendable argument
    /// - **Independent**: Each argument has independent state and notifier
    /// - **Stateful**: Can include methods and complex logic
    /// - **Observable**: Changes trigger dependent updates
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - factory: Closure that creates a notifier for the given argument
    /// - Returns: A function that takes an argument and returns a NotifierProvider
    ///
    /// **Example: User Manager Notifier**
    /// ```swift
    /// @riverpodNotifier
    /// final class UserManagerNotifier: Notifier<UserState> {
    ///     let userId: Int
    ///
    ///     init(userId: Int) {
    ///         self.userId = userId
    ///     }
    ///
    ///     override func build() -> UserState {
    ///         return UserState(userId: userId)
    ///     }
    ///
    ///     func updateName(_ name: String) {
    ///         update { $0.withName(name) }
    ///     }
    /// }
    ///
    /// let userManagerProvider = NotifierProvider.family { (userId: Int) in
    ///     UserManagerNotifier(userId: userId)
    /// }
    ///
    /// // Each user gets its own manager
    /// @Watch(userManagerProvider(123).notifier) var user123Manager
    /// @Watch(userManagerProvider(456).notifier) var user456Manager
    /// ```
    ///
    /// **Example: Document Editor**
    /// ```swift
    /// @riverpodNotifier
    /// final class DocumentNotifier: Notifier<Document> {
    ///     let documentId: String
    ///
    ///     init(documentId: String) {
    ///         self.documentId = documentId
    ///     }
    ///
    ///     override func build() -> Document {
    ///         return Document(id: documentId)
    ///     }
    ///
    ///     func addParagraph(_ text: String) {
    ///         update { $0.addParagraph(text) }
    ///     }
    /// }
    ///
    /// let docProvider = NotifierProvider.family { (docId: String) in
    ///     DocumentNotifier(documentId: docId)
    /// }
    /// ```
    ///
    /// - Important: Arguments must be Hashable and Sendable
    /// - Note: Each unique argument gets its own notifier instance and state
    /// - Warning: Notifier instances persist; don't store large objects if memory is a concern
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (Arg) -> N
    ) -> (Arg) -> NotifierProvider<N, T> {
        let familyID = UUID()
        return { arg in
            NotifierProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) {
                factory(arg)
            }
        }
    }
}

// MARK: - FutureProvider Family

/// Extension adding family support to asynchronous FutureProviders.
extension FutureProvider {

    /// Creates a family of async providers parameterized by an argument.
    ///
    /// Use this for one-shot async operations where each argument needs its own
    /// independent async operation and result caching.
    ///
    /// **Key Characteristics:**
    /// - **Async**: Each member runs an async operation
    /// - **One-shot**: Result is cached per argument
    /// - **Parameterized**: Takes a Hashable & Sendable argument
    /// - **Tracked**: Each argument's loading/error states tracked independently
    /// - **Cancellable**: Operations cancelled when provider is disposed
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - factory: Closure that performs the async operation for the given argument
    /// - Returns: A function that takes an argument and returns a FutureProvider
    ///
    /// **Example: Fetch User by ID**
    /// ```swift
    /// let userProvider = FutureProvider.family { (ref, userId: Int) async throws in
    ///     try await fetchUser(userId)
    /// }
    ///
    /// @Watch(userProvider(123)) var user123  // Fetches and caches user 123
    /// @Watch(userProvider(456)) var user456  // Separate fetch and cache for user 456
    /// ```
    ///
    /// **Example: API Requests with Arguments**
    /// ```swift
    /// let searchProvider = FutureProvider.family { (ref, query: String) async throws in
    ///     let results = try await api.search(query)
    ///     return results
    /// }
    ///
    /// @Watch(searchProvider("swift")) var swiftResults
    /// @Watch(searchProvider("kotlin")) var kotlinResults
    /// ```
    ///
    /// - Important: Arguments must be Hashable and Sendable
    /// - Note: Each unique argument gets its own async operation and cache
    /// - Warning: If dependencies change, the operation is cancelled and restarted
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) async throws -> T
    ) -> (Arg) -> FutureProvider<T> {
        let familyID = UUID()
        return { arg in
            FutureProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                try await factory(ref, arg)
            }
        }
    }
}

// MARK: - StreamProvider Family

/// Extension adding family support to continuous StreamProviders.
extension StreamProvider {

    /// Creates a family of stream providers parameterized by an argument.
    ///
    /// Use this for continuous streams where each argument needs its own independent
    /// stream subscription and cached values.
    ///
    /// **Key Characteristics:**
    /// - **Continuous**: Each member subscribes to a stream
    /// - **Parameterized**: Takes a Hashable & Sendable argument
    /// - **Independent**: Each argument has independent stream subscription
    /// - **Tracked**: Each argument's values and errors tracked independently
    /// - **Reactive**: Values update dependents as they arrive
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - factory: Closure that creates a Combine publisher for the given argument
    /// - Returns: A function that takes an argument and returns a StreamProvider
    ///
    /// **Example: Location Stream per User**
    /// ```swift
    /// let locationStreamProvider = StreamProvider.family { (ref, userId: Int) in
    ///     locationService.streamForUser(userId)
    ///         .eraseToAnyPublisher()
    /// }
    ///
    /// @Watch(locationStreamProvider(123)) var user123Location
    /// @Watch(locationStreamProvider(456)) var user456Location
    /// ```
    ///
    /// **Example: Data Stream with Filter**
    /// ```swift
    /// let filteredDataProvider = StreamProvider.family { (ref, category: String) in
    ///     dataStream
    ///         .filter { $0.category == category }
    ///         .eraseToAnyPublisher()
    /// }
    ///
    /// @Watch(filteredDataProvider("news")) var newsData
    /// @Watch(filteredDataProvider("sports")) var sportsData
    /// ```
    ///
    /// - Important: Arguments must be Hashable and Sendable
    /// - Note: Each unique argument gets its own stream subscription
    /// - Warning: Ensure streams complete or fail; incomplete streams prevent cleanup
    public static func family<Arg: Hashable & Sendable>(
        autoDispose: Bool = true,
        _ factory: @MainActor @escaping (ProviderRef, Arg) -> AnyPublisher<T, Error>
    ) -> (Arg) -> StreamProvider<T> {
        let familyID = UUID()
        return { arg in
            StreamProvider(
                id: FamilyMemberID(familyID: familyID, argument: AnyHashable(arg)),
                autoDispose: autoDispose
            ) { ref in
                factory(ref, arg)
            }
        }
    }
}
