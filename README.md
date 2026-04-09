# StateKit

A React Hooks-inspired state management library for Swift and SwiftUI. StateKit provides a lightweight hook runtime for scoped local state, plus a global atom store modelled after Recoil / Jotai.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6.2 (strict concurrency) |
| UI Framework | SwiftUI |
| Reactivity | `Observation` framework (`@Observable`, `ObservationRegistrar`) |
| Concurrency | Swift Structured Concurrency (`async`/`await`, `Task`, `AsyncSequence`) |
| Reactive streams | Combine (`usePublisher`) |
| Async utilities | `swift-concurrency-extras` (PointFree) |
| Testing | Swift Testing (`@Suite`, `@Test`, `#expect`) |
| Macros | SwiftSyntax 602 |
| Platforms | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ |

---

## Modules

| Module | What it provides |
|---|---|
| `StateKitCore` | `StateContext`, `StateRuntime`, `StateSignal`, `StateRef` |
| `StateKit` | All hook functions — `useState`, `useReducer`, `useMemo`, `useAsync`, `usePublisher`, … |
| `StateKitUI` | `StateView`, `StateScope` |
| `StateKitAtoms` | Global atom store — `SKStateAtom`, `SKValueAtom`, `SKTaskAtom`, atom hooks |
| `StateKitSupport` | Property wrappers — `@SKScopeState`, `@SKScopeMemo`, `@SKScopeRef` |
| `StateKitCombine` | Combine bridge |
| `StateKitTesting` | `StateTest` harness for unit-testing hooks |
| `StateKitDevTools` | `StateDevScope` — debug overlay for hook scopes |
| `StateConcurrency` | `AsyncCurrentValueStream`, `AsyncPassthroughStream`, type-erased async sequences |

### Architecture

```
StateKitCore          ← no SwiftUI, no Combine
    └── StateKit      ← hook functions + AsyncPhase
        ├── StateKitUI        ← StateScope, StateView
        ├── StateKitAtoms     ← atom store + atom hooks
        ├── StateKitSupport   ← @HState, @HMemo, @HRef
        ├── StateKitTesting   ← StateTest harness
        ├── StateKitDevTools  ← debug overlay
        └── StateKitCombine   ← Combine bridge

StateConcurrency      ← standalone async sequence utilities
```

---

## Installation

```swift
// Package.swift
.package(url: "https://github.com/your-org/state-kit", from: "1.0.0")
```

---

## Concepts

### Scoped state (hook layer)

Local state that lives inside a single `StateScope` / `StateView` — equivalent to React's component-local hooks. Hooks are identified by **call-site position**, so they must always be called in the same order across renders.

### Global state (atom layer)

Shared state stored in `SKAtomStore`. Every atom is an independent unit of state; views subscribe to exactly the atoms they read. Unrelated atoms never cause unnecessary re-renders.

---

## Quick Start

```swift
import SwiftUI
import StateKitUI
import StateKitAtoms

// 1. Wrap your root view in SKAtomRoot to provide the shared store
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            SKAtomRoot { ContentView() }
        }
    }
}

// 2. Use hooks in any view
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)
        let (name, _) = useAtomState(NameAtom())

        VStack {
            Text("Local: \(count)")
            Text("Global name: \(name)")
            Button("+1") { setCount(count + 1) }
        }
    }
}
```

---

## Scoped State — Hook API

All hooks must be called inside a `StateScope` closure or a `StateView.stateBody`. Hook call order must be stable across renders — never call hooks inside `if`, `guard`, or `for`.

### useState

Returns the current value and a setter. Calling the setter writes to an `@Observable` `StateSignal` and triggers a re-render.

```swift
@MainActor
public func useState<T>(_ initial: T) -> (T, (T) -> Void)
```

```swift
let (isOn, setIsOn) = useState(false)
Toggle("Enable", isOn: Binding(get: { isOn }, set: setIsOn))
```

### useBinding

Like `useState` but returns a SwiftUI `Binding<T>` directly.

```swift
let name = useBinding("")
TextField("Name", text: name)
```

### useReducer

Manages state through a typed action enum.

```swift
enum Action { case increment, decrement, reset }

let (count, dispatch) = useReducer(0) { state, action in
    switch action {
    case .increment: state += 1
    case .decrement: state -= 1
    case .reset:     state = 0
    }
}

HStack {
    Button("-") { dispatch(.decrement) }
    Text("\(count)")
    Button("+") { dispatch(.increment) }
}
```

### useRef

Returns a `StateRef<T>` that persists across renders. Mutations to `.value` do **not** trigger a re-render.

```swift
let timerRef = useRef<Timer?>(nil)

Button("Start") {
    timerRef.value?.invalidate()
    timerRef.value = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in print("tick") }
}
```

### useMemo

Returns a cached value, recomputing only when `updateStrategy` changes.

```swift
let sorted = useMemo(updateStrategy: .preserved(by: items)) {
    items.sorted()
}
```

### useCallback

Returns a cached closure, replacing it only when `updateStrategy` changes.

```swift
let stableHandler = useCallback(updateStrategy: .preserved(by: query)) {
    performSearch(query)
}
```

### useEffect

Runs a side effect after render. Returns an optional cleanup closure.

```swift
useEffect(updateStrategy: .preserved(by: userId)) {
    let task = Task { await loadProfile(userId) }
    return { task.cancel() }
}
```

### useLayoutEffect

Same as `useEffect` but runs synchronously during the render pass.

### useEnvironment

Reads a `EnvironmentValues` key path from within any `StateScope`.

```swift
let colorScheme = useEnvironment(\.colorScheme)
let store       = useEnvironment(\.skAtomStore)
```

### useOnChange

Fires a closure when a value changes between renders.

```swift
useOnChange(query) { newQuery in
    analytics.log("search", newQuery)
}
```

---

## Async Hooks

### useAsync

Runs an `async throws` operation and returns its current `AsyncPhase`.

```swift
struct UserView: StateView {
    let userId: String

    var stateBody: some View {
        let phase = useAsync(updateStrategy: .preserved(by: userId)) {
            try await api.fetchUser(id: userId)
        }

        switch phase {
        case .idle, .loading: ProgressView()
        case .success(let user): Text(user.name)
        case .failure(let error): Text(error.localizedDescription)
        }
    }
}
```

```swift
public enum AsyncPhase<Value> {
    case idle
    case loading
    case success(Value)
    case failure(Error)
}
```

### useAsyncSequence

Iterates an `AsyncSequence` element-by-element.

```swift
let phase = useAsyncSequence {
    NotificationCenter.default.notifications(named: .NSSystemClockDidChange).map { _ in Date() }
}

if case .value(let date) = phase { Text(date.formatted()) }
```

### usePublisher

Subscribes to a Combine `Publisher`.

```swift
let phase = usePublisher(updateStrategy: .preserved(by: query)) {
    searchService.search(query: query)
}

switch phase {
case .value(let items): ResultsList(items)
case .failure(let e):   Text(e.localizedDescription)
default:                ProgressView()
}
```

---

## UpdateStrategy

```swift
.once                              // evaluated exactly once on first render
.always                            // re-evaluated every render
.preserved(by: someEquatable)      // re-evaluated when deps change
.preserved(by: a, b, c)            // variadic AnyHashable
.preserved(by: [a, b])             // array
```

---

## SwiftUI Integration

### StateView

```swift
struct ProfileView: StateView {
    let userId: String

    var stateBody: some View {
        let phase = useAsync(updateStrategy: .preserved(by: userId)) {
            try await api.fetchUser(id: userId)
        }
        // ...
    }
}
```

### StateScope

Use `StateScope` directly inside a plain `View.body`:

```swift
struct RootView: View {
    var body: some View {
        StateScope {
            let (tab, setTab) = useState(0)
            TabView(selection: Binding(get: { tab }, set: setTab)) { ... }
        }
    }
}
```

---

## Global State — Atom API (`StateKitAtoms`)

### Defining atoms

```swift
// Named atom (Hashable struct — recommended for cross-module sharing)
struct CounterAtom: SKStateAtom, Hashable {
    typealias Value = Int   // explicit typealias required (Swift 6.3+)
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

// Derived read-only atom
struct DoubledAtom: SKValueAtom, Hashable {
    typealias Value = Int
    func value(context: SKAtomTransactionContext) -> Int {
        context.watch(CounterAtom()) * 2
    }
}

// Async atom
struct UserAtom: SKTaskAtom, Hashable {
    typealias TaskSuccess = User
    let id: String
    func task(context: SKAtomTransactionContext) async -> User {
        await api.fetchUser(id: id)
    }
}
```

### Inline atoms

```swift
let countAtom  = atom(0)
let doubleAtom = selector { ctx in ctx.watch(countAtom) * 2 }

// Parameterised family
let userAtom = atomFamily { (id: String) in "user:\(id)" }
let userProfile = selectorFamily { (id: String, ctx: SKAtomTransactionContext) in
    ctx.watch(userAtom(id)).uppercased()
}
```

### Atom hook API (inside `StateScope` / `StateView`)

| Hook | Description |
|---|---|
| `useAtomValue(_:)` | Read any atom's current value |
| `useAtomState(_:)` | `(value, setter)` for a mutable atom — like `useState` for globals |
| `useAtomBinding(_:)` | `Binding<Value>` for a mutable atom |
| `useAtomReset(_:)` | Closure that resets the atom to its default |
| `useAtomRefresher(_:)` | `async` closure that re-runs a task atom |

```swift
struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useAtomState(CounterAtom())
        let doubled           = useAtomValue(DoubledAtom())

        VStack {
            Text("Count: \(count)  Doubled: \(doubled)")
            Button("+1") { setCount(count + 1) }
        }
    }
}
```

### SwiftUI property wrappers (alternative to hooks)

| Wrapper | Description |
|---|---|
| `@SKState` | Read/write mutable atom; re-renders on change |
| `@SKValue` | Read-only derived atom |
| `@SKTask` | Async atom; exposes `AsyncPhase<T>` |
| `@SKAtomContext` | Imperative `read`, `set`, `reset`, `binding(for:)` |

```swift
struct CounterView: View {
    @SKState(CounterAtom()) var count
    @SKValue(DoubledAtom()) var doubled

    var body: some View {
        Button("Count: \(count)  Doubled: \(doubled)") {
            count += 1
        }
    }
}
```

### Store setup

```swift
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            SKAtomRoot { ContentView() }
        }
    }
}
```

### Eviction and imperative access

```swift
let store = SKAtomStore()

store.contains(CounterAtom())              // Bool
store.evict(CounterAtom())                 // removes atom from store

let ctx = SKAtomViewContext(store: store)
ctx.read(CounterAtom())                    // Int
ctx.set(42, for: CounterAtom())
ctx.reset(CounterAtom())
let binding = ctx.binding(for: CounterAtom())  // Binding<Int>
```

---

## Property Wrappers (`StateKitSupport`)

Must be declared inside a `StateScope` or `stateBody`. Import `StateKitSupport`.

### @SKScopeState

Backed by `useBinding`. `$name` gives the underlying `Binding<T>`.

```swift
@SKScopeState var name  = ""
@SKScopeState var count = 0

// Bridge an external Binding — no hook slot consumed
@SKScopeState var external = $parentCount
```

### @SKScopeMemo

Backed by `useMemo`. The initializer expression is an `@autoclosure`.

```swift
@SKScopeMemo(.preserved(by: items)) var sorted = items.sorted()
@SKScopeMemo var expensive = computeOnce()   // .once by default
```

### @SKScopeRef

Backed by `useRef`. Mutations never trigger re-renders. `$name` gives `StateRef<T>`.

```swift
@SKScopeRef var cancellable: AnyCancellable? = nil

Button("Load") {
    cancellable?.cancel()
    cancellable = publisher.sink { print($0) }
}
```

---

## Testing (`StateKitTesting`)

`StateTest` drives hook functions in plain Swift unit tests — no SwiftUI view hierarchy needed.

```swift
import Testing
import StateKit
import StateKitTesting

@MainActor
@Suite("Counter")
struct CounterTests {

    @Test("useState increments")
    func increment() {
        let h = StateTest()

        let (v1, set) = h.render { useState(0) }
        #expect(v1 == 0)

        set(42)

        let (v2, _) = h.render { useState(0) }
        #expect(v2 == 42)
    }

    @Test("useAtomState with injected store")
    func atomState() {
        var env = EnvironmentValues()
        env.skAtomStore = SKAtomStore()

        let h = StateTest()
        let (v1, set) = h.render(environment: env) { useAtomState(CounterAtom()) }
        #expect(v1 == 0)
        set(7)
        let (v2, _) = h.render(environment: env) { useAtomState(CounterAtom()) }
        #expect(v2 == 7)
    }
}
```

| API | Description |
|---|---|
| `StateTest()` | Creates a fresh harness |
| `h.render { ... }` | One render pass; returns closure value |
| `h.render(environment: env) { ... }` | Same, with injected `EnvironmentValues` |
| `h.renderCount` | Number of completed render calls |
| `h.reset()` | Releases all hook state; resets `renderCount` |

---

## Debug Tools (`StateKitDevTools`)

`StateDevScope` / `StateDevView` add a translucent overlay showing render counts and hook slot contents. Compiled out entirely in Release builds.

```swift
// Drop-in replacement for StateScope
StateDevScope {
    let (count, setCount) = useState(0)
    Button("Tap \(count)") { setCount(count + 1) }
}

// Swap StateView → StateDevView while debugging
struct CounterView: StateDevView {
    var stateBody: some View { ... }
}
```

---

## Async Sequences (`StateConcurrency`)

| Type | Description |
|---|---|
| `AsyncCurrentValueStream<T>` | Buffers the latest value (like `CurrentValueSubject`) |
| `AsyncPassthroughStream<T>` | Forwards values without buffering (like `PassthroughSubject`) |
| `AsyncValueStream<T>` | Value-semantics wrapper |
| `AnyAsyncSequence<T>` | Type-erased `AsyncSequence` |

Use with `useAsyncSequence` to drive hook state from live data streams:

```swift
let stream = AsyncCurrentValueStream<Int>(0)

// In a StateView:
let phase = useAsyncSequence { stream }
if case .value(let n) = phase { Text("\(n)") }

// Elsewhere:
stream.send(42)
```

---

## Global State — `StateStore` / `StateKey` (simple key-value store)

For lightweight cross-view sharing without full atom semantics, use `StateStore`:

```swift
extension StateKey {
    static let counter = StateKey<Int>("counter")
}

// Write
StateStore.shared.set(key: .counter, value: 5)

// Read
let n = StateStore.shared.get(key: .counter, default: 0)
```

Access from SwiftUI via `@ViewContext`:

```swift
struct CounterView: View {
    @ViewContext var store

    var body: some View {
        let count = store.get(key: .counter, default: 0)
        Button("\(count)") { store.set(key: .counter, value: count + 1) }
    }
}
```

---

## Rules of Hooks

1. **Call hooks at the top level** — never inside `if`, `guard`, `for`, or nested closures.
2. **Same order every render** — hooks are identified by position; reordering breaks state.
3. **Only inside a StateScope** — calling a hook outside `StateRuntime.current` is a `fatalError`.
4. **Main thread only** — all hooks are `@MainActor`.

---

## License

MIT
