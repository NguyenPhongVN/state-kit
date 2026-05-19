# StateKit V1 Macro Reference

Stable quick-reference for all shipped macros in V1.

Source of truth:

- `Sources/StateKitMacros/StateKitMacros.swift`

## Coverage Summary

| Group | Count |
|---|---:|
| Atoms | 17 |
| Riverpods | 11 |
| Views | 4 |
| Hooks | 13 |
| Utility | 2 |
| **Total** | **47** |

## Atom Macros (17)

`@StateAtom`, `@ValueAtom`, `@TaskAtom`, `@ThrowingTaskAtom`, `@PublisherAtom`, `@Atom`, `@AtomFamily`, `@SelectorFamily`, `@AsyncTaskFamily`, `@AtomReducer`, `@Computed`, `@SelectorAtom`, `@FilteredAtom`, `@MappedAtom`, `@CombineAtom`, `@DistinctAtom`, `@FlatMapAtom`

## Riverpod Macros (11)

`@RiverpodNotifier`, `@RiverpodFamily`, `@StateProvider`, `@Provider`, `@FutureProvider`, `@StreamProvider`, `@ProviderFamily`, `@RiverpodSelector`, `@RiverpodAsync`, `@RiverpodFutureFamily`, `@RiverpodStreamFamily`

## View Macros (4)

`@HookView`, `@StateView`, `@AsyncView`, `@ObservableState`

## Hook Macros (13)

`@Hook`, `@HookState`, `@HookRef`, `@HookToggle`, `@HookEffect`, `@AsyncHook`, `@HookPrevious`, `@HookInterval`, `@HookMemo`, `@HookCallback`, `@HookReducer`, `@HookContext`, `@HookForm`

## Utility Macros (2)

`@Debounce`, `@Throttle`

## Selection Cheatsheet

| Need | Recommended Macros |
|---|---|
| Global mutable state | `@StateAtom`, `@StateProvider` |
| Global derived state | `@ValueAtom`, `@Computed`, `@Provider` |
| Async state | `@TaskAtom`, `@ThrowingTaskAtom`, `@FutureProvider`, `@StreamProvider` |
| Parameterized state | `@AtomFamily`, `@SelectorFamily`, `@ProviderFamily` |
| View boilerplate reduction | `@StateView`, `@HookView`, `@AsyncView` |
| Local reusable hook patterns | `@HookState`, `@HookEffect`, `@HookMemo`, `@HookReducer`, `@HookForm` |
