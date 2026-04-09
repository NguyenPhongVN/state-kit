# StateKitAtoms

Atom-based state management for SwiftUI, inspired by [Jotai](https://jotai.org) and [Recoil](https://recoiljs.org).

Each piece of state lives in an independent **atom**. Views subscribe only to the atoms they actually read — nothing more, nothing less. When an atom changes, only its direct subscribers re-render.

---

## Table of Contents

- [Tech Stack](#tech-stack)
- [Requirements](#requirements)
- [Concepts](#concepts)
- [Atom Types](#atom-types)
- [Usage](#usage)
  - [1. Provide the store](#1-provide-the-store)
  - [2. Define atoms](#2-define-atoms)
  - [3. Read atoms in views](#3-read-atoms-in-views)
  - [4. Derived atoms (selectors)](#4-derived-atoms-selectors)
  - [5. Async atoms](#5-async-atoms)
  - [6. Inline atoms](#6-inline-atoms)
  - [7. Atom families](#7-atom-families)
  - [8. Imperative access via context](#8-imperative-access-via-context)
  - [9. Scoped stores](#9-scoped-stores)
  - [10. Local hooks — useState with atoms](#10-local-hooks--usestate-with-atoms)
- [Architecture](#architecture)
- [Known Limitations](#known-limitations)

---

## Tech Stack

| Layer | Technology | Role |
|---|---|---|
| **Language** | Swift 6.2, strict concurrency | Type-safe, data-race-free by default |
| **Concurrency** | `@MainActor`, `async/await`, `Task` | All atom mutations happen on the main actor; async atoms run structured tasks |
| **Reactivity** | `Observation` framework (`ObservationRegistrar`, `Observable`) | Per-atom fine-grained observation without `@Observable` macro (avoids Swift 6.3 compiler bug) |
| **UI integration** | SwiftUI — `DynamicProperty`, `@Environment`, `EnvironmentKey`, `@ViewBuilder` | Property wrappers integrate natively into SwiftUI's render cycle |
| **State propagation** | Bidirectional dependency DAG + topological sort (post-order DFS reversed) | Derived atoms recompute in correct dependency order when upstream atoms change |
| **Protocol dispatch** | Associated-type protocol hierarchy (`SKAtom` → sub-protocols) + `MainActor.assumeIsolated` | Unified property-wrapper API works across all atom kinds without actor-annotation conflicts |
| **Identity** | `Hashable` + Swift type metatype (`ObjectIdentifier`) | Two atoms of different Swift types are always distinct, even if they hash equally |
| **Local ↔ Global bridge** | `useAtomState` / `useAtomValue` / `useAtomBinding` / `useAtomRefresher` hooks | Use global atom state with `useState`-style API inside `StateScope` / `StateView`; reads store from `useEnvironment(\.skAtomStore)` |
| **Testing** | Swift Testing (`@Suite`, `@Test`, `#expect`) | 34 tests covering graph, propagation, task lifecycle, families, eviction, and atom hooks |
| **Base library** | StateKit (`AsyncPhase<Value>`) | Async atoms wrap their result in StateKit's phase enum |

### State management pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                         SKAtomStore                             │
│                                                                 │
│  boxes:       [SKAtomKey → SKAtomBox<Value>]  (Observable)      │
│  graph:       SKAtomGraph  (bidirectional DAG)                  │
│  recomputers: [SKAtomKey → @MainActor () -> Void]               │
│  tasks:       [SKAtomKey → Task<Void, Never>]                   │
└────────────────────────────┬────────────────────────────────────┘
                             │ owns
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
     SKAtomBox<Int>   SKAtomBox<String>  SKAtomBox<AsyncPhase<…>>
     (Observable)      (Observable)       (Observable)
            │
            │  SwiftUI tracks .value access via ObservationRegistrar
            ▼
        SwiftUI View  ──→  re-renders only when its atom's box changes
```

**Write path:** `store.setStateValue(newValue, for: atom)` → updates box → `propagateChange` walks the DAG topologically → each derived atom's recomputer updates its box → SwiftUI invalidates only affected views.

---

## Requirements

- iOS 17+ / macOS 14+ / tvOS 17+ / watchOS 10+ / visionOS 1+
- Swift 6.2+
- Xcode 16+

---

## Concepts

### Atom

The smallest unit of state. An atom has a unique identity (its `Hashable` value + Swift type) and produces a single `Value`. Every atom is stored in `SKAtomStore`; the store holds one `SKAtomBox<Value>` per atom.

### SKAtomBox

A lightweight `Observable` container for a single value. Because each atom has its own box, SwiftUI's observation system tracks reads at the per-atom level — changing atom A's box only re-renders views that read A, never views that only read B.

### Dependency graph

Derived atoms (`SKValueAtom`) declare their dependencies implicitly by calling `context.watch(_:)`. The store records a directed edge "B depends on A" whenever B watches A. When A is written, the store walks the graph in topological order and recomputes all downstream atoms.

### Atom key

`SKAtomKey` combines the atom's `Hashable` value with its Swift metatype. This means two different atom structs that happen to hash equally are still different atoms — no collisions across types.

---

## Atom Types

| Protocol | Associated type | Use for |
|---|---|---|
| `SKStateAtom` | `Value` | Mutable state with a default value |
| `SKValueAtom` | `Value` | Read-only derived value, watches other atoms |
| `SKTaskAtom` | `TaskSuccess` → `AsyncPhase<TaskSuccess>` | Async non-throwing work |
| `SKThrowingTaskAtom` | `TaskSuccess` → `AsyncPhase<TaskSuccess>` | Async work that can fail |

> **Swift 6.3 note:** Due to a compiler bug in the associated-type inference pipeline, conforming types must explicitly declare their associated type. See [Known Limitations](#known-limitations).

---

## Usage

### 1. Provide the store

Wrap your root view with `SKAtomRoot`. All descendant views share the same `SKAtomStore`.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            SKAtomRoot {
                ContentView()
            }
        }
    }
}
```

Or use the view-modifier shorthand:

```swift
ContentView()
    .atomRoot()
```

---

### 2. Define atoms

```swift
// Mutable state atom
struct CounterAtom: SKStateAtom, Hashable {
    typealias Value = Int                          // required — Swift 6.3 workaround
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

// Derived (read-only) atom
struct DoubledCounterAtom: SKValueAtom, Hashable {
    typealias Value = Int
    func value(context: SKAtomTransactionContext) -> Int {
        context.watch(CounterAtom()) * 2          // declares dependency on CounterAtom
    }
}
```

---

### 3. Read atoms in views

```swift
struct CounterView: View {
    // Read-only — re-renders when CounterAtom changes
    @SKValue(CounterAtom()) var count

    // Read-write — exposes $count Binding for controls
    @SKState(CounterAtom()) var editableCount

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Stepper("Count", value: $editableCount)
            Button("+1") { editableCount += 1 }
        }
    }
}
```

| Wrapper | Constraint | `wrappedValue` | `projectedValue` |
|---|---|---|---|
| `@SKValue` | `SKAtom` | `A.Value` (read-only) | — |
| `@SKState` | `SKStateAtom` | `A.Value` (read-write) | `Binding<A.Value>` |
| `@SKTask` | `SKAtom` | `AsyncPhase<…>` | — |

---

### 4. Derived atoms (selectors)

```swift
struct FormattedCounterAtom: SKValueAtom, Hashable {
    typealias Value = String
    func value(context: SKAtomTransactionContext) -> String {
        let name  = context.watch(NameAtom())
        let count = context.watch(CounterAtom())
        return "\(name): \(count)"       // re-evaluates when either atom changes
    }
}
```

`context.watch(_:)` records a dependency edge. Use `context.read(_:)` when you want the current value without creating a reactive dependency.

---

### 5. Async atoms

**Non-throwing:**

```swift
struct PostsAtom: SKTaskAtom, Hashable {
    typealias TaskSuccess = [Post]
    func task(context: SKAtomTransactionContext) async -> [Post] {
        await PostService.fetchAll()
    }
}

struct PostsView: View {
    @SKTask(PostsAtom()) var phase

    var body: some View {
        switch phase {
        case .loading:          ProgressView()
        case .success(let ps):  PostList(posts: ps)
        case .idle, .failure:   EmptyView()
        }
    }
}
```

**Throwing:**

```swift
struct ProfileAtom: SKThrowingTaskAtom, Hashable {
    typealias TaskSuccess = Profile
    let userID: String
    func task(context: SKAtomTransactionContext) async throws -> Profile {
        try await API.fetchProfile(id: userID)
    }
}

struct ProfileView: View {
    @SKTask(ProfileAtom(userID: "abc")) var phase

    var body: some View {
        switch phase {
        case .loading:          ProgressView()
        case .success(let p):   Text(p.bio)
        case .failure(let e):   Text(e.localizedDescription).foregroundStyle(.red)
        case .idle:             EmptyView()
        }
    }
}
```

---

### 6. Inline atoms

For quick, one-off atoms without defining a named struct. Always declare them at **module or type scope** — never inside a view body.

```swift
// Mutable inline atom
let counterAtom = atom(0)
let nameAtom    = atom("Alice")

// Derived inline selector
let doubledAtom = selector { ctx in ctx.watch(counterAtom) * 2 }

// Async
let postsAtom   = asyncAtom { _ in await PostService.fetchAll() }
let profileAtom = throwingAsyncAtom { _ in try await API.fetchProfile() }
```

Inline atoms use **reference identity** (`===`) for equality — two `atom(0)` calls produce two distinct atoms, just like Jotai.

```swift
struct MyView: View {
    @SKState(counterAtom) var count   // resolves to the module-level atom
    @SKValue(doubledAtom) var doubled
}
```

---

### 7. Atom families

Parameterise atoms by an ID to get independent instances that share the same production logic.

```swift
// atomFamily — one mutable atom per user ID
let userAtom = atomFamily { (id: String) in
    User.placeholder(id: id)
}

// selectorFamily — one derived atom per multiplier
let multipliedAtom = selectorFamily { (factor: Int, ctx: SKAtomTransactionContext) in
    ctx.watch(counterAtom) * factor
}

struct UserRow: View {
    let id: String
    @SKState var user: User

    init(id: String) {
        self.id = id
        _user = SKState(userAtom(id))      // each ID gets its own atom
    }
}
```

---

### 8. Imperative access via context

Use `@SKAtomContext` when you need to read, write, or reset atoms from action handlers rather than rendering.

```swift
struct ControlPanel: View {
    @SKAtomContext var atomCtx

    var body: some View {
        HStack {
            Button("Reset") { atomCtx.reset(CounterAtom()) }
            Button("Set 100") { atomCtx.set(100, for: CounterAtom()) }
            Button("Read") { print(atomCtx.read(CounterAtom())) }
        }
    }
}
```

`SKAtomViewContext` also provides:

```swift
// Binding
let binding = atomCtx.binding(for: CounterAtom())

// Refresh an async atom (awaitable)
await atomCtx.refresh(PostsAtom())

// Manually evict an atom from the store
atomCtx.evict(CounterAtom())
```

---

### 9. Scoped stores

Isolate a subtree with its own fresh store — useful for Previews, UI tests, or reusable modal components.

```swift
// Fresh isolated store
#Preview {
    CartView()
        .atomScope()
}

// Pre-seeded store for tests
let store = SKAtomStore()
store.setStateValue(42, for: CounterAtom())

SKAtomScopeView(store: store) {
    ContentView()
}
```

---

### 10. Local hooks — useState with atoms

`StateKitAtoms` ships four hook functions that bridge **global atom state** into the **`useState`-style hook API** from `StateKit`. Use them inside any `StateView` or `StateScope` closure alongside regular hooks.

> These hooks read the atom store from the SwiftUI environment, so they work correctly whether the store was provided by `SKAtomRoot`, `SKAtomScopeView`, or the default environment.

#### Hook reference

| Hook | Constraint | Returns | Analogue |
|---|---|---|---|
| `useAtomValue(atom)` | `SKAtom` | `A.Value` | `useAtomValue` / `@SKValue` |
| `useAtomState(atom)` | `SKStateAtom` | `(A.Value, (A.Value) -> Void)` | `useState` |
| `useAtomBinding(atom)` | `SKStateAtom` | `Binding<A.Value>` | `useBinding` |
| `useAtomReset(atom)` | `SKStateAtom` | `() -> Void` | — |
| `useAtomRefresher(atom)` | `SKTaskAtom` / `SKThrowingTaskAtom` | `@MainActor () async -> Void` | — |

#### Mixing local and global state

```swift
let counterAtom = atom(0)   // global — shared between all views
let nameAtom    = atom("Alice")

struct DashboardView: StateView {
    var stateBody: some View {

        // ── Local state (scoped to this view, dies when view is removed) ──
        let (draft, setDraft) = useState("")
        let isEditing         = useBinding(false)

        // ── Global atom state (survives navigation, shared across views) ──
        let (count, setCount) = useAtomState(counterAtom)
        let name              = useAtomBinding(nameAtom)
        let doubled           = useAtomValue(DoubledCounterAtom())
        let resetCount        = useAtomReset(counterAtom)

        return VStack(spacing: 16) {
            // Local state — only this view sees it
            TextField("Draft (local)", text: isEditing)

            // Global state — any view using counterAtom re-renders together
            Text("Count: \(count)  Doubled: \(doubled)")
            HStack {
                Button("+1") { setCount(count + 1) }
                Button("Reset") { resetCount() }
            }

            // Binding for SwiftUI controls
            TextField("Name (global)", text: name)
        }
    }
}
```

#### Async atom with refresh

```swift
struct PostsView: StateView {
    var stateBody: some View {
        let phase   = useAtomValue(PostsAtom())
        let refresh = useAtomRefresher(PostsAtom())

        Group {
            switch phase {
            case .loading:         ProgressView()
            case .success(let ps): PostList(posts: ps)
            case .failure(let e):  Button("Retry") { Task { await refresh() } }
            case .idle:            EmptyView()
            }
        }
        .toolbar {
            Button("Refresh") { Task { await refresh() } }
        }
    }
}
```

#### How environment injection works

When `StateScope` renders, it captures `@Environment(\.self)` — the full SwiftUI environment of its position in the view tree — and stores it in `StateContext`. The atom hooks call `useEnvironment(\.skAtomStore)` to retrieve the correct `SKAtomStore` from that snapshot. This means:

- `SKAtomRoot` → all atom hooks inside its subtree use the root's store
- `SKAtomScopeView(store: s)` → hooks inside use `s`
- No root → hooks use the environment's default store (same default as `@SKState`)

---

## Architecture

```
StateKitAtoms
│
├── Core
│   ├── SKAtomKey        — Hashable identity = atom value + Swift metatype
│   ├── SKAtomBox<V>     — Observable value container (one per atom per store)
│   ├── SKAtomGraph      — Bidirectional dependency DAG
│   └── SKAtomStore      — Central store: boxes + graph + recomputers + tasks
│
├── Protocol
│   ├── SKAtom           — Base: Hashable, Sendable, _getOrCreateBox
│   ├── SKStateAtom      — Mutable atom, defaultValue(context:)
│   ├── SKValueAtom      — Derived atom, value(context:), auto-tracked deps
│   ├── SKTaskAtom       — Async atom → AsyncPhase<Success>
│   └── SKThrowingTaskAtom — Async throwing atom → AsyncPhase<Success>
│
├── Context
│   ├── SKAtomTransactionContext — watch / read / set / reset inside atoms
│   └── SKAtomViewContext        — read / set / reset / binding / refresh from views
│
├── Selector (inline atoms)
│   ├── SKAtomRef<V>            — Inline SKStateAtom (reference identity)
│   ├── SKSelectorRef<V>        — Inline SKValueAtom
│   ├── SKAsyncAtomRef<S>       — Inline SKTaskAtom
│   ├── SKThrowingAsyncAtomRef<S> — Inline SKThrowingTaskAtom
│   └── SKSelectors             — atom() / selector() / asyncAtom() factories
│
├── Family
│   └── SKAtomFamily            — atomFamily() / selectorFamily()
│
├── Effect
│   └── SKAtomEffect            — Lifecycle hooks: initialized / updated / released
│
├── Hooks  (use inside StateScope / StateView from StateKitUI)
│   ├── useAtomValue(atom)      — Read any atom, reactive
│   ├── useAtomState(atom)      — useState-style tuple for state atoms
│   ├── useAtomBinding(atom)    — Binding<Value> for state atoms
│   ├── useAtomReset(atom)      — Reset state atom to default
│   └── useAtomRefresher(atom)  — Async refresh for task atoms
│
└── View
    ├── PropertyWrapper
    │   ├── @SKValue         — Read any atom
    │   ├── @SKState         — Read-write a SKStateAtom (+ Binding)
    │   ├── @SKTask          — Observe AsyncPhase from task atoms
    │   └── @SKAtomContext   — Imperative SKAtomViewContext access
    ├── SKAtomRoot           — Provides store to the whole view tree
    ├── SKAtomScopeView      — Provides an isolated store to a subtree
    └── EnvironmentValues    — skAtomStore environment key
```

---

## Known Limitations

### Swift 6.3 — explicit associated type required

A Swift 6.3 compiler bug (SIGSEGV in `ExprRewriter::coerceToType`) is triggered when macro-based assertion tools (e.g. Swift Testing's `#expect`) type-check expressions involving `SKAtomBox<Value>` returned from the generic `SKAtom._getOrCreateBox` protocol requirement. The crash prevents the compiler from completing associated-type inference.

**Workaround:** always declare your associated types explicitly:

```swift
// ✅ Required in Swift 6.3
struct CounterAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

struct FetchAtom: SKTaskAtom, Hashable {
    typealias TaskSuccess = [Post]
    func task(context: SKAtomTransactionContext) async -> [Post] { … }
}
```

```swift
// ❌ Crashes the Swift 6.3 compiler when used with #expect
struct CounterAtom: SKStateAtom, Hashable {
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
    // Missing: typealias Value = Int
}
```

This limitation applies **only to conforming types you define** (in app or test code). Inline atoms created with `atom()`, `selector()`, `asyncAtom()`, and `selectorFamily()` are unaffected.

### SKAtomEffect not auto-wired

`SKAtomEffect` and `SKStateAtomWithEffect` define the lifecycle-hook interface but are not yet called automatically by `SKAtomStore`. Invoke effect methods manually from your app code until a future release wires them in.
