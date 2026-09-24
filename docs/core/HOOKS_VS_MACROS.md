# Hooks vs `@Hook*` Macros — Which One to Use

StateKit exposes two first-class ways to write hook-based local state. Both are
supported, compile to the same runtime, and interoperate. Pick per call site:

## Function hooks (`useState`, `useEffect`, `useReducer`, …)

```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)
        useEffect(updateStrategy: .preserved(by: count)) {
            print("count is \(count)")
            return nil
        }
        return Button("Count: \(count)") { setCount(count + 1) }
    }
}
```

**Choose functions when:**

- You want direct control over hook order, dependencies (`UpdateStrategy`), and
  cleanup returns.
- The logic is dynamic — conditional composition across multiple hooks, custom
  helper hooks built from primitives.
- You are writing shared, reusable hook logic (a custom `useFetch`).

## Macro-annotated members (`@HookState`, `@HookEffect`, `@AsyncHook`, …)

```swift
@HookView
struct CounterView {
    @HookState var count = 0

    var body: some View {
        Button("Count: \(count)") { count += 1 }
    }
}
```

**Choose macros when:**

- You want plain property syntax (`count += 1`) with the hook machinery
  generated for you.
- You want compile-time checking of hook placement — the `@Hook` macro
  diagnostics reject hook members used outside a hook-enabled view instead of
  failing at runtime.
- The state mapping is conventional (state → property, effect → method) and
  you prefer less boilerplate over more control.

## Rules that apply to both

- Stable call/declaration order across renders (the runtime is positional).
- First render initializes; later renders ignore initial values.
- Effects clean up before re-running and on scope teardown.
- Never call hooks/macros conditionally or in loops.

## Interop

`@HookState` storage and `useState` slots live in the same positional store,
so mixing both styles in one view is safe — order still decides identity, and
macros reserve their slots at declaration order.
