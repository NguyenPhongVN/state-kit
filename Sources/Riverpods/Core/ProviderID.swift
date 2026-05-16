import Foundation

/// Một định danh duy nhất cho mỗi Provider.
public struct ProviderID: Hashable, @unchecked Sendable, CustomStringConvertible {
    private let identifier: AnyHashable
    private let debugName: String?
    
    public init<P: ProviderProtocol>(_ provider: P) {
        self.identifier = AnyHashable(provider)
        self.debugName = provider.name
    }
    
    public init(identifier: AnyHashable, name: String? = nil) {
        self.identifier = identifier
        self.debugName = name
    }
    
    public var description: String {
        debugName ?? "Provider(\(identifier))"
    }
}
