import Testing
import Foundation
@testable import Riverpods

@MainActor
@Suite("Provider Observers — Health Bundle")
struct ProviderObserverTests {

    /// Records every lifecycle callback it receives.
    private final class RecordingObserver: ProviderObserver {
        private let lock = NSLock()
        private var _events: [String] = []
        var events: [String] {
            lock.lock(); defer { lock.unlock() }
            return _events
        }
        private func record(_ event: String) {
            lock.lock(); defer { lock.unlock() }
            _events.append(event)
        }
        func didAddProvider<P: ProviderProtocol>(_ provider: P, value: P.State, container: ProviderContainer) {
            record("add")
        }
        func didUpdateProvider<P: ProviderProtocol>(_ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer) {
            record("update")
        }
        func didDisposeProvider<P: ProviderProtocol>(_ provider: P, container: ProviderContainer) {
            record("dispose")
        }
    }

    private var counter: StateProvider<Int> {
        StateProvider { _ in 0 }
    }

    @Test("removed observer receives no callbacks")
    func removedObserverGetsNothing() {
        let container = ProviderContainer()
        let observer = RecordingObserver()
        container.addObserver(observer)

        _ = container.read(counter)          // observer sees "add"
        #expect(observer.events.contains("add"))

        container.removeObserver(observer)
        _ = container.read(counter.notifier).state += 1   // update after removal

        #expect(!observer.events.contains("update"), "removed observer must receive no updates")
    }

    @Test("double removal is a harmless no-op")
    func doubleRemovalIsNoOp() {
        let container = ProviderContainer()
        let observer = RecordingObserver()
        container.addObserver(observer)

        container.removeObserver(observer)
        container.removeObserver(observer)  // second removal: harmless no-op

        let value = container.read(counter)  // container keeps working
        #expect(value == 0)
        #expect(observer.events.isEmpty, "removed observer must stay detached")
    }

    @Test("attached observer still receives callbacks (sanity)")
    func attachedObserverReceivesCallbacks() {
        let container = ProviderContainer()
        let observer = RecordingObserver()
        container.addObserver(observer)

        _ = container.read(counter)
        container.read(counter.notifier).state += 1

        #expect(observer.events.contains("add"))
        #expect(observer.events.contains("update"))
    }
}
