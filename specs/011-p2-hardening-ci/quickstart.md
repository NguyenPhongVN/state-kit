# Quickstart: Validating P2 Hardening + CI/Docs Batch

**Feature**: 011-p2-hardening-ci | **Date**: 2026-11-05

## Run

```bash
swift test          # full suite — expect green, no pipes
cd Examples && swift build   # examples still compile
```

## Targeted regression checks

| Story | Test |
|---|---|
| Named identity | two same-named instances share one element (compute count == 1); distinct names/types distinct |
| Reducer re-entrancy | dispatch from inside a queued reduce lands in final state |
| Debounce race | two same-tick invocations → operation ran once with latest input |
| Flush bound | listener ping-pong terminates; test completes |
| File race | concurrent save/load stress completes without crash |
| Notifier reload | re-created notifier loads persisted value |
| Stream order | burst 1→2→3 records transitions in order |
| Dep removal | `Package.resolved` lacks `swift-composable-architecture`; suite green |

## CI validation (next real push)

- Lint job red on violations (no `continue-on-error`).
- Toolchain step selects Xcode matching tools 6.2 or fails loudly listing candidates.
- Cache step restores `.build` on re-run (key from `Package.resolved`).
- Thread-sanitizer job runs, marked experimental (non-blocking).

## Release

```bash
swift test   # green gate
git tag -a 1.0.0 -m "StateKit 1.0.0" && git push origin 1.0.0
```

## Definition of done

- [ ] Full suite green with all new regression tests
- [ ] CI config matches SC-006
- [ ] Lockfile without TCA (SC-007)
- [ ] Inventory + test plan synced (SC-008)
- [ ] `1.0.0` tag pushed (SC-009)
