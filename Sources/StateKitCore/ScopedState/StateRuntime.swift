@MainActor
public enum StateRuntime {
    
    public static var current: StateContext?
    
    public static func begin(_ context: StateContext) {
        context.reset()
        current = context
    }
    
    public static var context: StateContext {
        guardFunction(StateRuntime.current) {
            StateContext()
        }
    }
    
    public static func end() {
        current = nil
    }
    
    @MainActor
    public static func stateRun<T>(
        context: StateContext,
        body: () -> T
    ) -> T {
        StateRuntime.begin(context)
        let view = body()
        StateRuntime.end()
        return view
    }
}
