// MARK: - Internal storage

/// Internal box that caches a single callback for a `useCallback` hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// The box is allocated once on the first render and lives for the lifetime
/// of the enclosing `StateScope`.
///
/// - `fn`: the last cached callback value; overwritten whenever
///   `updateStrategy` changes between renders.
/// - `updateStrategy`: the strategy stored from the last render, used on the
///   next render to decide whether to replace the cached callback.
///
/// Like `_HookMemoBox`, this box is a plain `final class` — not an
/// `@Observable` `StateSignal` — so replacing `fn` does not trigger a
/// re-render on its own.
final class _HookCallbackBox<T> {
    var fn: T
    var updateStrategy: UpdateStrategy?

    init(_ fn: T, updateStrategy: UpdateStrategy?) {
        self.fn = fn
        self.updateStrategy = updateStrategy
    }
}

// MARK: - Public API

/// Returns a memoized callback, replacing it only when `updateStrategy`
/// changes.
///
/// On the first render `callback` is stored in a `_HookCallbackBox` at the
/// current hook index and returned directly.
///
/// On every subsequent render the stored `UpdateStrategy.Dependency` is
/// compared against the one passed on this render using `!=`. If they differ
/// the box is updated with the new callback and it is returned. If they are
/// equal the previously cached callback is returned, preserving its identity
/// across renders.
///
/// Preserving callback identity is useful when the callback is passed as a
/// dependency to another hook (e.g. `useEffect`, `useMemo`) or to a child
/// view, where a changing reference would unnecessarily trigger downstream
/// recomputation.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - updateStrategy: Controls when the cached callback is replaced.
///     - `.once` (default) — the callback is cached once and never replaced.
///     - `.preserved(by:)` — the callback is replaced whenever the dependency
///       value changes between renders.
///     - `nil` — same as `.once`; cached once and never replaced.
///   - callback: The callback value to cache. Replaced only when
///     `updateStrategy` changes.
/// - Returns: The cached callback for the current dependency.
///
/// ### Example
/// ```swift
/// struct SearchView: StateView {
///     let onSubmit: (String) -> Void
///     let query: String
///
///     var stateBody: some View {
///         let stableOnSubmit = useCallback(
///             updateStrategy: .preserved(by: query)
///         ) {
///             onSubmit(query)
///         }
///
///         SearchField(onSubmit: stableOnSubmit)
///     }
/// }
/// ```
@MainActor
public func useCallback<T>(
    updateStrategy: UpdateStrategy? = .once,
    _ callback: T
) -> T {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(_HookCallbackBox(callback, updateStrategy: updateStrategy))
        return callback
    } else {
        let box = context.states[index] as! _HookCallbackBox<T>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            box.fn = callback
            box.updateStrategy = updateStrategy
        }
        return box.fn
    }
}
