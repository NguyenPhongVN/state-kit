import Foundation
import Observation

// MARK: - Internal storage

/// Internal box that pairs a `StateSignal` (the observable state container)
/// with the latest reducer closure for a single `useReducer` hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// `signal` is allocated once on first render and kept for the lifetime of
/// the enclosing `StateScope`; `reduce` is overwritten on every render so
/// that `dispatch` always calls the most recent closure captured at the
/// hook call site.
final class _HookReducerBox<State, Action> {
    let signal: StateSignal<State>
    var reduce: (inout State, Action) -> Void

    /// Re-entrancy guard + queue for dispatches issued from inside a reducer.
    @ObservationIgnored
    var isDispatching = false
    @ObservationIgnored
    var pendingActions: [Action] = []

    init(initial: State, reduce: @escaping (inout State, Action) -> Void) {
        self.signal = StateSignal(initial)
        self.reduce = reduce
    }
}

// MARK: - Public API

/// Returns the current reducer state and a `dispatch` closure for the current
/// hook position.
///
/// This behaves similarly to React's `useReducer`. On the first render a
/// `_HookReducerBox` is allocated with `initial` state and stored in
/// `StateRuntime.current.states` at the current hook index. On every
/// subsequent render the existing box is retrieved and `initial` is ignored;
/// the `reduce` closure is overwritten with the one passed on this render
/// so that `dispatch` always uses the latest reducer.
///
/// Calling `dispatch(_:)` synchronously applies `reduce` to the current
/// `StateSignal.value` via an `inout` mutation. Because `StateSignal` is
/// `@Observable`, the mutation is observed by SwiftUI and triggers a
/// re-render of the enclosing `StateScope`.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - initial: The initial state value for this hook slot on the first
///     render. Ignored on all subsequent renders.
///   - reduce: A function that receives the current state as `inout` and an
///     `Action`, and mutates the state in place to produce the next value.
///     Updated every render; `dispatch` always calls the latest version.
/// - Returns: A tuple of `(currentState, dispatch)` where `dispatch` applies
///   the reducer and schedules a re-render.
///
/// ### Example
/// ```swift
/// enum CounterAction {
///     case increment
///     case decrement
/// }
///
/// struct CounterView: StateView {
///     var stateBody: some View {
///         let (count, dispatch) = useReducer(0) { state, action in
///             switch action {
///             case .increment: state += 1
///             case .decrement: state -= 1
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
        fatalError("\(#function) must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    let box: _HookReducerBox<State, Action>

    if context.states.count <= index {
        box = _HookReducerBox(initial: initial, reduce: reduce)
        context.appendSlot(box)
    } else {
        // Positional slot invariant: created by this hook on first render;
        // stable hook order guarantees the type.
        box = context.states[index] as! _HookReducerBox<State, Action>
        // Keep the latest reducer to match the current hook call site.
        box.reduce = reduce
    }

    let dispatch: (Action) -> Void = { action in
        // Re-entrant dispatch (a reducer dispatching again) must not re-enter
        // the same inout access — that is an exclusivity crash. Queue the
        // action and drain it after the current reduce returns.
        if box.isDispatching {
            box.pendingActions.append(action)
            return
        }
        box.isDispatching = true
        defer {
            box.isDispatching = false
            while !box.pendingActions.isEmpty {
                let queued = box.pendingActions.removeFirst()
                var queuedValue = box.signal.value
                box.reduce(&queuedValue, queued)
                box.signal.value = queuedValue
            }
        }
        var value = box.signal.value
        box.reduce(&value, action)
        box.signal.value = value
    }

    return (box.signal.value, dispatch)
}
