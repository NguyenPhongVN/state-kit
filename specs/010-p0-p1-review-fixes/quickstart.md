# Quickstart: Validating P0/P1 Review Fixes

**Feature**: 010-p0-p1-review-fixes | **Date**: 2026-11-05

## Prerequisites

- macOS host with Swift 6.2 toolchain (Xcode 26)
- Repo at `/Users/computer/Desktop/state-kit` on `main`

## Run the full suite

```bash
swift test
```

Expected: all suites pass, including the new
`Tests/RiverpodsTests/P0P1ReviewFixRegressionTests.swift` (see tasks.md for the
expected count). Run **without pipes** — piping masks exit codes in zsh.

## Targeted regression checks (per defect)

| Defect | Regression test (group in P0P1ReviewFixRegressionTests) |
|---|---|
| Override-by-provider crash | override-by-provider serves mock value for standard + async provider kinds |
| Keep-alive double close | provider survives double close while second link open; disposed after all closed |
| Double resume | listener attached fire-immediately to fresh provider records exactly one resume |
| Async completion events | container listener on future provider receives success + failure events |
| Cross-container dispose | child listener removal disposes parent-owned auto-dispose element (weak ref released) |
| Override-scope parent | unoverridden provider read inside `ProviderScope(overrides:)` matches shared container state |

## Behavioral spot checks (Swift snippets during dev, optional)

- Value-override path: existing `ProviderOverride` tests must stay green (no regression).
- Existing suites pinning resume/dispose counts must be reviewed; any asserting the
  duplicated resume or wrong-container dispose is updated to the documented contract
  (tracked as explicit tasks).

## CI validation

- `docs.yml` change is validated on the next push: the "Find documentation archive"
  step must produce a non-empty path (empty now exits 1).
- `ci.yml` must stay green: `swift build` + `swift test` + Examples build.

## Definition of done

- [ ] `swift test` exit 0, zero failures (new tests included)
- [ ] Each fix has a regression test that demonstrably fails without the fix
- [ ] No public API signature changed (see contracts/public-api.md)
- [ ] Changelog entry added under `docs/release/CHANGELOG.md` (Fixed section)
