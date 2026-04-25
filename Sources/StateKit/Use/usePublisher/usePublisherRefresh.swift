import Combine

// MARK: - Internal storage

private final class _HookPublisherRefreshBox<Output> {
    let signal: StateSignal<PublisherPhase<Output>>
    var updateStrategy: UpdateStrategy?
    var cancellable: AnyCancellable?
    var start: (@MainActor () -> Void)?

    init(updateStrategy: UpdateStrategy?) {
        self.signal = StateSignal(.idle)
        self.updateStrategy = updateStrategy
    }

    deinit {
        cancellable?.cancel()
    }
}

// MARK: - Public API

/// Returns the current `PublisherPhase` plus an imperative `refresh()`
/// function that subscribes to the publisher on demand while preserving the
/// last successful value across later refreshes.
///
/// Behavior:
/// - Initial state is `.idle`.
/// - On the first `refresh()`, the publisher is subscribed to and the phase
///   remains `.idle` until the first event arrives.
/// - On value, phase becomes `.value(output)`.
/// - On later `refresh()` calls, if a previous `.value(oldOutput)` exists,
///   that value is kept visible while the new subscription is running.
/// - If a later refresh fails after a prior value, the old value is kept.
/// - If no prior value exists and the publisher fails, phase becomes
///   `.failure(error)`.
/// - If the publisher finishes without emitting and no prior value exists,
///   phase becomes `.finished`.
/// - If the publisher finishes after a prior value, the last `.value` is kept.
///
/// If `refresh()` is called while a previous subscription is still active,
/// the old subscription is cancelled and replaced by the new one.
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - updateStrategy: Controls when the stored publisher factory is replaced.
///     - `.once` (default) — captures the publisher factory once and keeps it.
///     - `.preserved(by:)` — replaces the stored factory whenever the
///       dependency changes between renders.
///     - `nil` — same as `.once`.
///   - publisher: A factory closure that produces the publisher to subscribe
///     to when `refresh()` is called.
/// - Returns: A tuple containing the current `PublisherPhase<P.Output>` and a
///   `refresh()` function that starts the subscription.
///
/// ### Example
/// ```swift
/// struct SearchView: StateView {
///     let service: SearchService
///     let query: String
///
///     var stateBody: some View {
///         let (phase, refresh) = usePublisherRefresh(updateStrategy: .preserved(by: query)) {
///             service.search(query: query)
///         }
///
///         VStack {
///             Button("Refresh") { refresh() }
///
///             switch phase {
///             case .idle:
///                 Text("Ready")
///             case .value(let results):
///                 ResultsList(results: results)
///             case .finished:
///                 Text("Done")
///             case .failure(let error):
///                 Text(error.localizedDescription)
///             }
///         }
///     }
/// }
/// ```
@MainActor
public func usePublisherRefresh<P: Publisher>(
    updateStrategy: UpdateStrategy? = .once,
    _ publisher: @escaping () -> P
) -> (phase: PublisherPhase<P.Output>, refresh: @MainActor () -> Void) {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()
    let box: _HookPublisherRefreshBox<P.Output>

    if context.states.count <= index {
        box = _HookPublisherRefreshBox(updateStrategy: updateStrategy)
        context.states.append(box)
    } else {
        box = context.states[index] as! _HookPublisherRefreshBox<P.Output>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            box.cancellable?.cancel()
            box.cancellable = nil
            box.signal.value = .idle
            box.updateStrategy = updateStrategy
        }
    }

    box.start = {
        let previousOutput = box.signal.value.output

        box.cancellable?.cancel()
        box.cancellable = publisher().sink { completion in
            switch completion {
            case .finished:
                if previousOutput == nil {
                    box.signal.value = .finished
                }
            case .failure(let error):
                if previousOutput == nil {
                    box.signal.value = .failure(error)
                }
            }
        } receiveValue: { output in
            box.signal.value = .value(output)
        }
    }

    let refresh = useCallback(updateStrategy: .once, {
        box.start?()
    } as @MainActor () -> Void)

    return (box.signal.value, refresh)
}
