// MARK: - Internal storage

/// Internal storage for a single `useEffect` hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// The object is allocated on the first render and lives for the lifetime
/// of the enclosing `StateScope`.
///
/// - `updateStrategy`: the strategy stored from the last render, compared
///   on the next render to decide whether to re-run the effect.
/// - `cleanup`: the closure returned by the last `effect` call, if any.
///   Called explicitly before re-running the effect when the strategy
///   changes, and automatically in `deinit` when the `StateScope` is
///   removed from the view hierarchy.
private class Effect {
    var updateStrategy: UpdateStrategy?
    var cleanup: (() -> Void)?

    init(updateStrategy: UpdateStrategy? = nil, cleanup: (() -> Void)? = nil) {
        self.updateStrategy = updateStrategy
        self.cleanup = cleanup
    }

    deinit {
        cleanup?()
    }
}

// MARK: - Public API

/// Runs a side effect after render and re-runs it whenever `updateStrategy`
/// changes.
///
/// On the first render `effect` is queued and runs after the current render
/// pass completes. Its return value (an optional cleanup closure) is stored
/// alongside the current `updateStrategy`.
///
/// On every subsequent render the stored `UpdateStrategy.Dependency` is
/// compared against the one passed on this render. If they differ, a post-
/// render job is queued that:
/// 1. The previous cleanup closure is called, if one exists.
/// 2. `effect` is called again and the new cleanup and strategy are stored.
///
/// If the strategies are equal, `effect` is not called and the stored
/// cleanup is left unchanged.
///
/// The cleanup closure is also called automatically when the enclosing
/// `StateScope` is removed from the view hierarchy (the `Effect` box is
/// deallocated via `deinit`).
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - effect: The side-effect closure to run. Returns an optional cleanup
///     closure that is called before the next run or when the scope is
///     destroyed. Return `nil` if no cleanup is needed.
///   - updateStrategy: Controls when `effect` is re-run.
///     - `nil` (default) — runs once on the first render, never re-run.
///     - `.once` — same as `nil`; runs exactly once.
///     - `.preserved(by:)` — re-runs whenever the dependency value changes.
///
/// ### Example
/// ```swift
/// struct TimerView: StateView {
///     var stateBody: some View {
///         let (isRunning, setRunning) = useState(false)
///
///         useEffect(updateStrategy: .preserved(by: isRunning)) {
///             guard isRunning else { return nil }
///             let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
///                 print("tick")
///             }
///             return { timer.invalidate() }
///         }
///
///         Button(isRunning ? "Stop" : "Start") {
///             setRunning(!isRunning)
///         }
///     }
/// }
/// ```
@MainActor public func useEffect(
    updateStrategy: UpdateStrategy? = nil,
    _ effect: @escaping () -> (() -> Void)?
) {
    guard let context = StateRuntime.current else {
        fatalError("\(#function) must be used inside StateRuntime")
    }
    let index = context.nextIndex()

    if index < context.states.count {
        guard let box = context.states[index] as? Effect else { return }

        if !areEqual(box.updateStrategy?.dependency, updateStrategy?.dependency) {
            context.enqueuePostRenderEffect {
                box.cleanup?()
                box.cleanup = effect()
                box.updateStrategy = updateStrategy
            }
        }
    } else {
        let box = Effect()
        context.states.append(box)
        context.enqueuePostRenderEffect {
            box.cleanup = effect()
            box.updateStrategy = updateStrategy
        }
    }
}

@MainActor public func useEffect(
    updateStrategy: UpdateStrategy? = nil,
    effect: (() -> Void)? = nil
) {
    useEffect(updateStrategy: updateStrategy) {
        effect?()
        return nil
    }
}
