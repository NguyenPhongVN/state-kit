import Combine

// MARK: - Internal storage

final class _HookPublisherBox<Output> {
    let signal: StateSignal<PublisherPhase<Output>>
    var deps: [AnyHashable]?
    var cancellable: AnyCancellable?

    init(initialPhase: PublisherPhase<Output>, deps: [AnyHashable]?) {
        self.signal = StateSignal(initialPhase)
        self.deps = deps
    }

    deinit {
        cancellable?.cancel()
    }
}

@MainActor
private func _startPublisher<P: Publisher>(
    box: _HookPublisherBox<P.Output>,
    deps: [AnyHashable],
    publisher: P
) {
    box.cancellable?.cancel()
    box.deps = deps
    box.signal.value = .idle

    box.cancellable = publisher.sink { completion in
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

// MARK: - Public API

/// Subscribes to a Combine publisher and exposes its latest event as a signal.
///
/// The subscription is:
/// - started immediately on the first call,
/// - restarted whenever the `deps` array changes (shallow equality),
/// - cancelled automatically when:
///   - `deps` change (previous subscription is cancelled before starting a new one), or
///   - the underlying `HookScope` / `HookContext` is deallocated (view is destroyed).
///
/// - Parameters:
///   - publisher: Publisher factory. It is called on first render and whenever
///                `deps` change. Use this to capture the current inputs.
///   - deps: Dependency array. If it changes between renders, the publisher is re-subscribed.
/// - Returns: A `StateSignal` of `PublisherPhase<P.Output>` reflecting the latest event.
///
/// ### Example
/// ```swift
/// struct SearchView: HookView {
///     let service: SearchService
///     let query: String
///
///     var hookBody: some View {
///         let phase = usePublisher({
///             service.search(query: query)
///         }, deps: [query])
///
///         switch phase.value {
///         case .idle:
///             ProgressView()
///         case .value(let results):
///             ResultsList(results: results)
///         case .finished:
///             EmptyView()
///         case .failure(let error):
///             Text(error.localizedDescription)
///         }
///     }
/// }
/// ```
@MainActor
public func usePublisher<P: Publisher>(
    _ publisher: @escaping () -> P,
    deps: [AnyHashable]
) -> PublisherPhase<P.Output> {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }

    let index = context.nextIndex()

    let box: _HookPublisherBox<P.Output>

    if context.states.count <= index {
        box = _HookPublisherBox(initialPhase: .idle, deps: nil)
        context.states.append(box)
        _startPublisher(box: box, deps: deps, publisher: publisher())
    } else {
        box = context.states[index] as! _HookPublisherBox<P.Output>
        if box.deps != deps {
            _startPublisher(box: box, deps: deps, publisher: publisher())
        }
    }

    return box.signal.value
}

/// Convenience overload: variadic `deps`.
@MainActor
public func usePublisher<P: Publisher>(
    _ publisher: @escaping () -> P,
    _ deps: AnyHashable...
) -> PublisherPhase<P.Output> {
    usePublisher(publisher, deps: deps)
}

/// Convenience overload with no `deps`.
///
/// The publisher is subscribed once during the lifetime of the surrounding `HookScope`.
@MainActor
public func usePublisher<P: Publisher>(
    _ publisher: @escaping () -> P
) -> PublisherPhase<P.Output> {
    usePublisher(publisher, deps: [])
}
