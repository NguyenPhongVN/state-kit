import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import StateKitAtoms
import Riverpods
import Observation

/// ## Examples (All Macros)
///
/// ### Atom macros
/// ```swift
/// @StateAtom
/// struct CounterAtom {
///     func defaultValue(context: Context) -> Int { 0 }
/// }
///
/// @ValueAtom
/// struct ThemeAtom {
///     func value(context: Context) -> String { "light" }
/// }
///
/// @TaskAtom
/// struct UserTaskAtom {
///     func task(context: Context) async -> User {
///         await api.currentUser()
///     }
/// }
///
/// @ThrowingTaskAtom
/// struct RemoteConfigAtom {
///     func task(context: Context) async throws -> Config {
///         try await api.fetchConfig()
///     }
/// }
///
/// @PublisherAtom
/// struct ClockAtom {
///     func publisher(context: Context) -> AnyPublisher<Date, Never> {
///         Timer.publish(every: 1, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
///     }
/// }
///
/// @Atom
/// struct AutoAtom {
///     func defaultValue(context: Context) -> Int { 1 }
/// }
///
/// @AtomFamily
/// struct CountByIdAtom {
///     let id: String
///     func defaultValue(context: Context) -> Int { 0 }
/// }
///
/// @SelectorFamily
/// struct NameByIdSelector {
///     let id: String
///     func value(context: Context) -> String { "name-\(id)" }
/// }
///
/// @AsyncTaskFamily
/// struct UserByIdTask {
///     let id: String
///     func task(context: Context) async -> User {
///         await api.user(id: id)
///     }
/// }
///
/// @AtomReducer
/// struct CounterReducer {
///     func defaultValue(context: Context) -> Int { 0 }
/// }
///
/// @Computed
/// struct FullNameComputed {
///     func compute(context: Context) -> String { "State Kit" }
/// }
///
/// @SelectorAtom
/// struct IsLoggedInSelector {
///     func select(context: Context) -> Bool { true }
/// }
///
/// @FilteredAtom
/// struct PositiveOnlyAtom {
///     func source(context: Context) -> Int { 10 }
///     func predicate(context: Context, value: Int) -> Bool { value > 0 }
/// }
///
/// @MappedAtom
/// struct CountTextAtom {
///     func source(context: Context) -> Int { 3 }
///     func transform(context: Context, value: Int) -> String { "\(value)" }
/// }
///
/// @CombineAtom
/// struct CombinedLabelAtom {
///     func combine(context: Context) -> String { "A-B" }
/// }
///
/// @DistinctAtom
/// struct DistinctValueAtom {
///     func source(context: Context) -> Int { 0 }
/// }
///
/// @FlatMapAtom
/// struct NestedTaskAtom {
///     func flatMap(context: Context) async -> Int { 42 }
/// }
/// ```
///
/// ### Riverpod macros
/// ```swift
/// @RiverpodNotifier
/// final class CounterNotifier {
///     func build() -> Int { 0 }
/// }
///
/// @RiverpodFamily
/// func userFamily(id: String) -> User? { nil }
///
/// @StateProvider
/// func selectedTab() -> Int { 0 }
///
/// @Provider
/// func greeting() -> String { "Hello StateKit" }
///
/// @FutureProvider
/// func userProfile() async throws -> Profile {
///     try await api.profile()
/// }
///
/// @StreamProvider
/// func ticker() -> AsyncStream<Int> {
///     AsyncStream { continuation in
///         continuation.yield(1)
///         continuation.finish()
///     }
/// }
///
/// @ProviderFamily
/// func todoById(id: String) -> Todo? { store[id] }
///
/// @RiverpodSelector
/// func isPremium() -> Bool { false }
///
/// @RiverpodAsync
/// func bootstrap() async -> Bool { true }
///
/// @RiverpodFutureFamily
/// func postById(id: String) async throws -> Post {
///     try await api.post(id: id)
/// }
///
/// @RiverpodStreamFamily
/// func chatByRoom(id: String) -> AsyncStream<Message> {
///     AsyncStream { continuation in
///         continuation.finish()
///     }
/// }
/// ```
///
/// ### View macros
/// ```swift
/// @HookView
/// struct CounterScreen: View {
///     var stateBody: some View { Text("Counter") }
/// }
///
/// @StateView
/// struct ProfileScreen: View {
///     var stateBody: some View { Text("Profile") }
/// }
///
/// @AsyncView(atom: UserTaskAtom())
/// struct UserScreen: View {
///     var stateBody: some View { Text("User") }
/// }
///
/// @ObservableState
/// struct FormState {
///     var name: String = ""
/// }
/// ```
///
/// ### Hook macros
/// ```swift
/// @Hook
/// func useLogger(_ value: Int) {
///     _ = value
/// }
///
/// @HookState
/// struct CounterState {
///     var count: Int = 0
/// }
///
/// @HookRef
/// struct NodeRef {
///     var node: Int? = nil
/// }
///
/// @HookToggle
/// struct ToggleState {
///     var isOn: Bool = false
/// }
///
/// @HookEffect
/// struct ScreenEffect {
///     var deps: [Int] = [0]
///     func effect() {}
/// }
///
/// @AsyncHook
/// struct LoadHook {
///     func run() async {}
/// }
///
/// @HookPrevious
/// struct PreviousValueHook {
///     var value: Int = 0
/// }
///
/// @HookInterval
/// struct PollHook {
///     var milliseconds: Int = 1000
///     func tick() {}
/// }
///
/// @HookMemo
/// struct FullNameMemo {
///     var first: String = "A"
///     var last: String = "B"
///     func build() -> String { "\(first) \(last)" }
/// }
///
/// @HookCallback
/// struct SaveCallback {
///     func callback() {}
/// }
///
/// @HookReducer
/// struct CounterHookReducer {
///     enum Action { case inc }
///     var initialState: Int = 0
///     func reduce(state: Int, action: Action) -> Int { state + 1 }
/// }
///
/// @HookContext
/// struct SessionContext {
///     var token: String = ""
/// }
///
/// @HookForm
/// struct LoginForm {
///     var email: String = ""
///     var password: String = ""
/// }
/// ```
///
/// ### Utility macros
/// ```swift
/// @Debounce(milliseconds: 300)
/// func onSearchChanged(_ query: String) async {
///     _ = query
/// }
///
/// @Throttle(milliseconds: 500)
/// func onTap() async {}
/// ```
///
// MARK: - Atom Macros

/// @StateAtom: Applied to `struct`. Generates `typealias Value` and `SKStateAtom` conformance.
@attached(extension, conformances: SKStateAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro StateAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateAtomMacro")

/// @ValueAtom: Applied to `struct`. Generates `typealias Value` and `SKValueAtom` conformance.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro ValueAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "ValueAtomMacro")

/// @TaskAtom: Applied to `struct`. Generates `typealias TaskSuccess` and `SKTaskAtom` conformance.
@attached(extension, conformances: SKTaskAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro TaskAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "TaskAtomMacro")

/// @ThrowingTaskAtom: Applied to `struct`. Generates `typealias TaskSuccess` and `SKThrowingTaskAtom` conformance.
@attached(extension, conformances: SKThrowingTaskAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro ThrowingTaskAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "TaskAtomMacro")

/// @PublisherAtom: Applied to `struct`. Generates associated types and `SKPublisherAtom` conformance.
@attached(extension, conformances: SKPublisherAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro PublisherAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "PublisherAtomMacro")

/// @Atom: Unified macro that auto-detects atom type.
@attached(extension, conformances: SKStateAtom, SKValueAtom, SKTaskAtom, SKThrowingTaskAtom, SKPublisherAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro Atom() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomMacro")

/// @AtomFamily: Parameterized state factory.
@attached(extension, conformances: SKStateAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro AtomFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomFamilyMacro")

/// @SelectorFamily: Parameterized computed values.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro SelectorFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "SelectorFamilyMacro")

/// @AsyncTaskFamily: Parameterized async tasks.
@attached(extension, conformances: SKTaskAtom, Hashable, names: arbitrary)
@attached(memberAttribute)
public macro AsyncTaskFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncTaskFamilyMacro")

/// @AtomReducer: Reducer-based state atom.
@attached(extension, conformances: SKStateAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
public macro AtomReducer() = #externalMacro(module: "StateKitMacrosPlugin", type: "AtomReducerMacro")

/// @Computed: Derived atom via `compute(context:)`.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro Computed() = #externalMacro(module: "StateKitMacrosPlugin", type: "ComputedMacro")

/// @SelectorAtom: Derived state via `select(context:)`.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro SelectorAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "SelectorAtomMacro")

/// @FilteredAtom: Filtered atom from predicate.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro FilteredAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "FilteredAtomMacro")

/// @MappedAtom: Mapped atom from transform.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro MappedAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "MappedAtomMacro")

/// @CombineAtom: Combines multiple atoms.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro CombineAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "CombineAtomMacro")

/// @DistinctAtom: Only emits distinct values.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro DistinctAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "DistinctAtomMacro")

/// @FlatMapAtom: Flattens nested async values.
@attached(extension, conformances: SKValueAtom, Hashable, names: arbitrary)
@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro FlatMapAtom() = #externalMacro(module: "StateKitMacrosPlugin", type: "FlatMapAtomMacro")

// MARK: - Riverpod Macros

/// @RiverpodNotifier: Generates a derived `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro RiverpodNotifier() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodNotifierMacro")

/// @RiverpodFamily: Generates a family suffixed with 'Family' (Peer).
@attached(peer, names: arbitrary)
public macro RiverpodFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodFamilyMacro")

/// @StateProvider: Generates a derived `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro StateProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "StateProviderMacro")

/// @Provider: Generates a derived `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro Provider() = #externalMacro(module: "StateKitMacrosPlugin", type: "ProviderMacro")

/// @FutureProvider: Generates a `FutureProvider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro FutureProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "FutureProviderMacro")

/// @StreamProvider: Generates a `StreamProvider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro StreamProvider() = #externalMacro(module: "StateKitMacrosPlugin", type: "StreamProviderMacro")

/// @ProviderFamily: Generates a family `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro ProviderFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "ProviderFamilyMacro")

/// @RiverpodSelector: Generates a selector `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro RiverpodSelector() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodSelectorMacro")

/// @RiverpodAsync: Generates an async `Provider` suffixed with 'Provider' (Peer).
@attached(peer, names: arbitrary)
public macro RiverpodAsync() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodAsyncMacro")

/// @RiverpodFutureFamily: Generates a family suffixed with 'Family' (Peer).
@attached(peer, names: arbitrary)
public macro RiverpodFutureFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodFutureFamilyMacro")

/// @RiverpodStreamFamily: Generates a family suffixed with 'Family' (Peer).
@attached(peer, names: arbitrary)
public macro RiverpodStreamFamily() = #externalMacro(module: "StateKitMacrosPlugin", type: "RiverpodStreamFamilyMacro")

// MARK: - View Macros

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
@attached(memberAttribute)
public macro ObservableState() = #externalMacro(module: "StateKitMacrosPlugin", type: "ObservableStateMacro")

// MARK: - Hook Macros

/// @Hook: Validates that the annotated function follows the `use` naming convention.
/// Generates no code — purely a compile-time validation marker.
@attached(peer, names: overloaded)
public macro Hook() = #externalMacro(module: "StateKitMacrosPlugin", type: "CheckHookFunctionMacro")


/// @HookState: Generates a hook function 'use<StructName>' returning a Binding (Peer).
@attached(peer, names: prefixed(use))
public macro HookState() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookStateMacro")

/// @HookRef: Generates a hook function 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookRef() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookRefMacro")

/// @HookToggle: Generates a boolean toggle hook 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookToggle() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookToggleMacro")

/// @HookEffect: Generates effect hook 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookEffect() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookEffectMacro")

/// @HookLayoutEffect: Generates layout-effect hook 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookLayoutEffect() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookLayoutEffectMacro")

/// @AsyncHook: Generates async hook 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro AsyncHook() = #externalMacro(module: "StateKitMacrosPlugin", type: "AsyncHookMacro")

/// @HookPrevious: Tracks previous value 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookPrevious() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookPreviousMacro")

/// @HookInterval: Polling hook 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookInterval() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookIntervalMacro")

/// @HookMemo: Generates memo hook 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookMemo() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookMemoMacro")

/// @HookCallback: Generates callback hook 'use<StructName>' (Peer).
@attached(peer, names: prefixed(use))
public macro HookCallback() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookCallbackMacro")

/// @HookReducer: Generates hook function 'use<StructName>' with reducer pattern (Peer).
@attached(peer, names: prefixed(use))
public macro HookReducer() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookReducerMacro")

/// @HookContext: Generates context hook 'use<StructName>' and _hookContext (Peer).
@attached(peer, names: prefixed(use), named(_hookContext))
public macro HookContext() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookContextMacro")

/// @HookForm: Generates form hook 'use<StructName>' and FHook struct (Peer).
@attached(peer, names: prefixed(use), named(FHook))
public macro HookForm() = #externalMacro(module: "StateKitMacrosPlugin", type: "HookFormMacro")

// MARK: - Utility Macros

/// @Debounce: Delays execution of an async function.
@attached(peer, names: arbitrary)
public macro Debounce(milliseconds: Int) = #externalMacro(module: "StateKitMacrosPlugin", type: "DebounceMacro")

/// @Throttle: Limits execution frequency of an async function.
@attached(peer, names: arbitrary)
public macro Throttle(milliseconds: Int) = #externalMacro(module: "StateKitMacrosPlugin", type: "ThrottleMacro")
