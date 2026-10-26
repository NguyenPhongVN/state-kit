import Testing
import Foundation
import StateKit
@testable import StateKitAtoms
@testable import Riverpods

// Spec 008 US3 (bridge level): a provider element that watches an atom must
// remove its store interceptor when it disposes, so create/dispose cycles do
// not accumulate permanent interceptor closures in SKAtomStore.shared.
//
// The bridge under test is `ProviderElement.watch<A: SKAtom>` (the provider→
// atom direction of the ecosystem bridge).

@MainActor
@Suite("Bridge Interceptor Cleanup — P1 fixes")
struct BridgeInterceptorCleanupTests {

    /// Casts the existential element back to its concrete element type so the
    /// atom-bridge `watch` (declared on `ProviderElement`) is callable.
    private func watchAtom(_ element: AnyProviderElement, _ atomRef: SKAtomRef<Int>) -> Int {
        (element as! ProviderElement<Provider<Int>>).watch(atomRef)
    }

    @Test("disposing a provider removes its atom interceptor")
    func interceptorCountReturnsToBaseline() {
        let store = SKAtomStore.shared
        let container = ProviderContainer()
        let provider = Provider(name: "bridge-cleanup-single") { _ in 0 }
        let watchedAtom = atom(1)

        let baseline = store.interceptorCount
        let element = container.ensureElement(for: provider)
        _ = watchAtom(element, watchedAtom)
        #expect(store.interceptorCount == baseline + 1,
                "watching an atom should register exactly one interceptor")

        element.dispose()
        #expect(store.interceptorCount == baseline,
                "interceptor leaked: the bridge never removes it on disposal")
    }

    @Test("repeated create/dispose cycles do not accumulate interceptors")
    func cyclesDoNotAccumulate() {
        let store = SKAtomStore.shared
        let container = ProviderContainer()

        let baseline = store.interceptorCount
        for index in 0..<10 {
            let provider = Provider(name: "bridge-cleanup-cycle-\(index)") { _ in 0 }
            let watchedAtom = atom(index)
            let element = container.ensureElement(for: provider)
            _ = watchAtom(element, watchedAtom)
            element.dispose()
        }

        #expect(store.interceptorCount == baseline,
                "each watch/dispose cycle leaked one interceptor")
    }

    @Test("survivor still recomputes from the atom after a sibling disposes")
    func survivorStillRecomputes() {
        let store = SKAtomStore.shared
        let container = ProviderContainer()
        let watchedAtom = atom(1)

        let survivor = Provider(name: "bridge-survivor") { ref -> Int in
            (ref as! ProviderElement<Provider<Int>>).watch(watchedAtom) * 10
        }
        let disposable = Provider(name: "bridge-disposable") { _ in 0 }

        let baseline = store.interceptorCount
        let survivorElement = container.ensureElement(for: survivor)
        _ = container.read(survivor)
        #expect(container.read(survivor) == 10)

        let disposableElement = container.ensureElement(for: disposable)
        _ = watchAtom(disposableElement, watchedAtom)
        #expect(store.interceptorCount == baseline + 2)

        disposableElement.dispose()
        #expect(store.interceptorCount == baseline + 1)

        // The survivor's edge must survive the sibling's disposal.
        store.setStateValue(2, for: watchedAtom)
        #expect(container.read(survivor) == 20,
                "surviving provider must still invalidate on atom change")
    }
}
