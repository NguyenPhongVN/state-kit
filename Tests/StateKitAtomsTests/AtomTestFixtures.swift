import Testing
import Combine
import SwiftUI
import StateKit
@testable import StateKitAtoms

struct CounterAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

struct NameAtom: SKStateAtom, Hashable {
    typealias Value = String
    func defaultValue(context: SKAtomTransactionContext) -> String { "Alice" }
}

struct DoubledCounterAtom: SKValueAtom, Hashable {
    typealias Value = Int
    func value(context: SKAtomTransactionContext) -> Int {
        context.watch(CounterAtom()) * 2
    }
}

struct FormattedAtom: SKValueAtom, Hashable {
    typealias Value = String
    func value(context: SKAtomTransactionContext) -> String {
        "\(context.watch(NameAtom())): \(context.watch(CounterAtom()))"
    }
}

struct FetchAtom: SKTaskAtom, Hashable {
    typealias TaskSuccess = String
    func task(context: SKAtomTransactionContext) async -> String { "fetched" }
}

struct FailingAtom: SKThrowingTaskAtom, Hashable {
    typealias TaskSuccess = String

    struct FetchError: Error {}

    func task(context: SKAtomTransactionContext) async throws -> String {
        throw FetchError()
    }
}

@MainActor
final class ControlledTaskSource: @unchecked Sendable {
    private var nextRequestID = 0
    private var continuations: [Int: CheckedContinuation<String, Never>] = [:]

    var pendingRequestIDs: [Int] {
        continuations.keys.sorted()
    }

    func suspend() async -> String {
        let requestID = nextRequestID
        nextRequestID += 1
        return await withCheckedContinuation { continuation in
            continuations[requestID] = continuation
        }
    }

    func resolve(_ requestID: Int, with value: String) {
        continuations.removeValue(forKey: requestID)?.resume(returning: value)
    }
}

@MainActor
final class ControlledThrowingTaskSource: @unchecked Sendable {
    private var nextRequestID = 0
    private var continuations: [Int: CheckedContinuation<String, Error>] = [:]

    var pendingRequestIDs: [Int] {
        continuations.keys.sorted()
    }

    func suspend() async throws -> String {
        let requestID = nextRequestID
        nextRequestID += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations[requestID] = continuation
        }
    }

    func resolve(_ requestID: Int, with value: String) {
        continuations.removeValue(forKey: requestID)?.resume(returning: value)
    }

    func fail(_ requestID: Int, with error: Error) {
        continuations.removeValue(forKey: requestID)?.resume(throwing: error)
    }
}

final class ControlledRefreshAtom: SKTaskAtom, @unchecked Sendable {
    typealias TaskSuccess = String

    let source: ControlledTaskSource

    init(source: ControlledTaskSource) {
        self.source = source
    }

    func task(context: SKAtomTransactionContext) async -> String {
        await source.suspend()
    }

    static func == (lhs: ControlledRefreshAtom, rhs: ControlledRefreshAtom) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

final class ControlledThrowingRefreshAtom: SKThrowingTaskAtom, @unchecked Sendable {
    typealias TaskSuccess = String

    let source: ControlledThrowingTaskSource

    init(source: ControlledThrowingTaskSource) {
        self.source = source
    }

    func task(context: SKAtomTransactionContext) async throws -> String {
        try await source.suspend()
    }

    static func == (lhs: ControlledThrowingRefreshAtom, rhs: ControlledThrowingRefreshAtom) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct UsePrimaryPublisherAtom: SKStateAtom, Hashable {
    typealias Value = Bool
    func defaultValue(context: SKAtomTransactionContext) -> Bool { true }
}

struct PrimaryPublisherValueAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 1 }
}

struct SecondaryPublisherValueAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 2 }
}

struct SwitchingValueAtom: SKValueAtom, Hashable {
    typealias Value = Int

    func value(context: SKAtomTransactionContext) -> Int {
        let usesPrimary = context.watch(UsePrimaryPublisherAtom())
        return usesPrimary
            ? context.watch(PrimaryPublisherValueAtom())
            : context.watch(SecondaryPublisherValueAtom())
    }
}

final class PublisherBuildTracker: @unchecked Sendable, Hashable {
    var builds = 0

    static func == (lhs: PublisherBuildTracker, rhs: PublisherBuildTracker) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct SwitchingPublisherAtom: SKPublisherAtom, Hashable {
    typealias PublisherOutput = Int
    typealias AtomPublisher = AnyPublisher<Int, Error>

    let tracker: PublisherBuildTracker

    func publisher(context: SKAtomTransactionContext) -> AnyPublisher<Int, Error> {
        tracker.builds += 1
        let usesPrimary = context.watch(UsePrimaryPublisherAtom())
        let value = usesPrimary
            ? context.watch(PrimaryPublisherValueAtom())
            : context.watch(SecondaryPublisherValueAtom())
        return CurrentValueSubject<Int, Error>(value)
            .eraseToAnyPublisher()
    }
}

struct ControlledRefreshError: Error {}

@MainActor
func waitUntil(
    _ predicate: @autoclosure () -> Bool,
    maxYields: Int = 20
) async {
    for _ in 0..<maxYields where !predicate() {
        await Task.yield()
    }
}

@MainActor
func makeStore(counter: Int = 0) -> SKAtomStore {
    let store = SKAtomStore()
    if counter != 0 {
        store.setStateValue(counter, for: CounterAtom())
    }
    return store
}

@MainActor
func environmentWith(store: SKAtomStore) -> EnvironmentValues {
    var env = EnvironmentValues()
    env.skAtomStore = store
    return env
}
