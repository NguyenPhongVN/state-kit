import SwiftUI
import Observation

/// Cung cấp ProviderContainer cho toàn bộ cây View bên dưới.
public struct ProviderScope<Content: View>: View {
    let container: ProviderContainer
    let content: Content
    
    public init(overrides: [ProviderOverride] = [], @ViewBuilder content: () -> Content) {
        if overrides.isEmpty {
            self.container = .shared
        } else {
            self.container = ProviderContainer(overrides: overrides)
        }
        self.content = content()
    }
    
    public init(container: ProviderContainer, @ViewBuilder content: () -> Content) {
        self.container = container
        self.content = content()
    }
    
    public var body: some View {
        content
            .environment(\.providerContainer, container)
    }
}
