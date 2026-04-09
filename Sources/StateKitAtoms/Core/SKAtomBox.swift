import Observation

/// A per-atom reactive value container.
///
/// Every atom registered in `SKAtomStore` owns exactly one `SKAtomBox`. Because
/// the box itself is the `Observable` unit — not the store — SwiftUI tracks
/// dependencies at the atom level: changing atom A's box only re-renders views
/// that accessed `A.box.value` during their last body run, leaving unrelated
/// views untouched.
///
/// - Note: Mutations must only happen on the main thread (via `@MainActor`
///   store methods). The type itself is not `@MainActor`-isolated so it can
///   be returned from protocol methods without actor-isolation constraints on
///   the protocol requirement.
public final class SKAtomBox<Value>: @unchecked Sendable {

    private var _value: Value
    private let _registrar = ObservationRegistrar()

    /// The atom's current cached value.
    ///
    /// Reading this property during a SwiftUI view body registers the view as
    /// a subscriber. Writing it notifies all registered subscribers.
    public var value: Value {
        get {
            _registrar.access(self, keyPath: \.value)
            return _value
        }
        set {
            _registrar.withMutation(of: self, keyPath: \.value) {
                _value = newValue
            }
        }
    }

    public init(_ value: Value) {
        _value = value
    }
}

extension SKAtomBox: Observable {}
