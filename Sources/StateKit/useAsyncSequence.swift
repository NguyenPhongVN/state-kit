import Foundation

/// Internal storage box for `useAsyncSequence`.
///
/// Stores the latest `AsyncPhase` in a `StateSignal`, remembers the last dependency
/// array, and holds a reference to the active `Task`.
///
/// The task is automatically cancelled when this box is deallocated, which happens
/// when the enclosing `HookScope` / `HookContext` is destroyed.
final class _HookAsyncSequenceBox<Element> {
    let signal: StateSignal<AsyncPhase<Element>>
    var deps: [AnyHashable]?
    var task: Task<Void, Never>?

    init(initialPhase: AsyncPhase<Element>, deps: [AnyHashable]?) {
        self.signal = StateSignal(initialPhase)
        self.deps = deps
    }

    deinit {
        task?.cancel()
    }
}

@MainActor
private func _startAsyncSequence<S: AsyncSequence>(
    box: _HookAsyncSequenceBox<S.Element>,
    deps: [AnyHashable],
    sequence: S
) {
    box.task?.cancel()

    box.deps = deps
    box.signal.value = .loading

    box.task = Task { @MainActor in
        do {
            // Emit every element as it arrives.
            for try await element in sequence {
                if Task.isCancelled { return }
                box.signal.value = .success(element)
            }

            // Sequence finished. We keep the last `.success` value as-is;
            // callers that need "finished" can model it in the element type.
        } catch {
            if Task.isCancelled { return }
            box.signal.value = .failure(error)
        }
    }
}

// MARK: - Public API

/// Consumes an `AsyncSequence` and exposes its latest element as an `AsyncPhase` signal.
///
/// The sequence is:
/// - started immediately on the first call,
/// - re-started whenever the `deps` array changes (shallow equality),
/// - cancelled automatically when:
///   - `deps` change (previous task is cancelled before starting a new one), or
///   - the underlying `HookScope` / `HookContext` is deallocated (view is destroyed).
///
/// The returned signal's phase is updated as follows:
/// - `.loading` when starting (or restarting),
/// - `.success(element)` for each element the sequence produces,
/// - `.failure(error)` if the sequence throws.
///
/// - Parameters:
///   - sequence: An async sequence factory. It is called on first render and whenever
///               `deps` change. Use this to capture the current inputs.
///   - deps: Dependency array. If it changes between renders, the sequence is restarted.
/// - Returns: A `StateSignal` of `AsyncPhase<S.Element>` reflecting the latest element/error.
///
/// ### Example
/// ```swift
/// struct ClockView: HookView {
///     var hookBody: some View {
///         let tick = useAsyncSequence({
///             AsyncTimerSequence(interval: .seconds(1))
///                 .map { Date() }
///         })
///
///         switch tick.value {
///         case .idle, .loading:
///             ProgressView()
///         case .success(let date):
///             Text(date.formatted())
///         case .failure(let error):
///             Text(error.localizedDescription)
///         }
///     }
/// }
/// ```
@MainActor
public func useAsyncSequence<S: AsyncSequence>(
    _ sequence: @escaping () -> S,
    deps: [AnyHashable]
) -> StateSignal<AsyncPhase<S.Element>> {

    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }

    let index = context.nextIndex()

    let box: _HookAsyncSequenceBox<S.Element>

    if context.states.count <= index {
        box = _HookAsyncSequenceBox(initialPhase: .idle, deps: nil)
        context.states.append(box)
        _startAsyncSequence(box: box, deps: deps, sequence: sequence())
    } else {
        box = context.states[index] as! _HookAsyncSequenceBox<S.Element>
        if box.deps != deps {
            _startAsyncSequence(box: box, deps: deps, sequence: sequence())
        }
    }

    return box.signal
}

/// Convenience overload: variadic `deps`.
@MainActor
public func useAsyncSequence<S: AsyncSequence>(
    _ sequence: @escaping () -> S,
    _ deps: AnyHashable...
) -> StateSignal<AsyncPhase<S.Element>> {
    useAsyncSequence(sequence, deps: deps)
}

/// Convenience overload with no `deps`.
///
/// The sequence is started once during the lifetime of the surrounding `HookScope`
/// and will not automatically restart unless the view tree is rebuilt with a fresh scope.
@MainActor
public func useAsyncSequence<S: AsyncSequence>(
    _ sequence: @escaping () -> S
) -> StateSignal<AsyncPhase<S.Element>> {
    useAsyncSequence(sequence, deps: [])
}
