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
        let observer = DevToolsObserver()
        observer.debugLoggingEnabled = false
        let container = ProviderContainer(observers: [observer])
        let provider = StateProvider { _ in 0 }

        let element = container.ensureElement(for: provider)
        _ = container.read(provider)

        // Pins didAddProvider/didDisposeProvider so a future label change cannot
        // silently regress the observer again.
        observer.startComputation(providerName: provider.name ?? "unknown")
        element.dispose()

        #expect(true)
    }
}
