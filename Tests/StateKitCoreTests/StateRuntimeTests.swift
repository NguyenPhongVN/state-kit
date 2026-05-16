import Testing
@testable import StateKitCore

@Suite("StateKitCore — StateRuntime")
@MainActor
struct StateRuntimeTests {
    
    @Test("stateRun correctly manages lifecycle")
    func testStateRunLifecycle() {
        let context = StateContext()
        
        #expect(StateRuntime.current == nil)
        
        let result = StateRuntime.stateRun(context: context) {
            #expect(StateRuntime.current === context)
            return "Rendered"
        }
        
        #expect(result == "Rendered")
        #expect(StateRuntime.current == nil)
    }
    
    @Test("stateRun injects environment")
    func testEnvironmentInjection() {
        let context = StateContext()
        let env = "MockEnvironment"
        
        StateRuntime.stateRun(context: context, environment: env) {
            #expect(context.injectedEnvironment as? String == "MockEnvironment")
        }
    }
    
    @Test("begin and end methods")
    func testBeginEnd() {
        let context = StateContext()
        
        StateRuntime.begin(context)
        #expect(StateRuntime.current === context)
        
        StateRuntime.end()
        #expect(StateRuntime.current == nil)
    }
}
