/// StateKitSupport — property-wrapper sugar for StateKit hook functions.
///
/// Import this module alongside `StateKit` to use the `@SKScopeState`, `@SKScopeMemo`,
/// and `@SKScopeRef` property wrappers inside `StateView.stateBody` or any
/// `StateScope` closure.
///
/// ```swift
/// import StateKit
/// import StateKitSupport
///
/// struct NameFormView: StateView {
///     var stateBody: some View {
///         @SKScopeState var name = ""
///         @SKScopeMemo(.once) var uppercased = name.uppercased()
///         @SKScopeRef var previousName: String? = nil
///
///         VStack {
///             TextField("Name", text: $name)
///             Text("Upper: \(uppercased)")
///         }
///     }
/// }
/// ```
///
/// ## Wrappers
///
/// | Wrapper | Backed by | Reactive? |
/// |---------|-----------|-----------|
/// | `@SKScopeState` | `useBinding` | Yes — re-renders on change |
/// | `@SKScopeMemo` | `useMemo` | No — memoized until deps change |
/// | `@SKScopeRef` | `useRef` | No — never triggers re-render |
///
/// See the individual wrapper types for full documentation.

