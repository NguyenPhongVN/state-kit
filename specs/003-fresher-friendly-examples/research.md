# Research: Fresher-Friendly Examples

Feature: specs/003-fresher-friendly-examples · Date: 2026-09-25

## D1 — APIs available for each chapter (verified in Sources/)

| Chapter | APIs used (verified to exist) |
|---------|-------------------------------|
| 1 — Local state | `StateView` + `stateBody`, `useState(_:)`, `useBinding(_:)` (Sources/StateKit/Use) |
| 2 — Global atoms | `@StateAtom` macro, `@SKState` property wrapper, `@Computed` / `@MappedAtom` for derivation |
| 3 — Providers | `StateProvider { }`, `container.read / watch`, `removeListener`, `@Watch` wrapper (post-002 honest semantics) |
| 4 — Async & derived | `@TaskAtom`, `@ThrowingTaskAtom`, phases `idle/loading/success/failure` (`AsyncPhase`), selector-style derived atoms |
| 5 — Persistence & cache | `userDefaultsAtom(_:)` + `UserDefaultsSerializable` (StateKitPersistence), `TimeToLiveCache`, `LeastRecentlyUsedCache` (StateKitCache, both @MainActor) |
| 6 — Architecture | No new library API — composition of everything above, presented as patterns |

**Decision**: the catalog in data-model.md only uses APIs from this table; anything else is out
of scope for lessons (advanced showcase already covers the rest).

## D2 — Placement & navigation

**Decision**: `StartHere/` folder inside the existing ReferenceExamplesApp target; the home view
gains one new first section ("Start Here") linking to a dedicated roadmap screen. The roadmap
pushes lessons via `NavigationStack` value destinations; each lesson footer includes a
"Next lesson" button that pushes the following entry programmatically.

**Rationale**: single app, zero package restructure, originals preserved; value-based
navigation makes "next lesson" trivial and stateless.

**Alternatives**: separate executable target (two apps confuse learners); renaming/replacing
advanced examples (violates originals-preserved).

## D3 — Lesson authoring style (the "fresher" contract)

**Decision**: every lesson = header comment block (Lesson N · concept · "You will learn" ·
time) + numbered, plain-language comments explaining WHAT HAPPENS at runtime (e.g. "tapping
calls the setter → the signal's value changes → SwiftUI re-runs this body → the label shows the
new number") + an interactive demo screen whose on-screen text mirrors the comments + a footer
pointing to the next lesson. First use of jargon (re-render, binding, atom, provider, watcher)
gets a one-line plain definition, then is reused.

**Rationale**: the spec's FR-03/FR-04 made this the acceptance bar; a fixed structure also makes
the path self-checkable.

## D4 — Chapter 5 persistence demo mechanics

**Decision**: L13 uses `userDefaultsAtom` with a stable key so relaunch shows the surviving
value, plus a "Reset" button so the lesson is repeatable. L14/L15 use in-screen TTL/LRU cache
instances with short durations/capacities so expiry/eviction is observable in seconds without
waiting.

**Rationale**: relaunch-survival must be demoable and resettable; expiry/eviction must be
observable within a lesson's attention span.

## D5 — Root package safety

**Decision**: no file under `Sources/` or `Tests/` changes; the only package-manifest change is
Examples/Package.swift adding the `StateKitPersistence` product. The root test suite is run
once at the end as a regression gate.

**Rationale**: keeps SC-04/SC-05 trivially verifiable and the blast radius inside `Examples/`.
