import Foundation

// MARK: - Notifier Composition Helpers

/// A protocol for notifiers that can be composed together.
///
/// Composable notifiers provide a standard way to combine multiple notifiers
/// into a single parent notifier, similar to reducer composition in TCA.
///
/// **Composition Pattern:**
/// ```swift
/// // Child notifier
/// class AuthNotifier: Notifier<AuthState>, ComposableNotifier {
///     typealias Action = AuthAction
///     override func build() -> AuthState { ... }
///     func reduce(state: inout AuthState, action: AuthAction) { ... }
/// }
///
/// // Parent notifier composing multiple children
/// class AppNotifier: Notifier<AppState> {
///     override func build() -> AppState {
///         return AppState(auth: AuthState(), ui: UIState())
///     }
///
///     func handleAuthAction(_ action: AuthAction) {
///         var authState = state.auth
///         ref.watch(authNotifier).reduce(state: &authState, action: action)
///         state.auth = authState
///     }
/// }
/// ```
///
/// - Important: When composing notifiers, ensure parent state is properly updated
/// - Tip: Use `reduce(state:action:)` pattern for predictable state mutations
/// - Note: Keep composed notifiers focused on their domain
public protocol ComposableNotifier: AnyObject {
    associatedtype Action
    associatedtype State: Sendable

    /// Reduces state based on an action.
    ///
    /// This method encapsulates state mutation logic, making it composable
    /// and predictable. Parent notifiers can call this to update child state.
    ///
    /// - Parameters:
    ///   - state: The state to mutate (passed as inout)
    ///   - action: The action triggering the state change
    func reduce(state: inout State, action: Action)
}

// MARK: - State Composition Helpers

/// Provides utilities for composing related state values.
///
/// Use these helpers when building composite state structures that combine
/// multiple substates from different domains or notifiers.
///
/// **Composition Examples:**
/// ```swift
/// // Combining substates
/// let appState = StateComposer()
///     .add(\.auth, AuthState())
///     .add(\.ui, UIState())
///     .add(\.data, DataState())
///     .build()
/// ```
public struct StateComposer<Root: Sendable> {
    private let root: Root

    /// Initializes a state composer with a root state.
    ///
    /// - Parameter root: The root state to compose around
    public init(_ root: Root) {
        self.root = root
    }

    /// Updates a property within the composed state.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the property
    ///   - value: The new value for that property
    /// - Returns: Self for chaining
    public func set<Value: Sendable>(_ keyPath: WritableKeyPath<Root, Value>, to value: Value) -> Self {
        var copy = root
        copy[keyPath: keyPath] = value
        return StateComposer(copy)
    }

    /// Retrieves the composed state value.
    public func build() -> Root {
        root
    }
}

// MARK: - Provider Composition Extensions

extension Provider {
    /// Composes multiple providers into a single derived value.
    ///
    /// Useful for creating computed states that depend on multiple providers,
    /// similar to selectors in Redux or derived atoms in Jotai.
    ///
    /// **Example:**
    /// ```swift
    /// let userWithPosts = Provider.compose(userProvider, postsProvider) { user, posts in
    ///     UserWithPosts(user: user, posts: posts)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - p1: First provider
    ///   - p2: Second provider
    ///   - transform: Closure to combine values
    /// - Returns: A provider returning the composed value
    public static func compose<P1: ProviderProtocol, P2: ProviderProtocol, Result: Sendable>(
        _ p1: P1,
        _ p2: P2,
        transform: @escaping (P1.State, P2.State) -> Result
    ) -> Provider<Result> {
        Provider { ref in
            let value1 = ref.watch(p1)
            let value2 = ref.watch(p2)
            return transform(value1, value2)
        }
    }

    /// Composes three providers into a single derived value.
    public static func compose<
        P1: ProviderProtocol,
        P2: ProviderProtocol,
        P3: ProviderProtocol,
        Result: Sendable
    >(
        _ p1: P1,
        _ p2: P2,
        _ p3: P3,
        transform: @escaping (P1.State, P2.State, P3.State) -> Result
    ) -> Provider<Result> {
        Provider { ref in
            let value1 = ref.watch(p1)
            let value2 = ref.watch(p2)
            let value3 = ref.watch(p3)
            return transform(value1, value2, value3)
        }
    }

    /// Composes four providers into a single derived value.
    public static func compose<
        P1: ProviderProtocol,
        P2: ProviderProtocol,
        P3: ProviderProtocol,
        P4: ProviderProtocol,
        Result: Sendable
    >(
        _ p1: P1,
        _ p2: P2,
        _ p3: P3,
        _ p4: P4,
        transform: @escaping (P1.State, P2.State, P3.State, P4.State) -> Result
    ) -> Provider<Result> {
        Provider { ref in
            let value1 = ref.watch(p1)
            let value2 = ref.watch(p2)
            let value3 = ref.watch(p3)
            let value4 = ref.watch(p4)
            return transform(value1, value2, value3, value4)
        }
    }

    /// Composes five providers into a single derived value.
    public static func compose<
        P1: ProviderProtocol,
        P2: ProviderProtocol,
        P3: ProviderProtocol,
        P4: ProviderProtocol,
        P5: ProviderProtocol,
        Result: Sendable
    >(
        _ p1: P1,
        _ p2: P2,
        _ p3: P3,
        _ p4: P4,
        _ p5: P5,
        transform: @escaping (P1.State, P2.State, P3.State, P4.State, P5.State) -> Result
    ) -> Provider<Result> {
        Provider { ref in
            let value1 = ref.watch(p1)
            let value2 = ref.watch(p2)
            let value3 = ref.watch(p3)
            let value4 = ref.watch(p4)
            let value5 = ref.watch(p5)
            return transform(value1, value2, value3, value4, value5)
        }
    }
}

// MARK: - State Mutation Helpers

/// Utilities for safely mutating state in notifiers.
///
/// These helpers encapsulate common patterns for state updates, ensuring
/// consistency across your application.
public struct StateMutationHelper {
    /// Safely updates a property in a state value.
    ///
    /// - Parameters:
    ///   - state: The state to update (passed as inout)
    ///   - keyPath: The key path to the property
    ///   - transform: Closure to transform the value
    ///
    /// **Example:**
    /// ```swift
    /// var state = AppState()
    /// StateMutationHelper.update(&state, \.user.name) { $0 = "New Name" }
    /// ```
    public static func update<Root: Sendable, Value: Sendable>(
        _ state: inout Root,
        _ keyPath: WritableKeyPath<Root, Value>,
        _ transform: (inout Value) -> Void
    ) {
        transform(&state[keyPath: keyPath])
    }

    /// Conditionally updates a property based on a predicate.
    ///
    /// - Parameters:
    ///   - state: The state to update (passed as inout)
    ///   - keyPath: The key path to the property
    ///   - predicate: Condition for the update
    ///   - transform: Closure to transform the value
    ///
    /// **Example:**
    /// ```swift
    /// var state = AppState()
    /// StateMutationHelper.updateIf(&state, \.isLoading, when: { !$0 }) { $0 = true }
    /// ```
    public static func updateIf<Root: Sendable, Value: Sendable>(
        _ state: inout Root,
        _ keyPath: WritableKeyPath<Root, Value>,
        when predicate: (Value) -> Bool,
        _ transform: (inout Value) -> Void
    ) {
        let value = state[keyPath: keyPath]
        if predicate(value) {
            transform(&state[keyPath: keyPath])
        }
    }

    /// Updates multiple properties at once.
    ///
    /// - Parameter state: The state to update (passed as inout)
    /// - Parameter updates: Closure performing multiple updates
    ///
    /// **Example:**
    /// ```swift
    /// var state = AppState()
    /// StateMutationHelper.batch(&state) { state in
    ///     state.isLoading = false
    ///     state.error = nil
    ///     state.data = newData
    /// }
    /// ```
    public static func batch<Root: Sendable>(
        _ state: inout Root,
        _ updates: (inout Root) -> Void
    ) {
        updates(&state)
    }
}

// MARK: - Scope Composition

/// Manages composition of multiple state scopes into a single logical scope.
///
/// Use this when you have multiple notifiers managing different aspects
/// of your application and need to coordinate them.
///
/// **Scope Composition Pattern:**
/// ```swift
/// class AppNotifier: Notifier<AppState> {
///     let authScope = AuthScope()
///     let uiScope = UIScope()
///     let dataScope = DataScope()
///
///     override func build() -> AppState {
///         AppState(
///             auth: authScope.state,
///             ui: uiScope.state,
///             data: dataScope.state
///         )
///     }
/// }
/// ```
public protocol ScopeComposable {
    associatedtype State: Sendable

    /// The current state managed by this scope.
    var state: State { get }

    /// Updates the state within this scope.
    ///
    /// - Parameter transform: Closure to transform the state
    func update(_ transform: (inout State) -> Void)
}

// MARK: - Action Routing

/// Routes actions from a parent notifier to multiple child notifiers.
///
/// Similar to reducer composition in TCA, this allows hierarchical action handling.
///
/// **Action Routing Pattern:**
/// ```swift
/// enum AppAction {
///     case auth(AuthAction)
///     case ui(UIAction)
///     case data(DataAction)
/// }
///
/// class AppNotifier: Notifier<AppState> {
///     func handleAction(_ action: AppAction) {
///         switch action {
///         case .auth(let authAction):
///             handleAuthAction(authAction)
///         case .ui(let uiAction):
///             handleUIAction(uiAction)
///         case .data(let dataAction):
///             handleDataAction(dataAction)
///         }
///     }
/// }
/// ```
public protocol ActionRoutable {
    associatedtype Action

    /// Routes an action to the appropriate handler.
    ///
    /// - Parameter action: The action to route
    func route(action: Action)
}

// MARK: - Composition Debugging

/// Helpers for debugging notifier composition.
///
/// Enable detailed logging of state changes and action routing across
/// composed notifiers, similar to Redux DevTools.
public struct CompositionDebugger {
    /// Logs state changes in a formatted, hierarchical way.
    ///
    /// - Parameters:
    ///   - scope: The scope or notifier name
    ///   - oldState: Previous state value
    ///   - newState: New state value
    ///   - action: Optional action that triggered the change
    ///
    /// **Example:**
    /// ```swift
    /// CompositionDebugger.logStateChange(
    ///     scope: "auth",
    ///     oldState: oldAuthState,
    ///     newState: newAuthState,
    ///     action: .login
    /// )
    /// ```
    public static func logStateChange<State: CustomStringConvertible>(
        scope: String,
        oldState: State,
        newState: State,
        action: String? = nil
    ) {
        let actionInfo = action.map { " via \($0)" } ?? ""
        let stateChange = oldState.description == newState.description ? "unchanged" : "changed"
        print("[StateKit] [\(scope)] State \(stateChange)\(actionInfo)")

        #if DEBUG
        print("  Old: \(oldState)")
        print("  New: \(newState)")
        #endif
    }

    /// Logs action routing between notifiers.
    ///
    /// - Parameters:
    ///   - from: Source notifier/scope name
    ///   - to: Destination notifier/scope name
    ///   - action: The action being routed
    public static func logActionRoute(
        from: String,
        to: String,
        action: String
    ) {
        print("[StateKit] [\(from) → \(to)] Action: \(action)")
    }

    /// Logs notifier lifecycle events.
    ///
    /// - Parameters:
    ///   - scope: Notifier/scope name
    ///   - event: The lifecycle event (e.g., "initialized", "disposed")
    public static func logLifecycleEvent(
        scope: String,
        event: String
    ) {
        print("[StateKit] [\(scope)] \(event)")
    }
}

// MARK: - Composition Macros Support

/// Metadata for composable notifiers to support macro-based generation.
///
/// When using the `@Provider` macro with `composable: true`, this type
/// holds metadata about how the notifier should be composed.
///
/// **Usage with Macros:**
/// ```swift
/// @Provider(composable: true, domains: [.auth, .ui])
/// class AppNotifier: Notifier<AppState> { ... }
/// ```
public struct CompositionMetadata {
    /// The domains this notifier manages.
    public let domains: [String]

    /// Whether to enable debug logging for this composition.
    public let debugEnabled: Bool

    /// The preferred composition strategy.
    public let strategy: CompositionStrategy

    /// Supported composition strategies.
    public enum CompositionStrategy {
        /// Flat composition - all substates at the same level.
        case flat

        /// Hierarchical composition - nested substate organization.
        case hierarchical

        /// Modular composition - independent modules with clear boundaries.
        case modular
    }

    public init(
        domains: [String],
        debugEnabled: Bool = false,
        strategy: CompositionStrategy = .hierarchical
    ) {
        self.domains = domains
        self.debugEnabled = debugEnabled
        self.strategy = strategy
    }
}
