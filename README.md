# StateKit

A React Hooks-inspired state management library for Swift and SwiftUI. StateKit provides a lightweight hook runtime for scoped local state, plus a global atom store modelled after Jotai / Recoil.

## Platforms

| Platform | Minimum |
|---|---|
| iOS | 17.0 |
| macOS | 14.0 |
| tvOS | 17.0 |
| watchOS | 10.0 |
| visionOS | 1.0 |

---

## Installation

```swift
// Package.swift
.package(url: "https://github.com/your-org/state-kit", from: "1.0.0")
```

### Modules

| Module | What it provides |
|---|---|
| `StateKitCore` | `StateContext`, `StateRuntime`, `StateSignal`, `StateRef`, `StateStore`, `StateKey` |
| `StateKit` | All hook functions — `useState`, `useReducer`, `useMemo`, `useAsync`, `usePublisher`, … |
| `StateKitUI` | `StateView`, `StateScope`, `ViewContext` |
| `StateKitSupport` | Property wrappers — `@HState`, `@HMemo`, `@HRef` |
| `StateKitCombine` | Combine bridge — `usePublisher` |
| `StateKitTesting` | `StateTest` harness for unit-testing hooks |

---

## Concepts

### Scoped state (hook layer)

Local state that lives inside a single `StateScope` / `StateView` — equivalent to React's component-local hooks. Hooks are identified by **call-site position**, so they must always be called in the same order across renders.

### Global state (atom layer)

Shared state keyed by `StateKey<T>` atoms, stored in the process-wide `StateStore.shared` singleton — equivalent to Jotai's `atom` / Riverpod's `StateProvider`.

---

## Quick Start

```swift
import SwiftUI
import StateKit
import StateKitUI

struct CounterView: StateView {
    var stateBody: some View {
        let (count, setCount) = useState(0)

        VStack {
            Text("Count: \(count)")
            Button("Increment") { setCount(count + 1) }
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

Like `useState` but returns a SwiftUI `Binding<T>` directly — ideal for controls that require a binding.

```swift
@MainActor
public func useBinding<T>(_ initial: T) -> Binding<T>
```

```swift
let name = useBinding("")
TextField("Name", text: name)
```

### useReducer

Manages state through a typed action enum. The reducer closure is updated every render; `dispatch` always calls the latest version.

```swift
@MainActor
public func useReducer<Action, State>(
    _ initial: State,
    _ reduce: @escaping (inout State, Action) -> Void
) -> (State, (Action) -> Void)
```

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

Returns a `StateRef<T>` that persists across renders. Mutations to `.value` do **not** trigger a re-render — use this for timers, cancellables, or any imperative object.

```swift
@MainActor
public func useRef<T>(_ initial: T) -> StateRef<T>
```

```swift
let timerRef = useRef<Timer?>(nil)

Button("Start") {
    timerRef.value?.invalidate()
    timerRef.value = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        print("tick")
    }
}
```

### useMemo

Returns a cached value, recomputing only when `updateStrategy` changes.

```swift
@MainActor
public func useMemo<T>(
    updateStrategy: UpdateStrategy? = .once,
    _ compute: () -> T
) -> T
```

```swift
let sorted = useMemo(updateStrategy: .preserved(by: items)) {
    items.sorted()
}
```

### useCallback

Returns a cached closure, replacing it only when `updateStrategy` changes. Preserving closure identity avoids unnecessary re-execution in downstream hooks.

```swift
@MainActor
public func useCallback<T>(
    updateStrategy: UpdateStrategy? = .once,
    _ callback: T
) -> T
```

```swift
let stableHandler = useCallback(updateStrategy: .preserved(by: query)) {
    performSearch(query)
}
```

### useEffect

Runs a side effect after render. Calls the previous cleanup before re-running, and calls cleanup one final time when the `StateScope` is destroyed.

```swift
@MainActor
public func useEffect(
    _ effect: @escaping () -> (() -> Void)?,
    updateStrategy: UpdateStrategy? = nil
)
```

```swift
useEffect(updateStrategy: .preserved(by: userId)) {
    let task = Task { await loadProfile(userId) }
    return { task.cancel() }
}
```

### useLayoutEffect

Identical storage and dependency semantics to `useEffect`. Intended for effects that must observe or mutate layout-related state before the view is presented.

```swift
@MainActor
public func useLayoutEffect(
    _ effect: @escaping () -> (() -> Void)?,
    updateStrategy: UpdateStrategy? = nil
)
```

---

## Async Hooks

### useAsync

Runs an `async throws` operation and returns its current `AsyncPhase`. The active task is cancelled when the scope is destroyed or when `updateStrategy` changes.

```swift
@MainActor
public func useAsync<Value>(
    updateStrategy: UpdateStrategy = .once,
    _ operation: @escaping () async throws -> Value
) -> AsyncPhase<Value>
```

```swift
public enum AsyncPhase<Value> {
    case idle
    case loading
    case success(Value)
    case failure(Error)
}
```

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

### useAsyncSequence

Iterates an `AsyncSequence` element-by-element, updating the phase on each emission. Cancellation is checked after every `await`.

```swift
@MainActor
public func useAsyncSequence<S: AsyncSequence>(
    _ updateStrategy: UpdateStrategy = .once,
    _ sequence: @escaping () -> S
) -> AsyncSequencePhase<S.Element>
```

```swift
public enum AsyncSequencePhase<Element> {
    case idle
    case loading
    case value(Element)
    case finished
    case failure(Error)
}
```

```swift
let phase = useAsyncSequence {
    NotificationCenter.default.notifications(named: .NSSystemClockDidChange).map { _ in Date() }
}

if case .value(let date) = phase {
    Text(date.formatted())
}
```

### usePublisher

Subscribes to a Combine `Publisher` and exposes its latest event as a `PublisherPhase`. Subscription is restarted when `updateStrategy` changes.

```swift
@MainActor
public func usePublisher<P: Publisher>(
    updateStrategy: UpdateStrategy?,
    _ publisher: @escaping () -> P
) -> PublisherPhase<P.Output>
```

```swift
public enum PublisherPhase<Output> {
    case idle
    case value(Output)
    case finished
    case failure(Error)
}
```

```swift
let phase = usePublisher(updateStrategy: .preserved(by: query)) {
    searchService.search(query: query)
}

switch phase {
case .idle:             ProgressView()
case .value(let items): ResultsList(items)
case .finished:         EmptyView()
case .failure(let e):   Text(e.localizedDescription)
}
```

---

## UpdateStrategy

All hooks that support conditional re-execution accept an `UpdateStrategy`.

```swift
// Run exactly once — never re-run (default for useMemo, useCallback, useAsync)
.once

// Re-run when a single value changes
.preserved(by: someEquatableValue)

// Re-run when any value in a set changes
.preserved(by: a, b, c)          // variadic AnyHashable
.preserved(by: [a, b])           // array
.preserved(by: { expensiveValue }) // closure — evaluated each render
```

---

## SwiftUI Integration

### StateView

Adopt `StateView` instead of `View`. Implement `stateBody` instead of `body` — the protocol wraps it in a `StateScope` automatically.

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

Use `StateScope` directly when you need hooks inside a plain `View.body`.

```swift
struct RootView: View {
    var body: some View {
        StateScope {
            let (tab, setTab) = useState(0)
            TabView(selection: Binding(get: { tab }, set: setTab)) {
                // ...
            }
        }
    }
}
```

---

## Property Wrappers

Property wrappers provide `@`-syntax for the most common hooks. They must be declared inside a `StateScope` or `stateBody`.

### @HState

Backed by `useBinding`. Exposes state as a SwiftUI `Binding` via `$name`. Can also wrap an existing `Binding` from a parent view.

```swift
// Hook-backed (allocates a new state slot)
@HState var count = 0
@HState var name  = ""

// Bridge an external Binding — no hook slot consumed
@HState var externalCount = $parentCount
```

### @HMemo

Backed by `useMemo`. The initializer expression is captured as an `@autoclosure`.

```swift
@HMemo(.preserved(by: items)) var sorted = items.sorted()
@HMemo var expensive = computeOnce()   // .once by default
```

### @HRef

Backed by `useRef`. Mutations to the property do not trigger re-renders. Use `$name` to access the underlying `StateRef<T>`.

```swift
@HRef var cancellable: AnyCancellable? = nil

Button("Load") {
    cancellable?.cancel()
    cancellable = publisher.sink { print($0) }
}
```

---

## Global State — Atom API

Global state is keyed by `StateKey<T>` atoms and stored in the process-wide `StateStore.shared`.

### Declare atoms

```swift
extension StateKey {
    static let counter    = StateKey<Int>("counter")
    static let currentUser = StateKey<User?>("currentUser")
}
```

### Read and write

```swift
// Read (initialises to default on first access)
let count = StateStore.shared.get(key: .counter, default: 0)

// Write (triggers re-render in subscribed views)
StateStore.shared.set(key: .counter, value: count + 1)

// Pre-register a default without overwriting an existing value
StateStore.shared.registerIfNeeded(key: .counter, value: 0)
```

### Access in views — ViewContext

`@ViewContext` gives direct access to `StateStore.shared` inside any SwiftUI view.

```swift
struct CounterView: View {
    @ViewContext var store

    var body: some View {
        let count = store.get(key: .counter, default: 0)

        VStack {
            Text("\(count)")
            Button("Increment") {
                store.set(key: .counter, value: count + 1)
            }
        }
    }
}
```

### useEnvironment

Reads a SwiftUI `EnvironmentValues` key path from within a `StateScope`.

```swift
let colorScheme = useEnvironment(\.colorScheme)
let locale      = useEnvironment(\.locale)
```

---

## Testing

`StateTest` provides a minimal hook harness for unit tests — no SwiftUI required.

```swift
import Testing
import StateKit
import StateKitTesting

@Test @MainActor
func counter_incrementsCorrectly() {
    let test = StateTest()

    // First render — state initialised to 0
    let initial = test.render {
        let (count, _) = useState(0)
        return count
    }
    #expect(initial == 0)

    // Second render — call the setter
    test.render {
        let (_, setCount) = useState(0)
        setCount(5)
    }

    // Third render — persisted value is 5
    let result = test.render {
        let (count, _) = useState(0)
        return count
    }
    #expect(result == 5)
}
```

`StateTest` API:

```swift
@MainActor
public final class StateTest {
    public let context: StateContext
    public private(set) var renderCount: Int

    public init(context: StateContext = StateContext())

    @discardableResult
    public func render<T>(_ body: () -> T) -> T

    public func renderAndCaptureStates<T>(_ body: () -> T) -> (result: T, states: [Any])

    public func reset()
}
```

---

## Rules of Hooks

1. **Call hooks at the top level** — never inside `if`, `guard`, `for`, or nested closures.
2. **Same order every render** — hooks are identified by position; reordering breaks state.
3. **Only inside a StateScope** — calling a hook outside `StateRuntime.current` is a `fatalError`.
4. **Main thread only** — all hooks are `@MainActor`.
