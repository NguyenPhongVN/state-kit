import Observation

/// A type-erased protocol for `StateBox<T>`, allowing values of any type
/// to be stored together in `StateStore.storage: [AnyHashable: AnyStateBox]`.
///
/// Consumers always go through `StateBox<T>` for typed access; `AnyStateBox`
/// exists solely so the dictionary can hold heterogeneous boxes without
/// losing the `@Observable` identity of each box.
protocol AnyStateBox {
    var anyValue: Any { get set }
}

/// The internal reactive cell that holds the actual value for one atom
/// (`StateKey<T>`) inside `StateStore`.
///
/// `StateBox<T>` is the equivalent of an **atom instance** in Jotai /
/// Recoil: it is created the first time a key is read or written, lives in
/// `StateStore.storage` for the lifetime of the store, and is never exposed
/// to app code directly.
///
/// Because `StateBox` is `@Observable`, any SwiftUI view (or `StateScope`)
/// that reads `value` during its body evaluation is automatically tracked.
/// When `value` is mutated — via `StateStore.set(key:value:)` — SwiftUI
/// invalidates every subscriber and schedules a re-render, without the view
/// needing to observe the store explicitly.
///
/// `defaultValue` stores the value the box was initialised with, enabling
/// a potential reset-to-default operation without re-creating the box.
@Observable
final class StateBox<T>: AnyStateBox {

    /// The current value of this atom.
    ///
    /// Reads are tracked by `@Observable`. Writes notify all SwiftUI views
    /// that read this box during their last render.
    var value: T

    /// The initial value this box was created with. Preserved for reset
    /// semantics; not mutated by normal `get`/`set` operations.
    var defaultValue: T

    /// Creates a box initialised with `value`, setting `defaultValue` to the
    /// same value.
    ///
    /// - Parameter value: The initial (and default) value for this atom slot.
    init(_ value: T) {
        self.value = value
        self.defaultValue = value
    }

    /// Type-erased read/write access used by `AnyStateBox` conformance.
    ///
    /// The force-cast in `set` is safe because `StateStore` always retrieves
    /// a box via the correctly-typed `StateKey<T>`, guaranteeing that
    /// `newValue` is of type `T`.
    var anyValue: Any {
        get { value }
        set { value = newValue as! T }
    }
}
