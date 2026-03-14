/// Creates a mutable reference that is persisted across renders without
/// triggering re-renders when its value changes.
///
/// This behaves similarly to React's `useRef`. The stored value lives inside
/// the hook runtime and is preserved as long as the surrounding `HookScope`
/// / `HookView` is alive. Updating the reference's `value` does **not**
/// cause the view to re-render, which makes it ideal for storing
/// imperatively updated values such as timers, cancellables, or cached
/// objects that are not part of the visual state.
///
/// - Parameter initial: The initial value for the reference on first render.
/// - Returns: A `HookRef<T>` whose `value` can be read and written freely.
///
/// ### Example
/// ```swift
/// struct TimerView: HookView {
///     var body: some View {
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
        fatalError("Hooks must be used inside HookView")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(StateRef(initial))
    }

    return context.states[index] as! StateRef<T>
}
