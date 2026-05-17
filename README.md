# StateKit

StateKit is a modular state management toolkit for Swift and SwiftUI. It combines React-style hooks for local state, an atom-based global store (Recoil/Jotai style), and a feature-complete Riverpod implementation for Swift.

For a comprehensive guide on how to use all features, see [GUIDE.md](docs/GUIDE.md).

## Installation

Add StateKit to your project via Swift Package Manager. In your `Package.swift` file, add it as a dependency:

```swift
dependencies: [
    .package(url: "https://github.com/NguyenPhongVN/state-kit", from: "1.0.0")
]
```

Then, add the specific modules you need to your targets:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "StateKit", package: "state-kit"),
            .product(name: "StateKitAtoms", package: "state-kit"),
            .product(name: "Riverpods", package: "state-kit"),
            .product(name: "StateKitMacros", package: "state-kit")
        ]
    )
]
```

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6.2+ (strict concurrency) |
| UI Framework | SwiftUI |
| Reactivity | `Observation` framework (`@Observable`, `ObservationRegistrar`) |
| Concurrency | Swift Structured Concurrency (`async`/`await`, `Task`, `AsyncSequence`) |
| Reactive streams | Combine (`usePublisher`, `StreamProvider`) |
| Async utilities | `swift-concurrency-extras` (PointFree) |
| Testing | Swift Testing (`@Suite`, `@Test`, `#expect`) |
| Platforms | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ |

---

## Modules

| Module | What it provides |
|---|---|
| `StateKitCore` | `StateContext`, `StateRuntime`, `StateSignal`, `StateRef` |
| `StateKit` | All hook functions — `useState`, `useReducer`, `useMemo`, `useAsync`, … |
| `StateKitUI` | `StateScope`, `StateView` |
| `StateKitAtoms` | Global atom store — `SKStateAtom`, `SKValueAtom`, `SKTaskAtom`, Effects |
| `Riverpods` | Full Riverpod port — `Notifier`, `AsyncNotifier`, `ProviderContainer`, `Family`, `Overrides` |
| `StateKitSupport` | Property wrappers — `@HState`, `@HMemo`, `@HRef`, `@HEnvironment` |
| `StateConcurrency` | `SCTask` (Retry, Timeout, Gather), `AsyncCurrentValueStream`, `AsyncPassthroughStream` |
| `StateKitTesting` | `StateTest` harness for unit-testing hooks |
| `StateKitDevTools` | `StateDevScope` — debug overlay for hook scopes |
| `StateKitMacros` | Swift Macros — `@Atom`, `@Provider` to reduce boilerplate |
| `StateKitCombine` | Combine Bridge — `SKCombineAtom`, `asPhase()`, `asPublisher()` |

### Architecture

```
StateKitCore          ← no SwiftUI, no Combine
    └── StateKit      ← hook functions + AsyncPhase
        ├── StateKitUI        ← StateScope, StateView
        ├── StateKitAtoms     ← atom store + atom hooks
        ├── Riverpods         ← Riverpod containers + providers
        ├── StateKitSupport   ← @HState, @HMemo, @HRef
        ├── StateKitTesting   ← StateTest harness
        ├── StateKitDevTools  ← debug overlay
        ├── StateKitMacros    ← @Atom, @Provider macros
        └── StateKitCombine   ← Combine bridge

StateConcurrency      ← SCTask + standalone async sequence utilities
```

---

## 1. Riverpods (Swift) — Global Logic & Business State

`Riverpods` is a high-performance, feature-complete port of Flutter's Riverpod. It focuses on encapsulating business logic in Notifiers and managing global state with advanced lifecycle features.

### Core Concepts
- **ProviderContainer**: The central hub that owns all provider states. Supports **Transaction Batching** and **Circular Dependency Detection**.
- **Notifiers**: Encapsulate complex state and behavior in classes. Supports `Notifier` and `AsyncNotifier` (with seamless refresh).
- **Auto-Dispose**: Automatically cleans up memory when providers are no longer watched.
- **Provider Overrides**: Mock any provider for testing or scoped behavior.

### Quick Start (Riverpod)

```swift
// 1. Define a Notifier
class CounterNotifier: Notifier<Int> {
    override func build() -> Int { 0 }
    func increment() { state += 1 }
}

// 2. Define Providers
let counterProvider = NotifierProvider { CounterNotifier() }
let doubleProvider  = Provider { ref in ref.watch(counterProvider) * 2 }

// 3. Use in View
struct CounterView: View {
    @Watch(counterProvider) var count
    @Watch(counterProvider.notifier) var controller // Access behavior
    
    var body: some View {
        Button("Count: \(count)") { controller.increment() }
    }
}
```

### Advanced Providers
- **`FutureProvider`**: One-shot async tasks.
- **`StreamProvider`**: Continuous data flows from Combine Publishers.
- **`Family`**: Parameterized providers (e.g., `userProvider(id: 123)`).
- **`select()`**: Watch only a specific property to minimize re-renders.

---

## 2. Scoped State — Hook API (`StateKit`)

Local state that lives inside a single `StateScope` — equivalent to React's component-local hooks.

### Usage
All hooks must be called inside a `StateScope` or `StateView`. Order must be stable.

```swift
struct MyView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)
        let name = useBinding("")

        VStack {
            TextField("Name", text: name)
            Button("Count: \(count)") { setCount(count + 1) }
        }
    }
}
```

### Common Hooks
- **`useState(initial)`**: Simple reactive value.
- **`useBinding(initial)`**: Returns a SwiftUI `Binding`.
- **`useMemo(updateStrategy, compute)`**: Cache computed results.
- **`useEffect(updateStrategy, action)`**: Side effects with cleanup.
- **`useAsync(updateStrategy, operation)`**: Manage async task phases.

---

## 3. Global Atoms — Data-First State (`StateKitAtoms`)

Modelled after Recoil and Jotai. Best for shared data structures and graph-based dependencies.

### Features
- **Transaction Batching**: Group updates to prevent flickering.
- **Automatic Eviction**: Configurable policies (`.keepAlive`, `.evictWhenUnused`).
- **Cycle Detection**: Prevents infinite re-computations in the atom graph.
- **Atom Effects**: Lifecycle hooks (`initialized`, `updated`, `released`) for persistence and analytics.

```swift
struct MyAtomView: View {
    @SKState(UserAtom()) var user
    @SKValue(DerivedStatsAtom()) var stats

    var body: some View { ... }
}
```

---

## 4. Concurrency Utilities — `SCTask`

Professional-grade extensions for Swift Concurrency, located in `StateConcurrency`.

### Task Extensions
- **`Task.retrying`**: Automatic retry with exponential backoff.
- **`Task.throwingTimeout`**: Enforce strict execution time limits.
- **`Task.gather`**: Parallel task execution with concurrency limiting (`maxConcurrentTasks`).
- **`Task.race`**: Return the result of the fastest task, cancel the rest.

### AsyncSequence Operators
- **`.timeout(_:)`**: Throws an error if the stream is idle for too long.
- **`.debounce(for:)`**: Debounce rapid stream emissions.

---

## 5. Property Wrappers (`StateKitSupport`)

Modern sugar for both Hooks and Atoms.

- **`@HState`**: Shortcut for `useBinding`.
- **`@HMemo`**: Shortcut for `useMemo`.
- **`@HRef`**: Shortcut for `useRef`.
- **`@SKState` / `@SKValue`**: Atom observers.
- **`@Watch` / `@Read`**: Riverpod observers.

---

## Rules of Hooks

1. **Top-level only**: Never call hooks inside `if`, `guard`, or `for`.
2. **Stable order**: Identification is positional; reordering breaks state.
3. **Scoped**: Only call inside `StateScope` or `StateView.stateBody`.
4. **Main Actor**: All hooks and state mutations are `@MainActor`.

---

## Credits & Inspiration

- **React Hooks**: The API design for local state.
- **Recoil / Jotai**: Inspiration for the Atom-based global state.
- **Riverpod (Flutter)**: The architecture for class-based notifiers and provider containers.
- **PointFree**: Use of `swift-concurrency-extras`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
