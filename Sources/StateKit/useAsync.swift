import Foundation

/// Internal storage box for `useAsync`.
///
/// Keeps the current `AsyncPhase` in a `StateSignal`, remembers
/// the last dependency array, and holds a reference to the active `Task`.
/// The task is automatically cancelled when this box is deallocated,
/// which happens when the enclosing `HookScope` / `HookContext` is destroyed.
final class _HookAsyncBox<Value> {
    let signal: StateSignal<AsyncPhase<Value>>
    var deps: [AnyHashable]?
    var task: Task<Void, Never>?

    init(initialPhase: AsyncPhase<Value>, deps: [AnyHashable]?) {
        self.signal = StateSignal(initialPhase)
        self.deps = deps
    }

    deinit {
        // When the view / HookScope is destroyed, make sure we cancel
        // the underlying async task to avoid leaks and unwanted side effects.
        task?.cancel()
    }
}

@MainActor
private func _startAsync<Value>(
    box: _HookAsyncBox<Value>,
    deps: [AnyHashable],
    operation: @escaping () async throws -> Value
) {
    // Cancel any in-flight task before starting a new one.
    box.task?.cancel()

    box.deps = deps
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

/// Runs an async operation and exposes its state as an `AsyncPhase` signal.
///
/// The operation is:
/// - started immediately on the first call,
/// - re-started whenever the `deps` array changes (shallow equality),
/// - cancelled automatically when:
///   - `deps` change (previous task is cancelled before starting a new one), or
///   - the underlying `HookScope` / `HookContext` is deallocated (view is destroyed).
///
/// Typical usage:
/// ```swift
/// let userRequest = useAsync({
///     try await api.fetchUser(id: userId)
/// }, deps: [userId])
///
/// switch userRequest.value {
/// case .idle, .loading:
///     ProgressView()
/// case .success(let user):
///     Text(user.name)
/// case .failure(let error):
///     Text(error.localizedDescription)
/// }
/// ```
///
/// - Parameters:
///   - operation: Async throwing closure to execute.
///   - deps: Dependency array. If it changes between renders, the operation is re-run.
/// - Returns: A `StateSignal` of `AsyncPhase<Value>` you can bind to your UI.
@MainActor
public func useAsync<Value>(
    _ operation: @escaping () async throws -> Value,
    deps: [AnyHashable]
) -> StateSignal<AsyncPhase<Value>> {

    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }

    let index = context.nextIndex()

    let box: _HookAsyncBox<Value>

    if context.states.count <= index {
        // Lần đầu: tạo box, lưu vào context và kick off task.
        box = _HookAsyncBox(initialPhase: .idle, deps: nil)
        context.states.append(box)
        _startAsync(box: box, deps: deps, operation: operation)
    } else {
        box = context.states[index] as! _HookAsyncBox<Value>

        // Nếu deps thay đổi -> chạy lại tác vụ.
        if box.deps != deps {
            _startAsync(box: box, deps: deps, operation: operation)
        }
    }

    return box.signal
}

/// Convenience overload: variadic `deps`.
///
/// Equivalent to passing an array, but nicer at the call-site:
/// ```swift
/// let state = useAsync({
///     try await api.search(query: query, page: page)
/// }, query, page)
/// ```
@MainActor
public func useAsync<Value>(
    _ operation: @escaping () async throws -> Value,
    _ deps: AnyHashable...
) -> StateSignal<AsyncPhase<Value>> {
    useAsync(operation, deps: deps)
}

/// Convenience overload with no `deps`.
///
/// The operation is started once during the lifetime of the surrounding `HookScope`
/// and will not automatically re-run unless the view tree is rebuilt with a fresh scope.
///
/// ```swift
/// let config = useAsync {
///     try await api.loadConfig()
/// }
/// ```
@MainActor
public func useAsync<Value>(
    _ operation: @escaping () async throws -> Value
) -> StateSignal<AsyncPhase<Value>> {
    useAsync(operation, deps: [])
}

/// Convenience overload for non-throwing async operations.
///
/// This simply wraps the non-throwing operation into a throwing one.
/// Cancellation semantics and dependency behaviour are identical to the
/// throwing base overload.
@MainActor
public func useAsync<Value>(
    _ operation: @escaping () async -> Value,
    deps: [AnyHashable]
) -> StateSignal<AsyncPhase<Value>> {
    useAsync({ () async throws -> Value in
        return await operation()
    }, deps: deps)
}

/// Convenience overload for non-throwing async operations with variadic `deps`.
///
/// See the throwing overload for detailed behaviour.
@MainActor
public func useAsync<Value>(
    _ operation: @escaping () async -> Value,
    _ deps: AnyHashable...
) -> StateSignal<AsyncPhase<Value>> {
    useAsync(operation, deps: deps)
}

/// Convenience overload for non-throwing async operations with no `deps`.
///
/// The operation is started once during the lifetime of the surrounding `HookScope`.
@MainActor
public func useAsync<Value>(
    _ operation: @escaping () async -> Value
) -> StateSignal<AsyncPhase<Value>> {
    useAsync(operation, deps: [])
}
