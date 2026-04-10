import Combine
import StateKit

/// A Combine-backed atom that produces a `PublisherPhase<PublisherOutput>`.
///
/// Use `SKPublisherAtom` to subscribe to a Combine publisher and expose its
/// latest event as reactive atom state. The atom starts at `.idle`, transitions
/// to `.value(output)` on each emission, and terminates at `.finished` or
/// `.failure(error)`.
///
/// ## Defining a publisher atom
///
/// ```swift
/// struct PriceStreamAtom: SKPublisherAtom, Hashable {
///     typealias PublisherOutput = Double   // required in Swift 6.3 — see SKAtom docs
///     typealias AtomPublisher = AnyPublisher<Double, Never>
///     let symbol: String
///
///     func publisher(context: SKAtomTransactionContext) -> AnyPublisher<Double, Never> {
///         MarketFeed.shared.priceStream(for: symbol)
///     }
/// }
/// ```
///
/// ## Using it in a view
///
/// ```swift
/// struct PriceView: View {
///     @SKValue(PriceStreamAtom(symbol: "AAPL")) var phase
///
///     var body: some View {
///         switch phase {
///         case .idle:            ProgressView()
///         case .value(let p):   Text(String(format: "%.2f", p))
///         case .finished:       Text("Stream ended")
///         case .failure(let e): Text(e.localizedDescription)
///         }
///     }
/// }
/// ```
///
/// ## Watching other atoms
///
/// Call `context.watch(_:)` inside `publisher(context:)` to declare atom
/// dependencies. When a watched atom changes the existing subscription is
/// cancelled and `publisher(context:)` is called again with a fresh context.
///
/// ```swift
/// struct FilteredStreamAtom: SKPublisherAtom, Hashable {
///     typealias PublisherOutput = [Item]
///     typealias AtomPublisher = AnyPublisher<[Item], Never>
///
///     func publisher(context: SKAtomTransactionContext) -> AnyPublisher<[Item], Never> {
///         let filter = context.watch(FilterAtom())
///         return DataService.shared.stream().map { $0.filter(filter) }.eraseToAnyPublisher()
///     }
/// }
/// ```
///
/// ## Failing publishers
///
/// When the upstream publisher can fail, map the error before returning so the
/// failure surfaces cleanly as `.failure(error)` in the phase:
///
/// ```swift
/// func publisher(context: SKAtomTransactionContext) -> AnyPublisher<Data, any Error> {
///     URLSession.shared
///         .dataTaskPublisher(for: url)
///         .map(\.data)
///         .mapError { $0 as Error }
///         .eraseToAnyPublisher()
/// }
/// ```
public protocol SKPublisherAtom: SKAtom where Value == PublisherPhase<PublisherOutput> {

    /// The type of values emitted by this atom's publisher.
    associatedtype PublisherOutput

    /// The concrete publisher type returned by `publisher(context:)`.
    associatedtype AtomPublisher: Publisher where AtomPublisher.Output == PublisherOutput

    /// Creates and returns the Combine publisher for this atom.
    ///
    /// Called once when the atom is first accessed in a store, and again
    /// whenever a dependency atom changes (when `context.watch(_:)` is used
    /// inside this method).
    ///
    /// - Parameter context: A transaction context. Use `context.watch(_:)` to
    ///   register reactive dependencies that restart the subscription on change.
    ///   Use `context.read(_:)` for one-shot reads without dependency tracking.
    @MainActor
    func publisher(context: SKAtomTransactionContext) -> AtomPublisher
}

extension SKPublisherAtom {
    public func _getOrCreateBox(in store: SKAtomStore) -> SKAtomBox<Value> {
        MainActor.assumeIsolated { store.publisherBox(for: self) }
    }
}
