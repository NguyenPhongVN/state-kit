import Foundation

// MARK: - Internal storage

/// Internal box that owns a single iteration `Task` for a `useAsyncSequence`
/// hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// The box is allocated once on the first render and lives for the lifetime
/// of the enclosing `StateScope`.
///
/// - `signal`: `@Observable` container updated on every element the sequence
///   yields and on terminal events (`.finished`, `.failure`), triggering a
///   re-render of the `StateScope` each time.
/// - `updateStrategy`: the strategy stored from the last render, used on the
///   next render to decide whether to restart iteration.
/// - `task`: the active iteration `Task`. The `didSet` observer automatically
///   cancels the previous task whenever a new one is assigned, ensuring at
///   most one active iteration per slot at any time. Also cancelled in
///   `deinit` when the `StateScope` is removed from the view hierarchy.
final class _HookAsyncSequenceBox<Element> {
    let signal: StateSignal<AsyncSequencePhase<Element>>
    var updateStrategy: UpdateStrategy?
    var task: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }

    init(updateStrategy: UpdateStrategy?) {
        self.signal = StateSignal(.idle)
        self.updateStrategy = updateStrategy
    }

    deinit {
        task?.cancel()
    }
}

// MARK: - Private runner

/// Cancels any in-flight task on `box`, sets the phase to `.loading`, then
/// spawns a new `@MainActor` `Task` that iterates `sequence`.
///
/// Phase transitions written to `box.signal.value`:
/// - `.loading` — immediately when the task starts.
/// - `.value(element)` — on each element yielded by the sequence.
/// - `.finished` — when the iterator returns `nil` (sequence exhausted).
/// - `.failure(error)` — when the sequence throws.
///
/// Cancellation is checked with `guard !Task.isCancelled` after **every**
/// suspension point — after each element, after the loop exits, and in the
/// catch block — to avoid writing stale phase values from a superseded
/// iteration. This is stricter than `useAsync`, which only checks once after
/// the entire operation completes.
@MainActor
private func _startAsyncSequence<S: AsyncSequence>(
    box: _HookAsyncSequenceBox<S.Element>,
    updateStrategy: UpdateStrategy,
    sequence: S
) {
    box.task?.cancel()
    box.updateStrategy = updateStrategy
    box.signal.value = .loading

    box.task = Task { @MainActor in
        do {
            for try await element in sequence {
                guard !Task.isCancelled else { return }
                box.signal.value = .value(element)
            }
            guard !Task.isCancelled else { return }
            box.signal.value = .finished
        } catch {
            guard !Task.isCancelled else { return }
            box.signal.value = .failure(error)
        }
    }
}

// MARK: - Public API

/// Iterates an `AsyncSequence` and returns its current lifecycle phase as an
/// `AsyncSequencePhase` value.
///
/// On the first render a `_HookAsyncSequenceBox` is stored at the current
/// hook index, the phase is set to `.loading`, and iteration begins
/// immediately in a new `@MainActor` `Task`. Each element the sequence yields
/// updates the phase to `.value(element)` and triggers a re-render, allowing
/// the view to reflect every emission. When the sequence is exhausted the
/// phase becomes `.finished`; if it throws, `.failure`.
///
/// On every subsequent render the stored `UpdateStrategy.Dependency` is
/// compared against the one passed on this render using `!=`. If they differ
/// the in-flight task is cancelled, the phase resets to `.loading`, and a
/// new iteration task is spawned. If they are equal the current phase is
/// returned unchanged.
///
/// The active task is cancelled automatically when the `StateScope` is removed
/// from the view hierarchy (the `_HookAsyncSequenceBox` is deallocated).
///
/// Unlike `useAsync` — which models a single result — `useAsyncSequence`
/// models a stream: the phase can transition through multiple `.value` states
/// before eventually reaching `.finished` or `.failure`.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - updateStrategy: Controls when iteration is restarted. Passed as an
///     unlabelled argument.
///     - `.once` (default) — iterates exactly once on the first render.
///     - `.preserved(by:)` — restarts iteration whenever the dependency value
///       changes between renders.
///   - sequence: A factory closure that produces the `AsyncSequence` to
///     iterate. Called on the first render and each time `updateStrategy`
///     changes.
/// - Returns: The current `AsyncSequencePhase<S.Element>` stored in the
///   signal: `.loading` while iterating, `.value` on each emission,
///   `.finished` when exhausted, or `.failure` on error.
///
/// ### Example
/// ```swift
/// struct ClockView: StateView {
///     var stateBody: some View {
///         let phase = useAsyncSequence {
///             AsyncTimerSequence(interval: .seconds(1)).map { Date() }
///         }
///
///         switch phase {
///         case .idle, .loading:
///             ProgressView()
///         case .value(let date):
///             Text(date.formatted())
///         case .finished:
///             Text("Stream ended")
///         case .failure(let error):
///             Text(error.localizedDescription)
///         }
///     }
/// }
/// ```
@MainActor
public func useAsyncSequence<S: AsyncSequence>(
    updateStrategy: UpdateStrategy = .once,
    _ sequence: @escaping () -> S
) -> AsyncSequencePhase<S.Element> {

    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()
    let box: _HookAsyncSequenceBox<S.Element>

    if context.states.count <= index {
        box = _HookAsyncSequenceBox(updateStrategy: nil)
        context.states.append(box)
        _startAsyncSequence(box: box, updateStrategy: updateStrategy, sequence: sequence())
    } else {
        box = context.states[index] as! _HookAsyncSequenceBox<S.Element>
        if box.updateStrategy?.dependency != updateStrategy.dependency {
            _startAsyncSequence(box: box, updateStrategy: updateStrategy, sequence: sequence())
        }
    }

    return box.signal.value
}
