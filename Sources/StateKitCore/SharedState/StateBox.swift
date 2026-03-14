import Observation

protocol AnyStateBox {
    var anyValue: Any { get set }
}

@Observable
final class StateBox<T>: AnyStateBox {
    
    var value: T
    var defaultValue: T
    
    init(_ value: T) {
        self.value = value
        self.defaultValue = value
    }
    
    var anyValue: Any {
        get { value }
        set { value = newValue as! T }
    }
}
