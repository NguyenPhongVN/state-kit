# Phase 0 Research: P0/P1 Review Fixes

**Feature**: 010-p0-p1-review-fixes | **Date**: 2026-11-05

All unknowns were resolved by direct code verification at tip `4694ea5`
(review findings re-checked line-by-line before planning).

## R1. P0 — `overrideWithProvider` crash cause

- **Verified**: `ProviderContainer.ensureElement` (ProviderContainer.swift:220-229)
  calls `ProviderOverrideDiagnostics.mismatchDiagnostic(actualType: type(of: element),
  expectedType: ProviderElement<P>.self)` and `fatalError`s on mismatch. Every real
  element type is a subclass (`SimpleProviderElement`, `NotifierProviderElement`,
  `FutureProviderElement`, `StateProviderElement`, …), so `type(of:)` (exact dynamic
  metatype) never equals the base metatype → crash on every call.
- **Verified**: the sibling value-override path (line 255) already validates via
  `element as? ProviderElement<P>` and works — this is the correct pattern.
- **Decision**: replace the metatype-equality diagnostic with a cast-based check
  (`element is ProviderElement<P>`); keep `fatalError` for genuinely wrong override
  kinds (different State type / non-element) so Loud Failures is preserved.
- **Alternatives considered**: removing the diagnostic entirely (rejected — loses the
  precise guard for wrong-type overrides); making all elements non-subclassed (rejected —
  invasive, breaks provider-kind specialization).

## R2. P1 — `KeepAliveLink.close()` idempotency

- **Verified**: `ProviderElement.keepAlive()` (ProviderElement.swift:459-466) returns a
  link whose closure decrements `keepAliveLinksCount` unconditionally; no closed flag.
- **Verified**: `KeepAliveLink` doc (ProviderRef.swift:327, 350) explicitly promises
  "Safe to call multiple times. Subsequent calls have no effect." Doc is the contract
  (constitution V) — code must follow.
- **Decision**: capture a local `closed` flag in the close closure (`@MainActor`-confined
  mutation, race-free). Also `guard` against negative counts defensively.
- **Alternatives considered**: tracking open links in a set on the element (rejected —
  more state, same outcome); atomic flag outside MainActor (rejected — unnecessary,
  element state is already MainActor-confined).

## R3. P1 — Double resume on listen-before-first-compute

- **Verified**: `incrementListeners()` fires `.resume` on the 0→1 transition
  (ProviderElement.swift:85-88). `addListener(fireImmediately: true)` then calls
  `getState()` (line 476); with `stateBox == nil`, `getState()` recomputes and fires
  `.resume` again because `listenersCount > 0` (line 155). Result: two resume signals
  for one subscription.
- **Verified**: documented semantics of `onResume` (line 448-450): "Runs when the first
  listener arrives (or the element reactivates)" — i.e. the 0→1 transition, owned by
  `incrementListeners`. First-compute is not reactivation.
- **Decision**: remove the `.resume` fire from `getState()`; the 0→1 transition owns the
  signal. Existing tests that pin resume counts will be checked; any test asserting the
  duplicate is updated to the documented contract (noted in tasks).
- **Alternatives considered**: suppressing resume inside `incrementListeners` when
  `stateBox == nil` (rejected — splits one contract across two paths, harder to reason
  about when listeners attach to a never-computed provider without immediate read).

## R4. P1 — Cross-container dispose and edge bookkeeping

- **Verified**: `removeListener` resolves the element through the parent chain via
  `existingElement(for:)` (ProviderContainer.swift:389-401) but `checkAutoDispose`
  removes from `self.elements` (line 447) — the receiving container, not the owner.
  A parent-owned element stays in the parent's dict after disposal → later `read`
  returns a disposed element.
- **Verified**: `clearDependencyEdges` (ProviderElement.swift:405-417) looks up deps via
  `container.element(for: depID)` which only checks the element's own container dict
  (ProviderContainer.swift:459-461) — parent-owned deps are missed, their `dependents`
  back-edges pin auto-dispose forever.
- **Decision**: `checkAutoDispose` resolves the owner via `element.container` (weak
  back-reference to the owning container, strengthened in spec 009) and mutates the
  owner's registry + observers. `clearDependencyEdges` uses the parent-traversing
  `existingElement(for:)` lookup.
- **Alternatives considered**: duplicating element dicts across containers (rejected —
  identity must stay single-owner); syncing dicts on every op (rejected — complexity,
  race-prone).

## R5. P1 — Override scope loses parent

- **Verified**: `ProviderScope.init(overrides:)` (ProviderScope.swift:171-178) builds
  `ProviderContainer(overrides:)` without `parent`; the documented parent-fallback
  feature ("Fallback container consulted when a provider has no local override here")
  never engages from views.
- **Decision**: pass `parent: .shared` so unoverridden providers resolve against the
  shared container. Verify `ProviderContainer.init` signature supports it during
  implementation.
- **Alternatives considered**: copying shared elements into the new container (rejected —
  breaks identity/sharing semantics); introducing a new scope API (rejected — FR-010
  forbids signature changes).

## R6. P1 — Async completion never reaches container listeners

- **Verified**: `FutureProviderElement.providerCreate()` completion paths
  (FutureProvider.swift:59-88) update `stateBox`, resolve continuations, notify
  dependents and `notifyProviderUpdated` — but never iterate `externalListeners`
  (unlike `recompute()` at ProviderElement.swift:233-234/262-263). `StreamProvider`
  completion has the same gap.
- **Decision**: add a single publish helper on `ProviderElement`
  (`publishExternalUpdate(old:new:)`-style, or reuse the existing publish path) and call
  it from Future success/failure and Stream event paths. Container listeners then receive
  completion events per the documented listener contract.
- **Alternatives considered**: routing completion through `notifyProviderChanged`
  batching (rejected — batching exists for invalidation/flush; external listener
  publishing must happen with the state write to preserve ordering).

## R7. P1 — docs.yml archive discovery

- **Verified**: `xcodebuild docbuild` runs without `-derivedDataPath`, so the archive
  lands under the runner's default DerivedData; the find step searches `.build`
  (docs.yml:28-36) → empty result → upload fails.
- **Decision**: pass `-derivedDataPath .build` to `docbuild` and make the find step fail
  loudly (`exit 1`) when no archive is found, per Loud Failures.
- **Alternatives considered**: searching DerivedData via `xcodebuild -showBuildSettings`
  (rejected — fragile parsing; explicit path is deterministic).

## R8. P3-followup — vacuous test assertions

- **Verified**: `CacheCorrectnessTests.swift:88` `#expect(true, "wiring returned a usable
  unsubscribe token")` and `DevToolsObserverRecordingTests.swift:50` similar.
- **Decision**: rewrite to assert recorded callbacks / token effect (events stop after
  unsubscribe). Task-level detail in tasks.md.

## R9. Test strategy for regression coverage

- Existing infrastructure suffices: weak-reference + bounded polling helpers
  (`HookTeardownRegressionTests` pattern), event-recording observers, temp containers.
- New file `Tests/RiverpodsTests/P0P1ReviewFixRegressionTests.swift` groups one test per
  defect; each test is written to fail at tip (verified by reasoning from R1-R8 code).
- Full-suite gate: `swift test` (no pipes — zsh pipestatus lesson) must stay green.
