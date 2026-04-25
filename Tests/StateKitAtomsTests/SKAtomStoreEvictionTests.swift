import Testing
import SwiftUI
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomStore — Eviction")
struct SKAtomStoreEvictionTests {

    @Test("contains is false before first access")
    func containsBeforeAccess() {
        #expect(!SKAtomStore().contains(CounterAtom()))
    }

    @Test("contains is true after first access")
    func containsAfterAccess() {
        let store = SKAtomStore()
        _ = store.stateBox(for: CounterAtom())
        #expect(store.contains(CounterAtom()))
    }

    @Test("evict removes atom from the store")
    func evictRemovesAtom() {
        let store = SKAtomStore()
        _ = store.stateBox(for: CounterAtom())

        store.evict(CounterAtom())

        #expect(!store.contains(CounterAtom()))
    }

    @Test("after eviction atom reinitializes to default value")
    func afterEvictionResetsToDefault() {
        let store = SKAtomStore()
        store.setStateValue(99, for: CounterAtom())

        store.evict(CounterAtom())

        #expect(store.stateBox(for: CounterAtom()).value == 0)
    }

    @Test("evict clears cached descendants so they rebind on next read")
    func evictClearsCachedDescendants() {
        let store = SKAtomStore()
        let doubledKey = SKAtomKey(DoubledCounterAtom())

        _ = store.valueBox(for: DoubledCounterAtom())
        store.setStateValue(5, for: CounterAtom())

        let doubledBox: SKAtomBox<Int>? = store.existingBox(for: doubledKey)
        #expect(doubledBox?.value == 10)

        store.evict(CounterAtom())

        let evictedBox: SKAtomBox<Int>? = store.existingBox(for: doubledKey)
        #expect(evictedBox == nil)

        store.setStateValue(1, for: CounterAtom())
        #expect(store.valueBox(for: DoubledCounterAtom()).value == 2)
    }
}
