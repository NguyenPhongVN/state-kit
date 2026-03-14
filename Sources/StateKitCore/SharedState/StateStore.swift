import Observation

@MainActor
@Observable
public final class StateStore {
    
    public static let shared = StateStore()
    
    private var storage: [AnyHashable: AnyStateBox] = [:]
    
    private init() {}
    
    public func get<T>(
        key: StateKey<T>,
        default defaultValue: @autoclosure () -> T
    ) -> T {
        
        if let box = storage[key] as? StateBox<T> {
            return box.value
        }
        
        let value = defaultValue()
        
        storage[key] = StateBox(value)
        
        return value
    }
    
    public func set<T>(
        key: StateKey<T>,
        value: T
    ) {
        if let box = storage[key] as? StateBox<T> {
            box.value = value
        } else {
            storage[key] = StateBox(value)
        }
    }
    
    public func registerIfNeeded<T>(
        key: StateKey<T>,
        value: T
    ) {
        if let _ = storage[key] as? StateBox<T> {
            return
        } else {
            storage[key] = StateBox(value)
        }
    }
    
    func printGraph() {
        
    }
}
