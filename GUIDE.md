# StateKit Documentation

Comprehensive guide for StateKit, StateKitAtoms, and Riverpods.

---

## Table of Contents
1. [Introduction](#introduction)
2. [StateKit (Hooks)](#statekit-hooks)
3. [Riverpods](#riverpods)
4. [StateKitAtoms](#statekitatoms)
5. [StateConcurrency](#stateconcurrency)
6. [StateKitSupport](#statekitsupport)
7. [Testing](#testing)
8. [Best Practices](#best-practices)

---

## Introduction

StateKit is a modern state management ecosystem for Swift and SwiftUI. It provides three distinct but compatible patterns for managing state:
- **Scoped State (Hooks)**: Component-local state inspired by React.
- **Global Business Logic (Riverpod)**: Class-based notifiers and providers.
- **Data-First State (Atoms)**: Graph-based global state inspired by Recoil/Jotai.

---

## StateKit (Hooks)

Scoped state lives inside a single `StateScope` or `StateView`. It's perfect for UI-only state like form inputs, animations, or temporary view data.

### Core Hooks
- `useState(initialValue)`: Returns a stateful value and a setter.
- `useReducer(reducer, initialState)`: For complex state logic.
- `useMemo(strategy, compute)`: Caches computed values.
- `useRef(initialValue)`: Persistent mutable value that doesn't trigger re-renders.
- `useEffect(strategy, effect)`: Side effects with optional cleanup.

### Async Hooks
- `useAsync(strategy, operation)`: Manage async task phases using `AsyncPhase`.
- `useAsyncSequence(sequence)`: Bridges an `AsyncSequence` into `AsyncSequencePhase`.
- `usePublisher(publisher)`: Bridges a Combine `Publisher` into `PublisherPhase`.

### Phase Enums
- **`AsyncPhase<T>`**: Used by `useAsync`. States: `.idle`, `.loading`, `.success(T)`, `.failure(Error)`.
- **`AsyncValue<T>`**: Used by Riverpod. States: `.data(T)`, `.loading`, `.error(Error)`, `.refreshing(T)`.
- **`PublisherPhase<T>`**: Used by `usePublisher`. States: `.idle`, `.value(T)`, `.finished`, `.failure(Error)`.

### Integration
Use `StateView` for a clean, protocol-based approach:
```swift
struct MyView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)
        Button("Count: \(count)") { setCount(count + 1) }
    }
}
```

---

## Riverpods

A feature-complete port of Riverpod for Swift. Best for shared business logic and global state.

### Providers
- `Provider`: For read-only computed values.
- `StateProvider`: For simple mutable global state.
- `NotifierProvider`: For class-based logic (use `Notifier`).
- `AsyncNotifierProvider`: For class-based async logic (use `AsyncNotifier`).
- `FutureProvider` / `StreamProvider`: Bridges async/streams into global state.

### Usage in SwiftUI
Use `@Watch` to observe a provider and `@Read` to read it once.
```swift
let counterProvider = StateProvider { _ in 0 }

struct CounterView: View {
    @Watch(counterProvider) var count
    @Watch(counterProvider.notifier) var controller
    
    var body: some View {
        Button("\(count)") { controller.state += 1 }
    }
}
```

---

## StateKitAtoms

Atom-based state management for fine-grained updates and dependency graphs.

### Core Concepts
- `SKStateAtom`: A simple piece of state.
- `SKValueAtom`: A derived (computed) value.
- `SKTaskAtom`: An async atom.
- `SKAtomStore`: The central store (inject via `SKAtomRoot`).

### Usage
```swift
struct MyAtom: SKStateAtom, Hashable {
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

struct MyView: View {
    @SKState(MyAtom()) var count
    var body: some View { ... }
}
```

---

## StateConcurrency

Powerful extensions for Swift Structured Concurrency.

### Task Extensions
- `Task.retrying(policy, operation)`: Retry with backoff.
- `Task.timeout(duration, operation)`: Enforce time limits.
- `Task.gather(operations)`: Concurrent execution with result gathering.
- `Task.gatherThrowing(operations, maxConcurrentTasks:)`: Parallel execution with concurrency limits.
- `Task.race(operations)`: Returns the fastest result.

### AsyncSequence Operators
- `.timeout(_:)`, `.debounce(for:)`, `.throttle(for:)`.

---

## StateKitSupport

Syntactic sugar for Hooks and Atoms.
- `@HState`, `@HMemo`, `@HRef`: Use hooks inside standard SwiftUI views (requires `StateScope`).
- `@SKState`, `@SKValue`, `@SKTask`: Atom property wrappers.

---

## Testing

Use `StateKitTesting` for isolated hook tests.
```swift
@Test func testCounter() async {
    let test = StateTest(0) { useState($0) }
    #expect(test.value.0 == 0)
    test.value.1(5)
    #expect(test.value.0 == 5)
}
```

---

## Best Practices

1. **Rules of Hooks**: Only call hooks at the top level of `stateBody`. Never in loops or conditionals.
2. **Stable Providers**: Always define Providers as global constants to ensure stable identity.
3. **Prefer Hooks for Local State**: Don't use global atoms/providers for state that only one view cares about.
4. **Use `select()`**: When watching a large object, use `.select(\.property)` to minimize re-renders.
5. **Auto-Dispose**: Use `autoDispose: true` (default) for providers to keep memory usage low.
