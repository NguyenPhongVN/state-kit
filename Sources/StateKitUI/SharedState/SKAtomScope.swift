import SwiftUI
import StateKitAtoms

/// A view that injects an isolated `SKAtomStore` into its subtree.
///
/// Use `SKAtomScopeView` to:
/// - **Isolate previews**: give each preview its own fresh store so that
///   mutations in one preview don't bleed into others.
/// - **Override atoms for testing**: inject a store pre-seeded with specific
///   atom values.
/// - **Create sub-trees with independent state**: useful in modal sheets or
///   reusable components that should start with clean state.
///
/// ```swift
/// #Preview {
///     SKAtomScopeView {
///         CartView()
///     }
/// }
/// ```
///
/// ```swift
/// // Inject a pre-configured store for UI tests
/// let store = SKAtomStore()
/// store.setStateValue(42, for: CounterAtom())
///
/// SKAtomScopeView(store: store) {
///     ContentView()
/// }
/// ```
public struct SKAtomScopeView<Content: View>: View {

    // MARK: - State / Store

    /// The store provided to this scope's subtree.
    @State private var ownedStore: SKAtomStore
    private let injectedStore: SKAtomStore?

    // MARK: - Content

    private let content: Content

    // MARK: - Init

    /// Creates a scope with a fresh, empty `SKAtomStore`.
    ///
    /// - Parameter content: The view hierarchy to wrap.
    public init(@ViewBuilder content: () -> Content) {
        _ownedStore = State(initialValue: SKAtomStore())
        injectedStore = nil
        self.content = content()
    }

    /// Creates a scope that uses an existing `SKAtomStore`.
    ///
    /// - Parameters:
    ///   - store: The store to inject. The scope does **not** take ownership;
    ///     the caller is responsible for the store's lifetime.
    ///   - content: The view hierarchy to wrap.
    public init(store: SKAtomStore, @ViewBuilder content: () -> Content) {
        _ownedStore = State(initialValue: store)
        injectedStore = store
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        let activeStore = injectedStore ?? ownedStore
        content
            .environment(\.skAtomStore, activeStore)
    }
}

// MARK: - View modifier convenience

extension View {
    /// Wraps this view in an `SKAtomScopeView` with a fresh isolated store.
    ///
    /// ```swift
    /// CartView()
    ///     .atomScope()
    /// ```
    public func atomScope() -> some View {
        SKAtomScopeView { self }
    }

    /// Wraps this view in an `SKAtomScopeView` using `store`.
    ///
    /// ```swift
    /// ContentView()
    ///     .atomScope(store: preSeededStore)
    /// ```
    ///
    /// - Parameter store: The store to inject into this view's subtree.
    public func atomScope(store: SKAtomStore) -> some View {
        SKAtomScopeView(store: store) { self }
    }
}
