import Combine

// MARK: - Internal storage

private final class _HookPublisherPerformBox<Output> {
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

/// Returns the current `PublisherPhase` plus an imperative `perform()`
/// function that subscribes to the publisher on demand.
///
/// Unlike `usePublisher`, this hook does **not** subscribe during render.
/// The publisher is only created and subscribed to when the returned
/// `perform()` function is called.
///
/// If `perform()` is called while a previous subscription is still active,
/// the old subscription is cancelled and replaced by the new one. When
/// `updateStrategy` changes between renders, any active subscription is
/// cancelled, the phase resets to `.idle`, and future `perform()` calls use
/// the latest publisher factory.
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
///     to when `perform()` is called.
/// - Returns: A tuple containing the current `PublisherPhase<P.Output>` and a
///   `perform()` function that starts the subscription.
///
/// ### Example
/// ```swift
/// struct SearchView: StateView {
///     let service: SearchService
///     let query: String
///
///     var stateBody: some View {
///         let (phase, perform) = usePublisherPerform(updateStrategy: .preserved(by: query)) {
///             service.search(query: query)
///         }
///
///         VStack {
///             Button("Search") { perform() }
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
public func usePublisherPerform<P: Publisher>(
    updateStrategy: UpdateStrategy? = .once,
    _ publisher: @escaping () -> P
) -> (phase: PublisherPhase<P.Output>, perform: @MainActor () -> Void) {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()
    let box: _HookPublisherPerformBox<P.Output>

    if context.states.count <= index {
        box = _HookPublisherPerformBox(updateStrategy: updateStrategy)
        context.states.append(box)
    } else {
        box = context.states[index] as! _HookPublisherPerformBox<P.Output>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            box.cancellable?.cancel()
            box.cancellable = nil
            box.signal.value = .idle
            box.updateStrategy = updateStrategy
        }
    }

    box.start = {
        box.cancellable?.cancel()
        box.signal.value = .idle
        box.cancellable = publisher().sink { completion in
            switch completion {
            case .finished:
                box.signal.value = .finished
            case .failure(let error):
                box.signal.value = .failure(error)
            }
        } receiveValue: { output in
            box.signal.value = .value(output)
        }
    }

    let perform = useCallback(updateStrategy: .once, {
        box.start?()
    } as @MainActor () -> Void)

    return (box.signal.value, perform)
}
