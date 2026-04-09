import SwiftUI

// MARK: - EnvironmentValues extension

public extension EnvironmentValues {
    /// The `SKAtomStore` provided by the nearest `SKAtomRoot` in the view
    /// hierarchy.
    ///
    /// Falls back to `SKAtomStore.shared` when no root is present. Override
    /// this key in tests or previews via `SKAtomScopeView` to isolate atom
    /// state.
    @Entry var skAtomStore: SKAtomStore = SKAtomStore()
}
