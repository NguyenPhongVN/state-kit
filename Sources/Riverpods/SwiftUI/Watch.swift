import SwiftUI
import Observation
import StateKit

/// Property wrapper để theo dõi một Provider trong SwiftUI.
@MainActor
@propertyWrapper
public struct Watch<P: ProviderProtocol>: DynamicProperty {
    @Environment(\.providerContainer) private var container
    @State private var listener = ProviderListener<P>()
    
    private let provider: P
    
    public init(_ provider: P) {
        self.provider = provider
    }
    
    public var wrappedValue: P.State {
        container.watch(provider)
    }
    
    nonisolated public func update() {
        MainActor.assumeIsolated {
            listener.setup(container: container, provider: provider)
        }
    }
}

/// Helper để quản lý vòng đời listener của một Provider trong View.
@MainActor
final class ProviderListener<P: ProviderProtocol> {
    private var container: ProviderContainer?
    private var provider: P?
    
    init() {}
    
    func setup(container: ProviderContainer, provider: P) {
        if self.container === container && self.provider == provider {
            return
        }
        
        // Cleanup old
        cleanup()
        
        // Set new
        self.container = container
        self.provider = provider
        _ = container.addListener(for: provider)
    }
    
    deinit {
        if let container = container, let provider = provider {
            Task { @MainActor in
                container.removeListener(for: provider)
            }
        }
    }
    
    private func cleanup() {
        if let container = container, let provider = provider {
            container.removeListener(for: provider)
        }
    }
}

// MARK: - Hook Bridge

/// Sử dụng Riverpod Provider bên trong một `StateScope` của StateKit.
@MainActor
public func useRiverpod<P: ProviderProtocol>(_ provider: P) -> P.State {
    let container = useEnvironment(\.providerContainer)
    
    // Đăng ký listener và dọn dẹp khi hook bị hủy
    useEffect(updateStrategy: .preserved(by: ProviderID(provider))) {
        _ = container.addListener(for: provider)
        return { container.removeListener(for: provider) }
    }
    
    return container.watch(provider)
}

// MARK: - Environment

private struct ProviderContainerKey: EnvironmentKey {
    static var defaultValue: ProviderContainer {
        MainActor.assumeIsolated { .shared }
    }
}

public extension EnvironmentValues {
    /// Truy cập ProviderContainer từ Environment.
    var providerContainer: ProviderContainer {
        get { self[ProviderContainerKey.self] }
        set { self[ProviderContainerKey.self] = newValue }
    }
}
