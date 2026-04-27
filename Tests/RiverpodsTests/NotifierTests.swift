import Testing
import Foundation
@testable import Riverpods

@MainActor
@Suite("Riverpods — Notifiers")
struct RiverpodNotifierTests {

    @Test("Notifier preserves state and notifies dependents")
    func notifierState() {
        let container = ProviderContainer()
        
        class TestNotifier: Notifier<Int> {
            override func build() -> Int { 0 }
            func inc() { state += 1 }
        }
        
        let p = NotifierProvider { TestNotifier() }
        let dep = Provider { ref in ref.watch(p) * 10 }
        
        #expect(container.read(p) == 0)
        #expect(container.read(dep) == 0)
        
        container.read(p.notifier).inc()
        
        #expect(container.read(p) == 1)
        #expect(container.read(dep) == 10)
    }

    @Test("AsyncNotifier handles loading and data transitions")
    func asyncNotifier() async throws {
        let container = ProviderContainer()
        
        class TestAsyncNotifier: AsyncNotifier<String> {
            var buildCount = 0
            override func build() async throws -> String {
                buildCount += 1
                try await Task.sleep(nanoseconds: 50_000_000)
                return "Done"
            }
        }
        
        let p = AsyncNotifierProvider { TestAsyncNotifier() }
        
        // Initial state is loading
        let firstRead = container.read(p)
        #expect(firstRead.isLoading)
        
        // Wait for result
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let secondRead = container.read(p)
        #expect(secondRead.value == "Done")
        
        // Manual refresh should trigger refreshing state
        container.refresh(p)
        let thirdRead = container.read(p)
        
        if case .refreshing(let val) = thirdRead {
            #expect(val == "Done")
        } else {
            Issue.record("Expected refreshing state, got \(thirdRead)")
        }
    }
}
