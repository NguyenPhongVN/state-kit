# Data Model & Contracts: Polish Pass

Feature: specs/007-polish-pass · Date: 2026-09-25

```swift
// StateKit (hooks)
public func useDeferred<T: Equatable>(_ value: T) -> T
public func useTransition() -> (isPending: Bool, start: (@MainActor () async -> Void) -> Void)

// StateKitCache
public actor SKAsyncCache<Key: Hashable & Sendable, Value: Sendable> {
    public init(capacity: Int? = nil, ttl: TimeInterval? = nil)
    public func get(_ key: Key) -> Value?
    public func set(_ key: Key, _ value: Value)
    public func remove(_ key: Key)
    public func removeAll()
    public var count: Int
}

// StateKitFeatureFlags
public protocol RemoteFlagSource: Sendable {
    func fetchOverrides() async -> [String: Bool]
}
public struct InMemoryRemoteFlagSource: RemoteFlagSource {
    public init(overrides: [String: Bool])
    public func fetchOverrides() async -> [String: Bool]
}
extension FeatureFlagRegistry {
    public func applyRemoteOverrides(from source: some RemoteFlagSource) async
}

// StateKitCache (behavior fix)
// TTLCache expiry → onExpire only (was onEvict + onExpire).

// StateKitFeatureFlags (behavior addition)
// GeolocationRollout.init(allowedRegions:percentage:regionResolver:)
```

Contracts: deferred coalesces to the latest source (no stale overwrite); transition
`isPending` true during awaited work; async cache race-free (actor) and bounded by capacity;
remote overrides replace only the flags they provide; TTL single-callback; region match is
exact/case-sensitive with documented nil-default false.
