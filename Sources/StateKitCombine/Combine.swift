import Combine
import Foundation

extension Publisher {
    func sinkOnMain(
        receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void = { _ in },
        receiveValue: @escaping (Output) -> Void
    ) -> AnyCancellable {
        receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: receiveCompletion,
                receiveValue: receiveValue
            )
    }
}

extension Publisher where Failure == Never {
    func assignWeak<T: AnyObject>(
        to keyPath: ReferenceWritableKeyPath<T, Output>,
        on object: T
    ) -> AnyCancellable {
        sink { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }
}

extension Publisher {
    func unwrap<T>() -> Publishers.CompactMap<Self, T> where Output == T? {
        compactMap { $0 }
    }
}

extension Publisher {
    func mapToVoid() -> Publishers.Map<Self, Void> {
        map { _ in () }
    }
}

extension Publisher {
    func withLatestFrom<Other: Publisher>(
        _ other: Other
    ) -> AnyPublisher<Other.Output, Failure> where Other.Failure == Failure {
        self
            .combineLatest(other)
            .map { _, latest in latest }
            .eraseToAnyPublisher()
    }
}

extension Publisher {
    func withUnretained<Object: AnyObject>(
        _ object: Object
    ) -> AnyPublisher<(Object, Output), Failure> {
        compactMap { [weak object] output in
            guard let object else { return nil }
            return (object, output)
        }
        .eraseToAnyPublisher()
    }
}

extension Publisher {
    func asResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        self
            .map { Result.success($0) }
            .catch { error in
                Just(Result.failure(error))
            }
            .eraseToAnyPublisher()
    }
}

extension Publisher {
    func setLoading(
        _ loading: CurrentValueSubject<Bool, Never>
    ) -> AnyPublisher<Output, Failure> {
        handleEvents(
            receiveSubscription: { _ in loading.send(true) },
            receiveCompletion: { _ in loading.send(false) },
            receiveCancel: { loading.send(false) }
        )
        .eraseToAnyPublisher()
    }
}

extension Publisher {
    func debugLog(_ prefix: String) -> AnyPublisher<Output, Failure> {
        handleEvents(
            receiveSubscription: { _ in Swift.print("🟡 \(prefix) subscribed") },
            receiveOutput: { value in Swift.print("🟢 \(prefix) value:", value) },
            receiveCompletion: { completion in Swift.print("🔴 \(prefix) completion:", completion) },
            receiveCancel: { Swift.print("⚫️ \(prefix) cancelled") }
        )
        .eraseToAnyPublisher()
    }
}
