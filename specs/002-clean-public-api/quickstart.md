# Quickstart: Verify the Clean Public API Overhaul

Feature: specs/002-clean-public-api · Date: 2026-09-25

## Prerequisites

- macOS host with Swift 6.2 toolchain; repo root `/Users/computer/Desktop/state-kit`

## 1. Full regression pass

```bash
swift build && swift test
```

Expected: build clean; all suites pass; no unexpected skips.

## 2. watch is reactive, read is pure (US1 / SC-03)

`Tests/RiverpodsTests`:

- auto-dispose provider + `container.watch(p)` → provider element stays alive (listener
  registered); after `container.removeListener(for: p)` and the dispose window, element is gone.
- `container.read(p)` on a fresh auto-dispose provider → no listener registered (element does
  not stay alive past the dispose window with zero listeners).
- deprecated `addListener(for:)` behaves identically to `watch(_:)` (compiles with deprecation,
  registers the same way).

## 3. Override mismatch diagnosed, not mystery-crashed (US2 / SC-02)

- Feed a state-box override whose stored value type mismatches the provider state type through
  the element-creation path → fails with a message naming provider and both types
  (debug-diagnostic path, no silent wrong behavior).
- Remaining container casts carry invariant justification comments (audit F3).

## 4. Docs parity (US3 / SC-04)

```bash
grep -c "static func preserved" Sources/StateKit/Core/UpdateStrategy.swift   # 8, none deprecated
grep -rn "deprecated" Sources/Riverpods/Container/ProviderContainer.swift    # addListener only
grep -rn "watch(" Examples/ | grep -v "context.watch"                        # examples on canonical paths
```

Expected: 8 overloads each with distinct use-case docs; single deprecation annotation; examples
clean.

## 5. Audit completeness (US4 / SC-01)

Open `specs/002-clean-public-api/audit.md`: findings index F1–F10 with dispositions; tally
states which closed here and which are P3-deferred (F7, F8, F9 only).

## 6. Changelog (FR-08)

`docs/release/CHANGELOG.md` Unreleased section: watch behavior change (⚠️ note),
addListener deprecation, override diagnostics, docs fixes.
