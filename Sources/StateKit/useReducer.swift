import Foundation

// MARK: - Internal storage

/// Internal box that keeps reducer state in a `StateSignal` so that
/// state changes trigger view re-renders via Swift's observation system.
final class _HookReducerBox<State, Action> {
    let signal: StateSignal<State>
    var reduce: (inout State, Action) -> Void

    init(initial: State, reduce: @escaping (inout State, Action) -> Void) {
        self.signal = StateSignal(initial)
        self.reduce = reduce
    }
}

// MARK: - Public API

/// Creates a reducer-driven piece of state associated with the current hook position.
///
/// This function behaves similarly to React's `useReducer`. It must be called
/// inside a `HookView` (or wherever `HookRuntime.current` is available), and
/// calls to `useReducer` must remain in a stable order across renders.
///
/// On the first render for a given hook index, the state is initialized with
/// the provided `initial` value. On subsequent renders, the previously stored
/// value is returned and the `initial` value is ignored.
///
/// The returned tuple contains the current state value and a `dispatch`
/// function. Calling `dispatch` with an `Action` will run the provided
/// `reduce` function to produce the next state, and update the underlying
/// observable signal so that the UI can re-render.
///
/// - Parameters:
///   - initial: The initial state value used on the first render.
///   - reduce: A reducer function that takes the current state `inout` and an
///             `Action`, and mutates the state to its next value.
/// - Returns: A tuple of the current state and a `dispatch` closure.
///
/// ### Example
/// ```swift
/// enum CounterAction {
///     case increment
///     case decrement
/// }
///
/// struct CounterView: HookView {
///     var body: some View {
///         let (count, dispatch) = useReducer(0) { state, action in
///             switch action {
///             case .increment:
///                 state += 1
///             case .decrement:
///                 state -= 1
///             }
///         }
///
///         VStack {
///             Text("Count: \(count)")
///             HStack {
///                 Button("-") { dispatch(.decrement) }
///                 Button("+") { dispatch(.increment) }
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useReducer<Action, State>(
    _ initial: State,
    _ reduce: @escaping (inout State, Action) -> Void
) -> (State, (Action) -> Void) {

    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }

    let index = context.nextIndex()

    let box: _HookReducerBox<State, Action>

    if context.states.count <= index {
        box = _HookReducerBox(initial: initial, reduce: reduce)
        context.states.append(box)
    } else {
        box = context.states[index] as! _HookReducerBox<State, Action>
        // Keep the latest reducer to match the current hook call site.
        box.reduce = reduce
    }

    let dispatch: (Action) -> Void = { action in
        box.reduce(&box.signal.value, action)
    }

    return (box.signal.value, dispatch)
}
