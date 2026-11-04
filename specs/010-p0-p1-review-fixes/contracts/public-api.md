# Contract: Public API — No Signature Changes

**Feature**: 010-p0-p1-review-fixes | **Date**: 2026-11-05

This feature is a behavior-only defect remediation. Public contract:

1. **Unchanged signatures** — the following declarations keep their exact public
   signatures; only their behavior is corrected:
   - `ProviderContainer.ensureElement<P>(for:)` (internal callers unchanged)
   - `ProviderContainer.overrideWithProvider` / value-override path
   - `ProviderElement.keepAlive() -> KeepAliveLink`
   - `KeepAliveLink.close()`
   - `ProviderElement.getState()`
   - `ProviderContainer.removeListener<P>(for:)`
   - `ProviderContainer.checkAutoDispose` (internal)
   - `ProviderScope.init(overrides:content:)`
   - `FutureProviderElement.providerCreate()` / `StreamProviderElement` internals

2. **Behavioral contracts now enforced** (previously documented but violated):
   - Override-by-provider serves the replacement value instead of crashing.
   - `close()` is idempotent ("Safe to call multiple times" per doc).
   - `.resume` fires once per 0→1 listener transition.
   - Container listeners receive async completion events.
   - Override scopes fall back to the shared parent container.

3. **No deprecations added**, no new public API introduced. If implementation discovers
   an unavoidable signature need, it must be recorded in tasks.md and re-reviewed
   against FR-010 before commit.
