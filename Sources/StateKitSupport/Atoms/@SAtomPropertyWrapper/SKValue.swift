import SwiftUI

/// A read-only property wrapper that observes an atom's value.
///
/// `@SKValue` subscribes the enclosing view to the atom's `SKAtomBox`. When
/// the atom's value changes, SwiftUI schedules a re-render of the view.
/// Because observation is at the per-box level, only views that access the
/// specific atom are re-rendered — unrelated atoms cause no overhead.
///
/// Use `@SKState` instead when you need to write back to a `SKStateAtom`.
///
/// ## Usage
///
/// ```swift
/// struct DoubledView: View {
///     @SKValue(doubledAtom) var doubled   // SKValueAtom, SKStateAtom, etc.
///
///     var body: some View {
///         Text("\(doubled)")
///     }
/// }
/// ```
///
/// ## With a named atom type
///
/// ```swift
/// @SKValue(DoubledCounterAtom()) var doubled
/// ```
@MainActor
@propertyWrapper
public struct SKValue<A: SKAtom>: DynamicProperty {

    // MARK: - Dependencies

    @Environment(\.skAtomStore) private var store
    private let atom: A

    // MARK: - Init

    /// Creates a read-only observer for `atom`.
    ///
    /// - Parameter atom: The atom whose value this wrapper observes.
    public init(_ atom: A) {
        self.atom = atom
    }

    // MARK: - DynamicProperty

    /// The atom's current value.
    ///
    /// Accessing this property during a view's `body` computation registers
    /// the view as an `@Observable` subscriber to the atom's `SKAtomBox`.
    public var wrappedValue: A.Value {
        atom._getOrCreateBox(in: store).value
    }
}
