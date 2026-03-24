/// A typed key that identifies a single piece of global state in a
/// `StateStore`.
///
/// `StateKey<T>` is the equivalent of an **atom** in Recoil / Jotai, or a
/// `StateProvider` key in Riverpod. It describes *what* the state is and
/// *what type* it holds, without holding the value itself — the value lives
/// in `StateStore`.
///
/// ## Declaring atoms
///
/// Define keys as static constants so every part of the app refers to the
/// same identity:
///
/// ```swift
/// extension StateKey {
///     static let counter   = StateKey<Int>("counter")
///     static let username  = StateKey<String>("username")
///     static let isLoggedIn = StateKey<Bool>("isLoggedIn")
/// }
/// ```
///
/// ## Reading and writing
///
/// Pass the key to `StateStore.shared` to read or write its value:
///
/// ```swift
/// let count = StateStore.shared.get(key: .counter, default: 0)
/// StateStore.shared.set(key: .counter, value: count + 1)
/// ```
///
/// ## Type safety
///
/// The generic parameter `T` is carried at compile time, so `get` and `set`
/// are fully typed — you cannot accidentally store a `String` under an
/// `Int` key.
///
/// ## Identity
///
/// Two `StateKey` values are equal (and hash to the same bucket) when their
/// `name` strings are equal **and** their `T` is the same type, because
/// `StateKey<Int>("counter") != StateKey<String>("counter")` — they are
/// distinct types at the Swift level even though their names are identical.
public struct StateKey<T>: Hashable, Identifiable {

    /// The human-readable name that uniquely identifies this atom within the
    /// store. Used as the dictionary key in `StateStore.storage`.
    public let name: String

    /// Creates an atom key with the given name.
    ///
    /// - Parameter name: A unique string identifier for this piece of state.
    ///   By convention, use a descriptive lowercase name matching the variable
    ///   name (e.g. `"counter"`, `"currentUser"`).
    public init(_ name: String) {
        self.name = name
    }

    /// The key's identifier, equal to `name`.
    ///
    /// Satisfies `Identifiable` so `StateKey` values can be used directly in
    /// SwiftUI `ForEach` and similar APIs.
    public var id: String { name }
}
