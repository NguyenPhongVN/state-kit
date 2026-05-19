# Hook Macros Complete List

This file documents all shipped hook macros declared in `Sources/StateKitMacros/StateKitMacros.swift`.

## Validation

### `@Hook`
Validates hook naming and usage conventions for hook functions.

## State and References

### `@HookState`
Generates `use<StructName>()` helpers for struct-backed state.

### `@HookRef`
Generates `use<StructName>()` helpers for mutable references.

### `@HookToggle`
Generates boolean toggle-oriented hook helpers.

### `@HookPrevious`
Generates helpers that track previous values.

## Effects and Async

### `@HookEffect`
Generates side-effect hook scaffolding.

### `@AsyncHook`
Generates async hook scaffolding.

### `@HookInterval`
Generates interval or polling hook scaffolding.

## Memoization and Callbacks

### `@HookMemo`
Generates memoized value helpers.

### `@HookCallback`
Generates memoized callback helpers.

## Complex Patterns

### `@HookReducer`
Generates reducer-based hook helpers.

### `@HookContext`
Generates context-oriented hook helpers.

### `@HookForm`
Generates form state and form helper scaffolding.

## Recommended Adoption Order

1. `@HookState`
2. `@HookEffect`
3. `@HookMemo`
4. `@HookCallback`
5. `@HookForm`
6. `@HookReducer`
