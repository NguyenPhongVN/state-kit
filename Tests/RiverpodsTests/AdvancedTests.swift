import Testing
import Foundation
@testable import Riverpods

@MainActor
@Suite("Riverpods — Advanced Features")
struct RiverpodAdvancedTests {

    @Test("Provider family generates unique instances")
    func family() {
        let container = ProviderContainer()
        
        let p = Provider.family { (ref, id: Int) in "User \(id)" }
        
        #expect(container.read(p(1)) == "User 1")
        #expect(container.read(p(2)) == "User 2")
        #expect(p(1) != p(2))
    }

    @Test("Select prevents unnecessary re-computations")
    func select() {
        let container = ProviderContainer()
        struct State: Hashable { var a: Int; var b: Int }
        
        let p = StateProvider { _ in State(a: 0, b: 0) }
        var selectComputeCount = 0
        let sel = p.select(\.a)
        
        let dep = Provider { ref in
            selectComputeCount += 1
            return ref.watch(sel)
        }
        
        #expect(container.read(dep) == 0)
        #expect(selectComputeCount == 1)
        
        // Update unrelated part (b)
        container.read(p.notifier).state = State(a: 0, b: 99)
        
        // dep should NOT recompute because sel.a hasn't changed
        #expect(selectComputeCount == 1)
        
        // Update relevant part (a)
        container.read(p.notifier).state = State(a: 1, b: 99)
        #expect(container.read(dep) == 1)
        #expect(selectComputeCount == 2)
    }

    @Test("Overrides work in ProviderContainer")
    func overrides() {
        let p = Provider { _ in "Real" }
        
        // Use an override in a dedicated container
        let container = ProviderContainer(overrides: [
            p.overrideWith("Mock")
        ])
        
        #expect(container.read(p) == "Mock")
    }
}
