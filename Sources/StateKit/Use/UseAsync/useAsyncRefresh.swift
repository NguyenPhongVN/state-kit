import Foundation

// MARK: - Internal storage

private final class _HookAsyncRefreshBox<Value> {
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

/// Returns the current `AsyncPhase` plus an imperative `refresh()` function
/// that starts the async operation on demand while preserving the last
/// successful value across subsequent refreshes.
///
/// Behavior:
/// - Initial state is `.idle`.
/// - On the first `refresh()`, phase becomes `.loading`.
/// - On success, phase becomes `.success(value)`.
/// - On later `refresh()` calls, if a success value already exists, that
///   `.success(oldValue)` is kept visible while the new request is running.
/// - If a later refresh fails after a prior success, the old success is kept.
/// - If no prior success exists and the request fails, phase becomes
///   `.failure(error)`.
///
/// If `refresh()` is called while a previous task is still running, the old
/// task is cancelled and replaced by the new one.
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
///   - operation: The async throwing operation to execute when `refresh()`
///     is called.
/// - Returns: A tuple containing the current `AsyncPhase<Value>` and a
///   `refresh()` function that starts the operation.
///
/// ### Example
/// ```swift
/// struct FeedView: StateView {
///     let url: URL
///
///     var stateBody: some View {
///         let (phase, refresh) = useAsyncRefresh(updateStrategy: .preserved(by: url)) {
///             try await URLSession.shared.data(from: url)
///         }
///
///         VStack {
///             Button("Refresh") { refresh() }
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
public func useAsyncRefresh<Value>(
    updateStrategy: UpdateStrategy? = .once,
    priority: TaskPriority? = nil,
    _ operation: @escaping @Sendable () async throws -> Value
) -> (phase: AsyncPhase<Value>, refresh: @MainActor () -> Void) {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()
    let box: _HookAsyncRefreshBox<Value>

    if context.states.count <= index {
        box = _HookAsyncRefreshBox(updateStrategy: updateStrategy)
        context.states.append(box)
    } else {
        box = context.states[index] as! _HookAsyncRefreshBox<Value>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            box.task?.cancel()
            box.signal.value = .idle
            box.updateStrategy = updateStrategy
        }
    }

    box.start = {
        let previousSuccess = box.signal.value.value

        if previousSuccess == nil {
            box.signal.value = .loading
        }

        box.task = Task(priority: priority) { @MainActor in
            do {
                let value = try await operation()
                guard !Task.isCancelled else { return }
                box.signal.value = .success(value)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                if previousSuccess == nil {
                    box.signal.value = .failure(error)
                }
            }
        }
    }

    let refresh = useCallback(updateStrategy: .once, {
        box.start?()
    } as @MainActor () -> Void)

    return (box.signal.value, refresh)
}

/// Returns the current `AsyncPhase` plus an imperative `refresh()` function
/// for a non-throwing async operation.
///
/// This overload keeps the same refresh semantics as the throwing version,
/// but the phase can only move through `.idle`, `.loading`, and `.success`.
@MainActor
public func useAsyncRefresh<Value>(
    updateStrategy: UpdateStrategy? = .once,
    priority: TaskPriority? = nil,
    _ operation: @escaping @Sendable () async -> Value
) -> (phase: AsyncPhase<Value>, refresh: @MainActor () -> Void) {
    let throwingOperation: @Sendable () async throws -> Value = {
        await operation()
    }
    return useAsyncRefresh(
        updateStrategy: updateStrategy,
        priority: priority,
        throwingOperation
    )
}
