import Testing
import SwiftUI
@testable import StateKitUI
@testable import StateKitCore

@Suite("StateKitUI — StateScope & StateView")
@MainActor
struct StateUITests {
    
    @Test("StateScope initializes context and runs content")
    func testStateScope() {
        var runCount = 0
        let scope = StateScope {
            runCount += 1
            return Text("Content")
        }
        
        // Simulating body access
        _ = scope.body
        #expect(runCount == 1)
        
        _ = scope.body
        #expect(runCount == 2)
    }
    
    @Test("StateView body wraps stateBody in StateScope")
    func testStateView() {
        struct TestView: StateView {
            let onRender: () -> Void
            var stateBody: some View {
                onRender()
                return Text("StateBody")
            }
        }
        
        var runCount = 0
        let view = TestView(onRender: { runCount += 1 })
        
        // In SwiftUI, accessing 'body' should trigger the rendering logic.
        // However, StateScope's body needs to be accessed as well.
        let body = view.body
        _ = (body as? StateScope<Text>)?.body
        
        #expect(runCount == 1)
    }
}
