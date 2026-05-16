import StateKitAtoms

/// A macro that generates an `SKStateAtom` conforming struct and a shared
/// instance from a variable declaration with an initial value.
///
/// ```swift
/// @Atom var counter = 0
/// ```
///
/// Expands to:
/// ```swift
/// struct _CounterAtom: SKStateAtom, Hashable {
///     typealias Value = Int
///     func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
/// }
/// let counter = _CounterAtom()
/// ```
@attached(peer, names: arbitrary)
public macro Atom() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomMacro")

/// A macro that generates a `NotifierProvider` for a `Notifier` class.
///
/// ```swift
/// @Provider class CounterNotifier: Notifier<Int> { ... }
/// ```
///
/// Expands to:
/// ```swift
/// let counterNotifierProvider = NotifierProvider { CounterNotifier() }
/// ```
@attached(peer, names: arbitrary)
public macro Provider() = #externalMacro(module: "StateKitMacrosPlugin", type: "NotifierProviderMacro")
