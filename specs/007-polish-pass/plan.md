# Implementation Plan: Polish Pass (useDeferred/useTransition, SKAsyncCache, Remote Flags, Fixes)

**Branch**: `007-polish-pass` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

## Summary

Four remaining review items in one pass: (1) `useDeferred(_:)` and `useTransition()` hooks in
`StateKit` (React idioms, SwiftUI-native via low-priority catch-up and async `start`);
(2) `SKAsyncCache<Key, Value>` — an actor in `StateKitCache` with optional LRU capacity and
TTL, usable from any isolation domain; (3) `RemoteFlagSource` protocol + registry merge in
`StateKitFeatureFlags` (remote overrides win, in-memory adapter ships for tests); (4) behavior
fixes — TTL expiry fires only `onExpire`, and `GeolocationRollout` gains an injectable region
resolver. Tests written first; all gates green.

## Technical Context

**Language/Version**: Swift 6.2; hooks are `@MainActor`; SKAsyncCache is an actor (any domain)
**Primary Dependencies**: none added
**Testing**: red→green per FR; existing TTL tests updated only for the callback-semantics fix
**Constraints**: conventions rulebook; no public API removals; gates green

## Constitution Check

| Gate | Status |
|------|--------|
| V.4 honest APIs (TTL callback fix, documented resolver) | PASS |
| VI concurrency discipline (actor cache, weak-free design) | PASS |
| VII test-first | FR-07 |
| Gates green | FR-07 |

## Project Structure

```text
Sources/StateKit/Use/useDeferred.swift        # useDeferred + useTransition (hooks chapter)
Sources/StateKitCache/SKAsyncCache.swift      # actor cache (capacity + TTL)
Sources/StateKitFeatureFlags/RemoteFlags.swift # RemoteFlagSource + registry merge + InMemory adapter
Sources/StateKitCache/TTLCache.swift          # expiry callback fix (onExpire only)
Sources/StateKitFeatureFlags/Rollout.swift    # GeolocationRollout resolver
Tests/…                                       # StateKitTests(new file), StateKitCacheTests, StateKitFeatureFlagsTests
```

**Structure Decision**: four independent work streams; each lands in its home module.

## Constitution Check (post-design): PASS.

## Complexity Tracking

No violations.
