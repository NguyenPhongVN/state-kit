# StateKit Architecture — Three Engines, Three Paradigms

> **Decision (2026-11-11, owner-approved):** StateKit ships **three intentional
> state engines**. This is design, not accident. Each solves reactive state for a
> different mental model; none is "the old one being phased out". This document is
> the authoritative map — consolidation is off the table unless the owner revisits.

## The three engines

| Engine | Module | Paradigm | State scope | Best for | Non-goals |
|---|---|---|---|---|---|
| **Hooks** | `StateKit` (+ `StateKitCore` runtime) | React hooks (`useState`, `useReducer`, `useEffect`…) | Local to a `StateView` render pass | Component-local state with React-familiar semantics; complex local logic via reducer | Global DI graphs, cross-screen shared state |
| **Atoms** | `StateKitAtoms` (+ `SKAtomStore`) | Recoil/Jotai-style derived graph (`SKStateAtom`, `@Computed`, `SKFocusAtom`, selectors) | Global, fine-grained, dependency-tracked values | Shared primitives with cheap derivation (focus/select) and transactional updates | Lifecycle-managed async resources with auto-dispose semantics |
| **Providers** | `Riverpods` | Riverpod-style DI graph (`Provider`, `FutureProvider`, `NotifierProvider`, container hierarchy, overrides) | Global, lifecycle-managed (auto-dispose, cacheTime, keepAlive) | Services and async resources with dispose semantics, test overrides, container scoping | Positional hook semantics inside render passes |

**Shared foundation:** `StateKitCore` (runtime primitives) sits under `StateKit`;
`Riverpods` and `StateKitAtoms` are siblings that do not depend on each other.

## Selection guide

- Local UI state that resets with the view → **Hooks**.
- A value many views read/derive with no lifecycle story → **Atoms**.
- Anything with async creation, dependencies on services, or dispose/caching
  semantics → **Providers**.
- Mixing engines is supported through the ecosystem bridge
  (`Sources/Riverpods/Core/EcosystemBridge.swift` — providers can watch atoms).

## Dependency map (must stay acyclic)

```text
StateKitCore → StateKit (hooks) → StateKitAtoms ┐
                                                ├→ feature modules
                 Riverpods ─────────────────────┘   (StateKitUI, StateKitCombine,
                                                     StateKitPersistence, StateKitCache,
                                                     StateKitAnalytics,
                                                     StateKitFeatureFlags,
                                                     StateKitDevTools,
                                                     StateConcurrency, StateKitTesting)
StateKitMacros (facade) / StateKitMacrosPlugin (compiler side) sit above all.
```

Constitution principle I (Modular Layering) enforces the direction; the review
history shows feature modules depend on **Riverpods** as their provider spine.

## Historical note

Specs 010-012 fixed the provider engine's public API (override crash, listener
contracts, hierarchy bookkeeping) — Riverpods is load-bearing for the feature
modules, which is exactly why its engine-level bugs mattered most. The 2026-11-05
quality review flagged the duplication; the owner decided to keep all three with
this document as the boundary contract.
