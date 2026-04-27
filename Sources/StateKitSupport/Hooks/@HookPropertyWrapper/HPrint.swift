import Foundation

/// A property wrapper that logs a value through `usePrint` and then exposes
/// that same value as `wrappedValue`.
///
/// `HPrint` is syntactic sugar over `usePrint`: instead of writing
/// ```swift
/// let count = 42
/// usePrint(.preserved(by: count), count, name: "count")
/// ```
/// you can write:
/// ```swift
/// @HPrint(.preserved(by: count), name: "count") var loggedCount = count
/// ```
///
/// The wrapped expression is evaluated immediately inside `init`, passed to
/// `usePrint` for logging, and then stored locally for later access through
/// `wrappedValue`.
///
/// Must be used inside a `StateScope` closure or a `StateView.stateBody`.
/// Hook ordering rules apply: always declare `@HPrint` properties in the same
/// order across renders.
///
/// - Note: `HPrint` has no `projectedValue`. Access the logged value directly
///   through the property name.
///
/// ### Example
/// ```swift
/// struct DebugCounterView: StateView {
///     var stateBody: some View {
///         @HState var count = 0
///         @HPrint(.preserved(by: count), name: "count") var loggedCount = count
///
///         VStack {
///             Text("Count: \(loggedCount)")
///             Button("Increment") { count += 1 }
///         }
///     }
/// }
/// ```
@propertyWrapper
@MainActor
public struct HPrint<Node> {

    private let _value: Node

    /// Creates a logged property backed by `usePrint`.
    ///
    /// - Parameters:
    ///   - updateStrategy: Controls when the log should re-run.
    ///     Defaults to `.once` — logged exactly once on the first render.
    ///   - compute: The value expression to log, captured as an `@autoclosure`.
    ///   - fileID: Source file ID forwarded to `usePrint`.
    ///   - line: Source line forwarded to `usePrint`.
    ///   - name: Optional label shown alongside the log output.
    ///   - separator: String inserted between printed items.
    ///   - terminator: String appended after the printed items.
    public init(
        updateStrategy: UpdateStrategy = .once,
        wrappedValue compute: @autoclosure @escaping () -> Node,
        fileID: String = #fileID,
        line: UInt = #line,
        name: String = "",
        separator: String = " ",
        terminator: String = "\n"
    ) {
        _value = compute()
        usePrint(
            updateStrategy: updateStrategy,
            _value,
            fileID: fileID,
            line: line,
            name: name,
            separator: separator,
            terminator: terminator
        )
    }

    /// The value produced by the wrapped expression.
    public var wrappedValue: Node {
        _value
    }
}
