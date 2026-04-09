import SwiftUI

/// A property wrapper that exposes hook-based state as a SwiftUI `Binding`,
/// backed by `useBinding`.
///
/// `SKScopeState` is syntactic sugar over `useBinding`: instead of writing
/// ```swift
/// let name = useBinding("")
/// TextField("Name", text: name)
/// ```
/// you can write:
/// ```swift
/// @SKScopeState var name = ""
/// TextField("Name", text: $name)
/// ```
///
/// Assigning to the property writes through the underlying `Binding`, which
/// mutates the `StateSignal` and triggers a re-render of the enclosing
/// `StateScope` via `@Observable`.
///
/// `SKScopeState` also accepts an existing `Binding<Node>` directly (via the
/// `Binding`-typed overloads), allowing you to bridge external SwiftUI state
/// — from a parent `@State`, `@Binding`, or `@Environment` — into a
/// `StateView` using the same `@SKScopeState` syntax.
///
/// Must be used inside a `StateScope` closure or a `StateView.stateBody`.
/// Hook ordering rules apply for the `useBinding`-backed overloads: always
/// declare `@SKScopeState` properties in the same order across renders.
///
/// Use `$name` to obtain the `Binding<Node>` for passing to SwiftUI controls.
///
/// ### Example — hook-backed state
/// ```swift
/// struct NameFormView: StateView {
///     var stateBody: some View {
///         @SKScopeState var name = ""
///
///         VStack {
///             TextField("Name", text: $name)
///             Text("Hello, \(name)")
///         }
///     }
/// }
/// ```
///
/// ### Example — bridging external state
/// ```swift
/// struct WrapperView: View {
///     @State private var count = 0
///
///     var body: some View {
///         StateScope {
///             @SKScopeState var count = $count   // wraps the parent Binding
///             Stepper("Count: \(count)", value: $count)
///         }
///     }
/// }
/// ```
@propertyWrapper
@MainActor
public struct SKScopeState<Node> {

    internal let _value: Binding<Node>

    /// Creates hook-backed state by passing `wrappedValue()` to `useBinding`.
    ///
    /// The closure is evaluated immediately to obtain the initial value.
    /// On subsequent renders the stored `StateSignal` is reused and this
    /// closure is not re-evaluated.
    ///
    /// - Parameter wrappedValue: A closure returning the initial value.
    public init(wrappedValue: @escaping () -> Node) {
        _value = useBinding(wrappedValue())
    }

    /// Creates hook-backed state by passing `wrappedValue` directly to
    /// `useBinding`.
    ///
    /// The most common overload: used when the initial value is a literal or
    /// a simple expression, e.g. `@HState var name = ""`.
    ///
    /// - Parameter wrappedValue: The initial value for this state slot.
    public init(wrappedValue: Node) {
        _value = useBinding(wrappedValue)
    }

    /// Wraps an existing `Binding<Node>` produced by a closure.
    ///
    /// The closure is evaluated once and its result stored directly as the
    /// backing `Binding`. Does **not** call `useBinding`; no hook slot is
    /// consumed. Use this to bridge a computed or lazily-obtained `Binding`
    /// into `@HState` syntax.
    ///
    /// - Parameter wrappedValue: A closure that returns an existing `Binding`.
    public init(wrappedValue: @escaping () -> Binding<Node>) {
        _value = wrappedValue()
    }

    /// Wraps an existing `Binding<Node>` directly.
    ///
    /// Does **not** call `useBinding`; no hook slot is consumed. Use this to
    /// bridge a parent `@State`, `@Binding`, or `@Environment` value into
    /// `@HState` syntax, e.g. `@HState var count = $parentCount`.
    ///
    /// - Parameter wrappedValue: An existing `Binding` to wrap.
    public init(wrappedValue: Binding<Node>) {
        _value = wrappedValue
    }

    /// The current value read through the underlying `Binding`.
    ///
    /// Assigning to this property writes through the `Binding`, mutating the
    /// backing `StateSignal` and triggering a re-render of the enclosing
    /// `StateScope` (for hook-backed instances), or updating the source of
    /// truth for the wrapped `Binding` (for externally-bridged instances).
    public var wrappedValue: Node {
        get { _value.wrappedValue }
        nonmutating set { _value.wrappedValue = newValue }
    }

    /// The underlying `Binding<Node>`.
    ///
    /// Accessible via the `$name` syntax. Pass this to SwiftUI controls that
    /// require a `Binding`, such as `TextField`, `Toggle`, or `Slider`.
    public var projectedValue: Binding<Node> {
        _value
    }
}
