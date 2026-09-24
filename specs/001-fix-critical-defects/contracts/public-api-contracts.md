# Public API Contracts (affected surface)

Feature: specs/001-fix-critical-defects · Date: 2026-09-24

All signatures below are **unchanged** (FR-10). Contracts describe post-fix behavior.

## StateKitCache

```swift
TimeToLiveCache.init(ttl:onEvict:onExpire:)          // unchanged
SlidingWindowTTLCache.init(ttl:onEvict:)             // unchanged
```

**Contract — lifecycle**: The instance may be deallocated once the caller drops all references; doing so stops all internal housekeeping. Before this fix, instances were immortal. Cleanup/expire callbacks for live instances fire exactly as before (interval ½·ttl).

## StateKitAnalytics

```swift
EventTracker.init(config:)                           // unchanged
EventTracker.track(_:), flush(), onFlush(_:), clearEvents()  // unchanged
```

**Contract — lifecycle**: Same as caches: dropping the last reference stops auto-flush and allows deallocation. **Contract — history**: `allEvents` remains uncapped by explicit product decision (Clarifications 2026-09-24); memory management is the host's responsibility.

## StateKitPersistence

```swift
KeychainAccessibility: String, Sendable   // cases unchanged; raw values change (accepted break)
KeychainBatch.deleteAll(matching:) throws // behavior redefined
KeychainStateProvider.store/retrieve/delete/exists  // unchanged signatures
```

**Contract — accessibility**: Each case applies the corresponding official `kSecAttrAccessible*` constant to every item it writes (insert and update paths). Raw values equal the platform's canonical codes; hosts persisting raw values must migrate (changelog).

**Contract — scoped deletion**: `deleteAll(matching:)` deletes only items previously added to this batch's `items`:
- `pattern == nil` or `""` → all batch items;
- otherwise → batch items whose key starts with `pattern` (prefix, case-sensitive).
Items not in `items` (including other items under the same app's keychain access) are never affected. Errors surface as `KeychainError.storeFailed(OSStatus)` per-item on first failure; already-deleted items stay deleted.

## StateKitFeatureFlags

```swift
PercentageRollout.init(percentage:userHasher:) isEnabled(for:)  // signatures unchanged
CanaryRollout.init(startPercentage:endPercentage:startDate:endDate:userHasher:)
```

**Contract — bucketing**: Default hasher derives the bucket from the full UTF-8 content of the user ID; deterministic across processes and launches; eligibility monotone in `percentage`. **Breaking-behavior note**: assignments may differ from the previous (biased) scheme — one-time re-bucketing, changelog-documented. Custom `userHasher` injection is unaffected.

## Documentation

```text
README.md — "47 public macros" claims (2 occurrences) replaced by the verified count.
```

**Contract**: any stated macro count in README equals `grep -c '^public macro' Sources/StateKitMacros/*.swift` at time of writing.
