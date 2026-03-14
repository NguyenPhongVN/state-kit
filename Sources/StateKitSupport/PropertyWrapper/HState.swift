import SwiftUI

@propertyWrapper
@MainActor
public struct HState<Node> {
    
    internal let _value: Binding<Node>
    
    public init(wrappedValue: @escaping () -> Node) {
        _value = useBinding(wrappedValue())
    }
    
    public init(wrappedValue: Node) {
        _value = useBinding(wrappedValue)
    }
    
    public init(wrappedValue: @escaping () -> Binding<Node>) {
        _value = wrappedValue()
    }
    
    public init(wrappedValue: Binding<Node>) {
        _value = wrappedValue
    }
    
    public var wrappedValue: Node {
        get {
            _value.wrappedValue
        }
        nonmutating set {
            _value.wrappedValue = newValue
        }
    }
    
    public var projectedValue: Binding<Node> {
        _value
    }
}
