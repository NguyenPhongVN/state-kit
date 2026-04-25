import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomTransactionContext")
struct SKAtomTransactionContextTests {

    @Test("watch reads value and records dependency edge")
    func watchReadsValueAndRecordsDependency() {
        let store = makeStore(counter: 4)
        let currentKey = SKAtomKey(DoubledCounterAtom())
        let watchedKey = SKAtomKey(CounterAtom())
        let context = SKAtomTransactionContext(store: store, currentKey: currentKey)

        let value = context.watch(CounterAtom())

        #expect(value == 4)
        #expect(store.graph.dependencies[currentKey]?.contains(watchedKey) == true)
    }

    @Test("read reads value without recording dependency edge")
    func readDoesNotRecordDependency() {
        let store = makeStore(counter: 7)
        let currentKey = SKAtomKey(DoubledCounterAtom())
        let context = SKAtomTransactionContext(store: store, currentKey: currentKey)

        let value = context.read(CounterAtom())

        #expect(value == 7)
        #expect(store.graph.dependencies[currentKey] == nil)
    }

    @Test("set writes through to the store")
    func setWritesThroughToStore() {
        let store = SKAtomStore()
        let context = SKAtomTransactionContext(store: store, currentKey: nil)

        context.set(21, for: CounterAtom())

        #expect(store.stateBox(for: CounterAtom()).value == 21)
    }

    @Test("reset restores default through the store")
    func resetRestoresDefaultThroughStore() {
        let store = SKAtomStore()
        store.setStateValue(55, for: CounterAtom())
        let context = SKAtomTransactionContext(store: store, currentKey: nil)

        context.reset(CounterAtom())

        #expect(store.stateBox(for: CounterAtom()).value == 0)
    }
}
