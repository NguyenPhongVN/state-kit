import Testing
import Foundation
@testable import Riverpods

@MainActor
@Suite("Riverpods — Lifecycle & Memory")
struct RiverpodLifecycleTests {

    @Test("Provider auto-disposes when no longer used")
    func autoDispose() {
        let container = ProviderContainer()
        var disposed = false
        
        let p = Provider { ref in
            ref.onDispose { disposed = true }
            return "Value"
        }
        
        // Use and then release
        _ = container.addListener(for: p)
        #expect(!disposed)
        
        container.removeListener(for: p)
        #expect(disposed)
    }

    @Test("KeepAlive provider persists even without listeners")
    func keepAlive() {
        let container = ProviderContainer()
        var disposed = false
        
        let p = Provider(autoDispose: false) { ref in
            ref.onDispose { disposed = true }
            return "Solid"
        }
        
        _ = container.addListener(for: p)
        container.removeListener(for: p)
        
        #expect(!disposed)
        #expect(container.read(p) == "Solid")
    }

    @Test("Lifecycle callbacks: onCancel and onResume")
    func cancelResume() {
        let container = ProviderContainer()
        var cancelledCount = 0
        var resumedCount = 0
        
        let p = Provider { ref in
            ref.onCancel { cancelledCount += 1 }
            ref.onResume { resumedCount += 1 }
            return "Live"
        }
        
        // Initial setup
        _ = container.addListener(for: p)
        #expect(cancelledCount == 0)
        #expect(resumedCount == 1) // First activation triggers resume
        
        // Remove all listeners
        container.removeListener(for: p)
        #expect(cancelledCount == 1)
        
        // Re-add listener (This should trigger onResume again)
        _ = container.addListener(for: p)
        #expect(resumedCount == 2)
    }
}
