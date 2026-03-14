public struct StateKey<T>: Hashable, Identifiable {
    
    public let name: String
    
    public init(_ name: String) {
        self.name = name
    }
    
    public var id: String { name }
}
