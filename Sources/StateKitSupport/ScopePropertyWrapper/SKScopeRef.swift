import Foundation

/// A property wrapper that creates a persistent, non-reactive reference using
/// `useRef`, suitable for values that must survive re-renders without
/// triggering them.
///
/// `SKScopeRef` is syntactic sugar over `useRef`: instead of writing
/// ```swift
/// let timerRef = useRef<Timer?>(nil)
/// ```
/// you can write:
/// ```swift
/// @SKScopeRef var timer: Timer? = nil
/// ```
///
/// The underlying `StateRef<Node>` is allocated once on the first render and
/// reused on every subsequent render. Because `StateRef` is not `@Observable`,
/// assigning to the property does **not** trigger a re-render.
///
/// Must be used inside a `StateScope` closure or a `StateView.stateBody`.
/// Hook ordering rules apply: always declare `@SKScopeRef` properties in the same
/// order across renders.
///
/// Use `$name` to access the underlying `StateRef<Node>` when you need to
/// pass the reference object itself to another function or store.
///
/// ### Example
/// ```swift
/// struct TimerView: StateView {
///     var stateBody: some View {
///         @SKScopeRef var timer: Timer? = nil
///
///         Button("Start") {
///             timer?.invalidate()
///             timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
///                 print("tick")
///             }
///         }
///     }
/// }
/// ```
@propertyWrapper
@MainActor public struct SKScopeRef<Node> {

    private let _ref: StateRef<Node>

    /// Creates a ref backed by `useRef`, with the initial value supplied as
    /// an `@autoclosure`.
    ///
    /// The autoclosure is evaluated immediately inside `init` to obtain the
    /// initial value passed to `useRef`. On subsequent renders the stored
    /// `StateRef` is returned and the expression is not re-evaluated.
    ///
    /// - Parameter initial: The initial value expression, captured as an
    ///   `@autoclosure`.
    public init(wrappedValue initial: @autoclosure @escaping () -> Node) {
        _ref = useRef(initial())
    }

    /// Creates a ref backed by `useRef`, with the initial value supplied as
    /// an explicit closure.
    ///
    /// Use this overload when the initial value is too complex to express as
    /// a single autoclosure expression, or when you already hold a `() -> Node`
    /// closure.
    ///
    /// - Parameter initial: A closure that returns the initial value. Evaluated
    ///   immediately inside `init`.
    public init(wrappedValue initial: @escaping () -> Node) {
        _ref = useRef(initial())
    }

    /// The current value stored in the underlying `StateRef`.
    ///
    /// Reads and writes go directly to `StateRef.value`. Because `StateRef`
    /// is not `@Observable`, neither reading nor writing this property
    /// triggers a re-render of the enclosing `StateScope`.
    public var wrappedValue: Node {
        get { _ref.value }
        nonmutating set { _ref.value = newValue }
    }

    /// The underlying `StateRef<Node>` object.
    ///
    /// Accessible via the `$name` syntax. Use this when you need to pass the
    /// ref container itself — rather than just its current value — to another
    /// function or store.
    public var projectedValue: StateRef<Node> {
        _ref
    }
}
