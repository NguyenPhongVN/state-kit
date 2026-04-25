import Foundation

// MARK: - Internal storage

private final class _HookAsyncPerformBox<Value> {
    let signal: StateSignal<AsyncPhase<Value>>
    var updateStrategy: UpdateStrategy?
    var task: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }
    var start: (@MainActor () -> Void)?

    init(updateStrategy: UpdateStrategy?) {
        self.signal = StateSignal(.idle)
        self.updateStrategy = updateStrategy
    }

    deinit {
        task?.cancel()
    }
}

// MARK: - Public API

/// Returns the current `AsyncPhase` plus an imperative `perform()` function
/// that starts the async operation on demand.
///
/// Unlike `useAsync`, this hook does **not** start automatically during
/// render. The operation is only launched when the returned `perform`
/// function is called.
///
/// If `perform()` is called while a previous task is still running, the old
/// task is cancelled and replaced by the new one. When `updateStrategy`
/// changes between renders, any in-flight task is cancelled, the phase is
/// reset to `.idle`, and future `perform()` calls use the latest operation.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - updateStrategy: Controls when the stored operation is replaced.
///     - `.once` (default) — captures the operation once and keeps it.
///     - `.preserved(by:)` — replaces the stored operation whenever the
///       dependency changes between renders.
///     - `nil` — same as `.once`.
///   - priority: The priority used for the spawned `Task`.
///   - operation: The async throwing operation to execute when `perform()`
///     is called.
/// - Returns: A tuple containing the current `AsyncPhase<Value>` and a
///   `perform()` function that starts the operation.
///
/// ### Example
/// ```swift
/// struct DownloadView: StateView {
///     let url: URL
///
///     var stateBody: some View {
///         let (phase, perform) = useAsyncPerform(updateStrategy: .preserved(by: url)) {
///             try await URLSession.shared.data(from: url)
///         }
///
///         VStack {
///             Button("Fetch") { perform() }
///
///             switch phase {
///             case .idle:
///                 Text("Ready")
///             case .loading:
///                 ProgressView()
///             case .success(let payload):
///                 Text("Downloaded \(payload.0.count) bytes")
///             case .failure(let error):
///                 Text(error.localizedDescription)
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func useAsyncPerform<Value>(
    updateStrategy: UpdateStrategy? = .once,
    priority: TaskPriority? = nil,
    _ operation: @escaping @Sendable () async throws -> Value
) -> (phase: AsyncPhase<Value>, perform: @MainActor () -> Void) {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()
    let box: _HookAsyncPerformBox<Value>

    if context.states.count <= index {
        box = _HookAsyncPerformBox(updateStrategy: updateStrategy)
        context.states.append(box)
    } else {
        box = context.states[index] as! _HookAsyncPerformBox<Value>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            box.task?.cancel()
            box.signal.value = .idle
            box.updateStrategy = updateStrategy
        }
    }

    box.start = {
        box.signal.value = .loading
        box.task = Task(priority: priority) { @MainActor in
            do {
                let value = try await operation()
                guard !Task.isCancelled else { return }
                box.signal.value = .success(value)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                box.signal.value = .failure(error)
            }
        }
    }

    let perform = useCallback(updateStrategy: .once, {
        box.start?()
    } as @MainActor () -> Void)

    return (box.signal.value, perform)
}

/// Returns the current `AsyncPhase` plus an imperative `perform()` function
/// that starts a non-throwing async operation on demand.
///
/// This overload behaves the same as the throwing version, but since the
/// operation cannot fail, the phase transitions only through `.idle`,
/// `.loading`, and `.success`.
@MainActor
public func useAsyncPerform<Value>(
    updateStrategy: UpdateStrategy? = .once,
    priority: TaskPriority? = nil,
    _ operation: @escaping @Sendable () async -> Value
) -> (phase: AsyncPhase<Value>, perform: @MainActor () -> Void) {
    let throwingOperation: @Sendable () async throws -> Value = {
        await operation()
    }
    return useAsyncPerform(
        updateStrategy: updateStrategy,
        priority: priority,
        throwingOperation
    )
}
