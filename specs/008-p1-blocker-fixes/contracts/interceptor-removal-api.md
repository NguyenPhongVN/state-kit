# Contract: Interceptor Removal API (`StateKitAtoms`)

## Public API change (additive)

```swift
extension SKAtomStore {
    /// Registers an interceptor invoked with the changed atom key on every atom write.
    /// - Returns: An opaque token; hold it to keep the registration removable.
    /// - Note: The store does NOT retain the registration beyond the store's own lifetime —
    ///   callers must remove the interceptor when done, or the closure outlives its purpose.
    public func addInterceptorRemovable(
        _ interceptor: @escaping (_ key: SKAtomKey, _ oldValue: Any?, _ newValue: Any?) -> Void
    ) -> SKInterceptorToken

    /// Removes a previously registered interceptor. Idempotent: removing an unknown,
    /// already-removed, or stale token is a no-op.
    public func removeInterceptor(_ token: SKInterceptorToken)
}

/// Opaque handle bound to one interceptor registration.
public struct SKInterceptorToken: Hashable, Sendable { /* identity */ }
```

## Semantics

1. **Notification contract (unchanged)**: active interceptors receive `(key, oldValue, newValue)` on
   every atom write, in registration order, synchronously within the write's batch/flush path.
2. **Removal**: after `removeInterceptor(token)`, the store releases the closure; subsequent atom
   writes must not invoke it. Removal during an in-flight `notifyInterceptors` iteration is safe
   (snapshot or index-safe iteration) and affects at most the current notification.
3. **Deprecation**: the existing append-only `addInterceptor(_:)` is marked deprecated
   (renamed-migration message pointing at `addInterceptorRemovable`) and forwards to the new path,
   discarding the token. No behavior change for existing callers.
4. **Bridge obligation** (`Riverpods`): a provider element that watches an atom must hold its token and
   call `removeInterceptor` when the element disposes, so the store's interceptor count returns to
   baseline after disposal.

## Verification

- `Tests/StateKitAtomsTests`: register → write → notified; remove → write → not notified; remove twice
  → no crash; interceptor count/deallocation check (closure released after removal).
- `Tests/RiverpodsTests`: create/dispose N provider-watch-atom edges → interceptor count returns to
  baseline; surviving element still invalidates.
