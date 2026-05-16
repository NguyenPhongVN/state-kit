import Testing
import Foundation
@testable import Riverpods
import StateKitAtoms

@MainActor
@Suite("Riverpods — New Features & Bug Fixes")
struct RiverpodNewFeaturesTests {

    @Test("AsyncValue.when handles previousData")
    func asyncValueWhen() {
        let val: AsyncValue<Int> = .loading(previousData: 42)
        
        let result = val.when(
            data: { "Data \($0)" },
            error: { _, prev in "Error \(prev ?? 0)" },
            loading: { "Loading \(($0 ?? 0))" }
        )
        
        #expect(result == "Loading 42")
    }

    @Test("ref.listen and container.listen receive updates")
    func listenUpdates() {
        let container = ProviderContainer()
        let p = StateProvider { _ in 0 }
        
        var callCount = 0
        var lastValue = -1
        
        let sub = container.listen(p) { old, new in
            callCount += 1
            lastValue = new
        }
        
        container.read(p.notifier).state = 1
        #expect(callCount == 1)
        #expect(lastValue == 1)
        
        sub.close()
        container.read(p.notifier).state = 2
        #expect(callCount == 1) // Should not be called after close
    }

    @Test("cacheTime prevents immediate disposal")
    func cacheTime() async throws {
        let container = ProviderContainer()
        var computeCount = 0
        let p = Provider(autoDispose: true, cacheTime: 0.1) { _ in
            computeCount += 1
            return "Value"
        }
        
        // Add and remove listener
        _ = container.addListener(for: p)
        container.removeListener(for: p)
        
        // Should NOT be disposed immediately
        #expect(computeCount == 1)
        
        // Try to read again immediately
        #expect(container.read(p) == "Value")
        #expect(computeCount == 1)
        
        // Wait for cacheTime
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Now it should be disposed, so next read recomputes
        #expect(container.read(p) == "Value")
        #expect(computeCount == 2)
    }

    @Test("RiverpodAtom bridge works")
    func bridge() {
        let container = ProviderContainer()
        let p = StateProvider { _ in "Hello" }
        let atom = p.asAtom(in: container)
        
        let store = SKAtomStore.shared
        let value = store.valueBox(for: atom).value
        
        #expect(value == "Hello")
    }
}
