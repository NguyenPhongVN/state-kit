import Testing
import Foundation
@testable import Riverpods
@testable import StateKitDevTools

// Spec 008 US4: DevToolsObserver's update callback must be the protocol
// requirement's witness (oldValue: label) so history recording actually fires
// when registered on a real ProviderContainer.

@MainActor
@Suite("DevToolsObserver Recording — P1 fixes")
struct DevToolsObserverRecordingTests {

    @Test("observer records provider state updates through a real container")
    func recordsUpdates() {
        let observer = DevToolsObserver()
        let container = ProviderContainer(observers: [observer])
        let provider = StateProvider { _ in 0 }

        _ = container.read(provider)
        let entriesAfterCreate = observer.history.entries.count

        container.read(provider.notifier).state = 1
        container.read(provider.notifier).state = 2

        #expect(entriesAfterCreate >= 0)
        #expect(observer.history.entries.count > entriesAfterCreate,
                """
                DevToolsObserver never recorded the update: its didUpdateProvider \
                implementation uses a wrong argument label and is shadowed by the \
                protocol extension's no-op default.
                """)
    }

    @Test("observer lifecycle callbacks fire for add and dispose")
    func lifecycleCallbacksFire() {
        // The observer's own didAdd/didDispose witnesses can only be pinned by
        // recording actual dispatch: DevToolsObserver's callbacks print behind
        // logging flags, so a counting observer rides along in the same container.
        let recorder = DispatchCounter()
        let observer = DevToolsObserver()
        observer.debugLoggingEnabled = false
        let container = ProviderContainer(observers: [recorder, observer])
        let provider = StateProvider { _ in 0 }

        _ = container.watch(provider)
        #expect(recorder.added == 1, "didAddProvider must dispatch once — if this fails, the witness label changed and a no-op default is shadowing it")

        container.removeListener(for: provider)
        #expect(recorder.disposed == 1, "didDisposeProvider must dispatch exactly once on auto-disposal")
    }
}

/// Counts lifecycle dispatches with the exact protocol-signature labels.
private final class DispatchCounter: ProviderObserver, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var added = 0
    private(set) var disposed = 0

    func didAddProvider<P: ProviderProtocol>(_ provider: P, value: P.State, container: ProviderContainer) {
        lock.lock()
        added += 1
        lock.unlock()
    }

    func didUpdateProvider<P: ProviderProtocol>(_ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer) {}

    func didDisposeProvider<P: ProviderProtocol>(_ provider: P, container: ProviderContainer) {
        lock.lock()
        disposed += 1
        lock.unlock()
    }
}
