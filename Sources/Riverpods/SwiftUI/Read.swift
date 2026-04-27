import SwiftUI

/// Property wrapper để đọc giá trị của Provider một lần mà không theo dõi.
@MainActor
@propertyWrapper
public struct Read<P: ProviderProtocol>: DynamicProperty {
    @Environment(\.providerContainer) private var container
    
    private let provider: P
    
    public init(_ provider: P) {
        self.provider = provider
    }
    
    public var wrappedValue: P.State {
        container.read(provider)
    }
}
