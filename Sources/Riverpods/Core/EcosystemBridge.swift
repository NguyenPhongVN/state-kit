import Foundation
import StateKitAtoms

// MARK: - Riverpod -> Atom Bridge

extension ProviderElement {
    /// Watch an Atom from within a Riverpod Provider.
    public func watch<A: SKAtom>(_ atom: A) -> A.Value {
        let store = SKAtomStore.shared
        let key = SKAtomKey(atom)
        
        // Register a listener on the Atom that invalidates this Provider
        if dependencies.insert(ProviderID(identifier: key, name: "Atom(\(key))")).inserted {
            // We use a subscriber token to keep the atom alive while this provider is active
            let token = SKSubscriberToken(store: store, key: key)
            onDispose {
                _ = token // Keep alive until dispose
            }
            
            // Listen for atom changes
            store.addInterceptor { [weak self] changedKey, _, _ in
                if changedKey == key {
                    self?.invalidate()
                }
            }
        }
        
        // Get current value from atom store
        let box: SKAtomBox<A.Value> = atom._getOrCreateBox(in: store)
        return box.value
    }
}

// MARK: - Atom -> Riverpod Bridge

/// An Atom that watches a Riverpod Provider.
public struct RiverpodAtom<P: ProviderProtocol>: SKValueAtom, Hashable {
    public typealias Value = P.State
    
    public let provider: P
    public let container: ProviderContainer
    
    @MainActor
    public init(_ provider: P, container: ProviderContainer = .shared) {
        self.provider = provider
        self.container = container
    }
    
    public func value(context: SKAtomTransactionContext) -> P.State {
        // Register a listener on the provider that invalidates this atom
        // We use the container's listen method.
        // For now, we return the current value. 
        // To make it reactive, we'd need to bridge the invalidation.
        
        return container.read(provider)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(provider)
    }
    
    public static func == (lhs: RiverpodAtom, rhs: RiverpodAtom) -> Bool {
        lhs.provider == rhs.provider && lhs.container === rhs.container
    }
}

// MARK: - Extension for easier access

extension ProviderProtocol {
    /// Chuyển đổi một Provider thành một Atom để có thể dùng trong hệ thống Atoms.
    @MainActor
    public func asAtom(in container: ProviderContainer = .shared) -> RiverpodAtom<Self> {
        RiverpodAtom(self, container: container)
    }
}
