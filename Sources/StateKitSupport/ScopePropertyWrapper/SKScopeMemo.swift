import Foundation

/// A property wrapper that memoizes a computed value using `useMemo`,
/// recomputing it only when `updateStrategy` changes.
///
/// `SKScopeMemo` is syntactic sugar over `useMemo`: instead of writing
/// ```swift
/// let sorted = useMemo(updateStrategy: .preserved(by: items)) {
///     items.sorted()
/// }
/// ```
/// you can write:
/// ```swift
/// @SKScopeMemo(.preserved(by: items)) var sorted = items.sorted()
/// ```
///
/// The initializer expression is captured as an `@autoclosure`, so it is
/// passed directly to `useMemo` as the compute closure. On the first render
/// the expression is evaluated and cached. On subsequent renders it is only
/// re-evaluated if `updateStrategy` changes between renders.
///
/// Must be used inside a `StateScope` closure or a `StateView.stateBody`.
/// Hook ordering rules apply: always declare `@SKScopeMemo` properties in the
/// same order across renders.
///
/// - Note: `SKScopeMemo` has no `projectedValue`. Access the memoized result
///   directly through the property name.
///
/// ### Example
/// ```swift
/// struct SortedListView: StateView {
///     let items: [Int]
///
///     var stateBody: some View {
///         @SKScopeMemo(.preserved(by: items)) var sorted = items.sorted()
///
///         List(sorted, id: \.self) { Text("\($0)") }
///     }
/// }
/// ```
@propertyWrapper
@MainActor
public struct SKScopeMemo<Node> {

    private let _value: Node

    /// Creates a memoized property backed by `useMemo`.
    ///
    /// - Parameters:
    ///   - compute: The expression to memoize, captured as an `@autoclosure`.
    ///     Passed directly to `useMemo` as its compute closure.
    ///   - updateStrategy: Controls when `compute` is re-evaluated.
    ///     Defaults to `.once` — computed exactly once on the first render.
    public init(
        wrappedValue compute: @autoclosure @escaping () -> Node,
        updateStrategy: UpdateStrategy = .once
    ) {
        _value = useMemo(updateStrategy: updateStrategy, compute)
    }

    /// The memoized value produced by the compute expression.
    public var wrappedValue: Node {
        _value
    }
}
