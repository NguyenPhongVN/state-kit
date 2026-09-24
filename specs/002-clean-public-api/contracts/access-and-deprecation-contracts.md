# Public API Contracts — Accessors & Deprecations

Feature: specs/002-clean-public-api · Date: 2026-09-25

## ProviderContainer (Riverpods)

```swift
public func read<P: ProviderProtocol>(_ provider: P) -> P.State            // unchanged signature
public func watch<P: ProviderProtocol>(_ provider: P) -> P.State          // unchanged signature, NEW behavior
public func addListener<P: ProviderProtocol>(for provider: P) -> P.State  // deprecated
public func removeListener<P: ProviderProtocol>(for provider: P)          // unchanged
```

**Contract — read**: pure; registers nothing; fires no lifecycle callbacks (beyond first-time
element creation).

**Contract — watch** (changed): registers a view-level listener (same refcount path the `@Watch`
wrapper uses) and returns the current value. Callers MUST balance with `removeListener(for:)`;
unbalanced watches keep auto-disposable providers alive. ⚠️ Behavior change vs previous releases
where `watch` was a pure read — changelog-documented.

**Contract — addListener(for:) [deprecated]**: identical to `watch(_:)`; exists only so existing
call sites compile. Replacement: `watch(_:)`.

**Contract — element creation diagnostics**: creating an element from an override whose value or
element type does not match the provider's state type produces a precise diagnostic naming the
provider and both types (no unexplained crash). Invariant-backed element lookups elsewhere in
the container are annotated with their justification (Principle V.3).

## UpdateStrategy (StateKit)

All `preserved(by:)` overloads remain non-deprecated; each documents its input shape and when to
prefer it (single Equatable / single Hashable / variadic / arrays / closures). Behavior unchanged.

## Documentation deliverables

- Hooks-vs-macros selection guide (functions vs `@Hook*`) under `docs/`.
- `KeychainStateProvider.clearAll()` doc corrected: deletes exactly this provider's key.
