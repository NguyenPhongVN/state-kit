# Research: Fix Critical Defects

Feature: specs/001-fix-critical-defects · Date: 2026-09-24

## D1 — How to stop the housekeeping-loop leak in `TimeToLiveCache`, `SlidingWindowTTLCache`, `EventTracker`

**Decision**: Capture `[weak self]` in the housekeeping `Task` closure; when `self` is gone, exit the loop (do not `guard let self` once and keep looping — re-check each iteration, or break on nil). Keep `deinit` cancellation as a secondary stop.

**Rationale**: The sole cause of the leak is the strong capture: the non-terminating `while !Task.isCancelled` loop retains `self`, so `deinit` (the only cancel site) is unreachable. Weak capture makes the loop's lifetime track the instance's lifetime directly, which is exactly the required semantic (FR-01/FR-02). It also survives the "released mid-sleep" edge case: after wake-up, nil-check exits without touching the dead instance.

**Alternatives considered**:
- Hold the Task unowned and cancel from outside — no; nothing outside knows when to cancel.
- Replace `Task` with `Timer` — same retention problem plus `@MainActor` run-loop coupling; more churn, no benefit.
- Wrap in a `BackgroundWorker` class — new abstraction for 3 call sites; violates no-unjustified-complexity gate.

## D2 — Semantics of `KeychainBatch.deleteAll(matching:)`

**Decision**: Delete only keys that (a) belong to the batch's `items` collection AND (b) start with `pattern` when a non-empty pattern is given. `nil` or empty pattern ⇒ all batch items. Do not touch any key not in `items`.

**Rationale**: This matches the function's documented intent ("Deletes all items in batch") and the clarified prefix-match semantics. It eliminates the data-loss path entirely: foreign keychain items can never be reached because the operation's key set is bounded by `items`.

**Alternatives considered**:
- Global query filtered by `kSecAttrService` namespace — requires introducing a service attribute on every store path (schema change, migration concern) and still can't reach keys stored before; rejected as scope creep.
- Keep global delete but add confirmation parameter — keeps the footgun in the API; rejected.

**Testability note**: Extract the key-selection as a pure internal helper (e.g. `keysToDelete(matching:) -> [String]`) so scoping rules are unit-testable without touching the real Keychain; SecItem interaction covered by a thin round-trip test (macOS host).

## D3 — `KeychainAccessibility` → platform protection attribute

**Decision**: Keep the public enum with its five cases and `String` raw type (public signature per FR-10), but stop using the raw value as the Keychain attribute. Add an internal mapping from each case to the official Security framework constants (`kSecAttrAccessibleAfterFirstUnlock`, `…ThisDeviceOnly` variants, `kSecAttrAccessibleAlways`, `kSecAttrAccessibleWhenUnlocked`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). All store/update/add sites use the mapping. Update raw values to the platform's canonical short codes so the public raw representation stops advertising invented strings.

**Rationale**: Referencing SDK constants makes correctness compiler- and SDK-guaranteed instead of string-magic-guaranteed (the invented `com.apple.keychain.*` strings are not valid `kSecAttrAccessible` values — the platform's are short codes like `ck`/`ak`).

**Alternatives considered**:
- Hardcode the short codes ourselves — works but re-introduces magic strings dependent on undocumented values; rejected.
- Change enum raw type to the CFString constants — would alter the public API shape beyond the accepted break; rejected.

## D4 — `djb2Hash` bucketing for international user IDs

**Decision**: Hash over the ID's UTF-8 bytes using `UInt32` djb2 arithmetic (wrapping `&*`/`&+`), then convert to `Int` (always non-negative on 64-bit since the value fits in 32 bits). Bucket = `hash % 100`. Eligibility stays `bucket < percentage`, which preserves monotonicity (FR-07) and determinism.

**Rationale**: Current code does `char.asciiValue ?? 0`, so every non-ASCII scalar contributes 0 — distinct Vietnamese/Chinese/Cyrillic IDs collapse onto identical buckets, skewing rollouts. UTF-8 byte iteration covers all scripts. Unsigned 32-bit math removes the `abs()` call and its `abs(Int.min)` trap plus the negative-modulo hazard in one move.

**Consequence (accepted, spec-documented)**: bucket assignments change for some users — one-time re-bucketing, changelog-documented.

**Alternatives considered**:
- `String.hashValue`/`Hasher` — not stable across processes; breaks per-user rollout stability; rejected.
- `stable xxHash/SHA` — external dependency or more code for no measurable benefit over djb2 for this use; rejected.

## D5 — README macro count

**Decision**: Replace the stated "47" with the verified count (48 today, re-verify at implement time) in both places it appears. No machinery to auto-generate the count (YAGNI).

**Alternatives considered**: build-time doc generation script — out of proportion for a one-line fix; rejected.
