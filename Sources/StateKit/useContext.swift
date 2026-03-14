import SwiftUI

public final class HookContext<Value> {
    
    public var value: Value
    
    public init(_ value: Value) {
        self.value = value
    }
}


func useContext<T>(
    _ context: HookContext<T>
) -> T {
    fatalError("Hooks must be used inside HookView")
}

@MainActor
public func useEnvironment<Value>(_ keyPath: KeyPath<EnvironmentValues, Value>) -> Value {
    guard let context = StateRuntime.current else {
        fatalError("Hooks must be used inside HookView")
    }

    let environment: EnvironmentValues = guardFunction(context.context.filter({$0 is EnvironmentValues}).first) {
        EnvironmentValues()
    } as! EnvironmentValues
    return environment[keyPath: keyPath]
}
