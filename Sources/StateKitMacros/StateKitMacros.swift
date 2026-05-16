import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Atom Macros

/// @StateAtom: Generates `typealias Value = <ReturnType>` from a struct with `func defaultValue(context:) -> Value`
@attached(member, names: named(Value))
public macro StateAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateAtomMacro")

/// @ValueAtom: Generates `typealias Value = <ReturnType>` from a struct with `func value(context:) -> Value`
@attached(member, names: named(Value))
public macro ValueAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "ValueAtomMacro")

/// @TaskAtom: Generates `typealias TaskSuccess = <ReturnType>` from a struct with `func task(context:) async -> TaskSuccess`
@attached(member, names: named(TaskSuccess))
public macro TaskAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "TaskAtomMacro")

/// @ThrowingTaskAtom: Generates `typealias TaskSuccess = <ReturnType>` from a struct with `func task(context:) async throws -> TaskSuccess`
@attached(member, names: named(TaskSuccess))
public macro ThrowingTaskAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "TaskAtomMacro")

/// @PublisherAtom: Generates `typealias PublisherOutput` and `typealias AtomPublisher` from a struct with `func publisher(context:) -> AnyPublisher<...>`
@attached(member, names: named(PublisherOutput), named(AtomPublisher))
public macro PublisherAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "PublisherAtomMacro")

/// @Atom: Unified macro that auto-detects the atom type from method names:
/// - `defaultValue(context:)` → SKStateAtom
/// - `value(context:)` → SKValueAtom
/// - `task(context:) async` → SKTaskAtom
/// - `task(context:) async throws` → SKThrowingTaskAtom
/// - `publisher(context:)` → SKPublisherAtom
@attached(member)
public macro Atom() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomMacro")

/// @AtomFamily: Generates an atomFamily factory function from a struct with stored properties used as ID parameters
@attached(peer)
public macro AtomFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomFamilyMacro")

/// @SelectorFamily: Generates a selectorFamily factory function from a struct with stored properties and value(context:) method
@attached(peer)
public macro SelectorFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "SelectorFamilyMacro")

/// @AsyncTaskFamily: Generates an atomFamily factory function for async task atoms from a struct with stored properties and task(context:) method
@attached(peer)
public macro AsyncTaskFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncTaskFamilyMacro")

/// @AtomReducer: Generates a reducer-based state atom from a struct with State typealias, Action typealias, and reduce(_:action:) method
@attached(peer)
public macro AtomReducer() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomReducerMacro")

/// @Computed: Generates a derived atom from a struct with compute(context:) method
@attached(member, names: named(Computed))
public macro Computed() = #externalMacro(module: "StateKitMacrosPlugin", type: "ComputedMacro")

/// @SelectorAtom: Generates derived state from select(context:) method
/// More semantic than @ValueAtom for explicitly selected/filtered values
@attached(member, names: named(Value))
public macro SelectorAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "SelectorAtomMacro")

/// @FilteredAtom: Auto-generates filtered atom from predicate method
/// Applies filtering to a source atom's list values
@attached(member, names: named(Value))
public macro FilteredAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "FilteredAtomMacro")

/// @MappedAtom: Auto-generates mapped atom from transform function
/// Transforms values from a source atom
@attached(member, names: named(Value))
public macro MappedAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "MappedAtomMacro")

/// @CombineAtom: Combines multiple atoms into a single tuple value
@attached(member, names: named(Value))
public macro CombineAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "CombineAtomMacro")

/// @DistinctAtom: Only emits distinct/unique values
@attached(member, names: named(Value))
public macro DistinctAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "DistinctAtomMacro")

/// @FlatMapAtom: Flattens nested async values
@attached(member, names: named(Value))
public macro FlatMapAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "FlatMapAtomMacro")

// MARK: - View Macros

/// @HookView: Generates `var body: some View { StateScope { stateBody } }` from a struct with `var stateBody: some View`
@attached(member, names: named(body))
public macro HookView() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookViewMacro")

/// @StateView: Convenience alias for @HookView for StateView protocol conformance
@attached(member, names: named(body))
public macro StateView() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateViewMacro")

/// @AsyncView: Generates helper properties for AsyncPhase handling
@attached(member)
public macro AsyncView() = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncViewMacro")

/// @ObservableState: Integrates with Swift's Observation framework for observable state management
@attached(member)
public macro ObservableState() = #externalMacro(module: "StateKitMacrosPlugin", type: "ObservableStateMacro")

// MARK: - Hook Macros

/// @Hook: Validates custom hook functions follow naming conventions (must start with 'use')
@attached(peer)
public macro Hook() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookMacro")

/// @HookState: Generates a hook function from a struct with stored properties using useBinding
@attached(peer)
public macro HookState() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookStateMacro")

/// @HookRef: Generates a hook function from a struct with stored properties using useRef
@attached(peer)
public macro HookRef() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookRefMacro")

/// @HookEffect: Generates a hook function from a struct with run() and optional cleanup() methods
@attached(peer)
public macro HookEffect() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookEffectMacro")

/// @AsyncHook: Generates an async hook function from a struct with async run() method
@attached(peer)
public macro AsyncHook() = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncHookMacro")

/// @Debounce: Delays execution of a function until interval elapses with no new calls
@attached(peer)
public macro Debounce(milliseconds: Int) = #externalMacro(module: "StateKitMacrosPlugin", type: "DebounceMacro")

/// @Throttle: Limits function execution frequency to once per interval
@attached(peer)
public macro Throttle(milliseconds: Int) = #externalMacro(module: "StateKitMacrosPlugin", type: "ThrottleMacro")

/// @HookPrevious: Tracks the previous value of a state
@attached(peer)
public macro HookPrevious() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookPreviousMacro")

/// @HookToggle: Simple boolean toggle helper
@attached(peer)
public macro HookToggle() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookToggleMacro")

/// @HookInterval: Interval/polling hook for periodic tasks
@attached(peer)
public macro HookInterval() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookIntervalMacro")

/// @HookMemo: Generates a hook function from a struct with compute() method using useMemo
@attached(peer)
public macro HookMemo() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookMemoMacro")

/// @HookCallback: Generates a hook function from a struct with call() or handle() method using useCallback
@attached(peer)
public macro HookCallback() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookCallbackMacro")

/// @HookReducer: Generates a hook function from a struct with State typealias, Action typealias, and reduce() method
@attached(peer)
public macro HookReducer() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookReducerMacro")

/// @HookContext: Generates a HookContext instance and hook function from a struct
@attached(peer)
public macro HookContext() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookContextMacro")

/// @HookForm: Generates a form hook struct with validation and error handling from a struct with stored properties
@attached(peer)
public macro HookForm() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookFormMacro")

/// @CustomHook: Validates custom hook functions and generates test helpers
@attached(peer)
public macro CustomHook() = #externalMacro(module: "StateKitMacrosPlugin", type: "CustomHookMacro")

// MARK: - Riverpod Macros

/// @riverpodNotifier: Generates a provider instance from a Notifier/AsyncNotifier subclass
/// Emits: `public let <lowercaseClassName>Provider = NotifierProvider { ClassName() }`
@attached(peer, names: named(provider))
public macro riverpodNotifier() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodNotifierMacro")

/// @StateProvider: Generates a StateProvider from a struct with 'initial' property
@attached(peer)
public macro StateProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateProviderMacro")

/// @Provider: Generates a derived Provider from a function with (ref: ProviderRef) parameter
@attached(peer)
public macro Provider() = #externalMacro(module: "StateKitMacrosPlugin", type: "ProviderMacro")

/// @FutureProvider: Generates a FutureProvider from an async function
@attached(peer)
public macro FutureProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "FutureProviderMacro")

/// @StreamProvider: Generates a StreamProvider from a function returning AnyPublisher
@attached(peer)
public macro StreamProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "StreamProviderMacro")

/// @ProviderFamily: Generates a family provider from a function with parameterized ID
@attached(peer)
public macro ProviderFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "ProviderFamilyMacro")

/// @RiverpodFamily: Generates a family provider from a Notifier/AsyncNotifier with parameterized build
@attached(peer, names: named(provider))
public macro RiverpodFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodFamilyMacro")

/// @RiverpodSelector: Generates a selector provider from a function
@attached(peer, names: named(Provider))
public macro RiverpodSelector() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodSelectorMacro")

/// @RiverpodFutureFamily: Generates a FutureProvider family
@attached(peer, names: named(Family))
public macro RiverpodFutureFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodFutureFamilyMacro")

/// @RiverpodStreamFamily: Generates a StreamProvider family
@attached(peer, names: named(Family))
public macro RiverpodStreamFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodStreamFamilyMacro")

/// @RiverpodAsync: Generates a simple async Provider
@attached(peer, names: named(Provider))
public macro RiverpodAsync() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodAsyncMacro")
