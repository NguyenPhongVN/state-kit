import Combine

// MARK: - Internal storage

/// Internal box that owns a single Combine subscription for a `usePublisher`
/// hook slot.
///
/// Stored in `StateRuntime.current.states` at the hook's index position.
/// The box is allocated once on the first render and lives for the lifetime
/// of the enclosing `StateScope`.
///
/// - `signal`: `@Observable` container whose value is updated on every
///   publisher event, triggering a re-render of the `StateScope`.
/// - `updateStrategy`: the strategy stored from the last render, used on the
///   next render to decide whether to restart the subscription.
/// - `cancellable`: holds the active Combine subscription; replaced (and the
///   previous subscription cancelled) each time the publisher is restarted.
///   Cancelled automatically when the box is deallocated (view destroyed).
final class _HookPublisherBox<Output> {
    let signal: StateSignal<PublisherPhase<Output>>
    var updateStrategy: UpdateStrategy?
    var cancellable: AnyCancellable?

    init(initialPhase: PublisherPhase<Output>, updateStrategy: UpdateStrategy?) {
        self.signal = StateSignal(initialPhase)
        self.updateStrategy = updateStrategy
    }

    deinit {
        cancellable?.cancel()
    }
}

/// Cancels any existing subscription on `box`, resets the phase to `.idle`,
/// then starts a new Combine subscription to `publisher`.
///
/// Publisher events are mapped to `PublisherPhase` cases and written to
/// `box.signal.value`:
/// - `receiveValue` → `.value(output)`
/// - `.finished`   → `.finished`
/// - `.failure`    → `.failure(error)`
///
/// Because `StateSignal` is `@Observable`, each write triggers a re-render
/// of the enclosing `StateScope`.
@MainActor
private func _startPublisher<P: Publisher>(
    box: _HookPublisherBox<P.Output>,
    updateStrategy: UpdateStrategy?,
    publisher: P
) {
    box.cancellable?.cancel()
    box.updateStrategy = updateStrategy
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

/// Subscribes to a Combine publisher and returns its latest event as a
/// `PublisherPhase` value.
///
/// On the first render a `_HookPublisherBox` is stored at the current hook
/// index and the publisher is subscribed to immediately, setting the phase
/// to `.idle` before any values arrive.
///
/// On every subsequent render the stored `UpdateStrategy.Dependency` is
/// compared against the one passed on this render using `!=`. If they differ
/// the existing subscription is cancelled, the phase resets to `.idle`, and
/// a new subscription is started via the `publisher` factory. If they are
/// equal the current phase is returned unchanged.
///
/// The subscription is cancelled automatically when the enclosing `StateScope`
/// is removed from the view hierarchy (the `_HookPublisherBox` is deallocated).
///
/// Must be called inside a `StateScope` closure or a `StateView.stateBody`,
/// and must be called in a stable order across renders (no conditionals or
/// loops around hook calls).
///
/// - Parameters:
///   - updateStrategy: Controls when the publisher is restarted.
///     - `nil` — never restarted after the first render.
///     - `.once` — same as `nil`; subscribed exactly once.
///     - `.preserved(by:)` — restarted whenever the dependency value changes.
///   - publisher: A factory closure that produces the publisher to subscribe
///     to. Called on the first render and each time `updateStrategy` changes.
/// - Returns: The current `PublisherPhase<P.Output>` stored in the signal:
///   `.idle` before the first value, `.value` on each emission, `.finished`
///   or `.failure` on completion.
///
/// ### Example
/// ```swift
/// struct SearchView: StateView {
///     let service: SearchService
///     let query: String
///
///     var stateBody: some View {
///         let phase = usePublisher(updateStrategy: .preserved(by: query)) {
///             service.search(query: query)
///         }
///
///         switch phase {
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
    updateStrategy: UpdateStrategy?,
    _ publisher: @escaping () -> P
) -> PublisherPhase<P.Output> {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside StateRuntime")
    }

    let index = context.nextIndex()

    let box: _HookPublisherBox<P.Output>

    if context.states.count <= index {
        box = _HookPublisherBox(initialPhase: .idle, updateStrategy: nil)
        context.states.append(box)
        _startPublisher(box: box, updateStrategy: updateStrategy, publisher: publisher())
    } else {
        box = context.states[index] as! _HookPublisherBox<P.Output>
        if box.updateStrategy?.dependency != updateStrategy?.dependency {
            _startPublisher(box: box, updateStrategy: updateStrategy, publisher: publisher())
        }
    }

    return box.signal.value
}
