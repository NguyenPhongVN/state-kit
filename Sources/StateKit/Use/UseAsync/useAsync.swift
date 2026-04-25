import Foundation

// MARK: - Internal storage

/// Internal box that owns a single async `Task` for a `useAsync` hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// The box is allocated once on the first render and lives for the lifetime
/// of the enclosing `StateScope`.
///
/// - `signal`: `@Observable` container whose value is updated as the task
///   progresses through its lifecycle (`.idle` → `.loading` → `.success` /
///   `.failure`), triggering a re-render of the `StateScope` on each change.
/// - `updateStrategy`: the strategy stored from the last render, used on the
///   next render to decide whether to restart the task.
/// - `task`: the active `Task`. The `didSet` observer automatically cancels
///   the previous task whenever a new one is assigned, ensuring at most one
///   in-flight operation per slot at any time. Also cancelled in `deinit`
///   when the `StateScope` is removed from the view hierarchy.
private final class _HookAsyncBox<Value> {
    let signal: StateSignal<AsyncPhase<Value>>
    var updateStrategy: UpdateStrategy?
    var task: Task<Void, Never>? {
        didSet {
            oldValue?.cancel()
        }
    }

    init(initialPhase: AsyncPhase<Value>, updateStrategy: UpdateStrategy?) {
        self.signal = StateSignal(initialPhase)
        self.updateStrategy = updateStrategy
    }

    deinit {
        task?.cancel()
    }
}

/// Cancels any in-flight task on `box`, sets the phase to `.loading`, then
/// spawns a new `@MainActor` `Task` that runs `operation`.
///
/// Phase transitions written to `box.signal.value`:
/// - `.loading` — immediately when the task starts.
/// - `.success(value)` — when `operation` returns successfully and the task
///   has not been cancelled in the meantime.
/// - `.failure(error)` — when `operation` throws and the task has not been
///   cancelled in the meantime.
///
/// Cancellation is checked after `await` returns to avoid overwriting the
/// phase with a stale result from a superseded operation.
@MainActor
private func _startAsync<Value>(
    box: _HookAsyncBox<Value>,
    updateStrategy: UpdateStrategy,
    operation: @escaping () async throws -> Value
) {
    box.task?.cancel()
    box.updateStrategy = updateStrategy
    box.signal.value = .loading

    box.task = Task { @MainActor in
        do {
            let value = try await operation()
            if Task.isCancelled { return }
            box.signal.value = .success(value)
        } catch {
            if Task.isCancelled { return }
            box.signal.value = .failure(error)
        }
    }
}

// MARK: - Public API

/// Runs an async throwing operation and returns its current lifecycle phase
/// as an `AsyncPhase` value.
///
/// On the first render a `_HookAsyncBox` is stored at the current hook index,
/// the phase is set to `.loading`, and the operation is launched immediately
/// in a new `@MainActor` `Task`.
///
/// On every subsequent render the stored `UpdateStrategy.Dependency` is
/// compared against the one passed on this render using `!=`. If they differ
/// the in-flight task is cancelled, the phase resets to `.loading`, and a new
/// task is spawned. If they are equal the current phase is returned unchanged.
///
/// The active task is cancelled automatically when the `StateScope` is removed
/// from the view hierarchy (the `_HookAsyncBox` is deallocated).
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - updateStrategy: Controls when the operation is re-run.
///     - `.once` (default) — the operation runs exactly once on the first render.
///     - `.preserved(by:)` — the operation is re-run whenever the dependency
///       value changes between renders.
///   - operation: An async throwing closure to execute. Called on the first
///     render and each time `updateStrategy` changes.
/// - Returns: The current `AsyncPhase<Value>` stored in the signal:
///   `.idle` before the first launch (never in practice, since the task starts
///   immediately), `.loading` while running, `.success` or `.failure` on
///   completion.
///
/// ### Example
/// ```swift
/// struct UserProfileView: StateView {
///     let userId: String
///
///     var stateBody: some View {
///         let phase = useAsync(updateStrategy: .preserved(by: userId)) {
///             try await api.fetchUser(id: userId)
///         }
///
///         switch phase {
///         case .idle, .loading:
///             ProgressView()
///         case .success(let user):
///             Text(user.name)
///         case .failure(let error):
///             Text(error.localizedDescription)
///         }
///     }
/// }
/// ```
@MainActor
public func useAsync<Value>(
    updateStrategy: UpdateStrategy = .once,
    _ operation: @escaping () async throws -> Value
) -> AsyncPhase<Value> {

    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    let box: _HookAsyncBox<Value>

    if context.states.count <= index {
        box = _HookAsyncBox(initialPhase: .idle, updateStrategy: nil)
        context.states.append(box)
        _startAsync(box: box, updateStrategy: updateStrategy, operation: operation)
    } else {
        box = context.states[index] as! _HookAsyncBox<Value>
        if box.updateStrategy?.dependency != updateStrategy.dependency {
            _startAsync(box: box, updateStrategy: updateStrategy, operation: operation)
        }
    }

    return box.signal.value
}
