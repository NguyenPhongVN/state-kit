import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import StateKitAtoms
import Riverpods
import Observation

// MARK: - Atom Macros (17)

/// @StateAtom: Applied to `struct`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKStateAtom, Hashable)
@attached(memberAttribute)
public macro StateAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateAtomMacro")

/// @ValueAtom: Applied to `struct`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro ValueAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "ValueAtomMacro")

/// @TaskAtom: Applied to `struct`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKTaskAtom, Hashable)
@attached(memberAttribute)
public macro TaskAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "TaskAtomMacro")

/// @ThrowingTaskAtom: Applied to `struct`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKThrowingTaskAtom, Hashable)
@attached(memberAttribute)
public macro ThrowingTaskAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "TaskAtomMacro")

/// @PublisherAtom: Applied to `struct`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKPublisherAtom, Hashable)
@attached(memberAttribute)
public macro PublisherAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "PublisherAtomMacro")

/// @Atom: Unified macro.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKStateAtom, SKValueAtom, SKTaskAtom, SKThrowingTaskAtom, SKPublisherAtom, Hashable)
@attached(memberAttribute)
public macro Atom() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomMacro")

/// @AtomFamily: Generates factory member `family`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKStateAtom, Hashable)
@attached(memberAttribute)
public macro AtomFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomFamilyMacro")

/// @SelectorFamily: Generates factory member `family`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro SelectorFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "SelectorFamilyMacro")

/// @AsyncTaskFamily: Generates factory member `family`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKTaskAtom, Hashable)
@attached(memberAttribute)
public macro AsyncTaskFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncTaskFamilyMacro")

/// @AtomReducer: Generates a reducer-based state atom.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKStateAtom, Hashable)
public macro AtomReducer() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomReducerMacro")

/// @Computed: Generates a derived atom.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro Computed() = #externalMacro(module: "StateKitMacrosPlugin", type: "ComputedMacro")

/// @SelectorAtom: Generates derived state via `select(context:)`.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro SelectorAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "SelectorAtomMacro")

/// @FilteredAtom: Auto-generates filtered atom.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro FilteredAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "FilteredAtomMacro")

/// @MappedAtom: Auto-generates mapped atom.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro MappedAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "MappedAtomMacro")

/// @CombineAtom: Combines multiple atoms.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro CombineAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "CombineAtomMacro")

/// @DistinctAtom: Only emits distinct values.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro DistinctAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "DistinctAtomMacro")

/// @FlatMapAtom: Flattens nested async values.
@attached(member, names: arbitrary)
@attached(extension, conformances: SKValueAtom, Hashable)
@attached(memberAttribute)
public macro FlatMapAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "FlatMapAtomMacro")

// MARK: - View Macros (4)

/// @HookView: Generates `body` with `StateScope` wrapping.
@attached(member, names: named(body))
public macro HookView() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookViewMacro")

/// @StateView: Alias for @HookView for StateView protocol.
@attached(member, names: named(body))
public macro StateView() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateViewMacro")

/// @AsyncView: Generates AsyncPhase helper properties.
@attached(member, names: named(body), named(isLoading), named(hasError))
public macro AsyncView<A: SKAtom>(atom: A) = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncViewMacro")

/// @ObservableState: Integrates with Observation framework.
@attached(member, names: arbitrary)
@attached(extension, conformances: Observable)
public macro ObservableState() = #externalMacro(module: "StateKitMacrosPlugin", type: "ObservableStateMacro")

// MARK: - Hook Macros (16)

/// @Hook: Validates 'use' naming convention.
@attached(peer, names: arbitrary)
public macro Hook() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookMacro")

/// @CustomHook: Validates custom hooks and generates helpers.
@attached(peer, names: arbitrary)
public macro CustomHook() = #externalMacro(module: "StateKitMacrosPlugin", type: "CustomHookMacro")

/// @HookState: Generates a hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookState() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookStateMacro")

/// @HookRef: Generates a hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookRef() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookRefMacro")

/// @HookToggle: Simple boolean toggle hook prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookToggle() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookToggleMacro")

/// @HookEffect: Generates a hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookEffect() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookEffectMacro")

/// @AsyncHook: Generates an async hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro AsyncHook() = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncHookMacro")

/// @Debounce: Delays execution (Peer).
@attached(peer, names: suffixed(_debounced))
public macro Debounce(milliseconds: Int) = #externalMacro(module: "StateKitMacrosPlugin", type: "DebounceMacro")

/// @Throttle: Limits execution frequency (Peer).
@attached(peer, names: suffixed(_throttled))
public macro Throttle(milliseconds: Int) = #externalMacro(module: "StateKitMacrosPlugin", type: "ThrottleMacro")

/// @HookPrevious: Tracks previous value prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookPrevious() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookPreviousMacro")

/// @HookInterval: Polling hook prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookInterval() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookIntervalMacro")

/// @HookMemo: Generates hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookMemo() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookMemoMacro")

/// @HookCallback: Generates hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookCallback() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookCallbackMacro")

/// @HookReducer: Generates hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookReducer() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookReducerMacro")

/// @HookContext: Generates hook function prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookContext() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookContextMacro")

/// @HookForm: Generates a form hook prefixed with 'use' (Peer).
@attached(peer, names: prefixed(use))
public macro HookForm() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookFormMacro")

// MARK: - Riverpod Macros (11)

/// @RiverpodNotifier: Generates a static `provider` member (Member).
@attached(member, names: arbitrary)
public macro RiverpodNotifier() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodNotifierMacro")

/// @RiverpodFamily: Generates a static `family` member (Member).
@attached(member, names: arbitrary)
public macro RiverpodFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodFamilyMacro")

/// @StateProvider: Generates a static `provider` member (Member).
@attached(member, names: arbitrary)
public macro StateProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateProviderMacro")

/// @Provider: Generates a derived `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: suffixed(Provider))
public macro Provider() = #externalMacro(module: "StateKitMacrosPlugin", type: "ProviderMacro")

/// @FutureProvider: Generates a `FutureProvider` suffixed with 'Provider' (Peer).
@attached(peer, names: suffixed(Provider))
public macro FutureProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "FutureProviderMacro")

/// @StreamProvider: Generates a `StreamProvider` suffixed with 'Provider' (Peer).
@attached(peer, names: suffixed(Provider))
public macro StreamProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "StreamProviderMacro")

/// @ProviderFamily: Generates a family `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: suffixed(Provider))
public macro ProviderFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "ProviderFamilyMacro")

/// @RiverpodSelector: Generates a selector `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: suffixed(Provider))
public macro RiverpodSelector() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodSelectorMacro")

/// @RiverpodAsync: Generates an async `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: suffixed(Provider))
public macro RiverpodAsync() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodAsyncMacro")

/// @RiverpodFutureFamily: Generates a family suffixed with 'Family' (Peer).
@attached(peer, names: suffixed(Family))
public macro RiverpodFutureFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodFutureFamilyMacro")

/// @RiverpodStreamFamily: Generates a family suffixed with 'Family' (Peer).
@attached(peer, names: suffixed(Family))
public macro RiverpodStreamFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodStreamFamilyMacro")
