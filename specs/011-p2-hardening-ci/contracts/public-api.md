# Contract: Public API — Named Identity (Additive)

**Feature**: 011-p2-hardening-ci | **Date**: 2026-11-05

1. **Changed (documented) behavior** — the only contract change in this feature:
   - Provider instances created with an explicit `name:` now share identity across
     instances with the same name + value type (previously: unique per instance).
   - Providers without a name keep per-instance identity (unchanged).
   - Family-generated providers keep their per-argument identity (internal init
     untouched).
   - Rationale: inline provider creation in view bodies previously leaked one element
     per recreation; named usage is the documented escape hatch and now behaves as the
     logical-identity model users already assume.

2. **Unchanged signatures** — all public initializers keep their exact signatures
   (`_id` derivation is internal). `ProviderID`, `ProviderContainer`, hooks,
   `DebouncedAction`, `FileAtomStorage`, `SwiftDataNotifier` APIs unchanged.

3. **Manifest change** — `swift-composable-architecture` dependency removed. No public
   symbol of StateConcurrency changes (zero imports verified).

4. **No deprecations added.**
