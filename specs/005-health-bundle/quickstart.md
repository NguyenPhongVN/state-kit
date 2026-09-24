# Quickstart: Verify Health Bundle

Feature: specs/005-health-bundle · Date: 2026-09-25

## 1. Gates

```bash
swift build && swift test && (cd Examples && swift build)
```

## 2. Replay honesty (US2)

- Test: record actions into `InMemoryStateHistory`, replay with a counting handler →
  executed == applicable actions in order; unhandled → skipped list; throwing handler →
  report.failure set and replay stops.
- Old no-argument `replay()` no longer exists.

## 3. LRU behavior parity + stress (US3)

- Existing `CacheTests` LRU tests pass **unmodified**.
- New stress test: 10,000 mixed get/set over capacity-100 cache completes well under a
  generous bound and keeps hit/miss stats consistent.

## 4. Load-proof suite (US4)

```bash
for i in 1 2 3 4 5; do swift test > /dev/null 2>&1 || echo "RUN $i FAILED"; done
```
Expected: zero failures (also once under a parallel Examples build).

## 5. removeObserver (US5)

- Add observer → remove → provider update → observer received nothing.
- Remove twice → no crash, no change.

## 6. CI (US1)

After push: the Actions run appears and passes on GitHub (verify in the browser); lint job is
visible and non-blocking.
