import Foundation
import StateKit
import Combine

// MARK: - StreamProviderElement

/// Internal element managing a StreamProvider's continuous stream of values.
///
/// `StreamProviderElement` is responsible for:
/// - Subscribing to the Combine publisher
/// - Receiving and caching successive values
/// - Tracking error states
/// - Notifying dependents on each value change
/// - Managing subscription lifecycle (cancellation on disposal)
///
/// **Lifecycle:**
/// 1. Created: Provider accessed, subscription established
/// 2. Loading: Stream starts, no values yet, state = .loading()
/// 3. Streaming: Values received, state = .data(value) updated on each value
/// 4. Error: Stream fails, state = .error(error)
/// 5. Disposed: Subscription cancelled, resources released
///
/// **Thread Safety:**
/// Confined to the MainActor. Stream events are bridged to the main thread via Task.
///
/// - Note: This is an internal implementation detail. Use StreamProvider macro to create stream-based providers.
@MainActor
public final class StreamProviderElement<T: Sendable>: ProviderElement<StreamProvider<T>> {

    // MARK: - Value Creation

    /// Subscribes to the stream and returns initial loading state.
    ///
    /// **Lifecycle:**
    /// 1. Creates a subscription to the Combine publisher
    /// 2. Returns .loading() immediately
    /// 3. As values arrive, updates state and notifies dependents
    /// 4. On error, updates state to .error()
    /// 5. On completion, keeps last value in cache
    ///
    /// - Returns: AsyncValue representing the stream's initial state
    public override func providerCreate() -> AsyncValue<T> {
        // Subscribe to the stream
        let cancellable = provider.stream(ref: self)
            .sink { completion in
                // Handle stream completion
                Task { @MainActor in
                    switch completion {
                    case .finished:
                        // Stream finished normally, keep last value
                        break

                    case .failure(let error):
                        // Stream failed, update to error state
                        let oldState = self.stateBox?.value
                        self.stateBox?.value = .error(error, previousData: oldState?.value)
                        self.notifyDependents()
                        self.container.notifyProviderUpdated(
                            provider: self.provider,
                            oldValue: oldState ?? .loading(),
                            newValue: .error(error, previousData: oldState?.value)
                        )
                    }
                }
            } receiveValue: { value in
                // Handle each streamed value
                Task { @MainActor in
                    let oldState = self.stateBox?.value
                    self.stateBox?.value = .data(value)
                    self.notifyDependents()
                    self.container.notifyProviderUpdated(
                        provider: self.provider,
                        oldValue: oldState ?? .loading(),
                        newValue: .data(value)
                    )
                }
            }

        // Cancel subscription when provider is disposed
        onDispose {
            cancellable.cancel()
        }

        // Return initial state
        if let lastValue = stateBox?.value.value {
            return .refreshing(lastValue)
        }
        return .loading()
    }
}

// MARK: - StreamProvider

/// A provider that subscribes to a Combine publisher and emits a stream of values.
///
/// `StreamProvider` is designed for handling continuous streams of data, such as:
/// - Real-time data updates (WebSocket streams, database change streams)
/// - Sensor data (location updates, motion events)
/// - User input sequences (keyboard, touch events)
/// - Polling-based updates
///
/// Unlike `FutureProvider` which runs once and caches a single result, StreamProvider
/// continuously listens to a stream and updates its cached value with each new emission.
///
/// **Key Characteristics:**
/// - **Streaming**: Handles continuous data flow, not just one-shot operations
/// - **Reactive**: Automatically updates cached value as stream emits values
/// - **Error-aware**: Tracks error states in AsyncValue
/// - **Cancellable**: Automatically cancels subscription when provider is disposed
/// - **Combine-based**: Built on the powerful Combine framework
///
/// **Thread Safety:**
/// Confined to the MainActor. Stream events are safely bridged to the main thread.
///
/// **State Progression:**
/// ```
/// Initial: .loading()
///      ↓
/// First value: .data(T)
///      ↓
/// More values: .data(T) [updated repeatedly]
///      ↓
/// Stream error: .error(Error, previousData?)
///      ↓
/// Stream completed: Last value cached
/// ```
///
/// **When to Use:**
/// - Real-time data updates
/// - Continuous sensors or monitoring
/// - WebSocket or server-sent events
/// - Polling-based data refresh
/// - Any continuous data source
///
/// **When NOT to Use:**
/// - Single async operations (use `FutureProvider`)
/// - Simple sync values (use `Provider`)
/// - Imperative state management (use `StateProvider`)
///
/// **Example: Real-time Data Stream**
/// ```swift
/// @StreamProvider
/// func locationStreamProvider(ref: ProviderRef) -> AnyPublisher<Location, Error> {
///     locationManager.locationPublisher()
///         .eraseToAnyPublisher()
/// }
///
/// struct LocationView: View {
///     @Watch(locationStreamProvider) var locationState
///
///     var body: some View {
///         switch locationState {
///         case .data(let location):
///             Text("Latitude: \\(location.latitude)")
///             Text("Longitude: \\(location.longitude)")
///         case .loading():
///             Text("Finding location...")
///         case .error(let error, _):
///             Text("Error: \\(error.localizedDescription)")
///         case .refreshing(let lastLocation):
///             Text("Updating... Last: \\(lastLocation.latitude)")
///         }
///     }
/// }
/// ```
///
/// **Example: WebSocket Stream**
/// ```swift
/// @StreamProvider
/// func chatMessagesProvider(ref: ProviderRef) -> AnyPublisher<ChatMessage, Error> {
///     let room = ref.watch(selectedRoomProvider)
///     return WebSocketManager.shared
///         .connect(to: room)
///         .map { $0.message }
///         .eraseToAnyPublisher()
/// }
/// ```
///
/// **Example: Polling Updates**
/// ```swift
/// @StreamProvider
/// func priceStreamProvider(ref: ProviderRef) -> AnyPublisher<Double, Error> {
///     Timer.publish(every: 5, on: .main, in: .common)
///         .autoconnect()
///         .flatMap { _ in fetchCurrentPrice() }
///         .eraseToAnyPublisher()
/// }
/// ```
///
/// **Example: Combining Streams**
/// ```swift
/// @StreamProvider
/// func searchResultsProvider(ref: ProviderRef) -> AnyPublisher<[SearchResult], Error> {
///     let query = ref.watch(searchQueryProvider)
///     return apiService.search(query: query)
///         .eraseToAnyPublisher()
/// }
/// ```
///
/// - Important: StreamProvider caches the latest value. Previous values are not retained.
/// - Note: The stream publisher is created fresh each time the provider is accessed or invalidated.
/// - Warning: Ensure the publisher completes or fails; incomplete streams prevent provider cleanup.
public struct StreamProvider<T: Sendable>: ProviderProtocol, @unchecked Sendable {

    // MARK: - Type Definition

    /// The state type is AsyncValue tracking the stream's current value
    public typealias State = AsyncValue<T>

    // MARK: - Properties

    /// The closure that creates the Combine publisher for the stream
    private let _create: @MainActor (ProviderRef) -> AnyPublisher<T, Error>

    /// Unique identifier for this provider instance
    private let _id: AnyHashable

    /// Whether to automatically dispose when no longer listened to
    public let autoDispose: Bool

    /// Time in seconds before the cached value is invalidated
    public let cacheTime: TimeInterval

    /// Human-readable name for debugging
    public let name: String?

    // MARK: - Initialization

    /// Creates a new StreamProvider with explicit configuration.
    ///
    /// - Parameters:
    ///   - autoDispose: Whether to automatically dispose when unused (default: true)
    ///   - cacheTime: How long to cache the last value in seconds (default: 0)
    ///   - name: Optional debug name
    ///   - create: The closure that creates the Combine publisher
    ///
    /// **Example: Polling Stream**
    /// ```swift
    /// let priceProvider = StreamProvider(
    ///     cacheTime: 60,  // Refresh every minute
    ///     name: "priceProvider"
    /// ) { ref in
    ///     Timer.publish(every: 10, on: .main, in: .common)
    ///         .autoconnect()
    ///         .flatMap { _ in fetchPrice() }
    ///         .eraseToAnyPublisher()
    /// }
    /// ```
    public init(
        autoDispose: Bool = true,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        _ create: @escaping @MainActor (ProviderRef) -> AnyPublisher<T, Error>
    ) {
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
        self._id = UUID()
    }

    /// Internal initializer for family providers.
    /// - Note: For internal use only.
    internal init(
        id: AnyHashable,
        autoDispose: Bool,
        cacheTime: TimeInterval = 0,
        name: String? = nil,
        create: @escaping @MainActor (ProviderRef) -> AnyPublisher<T, Error>
    ) {
        self._id = id
        self.autoDispose = autoDispose
        self.cacheTime = cacheTime
        self.name = name
        self._create = create
    }

    // MARK: - Internal Methods

    /// Creates the Combine publisher for this stream.
    ///
    /// - Parameter ref: The provider reference for dependency tracking
    /// - Returns: A Combine publisher emitting stream values
    @MainActor
    func stream(ref: ProviderRef) -> AnyPublisher<T, Error> {
        _create(ref)
    }

    // MARK: - ProviderProtocol Conformance

    /// Creates an element to manage this provider's stream subscription
    @MainActor
    public func createElement(container: ProviderContainer) -> AnyProviderElement {
        StreamProviderElement(provider: self, container: container)
    }

    /// Hashes this provider using its unique identifier
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_id)
    }

    /// Two StreamProviders are equal if they have the same identifier
    public static func == (lhs: StreamProvider, rhs: StreamProvider) -> Bool {
        lhs._id == rhs._id
    }
}
