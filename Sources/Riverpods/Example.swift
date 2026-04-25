//import Observation
//
//@Observable
//public final class Container {
//    
//    private let parent: Container?
//    private var storage: [AnyHashable: Any] = [:]
//    
//    public init(parent: Container? = nil) {
//        self.parent = parent
//    }
//    
//    // MARK: - Resolve normal
//    public func resolve<P: Provider>(_ provider: P) -> P.Value {
//        let key = ObjectIdentifier(P.self)
//        
//        if let value = storage[key] as? P.Value {
//            return value
//        }
//        
//        if let parentValue = parent?.resolve(provider) {
//            return parentValue
//        }
//        
//        let newValue = provider.resolve(container: self)
//        storage[key] = newValue
//        return newValue
//    }
//    
//    // MARK: - Resolve family
//    public func resolve<F: FamilyProvider>(
//        _ provider: F,
//        param: F.Param
//    ) -> F.Value {
//        
//        let key = FamilyKey(type: ObjectIdentifier(F.self), param: param)
//        
//        if let value = storage[key] as? F.Value {
//            return value
//        }
//        
//        let newValue = provider.resolve(container: self, param: param)
//        storage[key] = newValue
//        return newValue
//    }
//    
//    // MARK: - Dispose
//    deinit {
//        storage.values.forEach {
//            ($0 as? Disposable)?.dispose()
//        }
//    }
//}
//
//
//public protocol Provider {
//    associatedtype Value
//    func resolve(container: Container) -> Value
//    init()
//}
//
//extension Provider {
//    static var id: ObjectIdentifier {
//        ObjectIdentifier(Self.self)
//    }
//}
//
//public protocol FamilyProvider {
//    associatedtype Param: Hashable
//    associatedtype Value
//    
//    func resolve(container: Container, param: Param) -> Value
//    
//    init()
//}
//
//public struct FamilyKey: Hashable {
//    let type: ObjectIdentifier
//    let param: AnyHashable
//}
//
//public protocol Disposable {
//    func dispose()
//}
//
