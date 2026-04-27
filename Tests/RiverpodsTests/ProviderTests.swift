import Testing
import Foundation
@testable import Riverpods

@MainActor
@Suite("Riverpods — Core Logic")
struct RiverpodCoreTests {

    @Test("Basic StateProvider read/write")
    func basicState() {
        let container = ProviderContainer()
        let p = StateProvider { _ in 0 }
        
        #expect(container.read(p) == 0)
        
        container.read(p.notifier).state = 42
        #expect(container.read(p) == 42)
    }

    @Test("Provider dependency tracking (watch)")
    func dependencyTracking() {
        let container = ProviderContainer()
        let countP = StateProvider { _ in 1 }
        let doubledP = Provider { ref in ref.watch(countP) * 2 }
        
        #expect(container.read(doubledP) == 2)
        
        container.read(countP.notifier).state = 5
        #expect(container.read(doubledP) == 10)
    }

    @Test("Topological sort prevents redundant re-computations")
    func topoSort() {
        let container = ProviderContainer()
        var computeCount = 0
        
        let a = StateProvider { _ in "A" }
        let b = Provider { ref in 
            _ = ref.watch(a)
            return "B"
        }
        let c = Provider { ref in
            _ = ref.watch(a)
            return "C"
        }
        let d = Provider { ref in
            computeCount += 1
            return ref.watch(b) + ref.watch(c)
        }
        
        #expect(container.read(d) == "BC")
        #expect(computeCount == 1)
        
        // Update A, D should only recompute once even if it has two paths to A
        container.read(a.notifier).state = "A2"
        #expect(computeCount == 2)
    }
}
