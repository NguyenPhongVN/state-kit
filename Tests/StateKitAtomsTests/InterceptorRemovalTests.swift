import Testing
import StateKit
@testable import StateKitAtoms

// Spec 008 US3 (store level): interceptor registrations must be removable.
// Removal must stop notifications, release the closure, and be idempotent.

@MainActor
@Suite("Interceptor Removal — P1 fixes")
struct InterceptorRemovalTests {

    @Test("registered interceptor receives writes until removed")
    func receivesUntilRemoved() {
        let store = SKAtomStore()
        let countAtom = atom(0)
        _ = store.stateBox(for: countAtom)

        var hits = 0
        let token = store.addInterceptorRemovable { key, _, _ in
            if key == SKAtomKey(countAtom) { hits += 1 }
        }

        store.setStateValue(1, for: countAtom)
        #expect(hits == 1)

        store.removeInterceptor(token)
        store.setStateValue(2, for: countAtom)
        #expect(hits == 1, "interceptor fired after removal")
    }

    @Test("removal releases the registered closure")
    func removalReleasesClosure() {
        final class Sentinel {
            var onDeinit: (() -> Void)?
            deinit { onDeinit?() }
        }

        let store = SKAtomStore()
        let countAtom = atom(0)
        _ = store.stateBox(for: countAtom)

        // Debug builds extend local `let` lifetimes to scope end, so a weak
        // reference alone cannot observe release — detect it via deinit.
        var released = false
        var holder: Sentinel? = {
            let s = Sentinel()
            s.onDeinit = { released = true }
            return s
        }()

        let token = store.addInterceptorRemovable { [sentinel = holder!] _, _, _ in
            _ = sentinel
        }
        holder = nil
        #expect(!released, "closure should still be registered")

        store.removeInterceptor(token)
        #expect(released, "store kept the interceptor closure after removal")

        // A write after removal must not resurrect or crash.
        store.setStateValue(3, for: countAtom)
        #expect(released)
    }

    @Test("double removal is a no-op")
    func doubleRemoval() {
        let store = SKAtomStore()
        let token = store.addInterceptorRemovable { _, _, _ in }

        store.removeInterceptor(token)
        store.removeInterceptor(token)
        #expect(store.interceptorCount == 0)
    }

    @Test("removal during notification is safe")
    func removalDuringNotification() {
        let store = SKAtomStore()
        let countAtom = atom(0)
        _ = store.stateBox(for: countAtom)

        var firstHits = 0
        var firstToken: SKInterceptorToken?
        let first = store.addInterceptorRemovable { _, _, _ in
            firstHits += 1
            if let firstToken {
                store.removeInterceptor(firstToken)
            }
        }
        firstToken = first
        let second = store.addInterceptorRemovable { _, _, _ in }
        _ = second

        store.setStateValue(1, for: countAtom)
        store.setStateValue(2, for: countAtom)
        #expect(firstHits == 1, "removed interceptor must not be re-invoked")
        #expect(store.interceptorCount == 1, "only the surviving registration remains")
    }
}
