import SwiftUI

/// A property wrapper that injects an `SKAtomViewContext` into a view.
///
/// Use `@SKContext` when you need imperative access to the atom store —
/// for reading arbitrary atoms, performing mutations in response to events,
/// or refreshing async atoms on demand — without committing the view to
/// observing a specific atom via `@SKValue` or `@SKState`.
///
/// ## Usage
///
/// ```swift
/// struct CartView: View {
///     @SKContext var atomContext
///
///     var body: some View {
///         Button("Clear cart") {
///             atomContext.reset(CartAtom())
///         }
///         Button("Reload feed") {
///             Task { await atomContext.refresh(FeedAtom()) }
///         }
///     }
/// }
/// ```
///
/// ## Reading atoms imperatively
///
/// ```swift
/// let count = atomContext.read(CounterAtom())   // current value, no subscription
/// ```
///
/// ## Creating bindings
///
/// ```swift
/// TextField("Name", text: atomContext.binding(for: NameAtom()))
/// ```
@MainActor
@propertyWrapper
public struct SKContext: DynamicProperty {

    // MARK: - Dependencies

    @Environment(\.skAtomStore) private var store

    // MARK: - Init

    public init() {}

    // MARK: - DynamicProperty

    /// The `SKAtomViewContext` bound to the nearest store in the environment.
    public var wrappedValue: SKAtomViewContext {
        SKAtomViewContext(store: store)
    }
}
