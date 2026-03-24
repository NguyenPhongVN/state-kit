// MARK: - Internal storage

/// Internal box that tracks the last seen value for a `useOnChange` hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// The box is allocated on the first render with the initial value and reused
/// on every subsequent render.
///
/// Unlike `_HookReducerBox` or `_HookAsyncBox`, this box is a plain
/// `final class` — not `@Observable` — because `useOnChange` is a pure
/// side-effect hook and never triggers re-renders on its own.
private final class _HookOnChangeBox<T> {
    var previousValue: T

    init(_ value: T) {
        self.previousValue = value
    }
}

// MARK: - Public API

/// Calls `action` whenever `value` changes between renders.
///
/// On the first render `value` is stored as the baseline; `action` is **not**
/// called. On every subsequent render `value` is compared against the stored
/// baseline using `!=`. If they differ `action` is called with the new value,
/// then the baseline is updated.
///
/// This mirrors SwiftUI's `.onChange(of:)` modifier and Vue's `watch` API:
/// the callback fires reactively on change, not on the initial mount.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - value: The `Equatable` value to observe. Compared by `!=` each render.
///   - action: Called with the new value whenever `value` changes. Runs
///     synchronously during the render in which the change is detected.
///
/// ### Example
/// ```swift
/// struct SearchView: StateView {
///     let query: String
///
///     var stateBody: some View {
///         let (results, setResults) = useState([String]())
///
///         useOnChange(query) { newQuery in
///             Task { setResults(await search(newQuery)) }
///         }
///
///         List(results, id: \.self) { Text($0) }
///     }
/// }
/// ```
@MainActor
public func useOnChange<T: Equatable>(
    _ value: T,
    perform action: (T) -> Void
) {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(_HookOnChangeBox(value))
    } else {
        let box = context.states[index] as! _HookOnChangeBox<T>
        if box.previousValue != value {
            box.previousValue = value
            action(value)
        }
    }
}

/// Calls `action` with both the old and new values whenever `value` changes
/// between renders.
///
/// Identical to `useOnChange(_:perform:)` but the `action` closure receives
/// both the previous and the new value — mirroring SwiftUI's iOS 17+
/// `.onChange(of:) { oldValue, newValue in }` overload.
///
/// On the first render the value is stored as the baseline without calling
/// `action`. On subsequent renders, if the value has changed, `action` is
/// called as `action(oldValue, newValue)` and the baseline is updated.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders.
///
/// - Parameters:
///   - value: The `Equatable` value to observe.
///   - action: Called with `(oldValue, newValue)` whenever `value` changes.
///
/// ### Example
/// ```swift
/// struct PaginatedView: StateView {
///     let page: Int
///
///     var stateBody: some View {
///         useOnChange(page) { old, new in
///             print("Moved from page \(old) to \(new)")
///         }
///
///         PageContent(page: page)
///     }
/// }
/// ```
@MainActor
public func useOnChange<T: Equatable>(
    _ value: T,
    perform action: (T, T) -> Void
) {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(_HookOnChangeBox(value))
    } else {
        let box = context.states[index] as! _HookOnChangeBox<T>
        if box.previousValue != value {
            let old = box.previousValue
            box.previousValue = value
            action(old, value)
        }
    }
}

/// Calls `action` on the first render and whenever `value` changes between
/// renders.
///
/// Identical to `useOnChange(_:perform:)` but also fires immediately on the
/// first render with the initial value — equivalent to React's `useEffect`
/// with a single dependency, or SwiftUI's `.task(id:)`.
///
/// - Parameters:
///   - value: The `Equatable` value to observe.
///   - action: Called with the current value on the first render and whenever
///     `value` changes on subsequent renders.
///
/// ### Example
/// ```swift
/// struct UserView: StateView {
///     let userId: String
///
///     var stateBody: some View {
///         let (phase, setPhase) = useState(AsyncPhase<User>.idle)
///
///         useOnChange(userId, initial: true) { id in
///             Task {
///                 setPhase(.loading)
///                 setPhase(await Result { try await api.fetchUser(id: id) }
///                     .map { .success($0) }
///                     .mapError { .failure($0) }
///                     .get())
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useOnChange<T: Equatable>(
    _ value: T,
    initial: Bool = false,
    perform action: (T) -> Void
) {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(_HookOnChangeBox(value))
        if initial {
            action(value)
        }
    } else {
        let box = context.states[index] as! _HookOnChangeBox<T>
        if box.previousValue != value {
            box.previousValue = value
            action(value)
        }
    }
}
