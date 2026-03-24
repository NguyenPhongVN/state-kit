import Foundation

// MARK: - Internal storage

/// Internal box that caches a single memoized value for a `useMemo` hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// The box is allocated once on the first render and lives for the lifetime
/// of the enclosing `StateScope`.
///
/// - `value`: the last computed result; overwritten whenever `updateStrategy`
///   changes.
/// - `updateStrategy`: the strategy stored from the last render, used on the
///   next render to decide whether to recompute.
///
/// Unlike `_HookPublisherBox` or `_HookReducerBox`, this box does **not** use
/// a `StateSignal` — memoized values do not drive re-renders on their own.
/// The cached value is simply returned to the caller each render.
final class _HookMemoBox<T> {
    var value: T
    var updateStrategy: UpdateStrategy?

    init(_ value: T, updateStrategy: UpdateStrategy?) {
        self.value = value
        self.updateStrategy = updateStrategy
    }
}

// MARK: - Public API

/// Returns a memoized result of `compute`, recomputing only when
/// `updateStrategy` changes.
///
/// On the first render `compute` is called immediately, the result is stored
/// in a `_HookMemoBox` at the current hook index, and the value is returned.
///
/// On every subsequent render the stored `UpdateStrategy.Dependency` is
/// compared against the one passed on this render using `!=`. If they differ
/// `compute` is called again, the box is updated, and the new value is
/// returned. If they are equal the cached value is returned without calling
/// `compute`.
///
/// Unlike `useState` or `useReducer`, updating a memoized value does **not**
/// trigger a re-render — `_HookMemoBox` is a plain `final class`, not an
/// `@Observable` `StateSignal`. `useMemo` is purely a performance tool: it
/// avoids repeating expensive computations on renders caused by other state
/// changes.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - updateStrategy: Controls when `compute` is re-evaluated.
///     - `.once` (default) — computed exactly once on the first render.
///     - `.preserved(by:)` — recomputed whenever the dependency value changes.
///     - `nil` — same as `.once`; computed once and never recomputed.
///   - compute: The closure whose return value is cached. Called on the first
///     render and each time `updateStrategy` changes between renders.
/// - Returns: The cached result of `compute` for the current dependency.
///
/// ### Example
/// ```swift
/// struct SortedListView: StateView {
///     let items: [Int]
///
///     var stateBody: some View {
///         let sorted = useMemo(updateStrategy: .preserved(by: items)) {
///             items.sorted()
///         }
///
///         List(sorted, id: \.self) { item in
///             Text("\(item)")
///         }
///     }
/// }
/// ```
@MainActor
public func useMemo<T>(
    updateStrategy: UpdateStrategy? = .once,
    _ compute: () -> T
) -> T {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        let value = compute()
        context.states.append(_HookMemoBox(value, updateStrategy: updateStrategy))
        return value
    } else {
        let box = context.states[index] as! _HookMemoBox<T>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            box.value = compute()
            box.updateStrategy = updateStrategy
        }
        return box.value
    }
}
