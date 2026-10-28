import ConcurrencyExtras
#if canImport(Combine)
import Combine
#endif

// MARK: - AsyncSequence
extension AsyncSequence {
    /// Used to expose an instance of `some AsyncSequence` to the client, rather
    /// than this async sequence’s actual type to preserve abstraction across API
    /// boundaries, such as different modules.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public func eraseToAsyncSequence() -> some AsyncSequence<Element, Failure> {
        self
    }
}

#if canImport(Combine)
// MARK: - AsyncSequence
extension AsyncSequence where Self: Sendable {
    /// Converts the asynchronous sequence into a Combine publisher.
    ///
    /// **Subscribe-immediately semantics:** a pump task starts consuming the
    /// sequence the moment this property is accessed — elements emitted before
    /// any subscriber attaches are DROPPED, and there is no backpressure
    /// (a `PassthroughSubject` is a firehose, not a demand-driven source).
    /// Cancel the pump by cancelling the subscription, or by deallocating the
    /// returned publisher.
    ///
    /// - Returns: A publisher that emits values from the async sequence and
    ///   propagates thrown errors.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public var publisher: some Publisher<Element, Failure> {
        let box = UncheckedSendable(PassthroughSubject<Element, Failure>())

        let task = Task { @Sendable in
            do {
                for try await value in self {
                    box.wrappedValue.send(value)
                }
                box.wrappedValue.send(completion: .finished)
            } catch let error as Failure {
                box.wrappedValue.send(completion: .failure(error))
            } catch {
                box.wrappedValue.send(completion: .failure(error as! Failure))
            }
        }

        // The pump is held by the returned publisher: a publisher that is
        // never subscribed does not leak an unstructured task draining the
        // whole sequence.
        return PumpPublisher(
            subject: box.wrappedValue,
            pump: task
        )
    }
}
#endif


/// Wraps a pump-fed subject so deallocating the publisher (with no active
/// subscriptions) cancels the pump task.
private final class PumpPublisher<Output, Failure: Error>: Publisher, @unchecked Sendable {
    typealias Output = Output
    typealias Failure = Failure

    private let subject: PassthroughSubject<Output, Failure>
    private let pump: Task<Void, Never>
    private let cancelPump: @Sendable () -> Void

    init(subject: PassthroughSubject<Output, Failure>, pump: Task<(), Never>) {
        self.subject = subject
        self.pump = pump
        self.cancelPump = { pump.cancel() }
    }

    func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        subject
            .handleEvents(receiveCancel: { self.cancelPump() })
            .receive(subscriber: subscriber)
    }

    deinit {
        cancelPump()
    }
}
