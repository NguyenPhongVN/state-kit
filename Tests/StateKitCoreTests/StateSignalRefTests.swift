import Testing
import Observation
import Foundation
@testable import StateKitCore

@Suite("StateKitCore — StateSignal & StateRef")
struct StateSignalRefTests {
    
    @Test("StateSignal value updates")
    @MainActor
    func testStateSignalUpdate() {
        let signal = StateSignal(0)
        #expect(signal.value == 0)
        
        signal.value = 1
        #expect(signal.value == 1)
        
        // Test _safeUpdate outside of render
        signal._safeUpdate(to: 2)
        #expect(signal.value == 2)
    }
    
    @Test("StateSignal _safeUpdate during render")
    @MainActor
    func testStateSignalSafeUpdateDuringRender() async {
        let context = StateContext()
        let signal = StateSignal(0)
        
        StateRuntime.begin(context)
        signal._safeUpdate(to: 1)
        #expect(signal.value == 0) // Should not update immediately
        StateRuntime.end()
        
        // Wait for the task to execute
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(signal.value == 1)
    }
    
    @Test("StateRef value updates")
    func testStateRefUpdate() {
        let ref = StateRef(0)
        #expect(ref.value == 0)
        
        ref.value = 1
        #expect(ref.value == 1)
    }
    
    @Test("StateSignal observation")
    @MainActor
    func testStateSignalObservation() {
        let signal = StateSignal(0)
        
        final class Box: @unchecked Sendable {
            var observed = false
        }
        let box = Box()
        
        withObservationTracking {
            _ = signal.value
        } onChange: {
            box.observed = true
        }
        
        #expect(box.observed == false)
        signal.value = 1
        #expect(box.observed == true)
    }
}
