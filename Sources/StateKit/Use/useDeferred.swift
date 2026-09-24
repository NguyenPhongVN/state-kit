import SwiftUI

// MARK: - useDeferred

/// Returns a value that **lags behind** `value`: the returned copy starts as
/// the initial value and catches up to the latest source asynchronously, at a
/// lower task priority than the urgent render.
///
/// Use it to keep an urgent part of the UI (the text field the user is typing
/// in) responsive while an expensive derived part (filtering a large list)
/// catches up a beat later. Rapid source changes coalesce: only the latest
/// value lands.
///
/// - Parameter value: The urgent source value.
/// - Returns: The deferred copy. It may lag `value` by one render.
///
/// ### Example
/// ```swift
/// struct SearchView: StateView {
///     var stateBody: some View {
///         let (query, setQuery) = useState("")
///         let deferredQuery = useDeferred(query)
///
///         TextField("Search", text: setQueryBinding)   // urgent
///         ExpensiveResults(query: deferredQuery)        // catches up
///     }
/// }
/// ```
@MainActor
public func useDeferred<T: Equatable>(_ value: T) -> T {
    guard let context = StateRuntime.current else {
        fatalError("useDeferred must be used inside StateRuntime")
    }

    // Slot 1: the deferred copy.
    let (deferred, setDeferred) = useState(value)
    // Slot 2: tracks the latest source value seen so far.
    let source = useRef(value)
    // Slot 3: generation counter guarding against out-of-order catch-ups.
    let generation = useRef(0)

    if source.value != value {
        source.value = value
        generation.value += 1
        let generationNow = generation.value
        // Low priority: the urgent render is already done; this catch-up
        // yields first and coalesces via the generation guard.
        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 30_000_000)
            if generation.value == generationNow {
                setDeferred(value)
            }
        }
    }

    return deferred
}

// MARK: - useTransition

/// Marks non-urgent work as a "transition".
///
/// Returns a pending flag plus a `start` closure. `start` flips the flag on,
/// runs the awaited work on the main actor, and flips it off when the work
/// completes. While the work is in flight (at an `await`), a re-render sees
/// `isPending == true` so the UI can show a spinner instead of stuttering.
///
/// - Returns: `(isPending, start)`. Render `isPending`; call `start(work)`
///   for the heavy update.
///
/// ### Example
/// ```swift
/// struct SubmitView: StateView {
///     var stateBody: some View {
///         let (isPending, start) = useTransition()
///
///         Button(isPending ? "Submitting…" : "Submit") {
///             start {
///                 try? await submitForm()
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useTransition() -> (isPending: Bool, start: (@MainActor @escaping () async -> Void) -> Void) {
    guard let context = StateRuntime.current else {
        fatalError("useTransition must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    if context.states.count <= index {
        context.states.append(StateSignal(false))
    }

    // swiftlint:disable:next force_cast
    let pendingSignal = context.states[index] as! StateSignal<Bool>
    let isPending = pendingSignal.value

    let start: (@MainActor @escaping () async -> Void) -> Void = { work in
        pendingSignal.value = true
        Task { @MainActor in
            await work()
            pendingSignal.value = false
        }
    }

    return (isPending, start)
}
