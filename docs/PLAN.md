# StateKit — Development Plan

> Goal: bring state-kit to a stable, production-ready 1.0 release.

---

## Current status

| Module | Implementation | Tests | Notes |
|---|---|---|---|
| `StateKitCore` | ✅ Complete | ❌ None | Engine: StateRuntime, StateContext, StateSignal, StateRef |
| `StateKit` | ✅ Complete | ❌ None | All hook functions: useState, useReducer, useMemo, useAsync, useEffect, … |
| `StateKitUI` | ✅ Complete | ❌ None | StateScope, StateView |
| `StateKitAtoms` | ✅ Complete | ✅ 34 passing | Atom store, protocols, dependency graph, families, task atoms, hooks |
| `StateKitSupport` | ✅ Complete | ❌ None | @SKScopeState, @SKScopeMemo, @SKScopeRef, atom property wrappers |
| `StateKitTesting` | ✅ Complete | N/A | StateTest harness |
| `StateKitDevTools` | ✅ Complete | N/A | StateDevScope overlay |
| `StateKitCombine` | ❌ Stub | — | Empty — only import statements |
| `StateKitMacros` | ❌ Stub | — | Empty — only import statements |
| `StateConcurrency` | ✅ Complete | ❌ None | AsyncCurrentValueStream, AsyncPassthroughStream, type-erased sequences |

---

## Phase 1 — Test coverage (P0, blocking 1.0)

All implemented modules need tests before the library can be considered stable.
Use `StateTest` from `StateKitTesting` for hook tests; Swift Testing (`@Suite`, `@Test`, `#expect`) for everything.

### 1.1  StateKit hooks (`Tests/StateKitTests/`)

The test file exists but is empty. Add tests for every hook:

- [ ] `useState` — initial value, setter updates value, re-renders on change
- [ ] `useBinding` — binding reads/writes through the same slot as useState
- [ ] `useReducer` — initial state, dispatch updates state, reducer closure is replaced each render
- [ ] `useRef` — value persists across renders, mutation does not re-render
- [ ] `useMemo` — `.once` computes exactly once; `.preserved(by:)` recomputes on dep change; `.always` recomputes every render
- [ ] `useCallback` — same re-execution semantics as useMemo, returns the closure
- [ ] `useEffect` — runs after render, cleanup runs before next effect, cleanup runs on reset
- [ ] `useLayoutEffect` — same lifecycle as useEffect
- [ ] `useOnChange` — fires closure only when value changes, not on first render
- [ ] `useAsync` — starts `.loading`, resolves to `.success` or `.failure`, task is cancelled on reset
- [ ] `useAsyncSequence` — emits `.value` per element, `.finished` when done
- [ ] `usePublisher` — reflects publisher emissions as `PublisherPhase`
- [ ] `UpdateStrategy` — `.once`, `.preserved(by:)`, `.always` behave correctly across renders
- [ ] `AsyncPhase` — `isLoading`, `value`, `isFailure` helpers
- [ ] `useEnvironment` — reads injected EnvironmentValues key path

Add `StateKitTesting` to the test target dependencies (already present).

### 1.2  StateKitCore (`Tests/StateKitCoreTests/` — new target)

- [ ] `StateContext` — `nextIndex()` increments correctly; `reset()` brings index back to 0
- [ ] `StateRuntime` — `begin/end` sets/clears `current`; `stateRun` calls `begin`, body, `end` in order; `stateRun` with `environment:` injects into `context.injectedEnvironment`
- [ ] `StateSignal` — `@Observable` notifications fire when `.value` changes
- [ ] `StateRef` — `.value` mutation does not trigger observation

Add target to `Package.swift`:
```swift
.testTarget(name: "StateKitCoreTests", dependencies: ["StateKitCore"])
```

### 1.3  StateKitUI (`Tests/StateKitUITests/` — new target)

These need a `@MainActor` host or `ViewHostingTest` helper because they interact with the SwiftUI view lifecycle.

- [ ] `StateScope` — hook slots accumulate across `body` calls
- [ ] `StateView` — `body` delegates to `stateBody` through a `StateScope`
- [ ] Environment injection — `@Environment(\.self)` is threaded into `StateRuntime.stateRun`

Add target to `Package.swift`:
```swift
.testTarget(name: "StateKitUITests", dependencies: ["StateKitUI", "StateKitTesting"])
```

### 1.4  StateKitSupport (`Tests/StateKitSupportTests/` — new target)

- [ ] `@SKScopeState` — initial value, setter, bridging external Binding
- [ ] `@SKScopeMemo` — memoized value, re-computation on dep change
- [ ] `@SKScopeRef` — persists across renders, no re-render on mutation
- [ ] `@SKState` / `@SKValue` / `@SKTask` — atom property wrapper read/write
- [ ] `@SKAtomContext` — read, set, reset, binding via context object

Add target to `Package.swift`:
```swift
.testTarget(name: "StateKitSupportTests", dependencies: ["StateKitSupport", "StateKitTesting"])
```

### 1.5  StateConcurrency (`Tests/StateConcurrencyTests/` — new target)

- [ ] `AsyncCurrentValueStream` — initial value is emitted on subscribe; `send` emits to all iterators; `finish` terminates all iterators; cancelled task removes iterator
- [ ] `AsyncPassthroughStream` — `send` emits; no replay of past values
- [ ] `AnyAsyncSequence` — type erasure works with standard sequences

Add to `Package.swift` products and targets:
```swift
.library(name: "StateConcurrency", targets: ["StateConcurrency"])
.testTarget(name: "StateConcurrencyTests", dependencies: ["StateConcurrency"])
```

---

## Phase 2 — Implement missing modules (P1)

### 2.1  StateKitCombine

Currently empty. Implement:

- [ ] `SKCombineAtom` — `SKTaskAtom` backed by a Combine `Publisher` (wraps publisher output into `AsyncPhase`)
- [ ] `Publisher+atom` — convenience extension to bridge any `Publisher` into an atom or into `usePublisher`
- [ ] Basic tests

Approach: wrap `Publisher.values` (AsyncSequence bridge) inside a `SKTaskAtom`.

```swift
// Usage goal:
let priceAtom = combineAtom(pricePublisher)   // SKTaskAtom<Price>
```

### 2.2  StateKitMacros

Currently empty. Implement one macro that covers the most common boilerplate:

- [ ] `@Atom` macro — generates a `SKStateAtom`-conforming struct from a default value expression

```swift
// Desired input:
@Atom var counter = 0

// Expands to:
struct _CounterAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}
let counter = _CounterAtom()
```

Add macro tests using `SwiftSyntaxMacrosTestSupport`.

---

## Phase 3 — Code quality & API hardening (P2)

### 3.1  Remove legacy / dead code

- [ ] `Sources/StateKitUI/SharedState/SharedStateView.swift` — appears unused; remove or document
- [ ] `Sources/StateKitCore/SharedState/Node.swift` — has commented-out debug fatalErrors; clean up
- [ ] `Sources/StateKitCore/SharedState/Example.swift` — if this is an example file, move to docs or delete

### 3.2  API review

- [ ] `useAtomReset` return type — currently `() -> Void`; verify that it correctly captures MainActor isolation in Swift 6.2 (the returned closure calls `@MainActor` methods)
- [ ] `StateRuntime.stateRun` body parameter is now `@MainActor () -> T` — ensure all call sites and docs are updated
- [ ] `StateContext.injectedEnvironment: Any?` — typed as `Any?` to avoid importing SwiftUI from Core; document this intentional looseness
- [ ] Audit all `fatalError` calls — ensure messages are actionable and mention the hook name

### 3.3  Documentation

- [ ] All public symbols in `StateKitCore` — add or complete doc comments
- [ ] `StateKitAtoms` atom protocols — update examples to reflect `typealias Value = ...` requirement (Swift 6.3 workaround)
- [ ] Update `README.md` to reflect final module structure (hooks in `StateKitAtoms`, not `StateKitSupport`)

### 3.4  Performance

- [ ] Benchmark `SKAtomGraph.topologicallySortedDescendants` with wide diamond graphs (>50 atoms)
- [ ] Ensure `SKAtomStore` does not hold strong references to evicted atoms (check for leaks)

---

## Phase 4 — Release preparation (P3)

- [ ] Set up GitHub Actions CI: `swift build` + `swift test` on macOS-latest for every PR
- [ ] Tag `1.0.0-beta.1` once Phase 1 is complete and all tests pass
- [ ] Tag `1.0.0` once Phase 2 and 3 are complete
- [ ] Write migration guide if any public API changed from internal builds
- [ ] Publish to Swift Package Index

---

## What's already production-ready today

The following can be used in production as-is (implementation is complete and stable):

| Feature | How to use |
|---|---|
| `useState`, `useReducer`, `useMemo`, `useRef`, `useCallback` | `import StateKit` + `StateView` / `StateScope` |
| `useEffect`, `useLayoutEffect`, `useOnChange` | same |
| `useAsync`, `useAsyncSequence`, `usePublisher` | same |
| `useEnvironment` | same |
| Atom store (`SKStateAtom`, `SKValueAtom`, `SKTaskAtom`) | `import StateKitAtoms` + `SKAtomRoot` |
| Atom families (`atomFamily`, `selectorFamily`) | same |
| Atom hooks (`useAtomState`, `useAtomValue`, etc.) | same |
| `@SKState`, `@SKValue`, `@SKTask`, `@SKAtomContext` | `import StateKitSupport` |
| `@SKScopeState`, `@SKScopeMemo`, `@SKScopeRef` | same |
| `StateTest` harness | `import StateKitTesting` (test targets only) |
| `StateDevScope`, `StateDevView` | `import StateKitDevTools` (debug builds) |
| `AsyncCurrentValueStream`, `AsyncPassthroughStream` | `import StateConcurrency` |

**Do NOT use in production yet:** `StateKitCombine`, `StateKitMacros` (stubs).

---

## Known issues

| Issue | Status | Workaround |
|---|---|---|
| Swift 6.3 SIGSEGV with `#expect` + generic `SKAtom` | ✅ Workaround applied | Explicit `typealias Value = T` in every conforming atom |
| `body: @MainActor () -> T` in `stateRun` — breaks callers that pass non-isolated closures | ✅ Fixed | All call sites updated |
| Atom hook files were in wrong module (`StateKitSupport` vs `StateKitAtoms`) | ✅ Fixed | Moved to `StateKitAtoms/Hooks/` |
