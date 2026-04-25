// MARK: - Internal storage

/// Internal storage for a single `useLayoutEffect` hook slot.
///
/// Identical in structure to the `Effect` box used by `useEffect`. Stored
/// in `StateRuntime.current.states` at the hook's index position and lives
/// for the lifetime of the enclosing `StateScope`.
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

/// Runs a layout-time side effect after render and re-runs it whenever
/// `updateStrategy` changes.
///
/// `useLayoutEffect` runs in a dedicated post-render phase: after the
/// current render pass completes, but before regular `useEffect` jobs are
/// flushed. This mirrors React's distinction between layout effects and
/// passive effects as closely as the local hook runtime allows.
///
/// `useLayoutEffect` is intended for effects that must observe or mutate
/// layout-related state before the view is presented — analogous to React's
/// `useLayoutEffect`, which fires synchronously after DOM mutations but
/// before the browser paints. Use `useEffect` for effects that do not
/// depend on layout measurement or that can safely run after the render
/// is committed.
///
/// On the first render `effect` is queued into the layout-effect phase and
/// its return value (an optional cleanup closure) is stored alongside the
/// current `updateStrategy`.
///
/// On every subsequent render the stored `UpdateStrategy.Dependency` is
/// compared against the one passed on this render. If they differ, a layout-
/// phase job is queued that:
/// 1. The previous cleanup closure is called, if one exists.
/// 2. `effect` is called again and the new cleanup and strategy are stored.
///
/// The cleanup closure is also called automatically when the enclosing
/// `StateScope` is removed from the view hierarchy (via `deinit`).
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
/// struct MeasuredView: StateView {
///     @State private var height: CGFloat = 0
///
///     var stateBody: some View {
///         useLayoutEffect {
///             // Perform layout-dependent setup before first presentation.
///             return nil
///         }
///
///         Text("Height: \(height)")
///     }
/// }
/// ```
@MainActor public func useLayoutEffect(
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
            context.enqueueLayoutEffect {
                box.cleanup?()
                box.cleanup = effect()
                box.updateStrategy = updateStrategy
            }
        }
    } else {
        let box = Effect()
        context.states.append(box)
        context.enqueueLayoutEffect {
            box.cleanup = effect()
            box.updateStrategy = updateStrategy
        }
    }
}
