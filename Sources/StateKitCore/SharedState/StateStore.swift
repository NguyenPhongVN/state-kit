import Observation

/// The global container that owns all atom values in the app.
///
/// `StateStore` is the equivalent of Riverpod's `ProviderContainer`, Recoil's
/// `RecoilRoot` atom map, or Jotai's `createStore()`. It is the single source
/// of truth for every `StateKey` atom: when a key is first read or written a
/// `StateBox<T>` is allocated and stored here; subsequent reads return the
/// same box.
///
/// ## Reactivity
///
/// `StateStore` is `@Observable`. Any SwiftUI view whose body reads an atom
/// via `StateStore.shared.get(key:default:)` is automatically tracked by the
/// observation system. When that atom's value changes via `set(key:value:)`,
/// SwiftUI invalidates the subscriber and schedules a re-render — no
/// `objectWillChange` publisher or `@Published` annotation required.
///
/// ## Usage pattern
///
/// Declare atoms as static `StateKey` constants (see `StateKey`), then read
/// and write them through `StateStore.shared`:
///
/// ```swift
/// extension StateKey {
///     static let counter = StateKey<Int>("counter")
/// }
///
/// // Read (initialises to 0 on first access)
/// let count = StateStore.shared.get(key: .counter, default: 0)
///
/// // Write (triggers re-render in any subscribed view)
/// StateStore.shared.set(key: .counter, value: count + 1)
/// ```
///
/// ## Threading
///
/// `StateStore` is `@MainActor`. All reads and writes must happen on the main
/// thread; this is automatically satisfied for SwiftUI view bodies and
/// `@MainActor`-isolated code.
@MainActor
@Observable
public final class StateStore {

    /// The process-wide singleton store.
    ///
    /// Equivalent to Riverpod's global `ProviderContainer` or Recoil's root
    /// atom store. All atoms share this instance unless a scoped store is
    /// needed for testing or preview isolation.
    public static let shared = StateStore()

    /// Dictionary mapping each `StateKey` to its reactive `StateBox`.
    ///
    /// Keyed by `AnyHashable` to hold boxes of heterogeneous types. Boxes
    /// are created lazily on first `get` or `set` for a given key.
    private var storage: [AnyHashable: any AnyStateBox] = [:]

    private init() {}

    // MARK: - Reading

    /// Returns the current value for `key`, initialising it with
    /// `defaultValue` if it has never been written.
    ///
    /// Equivalent to Riverpod's `ref.watch(provider)` or Recoil's
    /// `useRecoilValue(atom)`: the first call creates the atom slot and stores
    /// `defaultValue`; subsequent calls return the stored value. Because the
    /// read goes through an `@Observable` `StateBox`, any SwiftUI view body
    /// that calls this method is automatically subscribed to future changes.
    ///
    /// - Parameters:
    ///   - key: The atom key identifying the piece of state to read.
    ///   - defaultValue: An `@autoclosure` producing the initial value if the
    ///     atom has not been registered yet. Evaluated at most once per key.
    /// - Returns: The current value stored for `key`.
    public func get<T>(
        key: StateKey<T>,
        default defaultValue: @autoclosure () -> T
    ) -> T {
        if let box = storage[key] as? StateBox<T> {
            return box.value
        }
        let value = defaultValue()
        storage[key] = StateBox(value)
        return value
    }

    // MARK: - Writing

    /// Writes `value` for `key`, creating the atom slot if it does not exist.
    ///
    /// Equivalent to Riverpod's `ref.read(provider.notifier).state = value`
    /// or Jotai's `store.set(atom, value)`. If a `StateBox` already exists
    /// for `key` its `value` is updated in place, triggering `@Observable`
    /// notifications to all subscribed views. If no box exists yet, a new one
    /// is created with `value` as both its current and default value.
    ///
    /// - Parameters:
    ///   - key: The atom key identifying the piece of state to write.
    ///   - value: The new value to store.
    public func set<T>(
        key: StateKey<T>,
        value: T
    ) {
        if let box = storage[key] as? StateBox<T> {
            box.value = value
        } else {
            storage[key] = StateBox(value)
        }
    }

    // MARK: - Registration

    /// Registers a default value for `key` only if the atom slot does not
    /// already exist.
    ///
    /// Equivalent to declaring an atom's default in Recoil's `atom({ default })`
    /// or Riverpod's provider default — it establishes the initial value
    /// without overwriting a value that was already set. Use this during app
    /// startup or in a dependency-injection layer to pre-seed atoms before
    /// any view reads them.
    ///
    /// - Parameters:
    ///   - key: The atom key to pre-register.
    ///   - value: The default value to use if the atom has not been written
    ///     yet. A no-op if a `StateBox` for `key` already exists.
    public func registerIfNeeded<T>(
        key: StateKey<T>,
        value: T
    ) {
        guard storage[key] as? StateBox<T> == nil else { return }
        storage[key] = StateBox(value)
    }

    // MARK: - Debug

    func printGraph() {
        // Reserved for future atom dependency graph visualisation.
    }
}
