# StateKit Manual

This documentation summarizes the complete API of `StateKit` (Hooks, Atoms, Concurrency, and Macros) as demonstrated in the `CaseStudies` application.

---

## 1. Scoped Hook API (Local State)

| Category | API |
|------|-----|
| State | `useState`, `useBinding`, `useReducer`, `useRef`, `useMemo`, `useCallback` |
| Data Flow | `useContext`, `useEnvironment`, `useOnChange` |
| Effects | `useEffect`, `useLayoutEffect` |
| Async | `useAsync`, `useAsyncSequence`, `usePublisher` |
| Runtime | `StateScope`, `StateView`, `UpdateStrategy` |

### Critical Runtime Concepts
- **`StateScope`**: Mandatory wrapper for any code utilizing hooks.
- **`UpdateStrategy`**: Controls hook re-execution (`.once`, `.preserved(by:)`).

---

## 2. Atom API (Global State)

Atoms are independent state units accessible from anywhere in the application.

| Atom Type | Protocol | Description |
|-----------|----------|-------------|
| State Atom | `SKStateAtom` | Stores data with direct read/write access. |
| Value Atom | `SKValueAtom` | Derived data that updates automatically when source atoms change. |
| Task Atom | `SKTaskAtom` | Performs asynchronous tasks that do not throw errors. |
| Throwing Task | `SKThrowingTaskAtom` | Performs asynchronous tasks that may `throw` errors. |
| Publisher | `SKPublisherAtom` | Integrates with Combine Publishers. |

### Usage (Property Wrappers)
- **`@SKState(MyAtom())`**: Read/write access to a state atom.
- **`@SKValue(MyDerivedAtom())`**: Read access to derived data (read-only).
- **`@SKTask(MyAsyncAtom())`**: Track the state of an async task (`AsyncPhase`).
- **`@SKContext`**: Imperative access to the store (for action handlers).

---

## 3. Macro API - 48 Macros

The Macro system minimizes boilerplate, automatically generates conformances, and manages Concurrency isolation.

### 3.1 Atom Macros (17)
Applied to `struct`. Automatically adds `@MainActor`, `Hashable`, and `typealias Value`.

- **Core**: `@StateAtom`, `@ValueAtom`, `@TaskAtom`, `@ThrowingTaskAtom`, `@PublisherAtom`, `@Atom`.
- **Advanced**: `@AtomFamily` (ID-based), `@AtomReducer` (Reducer pattern).
- **Variants**: `@Computed`, `@SelectorAtom`, `@FilteredAtom`, `@MappedAtom`, `@CombineAtom`, `@DistinctAtom`, `@FlatMapAtom`.

### 3.2 Riverpod Macros (11)
Bridges the Riverpod system with StateKit.

- **Providers**: `@RiverpodNotifier` (class), `@StateProvider`, `@Provider`, `@FutureProvider`, `@StreamProvider`.
- **Families**: `@RiverpodFamily` (class), `@ProviderFamily`, `@RiverpodFutureFamily`, `@RiverpodStreamFamily`.
- **Misc**: `@RiverpodSelector`, `@RiverpodAsync`.

### 3.3 Hook Macros (16)
Peer macros that generate `use...` functions from logic structs.

- **Stateful**: `@HookState`, `@HookRef`, `@HookToggle`, `@HookPrevious`, `@HookMemo`, `@HookCallback`, `@HookReducer`.
- **Effects**: `@HookEffect`, `@AsyncHook`, `@HookInterval`.
- **Control**: `@Debounce`, `@Throttle` (Applied to async functions).
- **Infrastructure**: `@HookContext`, `@HookForm`, `@Hook`, `@CustomHook`.

### 3.4 View Macros (4)
Optimizes SwiftUI View declarations.

- **UI Integration**: `@HookView`, `@StateView` (Auto-generates `body` and `StateScope`).
- **Async Handling**: `@AsyncView(atom:)` (Generates `isLoading`, `hasError` helpers).
- **Observation**: `@ObservableState` (Integration with Swift 6 Observation Framework).

---

## 4. Concurrency Utilities (SCTask)

Extended toolkit for Swift Concurrency and `AsyncSequence`.

### Task Extensions
- **`Task.retrying`**: Automatically retries on failure (supports exponential backoff).
- **`Task.throwingTimeout`**: Limits the execution time of a task.
- **`Task.gather`**: Executes multiple tasks in parallel and collects results (concurrency limited).
- **`Task.race`**: Executes multiple tasks and returns the fastest result.

### AsyncSequence Operators
- **`.timeout(_:)`**: Terminates the stream if no new data is received within a specified interval.
- **`.debounce(for:)`**: Delays data emission until the stream stabilizes.

---

## 5. Common Hooks in Detail

### `useState` / `useBinding`
Local state management. `useBinding` returns a SwiftUI `Binding<T>`.

```swift
let (count, setCount) = useState(0)
let name = useBinding("")
```

### `useEffect` / `useLayoutEffect`
Runs side effects after rendering. Supports a cleanup function for resource management.

```swift
useEffect(updateStrategy: .preserved(by: socketURL)) {
    let socket = connect(socketURL)
    return { socket.disconnect() } // Cleanup
}
```

---

## 6. Quick Selection Guide

| If you need... | Use... |
|----------------|-------------|
| Fast Atom definition | `@StateAtom`, `@ValueAtom` |
| Identity/Auth management | `@RiverpodNotifier` + `@RiverpodSelector` |
| View using Hooks | `@HookView` |
| Debounced Search | `@Debounce` on an async function |
| Form Validation | `@HookForm` |
| Complex update logic | `useReducer` or `@HookReducer` |
| Global state (Observed) | `@ObservableState` |
| Calculation optimization | `useMemo` or `@HookMemo` |
