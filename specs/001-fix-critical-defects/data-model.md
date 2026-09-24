# Data Model: Fix Critical Defects

Feature: specs/001-fix-critical-defects · Date: 2026-09-24

No persistent schemas change. This feature modifies behavior and lifecycle of the following in-memory/Keychain entities.

## Entities

### KeychainAccessibility (StateKitPersistence)

| Case | Official platform constant it maps to |
|------|----------------------------------------|
| `afterFirstUnlock` | `kSecAttrAccessibleAfterFirstUnlock` |
| `afterFirstUnlockThisDeviceOnly` | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| `always` | `kSecAttrAccessibleAlways` |
| `whenUnlocked` | `kSecAttrAccessibleWhenUnlocked` |
| `whenUnlockedThisDeviceOnly` | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |

- Raw string values change from invented `com.apple.keychain.*` to the platform's canonical short codes (accepted break, changelog-documented).
- Validation rule: the mapping is total (every case covered; compiler-exhaustive switch).
- Consumers: `KeychainStateProvider.store`, `KeychainBatch.store` — all must read the mapping, never the raw value.

### KeychainBatch (StateKitPersistence)

- State: `items: [String: Data]` (unchanged).
- Derived operation `keysToDelete(matching:)`: `[String]` =
  - all keys of `items`, when `pattern` is nil or empty;
  - otherwise keys of `items` where `key.hasPrefix(pattern)`.
- Invariant: the SecItem delete loop iterates exactly `keysToDelete(matching:)` and nothing else — foreign keys are unreachable by construction.

### Housekeeping loop (TimeToLiveCache, SlidingWindowTTLCache, EventTracker)

Lifecycle state machine (per instance):

```
init() ──▶ loop running (interval: ½ TTL / ½ TTL / flushInterval)
              │
              ├─ instance released ──▶ weak ref nil on next wake ──▶ loop exits (FR-01)
              └─ instance alive ───▶ cleanup/flush runs as before (FR-02)
deinit ──▶ task cancelled (unchanged, now also reachable)
```

- Validation rules: interval derivation stays valid for `ttl`/`flushInterval ≥ 0.001`; loop never busy-waits; no post-deinstance callback fires.
- Observable: `Task.isCancelled` becomes true, and instance deallocation is assertable (weak-reference nil-ing in tests).

### Rollout bucket value (StateKitFeatureFlags)

- Input: user ID `String`; derivation: djb2 over the ID's UTF-8 bytes in `UInt32` → `Int` (non-negative) → `bucket = value % 100`.
- Rules: deterministic across runs/processes (FR-07); full-script coverage (FR-08); eligibility monotone in percentage (`bucket < percentage`).
- Consumer: `PercentageRollout.isEnabled`, `CanaryRollout.isEnabled` (unchanged formulas, new hash).

## State transitions affected

- Keychain item store path: update-vs-insert branch unchanged; the accessibility attribute applied on both paths now comes from the official constants.
- Tracker flush path: unchanged (`batch` → `onFlush`), history path unchanged (uncapped, per Clarifications).
