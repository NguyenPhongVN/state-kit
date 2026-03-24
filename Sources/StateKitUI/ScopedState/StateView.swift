import SwiftUI

/// A SwiftUI `View` that opts into HookKit's hook-based rendering model.
///
/// Conformers implement `hookBody` instead of `body`. The `hookBody` is
/// automatically wrapped in a `HookScope`, which sets up a `HookContext`
/// and enables the use of hook functions such as `useState`, `useReducer`,
/// `useAsync`, `useMemo`, and `useRef`.
///
/// Usage:
/// ```swift
/// struct CounterView: StateView {
///     var stateBody: some View {
///         let (count, setCount) = useStateSet(0)
///         VStack {
///             Text("Count: \(count)")
///             Button("Increment") {
///                 setCount(count + 1)
///             }
///         }
///     }
/// }
/// ```
public protocol StateView: View {
    /// The type of view representing the body of this view that can use hooks.
    associatedtype StateBody: View
    
    /// The content and behavior of the hook-scoped view.
    @ViewBuilder @MainActor var stateBody: Self.StateBody { get }
}

/// Default implementation that wires `stateBody` into SwiftUI's `body`
/// by wrapping it in a `StateScope`.
@MainActor
public extension StateView {
    var body: some View {
        StateScope {
            stateBody
        }
    }
}
