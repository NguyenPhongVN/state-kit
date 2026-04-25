import SwiftUI

/// The full read/write context injected into views via `@SKAtomContext`.
///
/// `SKAtomViewContext` is the view-facing API for the atom store. It provides
/// `read`, `set`, `reset`, `binding`, and `refresh` operations on any atom,
/// without tying the call site to a specific atom type at the struct level.
///
/// ## Injecting the context
///
/// ```swift
/// struct CartView: View {
///     @SKAtomContext var ctx
///
///     var body: some View {
///         Button("Clear") {
///             ctx.reset(CartAtom())
///         }
///     }
/// }
/// ```
///
/// - Note: All operations are `@MainActor`. The context is always used on the
///   main thread inside SwiftUI views.
@MainActor
public struct SKAtomViewContext {

    // MARK: - Internal

    let store: SKAtomStore

    @MainActor
    public init(store: SKAtomStore) {
        self.store = store
    }

    // MARK: - Reading

    /// Returns the current value of `atom`.
    ///
    /// Unlike property wrappers, this does **not** subscribe the view to future
    /// changes from this call site alone. Use it when you need the current
    /// value imperatively (e.g. inside a button action).
    ///
    /// For reactive observation, use `@SKValue` or `@SKState` instead.
    ///
    /// - Parameter atom: The atom to read.
    /// - Returns: The atom's current cached value.
    public func read<A: SKAtom>(_ atom: A) -> A.Value {
        atom._getOrCreateBox(in: store).value
    }

    // MARK: - Mutation

    /// Writes a new value to a `SKStateAtom` and propagates the change.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - atom: The atom to update.
    public func set<A: SKStateAtom>(_ value: A.Value, for atom: A) {
        store.setStateValue(value, for: atom)
    }

    /// Resets `atom` to the value returned by its `defaultValue(context:)`.
    ///
    /// - Parameter atom: The atom to reset.
    public func reset<A: SKStateAtom>(_ atom: A) {
        store.resetStateValue(for: atom)
    }

    // MARK: - Binding

    /// Returns a `Binding` for a `SKStateAtom`, suitable for use with SwiftUI
    /// controls that require two-way bindings.
    ///
    /// ```swift
    /// TextField("Name", text: ctx.binding(for: NameAtom()))
    /// ```
    ///
    /// - Parameter atom: The mutable atom to bind.
    /// - Returns: A binding that reads and writes the atom's value.
    public func binding<A: SKStateAtom>(for atom: A) -> Binding<A.Value> {
        Binding {
            self.read(atom)
        } set: { newValue in
            self.store.setStateValue(newValue, for: atom)
        }
    }

    // MARK: - Refresh

    /// Cancels any in-flight task for `atom`, resets its phase to `.loading`,
    /// and suspends until the new task finishes.
    ///
    /// ```swift
    /// Button("Retry") {
    ///     Task { await ctx.refresh(FeedAtom()) }
    /// }
    /// ```
    ///
    /// - Parameter atom: The async atom to refresh.
    public func refresh<A: SKTaskAtom>(_ atom: A) async {
        await store.refreshTask(for: atom)
    }

    /// Cancels any in-flight task for `atom`, resets its phase to `.loading`,
    /// and suspends until the new task finishes.
    ///
    /// - Parameter atom: The async throwing atom to refresh.
    public func refresh<A: SKThrowingTaskAtom>(_ atom: A) async {
        await store.refreshThrowingTask(for: atom)
    }

    // MARK: - Eviction

    /// Removes all cached state for `atom` from the store.
    ///
    /// Cached descendants that depend on `atom` are also evicted so they do
    /// not retain stale derived values or stale dependency edges.
    ///
    /// After eviction, the next read will re-initialise the atom from its
    /// default value or re-run its task.
    ///
    /// - Parameter atom: The atom to evict.
    public func evict<A: SKAtom>(_ atom: A) {
        store.evict(atom)
    }
}
