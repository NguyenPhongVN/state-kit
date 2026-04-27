import Foundation

/// Một định danh duy nhất cho mỗi Provider.
public struct ProviderID: Hashable, @unchecked Sendable {
    private let identifier: AnyHashable
    
    public init<P: ProviderProtocol>(_ provider: P) {
        self.identifier = AnyHashable(provider)
    }
}
