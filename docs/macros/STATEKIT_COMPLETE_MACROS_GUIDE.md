# StateKit Complete Macros Guide (V1)

This guide introduces all shipped macros in StateKit V1 by category, then shows usage examples and a practical adoption path.

Macro source of truth:

- `Sources/StateKitMacros/StateKitMacros.swift`

## Coverage

- Total public macros: `47`
- Categories: Atoms (`17`), Riverpods (`11`), Views (`4`), Hooks (`13`), Utility (`2`)

## 1) Atom Macros

Use Atom macros for shared/global state and derived graph-based state.

### Core Atom Types

- `@StateAtom` - mutable atom with `defaultValue(context:)`
- `@ValueAtom` - derived atom with `value(context:)`
- `@TaskAtom` - async atom with `task(context:) async`
- `@ThrowingTaskAtom` - async throwing atom with `task(context:) async throws`
- `@PublisherAtom` - publisher-based atom with `publisher(context:)`
- `@Atom` - auto-detects atom shape from methods

### Families and Reducers

- `@AtomFamily` - parameterized state atoms
- `@SelectorFamily` - parameterized derived atoms
- `@AsyncTaskFamily` - parameterized async atoms
- `@AtomReducer` - reducer-driven state atom

### Derived and Transformation Atoms

- `@Computed`
- `@SelectorAtom`
- `@FilteredAtom`
- `@MappedAtom`
- `@CombineAtom`
- `@DistinctAtom`
- `@FlatMapAtom`

## 2) Riverpod Macros

Use Riverpod macros when you prefer provider-style APIs.

### Provider Macros

- `@StateProvider`
- `@Provider`
- `@FutureProvider`
- `@StreamProvider`
- `@ProviderFamily`

### Riverpod-Specific Helpers

- `@RiverpodNotifier`
- `@RiverpodFamily`
- `@RiverpodSelector`
- `@RiverpodAsync`
- `@RiverpodFutureFamily`
- `@RiverpodStreamFamily`

## 3) View Macros

Use View macros to reduce SwiftUI state-view boilerplate.

- `@HookView`
- `@StateView`
- `@AsyncView(atom:)`
- `@ObservableState`

## 4) Hook Macros

Use Hook macros for local state composition and reusable hook patterns.

### Validation

- `@Hook`

### State, Effects, and Context

- `@HookState`
- `@HookRef`
- `@HookToggle`
- `@HookEffect`
- `@AsyncHook`
- `@HookPrevious`
- `@HookInterval`
- `@HookMemo`
- `@HookCallback`
- `@HookReducer`
- `@HookContext`
- `@HookForm`

## 5) Utility Macros

- `@Debounce(milliseconds:)`
- `@Throttle(milliseconds:)`

## Examples by Category

### Atom Example

```swift
@StateAtom
struct CounterAtom {
    func defaultValue(context: Context) -> Int { 0 }
}
```

### Riverpod Example

```swift
@Provider
func greeting() -> String { "Hello" }
```

### View Example

```swift
@StateView
struct CounterView: View {
    var stateBody: some View {
        Text("Counter")
    }
}
```

### Hook Example

```swift
@HookState
struct LoginState {
    var email: String = ""
    var password: String = ""
}
```

## Practical Usage Guide

### Step 1: Start with one style

- Shared state first: use `@StateAtom` or `@StateProvider`
- Local state first: use `@HookState`

### Step 2: Add derived and async behavior

- Derived state: `@ValueAtom`, `@Computed`, `@Provider`
- Async state: `@TaskAtom`, `@ThrowingTaskAtom`, `@FutureProvider`

### Step 3: Reduce view boilerplate

- Use `@StateView` / `@HookView`
- Use `@AsyncView` for async UI helpers

### Step 4: Add advanced patterns only when needed

- Families: `@AtomFamily`, `@SelectorFamily`, `@ProviderFamily`
- Complex state: `@AtomReducer`, `@HookReducer`
- Timing: `@Debounce`, `@Throttle`

## Related Docs

- `STATEKIT_V1_REFERENCE.md`
- `HOOK_MACROS_COMPLETE_LIST.md`
- `HOOK_MACROS_EXAMPLES.md`
