//import SwiftUI
//import StateKitCore
//
////@propertyWrapper
////@MainActor
////public struct WatchState<T>: DynamicProperty {
////    @Bindable var state = StateStore.shared
////    let key: StateKey<T>
////    let defaultValue: () -> T
////    public init( _ key: StateKey<T>, default defaultValue: @autoclosure @escaping () -> T) {
////        self.key = key
////        self.defaultValue = defaultValue
////        self.state.registerIfNeeded(key: key, value: defaultValue())
////    }
////    
////    public var wrappedValue: T {
////        get {
////            state.get(key: key, default: defaultValue())
////        }
////    
////        nonmutating set {
////            state.set(key: key, value: newValue)
////        }
////    }
////}
//
//@propertyWrapper
//@dynamicMemberLookup
//@MainActor public struct ViewContext: DynamicProperty {
//    
//    /// The underlying ViewModel instance
//    @State var viewModel = StateStore.shared
//    
//    public init() {
//
//    }
//    
//    /// The wrapped ViewModel instance
//    public var wrappedValue: StateStore {
//        viewModel
//    }
//    
//    /// A binding to the ViewModel instance for two-way data binding
//    public var projectedValue: Binding<StateStore> {
//        return $viewModel
//    }
//    
//    /// Provides read-only access to ViewModel properties through dynamic member lookup
//    /// - Parameter keyPath: The key path to the property to access
//    /// - Returns: The value at the specified key path
//    public subscript<U>(dynamicMember keyPath: KeyPath<StateStore, U>) -> U {
//        return viewModel[keyPath: keyPath]
//    }
//    
//    /// Provides read-write access to ViewModel properties through dynamic member lookup
//    /// - Parameter keyPath: The writable key path to the property to access
//    /// - Returns: The value at the specified key path
//    public subscript<U>(dynamicMember keyPath: WritableKeyPath<StateStore, U>) -> U {
//        get { return viewModel[keyPath: keyPath] }
//        set { viewModel[keyPath: keyPath] = newValue }
//    }
//}
//
//extension ViewContext: @MainActor CustomReflectable {
//    public var customMirror: Mirror {
//        Mirror(reflecting: wrappedValue)
//    }
//}
//
//extension ViewContext: @MainActor CustomStringConvertible {
//    public var description: String {
//        "\(typeName(Self.self, genericsAbbreviated: false))(\("viewModel"))"
//    }
//}
//
//extension ViewContext: Observable {}
//
//#if compiler(>=6)
//extension ViewContext: Sendable {}
//#else
//extension ViewContext: @unchecked Sendable {}
//#endif
//
//@propertyWrapper
//public struct Inject<P: Provider>: DynamicProperty {
//    @Environment(Container.self) private var container
//    
//    public init() { }
//    
//    public var wrappedValue: P.Value {
//        container.resolve(P())
//    }
//}
//
//@propertyWrapper
//public struct InjectFamily<F: FamilyProvider>: DynamicProperty {
//    @Environment(Container.self) private var container
//    
//    let param: F.Param
//    
//    public init(param: F.Param) {
//        self.param = param
//    }
//    
//    public var wrappedValue: F.Value {
//        container.resolve(F(), param: param)
//    }
//}
//
//@propertyWrapper
//public struct Watch<P: Provider>: DynamicProperty {
//    @Environment(Container.self) private var container
//    
//    @State private var value: P.Value?
//    
//    public init() { }
//    
//    public var wrappedValue: P.Value {
//        let resolved = container.resolve(P())
//        value = resolved
//        return resolved
//    }
//}
//
//
