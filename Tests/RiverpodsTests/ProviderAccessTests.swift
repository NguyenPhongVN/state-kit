import Testing
import Foundation
@testable import Riverpods

@MainActor
@Suite("Provider Access Semantics — Clean Public API")
struct ProviderAccessTests {

    @Test("watch registers a reactive listener and balances with removeListener")
    func watchRegisters() async throws {
        let container = ProviderContainer()
        var disposed = false
        let p = Provider<Int>(cacheTime: 0.05) { ref in
            ref.onDispose { disposed = true }
            return 42
        }
        let id = ProviderID(p)

        _ = container.watch(p)
        #expect(container.element(for: id)?.listenersCount == 1, "watch must register exactly one listener")

        // While watched, the auto-dispose provider must stay alive past its
        // dispose window.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(!disposed, "watch must keep an auto-dispose provider alive")

        container.removeListener(for: p)
        #expect(container.element(for: id)?.listenersCount == 0, "removeListener must balance watch")

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(disposed, "releasing the last listener must dispose the provider after its window")
    }

    @Test("read is pure — it registers no listener")
    func readIsPure() async throws {
        let container = ProviderContainer()
        let p = Provider<Int>(cacheTime: 0.05) { _ in 7 }
        let id = ProviderID(p)

        _ = container.read(p)
        #expect(container.element(for: id)?.listenersCount == 0, "read must not register a listener")
    }

    @Test("deprecated addListener behaves identically to watch")
    func addListenerMatchesWatch() async throws {
        let container = ProviderContainer()
        var disposed = false
        let p = Provider<Int>(cacheTime: 0.05) { ref in
            ref.onDispose { disposed = true }
            return 5
        }
        let id = ProviderID(p)

        _ = container.addListener(for: p)  // deprecated alias — same registration path
        #expect(container.element(for: id)?.listenersCount == 1, "addListener must register like watch")

        container.removeListener(for: p)
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(disposed, "addListener/removeListener must balance and dispose")
    }
}
