import Combine

/// StateKitCombine — Combine-focused convenience extensions layered on top of
/// the core `StateKit` hook runtime.
///
/// Import this module when you want ergonomic bridges between Combine
/// publishers and `PublisherPhase`, while keeping the underlying hook APIs in
/// `StateKit`.

// MARK: - Publisher — hook bridge

public extension Publisher {

    /// Subscribes to this publisher inside the current `StateScope` and
    /// returns its latest `PublisherPhase`.
    ///
    /// Shorthand for `usePublisher(updateStrategy:) { self }`. The publisher
    /// is subscribed immediately on the first render. On subsequent renders
    /// the subscription is restarted only when `updateStrategy` changes.
    ///
    /// Must be called inside a `StateScope` closure or a
    /// `StateView.stateBody`.
    ///
    /// ```swift
    /// var stateBody: some View {
    ///     let phase = searchPublisher.asPhase(updateStrategy: .preserved(by: query))
    ///
    ///     switch phase {
    ///     case .idle:           ProgressView()
    ///     case .value(let r):  ResultsList(r)
    ///     case .finished:      EmptyView()
    ///     case .failure(let e): Text(e.localizedDescription)
    ///     }
    /// }
    /// ```
    @MainActor
    func asPhase(updateStrategy: UpdateStrategy? = .once) -> PublisherPhase<Output> {
        usePublisher(updateStrategy: updateStrategy) { self }
    }

    /// Returns a non-failing publisher that maps every event from `self` into
    /// a `PublisherPhase<Output>` value.
    ///
    /// The returned stream:
    /// - Starts with `.idle` before any upstream event.
    /// - Emits `.value(output)` for each value received.
    /// - Emits `.finished` when the upstream completes normally.
    /// - Emits `.failure(error)` and completes when the upstream fails.
    ///
    /// Use this operator to convert any publisher pipeline into a phase
    /// stream outside of a `StateScope` — for example when bridging Combine
    /// pipelines into `@Observable` view models.
    func materializeAsPhase() -> AnyPublisher<PublisherPhase<Output>, Never> {
        self
            .map { PublisherPhase.value($0) }
            .catch { Just(.failure($0)) }
            .prepend(.idle)
            .eraseToAnyPublisher()
    }
}

// MARK: - PublisherPhase — publisher bridge

public extension PublisherPhase {

    /// Returns an `AnyPublisher` that immediately emits this phase value and
    /// completes, without ever failing.
    ///
    /// Useful for building stub publishers in previews or tests:
    ///
    /// ```swift
    /// let preview: AnyPublisher<PublisherPhase<[User]>, Never> =
    ///     PublisherPhase.value([.mock]).asPublisher()
    /// ```
    func asPublisher() -> AnyPublisher<PublisherPhase<Output>, Never> {
        Just(self).eraseToAnyPublisher()
    }
}
