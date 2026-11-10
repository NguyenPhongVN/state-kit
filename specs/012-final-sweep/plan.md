# Implementation Plan: Final Sweep

**Branch**: straight to `main` (repo convention) | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

## Summary

Close every remaining review finding: system-logger-backed diagnostics (notifier
composition + DevTools observers), regression pins for the two already-correct
contracts (TTL expiry callback, geolocation resolver), stale-doc sweep, repo-hygiene
(tracked-ignored consistency), bounded coverage additions (StateKitTesting target +
Support hooks), CI iOS destination check, and a verified-green lint gate.

## Technical Context

**Language/Version**: Swift 6.2 SPM · **Testing**: Swift Testing via `swift test`
(405 green at 608be23) · **Constraint**: no public signature changes (logging backend
is internal); `usePrint` and `CompositionDebugger` remain public APIs with a changed
logging backend only.

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Layering | ✅ PASS | os.log is a system framework — no new package deps |
| II. Hooks parity | ✅ PASS | hooks untouched |
| III. Unidirectional flow | ✅ PASS | logging is side-band |
| IV. Loud failures | ✅ PASS | pins make silent regressions loud |
| V. Docs tell the truth | ✅ PASS | the whole point of US3 |
| VI. Test-first | ✅ PASS | pins + new coverage tests |
| VII. Versioning | ✅ PASS | behavior-neutral; changelog entry |
| VIII. Workspace rules | ✅ PASS | `.opencode/`/`config/` stay untracked |

## Project Structure

```text
Sources/Riverpods/Composition/NotifierComposition.swift   # print → Logger
Sources/StateKitDevTools/Observers/{DevToolsObserver,DebugProviderObserver}.swift  # print → Logger
Sources/StateKit/Core/StatePhases/SKStatus.swift           # stale MARK/doc
Sources/StateConcurrency/SKTask/Objects/SCGlobalActor.swift # PerformerActor → SKGlobalActor
Sources/StateConcurrency/Actions/ThrottledAction.swift      # example fix
.gitignore                                                  # resolved-tracking consistency
Tests/StateKitTestingTests/                                 # NEW target (Package.swift + tests)
Tests/StateKitSupportTests/StateKitSupportCoverageTests.swift # NEW file
Tests/StateKitCacheTests/ + Tests/StateKitFeatureFlagsTests/ # pin tests
.github/workflows/ci.yml                                    # iOS destination job
```

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
