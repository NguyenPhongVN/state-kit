import Testing
@testable import StateKitCore

@Suite("StateKitCore — StateContext")
struct StateContextTests {
    
    @Test("nextIndex increments correctly and reset works")
    func testIndexManagement() {
        let context = StateContext()
        #expect(context.nextIndex() == 0)
        #expect(context.nextIndex() == 1)
        #expect(context.nextIndex() == 2)
        
        context.reset()
        #expect(context.nextIndex() == 0)
    }
    
    @Test("State storage and retrieval")
    func testStateStorage() {
        let context = StateContext()
        let idx = context.nextIndex()
        
        #expect(context.states.count == 0)
        context.states.append("TestState")
        #expect(context.states[idx] as? String == "TestState")
    }
}
