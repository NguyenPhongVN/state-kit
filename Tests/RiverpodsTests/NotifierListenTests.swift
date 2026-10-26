import Testing
import Foundation
@testable import Riverpods

// Spec 009 US2(a): `container.listen` and `ref.listen` must observe
// Notifier/AsyncNotifier state mutations — they go through a publish path,
// not recompute(), which is where external listeners used to be invoked only.

@MainActor
@Suite("Notifier Listen — 009 US2")
struct NotifierListenTests {

    @Test("container.listen observes Notifier state mutations")
    func containerListenSeesNotifierMutation() {
        let container = ProviderContainer()
        let provider = NotifierProvider { TestCounterNotifier() }

        var calls = 0
        var lastOld = -1
        var lastNew = -1
        let sub = container.listen(provider) { old, new in
            calls += 1
            lastOld = old ?? -1
            lastNew = new
        }

        container.read(provider.notifier).state = 5

        #expect(calls == 1, "external listener missed a Notifier mutation")
        #expect(lastOld == 0)
        #expect(lastNew == 5)
        sub.close()
    }

    @Test("ref.listen inside another provider observes Notifier mutations")
    func refListenSeesNotifierMutation() {
        let container = ProviderContainer()
        let counter = NotifierProvider { TestCounterNotifier() }

        var observed: [Int] = []
        let derived = Provider { ref -> Int in
            ref.listen(counter, fireImmediately: false) { _, new in observed.append(new) }
            return container.read(counter)
        }
        _ = container.read(derived)

        container.read(counter.notifier).state = 7
        #expect(observed.contains(7), "ref.listen did not observe the Notifier mutation")
    }

    @Test("observers see Notifier mutations through notifyProviderUpdated")
    func observerSeesNotifierMutation() {
        let container = ProviderContainer()
        let provider = NotifierProvider { TestCounterNotifier() }
        _ = container.read(provider)

        var updates = 0
        let observer = RecordingObserver { updates += 1 }
        container.addObserver(observer)

        container.read(provider.notifier).state = 3
        #expect(updates >= 1, "observers missed the Notifier mutation")
    }

    @Test("AsyncNotifier mutations also reach listeners")
    func asyncNotifierMutationReachesListeners() async throws {
        let container = ProviderContainer()
        let provider = AsyncNotifierProvider { TestAsyncCounterNotifier() }
        _ = container.read(provider)
        // Let the initial build finish.
        try await Task.sleep(for: .milliseconds(50))

        var calls = 0
        let sub = container.listen(provider) { _, _ in calls += 1 }

        container.read(provider.notifier).state = .data(9)
        try await Task.sleep(for: .milliseconds(50))

        #expect(calls >= 1, "listener missed an AsyncNotifier mutation")
        sub.close()
    }
}

/// Minimal Notifier for tests.
final class TestCounterNotifier: Notifier<Int> {
    override func build() -> Int { 0 }
}

/// Minimal AsyncNotifier for tests.
final class TestAsyncCounterNotifier: AsyncNotifier<Int> {
    override init() {
        super.init()
        state = .data(0)
    }

    override func build() async throws -> Int {
        0
    }
}

/// Minimal observer counting updates.
final class RecordingObserver: ProviderObserver, @unchecked Sendable {
    private let onUpdate: @MainActor () -> Void

    init(onUpdate: @escaping @MainActor () -> Void) {
        self.onUpdate = onUpdate
    }

    func didUpdateProvider<P: ProviderProtocol>(
        _ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer
    ) {
        onUpdate()
    }
}
