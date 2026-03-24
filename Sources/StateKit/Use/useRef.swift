/// Returns a mutable reference that persists across renders without triggering
/// re-renders when its value changes.
///
/// This behaves similarly to React's `useRef`. The `StateRef` object is
/// allocated once on the first render and stored in `StateRuntime.current.states`
/// at the current hook index. On every subsequent render the same object is
/// returned; `initial` is ignored.
///
/// Unlike `useState(_:)` — which stores state in an `@Observable` `StateSignal`
/// so that mutations trigger a re-render — `useRef(_:)` stores state in a plain
/// `final class` (`StateRef`). Mutating `StateRef.value` is **not** observed by
/// SwiftUI and does **not** cause the enclosing `StateScope` to re-render.
///
/// Use `useRef` for values that must survive re-renders but whose changes should
/// not drive the UI — for example: timers, `AnyCancellable` tokens, cached
/// objects, or counters used only in callbacks.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameter initial: The initial value for the reference slot on the first
///   render. Ignored on all subsequent renders.
/// - Returns: The `StateRef<T>` stored at the current hook index.
///
/// ### Example
/// ```swift
/// struct TimerView: StateView {
///     var stateBody: some View {
///         let timerRef = useRef<Timer?>(nil)
///
///         VStack {
///             Button("Start timer") {
///                 timerRef.value?.invalidate()
///                 timerRef.value = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
///                     print("tick")
///                 }
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useRef<T>(_ initial: T) -> StateRef<T> {

    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(StateRef(initial))
    }

    return context.states[index] as! StateRef<T>
}
