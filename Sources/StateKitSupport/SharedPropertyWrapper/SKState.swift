import SwiftUI

/// A read-write property wrapper for a mutable `SKStateAtom`.
///
/// `@SKState` observes the atom (re-renders the view on changes) and provides
/// a `Binding<Value>` via the `$` prefix for two-way controls.
///
/// For read-only atoms (`SKValueAtom`, `SKTaskAtom`, …) use `@SKValue`.
///
/// ## Usage
///
/// ```swift
/// struct CounterView: View {
///     @SKState(CounterAtom()) var count
///
///     var body: some View {
///         Stepper("Count: \(count)", value: $count)
///         Button("Reset") { count = 0 }
///     }
/// }
/// ```
///
/// ## With an inline atom
///
/// ```swift
/// let counterAtom = atom(0)
///
/// struct CounterView: View {
///     @SKState(counterAtom) var count
/// }
/// ```
@MainActor
@propertyWrapper
public struct SKState<A: SKStateAtom>: DynamicProperty {

    // MARK: - Dependencies

    @Environment(\.skAtomStore) private var store
    private let atom: A

    // MARK: - Init

    /// Creates a read-write observer for `atom`.
    ///
    /// - Parameter atom: The mutable atom to observe and write.
    public init(_ atom: A) {
        self.atom = atom
    }

    // MARK: - DynamicProperty

    /// The atom's current value.
    ///
    /// Assigning to this property writes the new value to the store and
    /// triggers downstream propagation.
    public var wrappedValue: A.Value {
        get { atom._getOrCreateBox(in: store).value }
        nonmutating set { store.setStateValue(newValue, for: atom) }
    }

    /// A `Binding` suitable for use with SwiftUI controls.
    ///
    /// ```swift
    /// TextField("Name", text: $name)
    /// Toggle("Active", isOn: $isActive)
    /// ```
    public var projectedValue: Binding<A.Value> {
        Binding {
            atom._getOrCreateBox(in: store).value
        } set: { newValue in
            store.setStateValue(newValue, for: atom)
        }
    }
}
