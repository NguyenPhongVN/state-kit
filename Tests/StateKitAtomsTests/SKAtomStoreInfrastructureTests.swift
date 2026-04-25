import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomStore — Infrastructure")
struct SKAtomStoreInfrastructureTests {

    @Test("storeBox and existingBox round-trip the same instance")
    func storeBoxAndExistingBoxRoundTrip() {
        let store = SKAtomStore()
        let key = SKAtomKey(CounterAtom())
        let box = SKAtomBox(12)

        store.storeBox(box, for: key)

        let existing: SKAtomBox<Int>? = store.existingBox(for: key)
        #expect(existing === box)
    }

    @Test("addGraphDependency and clearGraphDependencies update the store graph")
    func graphDependencyHelpersUpdateStoreGraph() {
        let store = SKAtomStore()
        let upstream = SKAtomKey(CounterAtom())
        let downstream = SKAtomKey(DoubledCounterAtom())

        store.addGraphDependency(from: downstream, to: upstream)
        #expect(store.graph.children[upstream]?.contains(downstream) == true)

        store.clearGraphDependencies(of: downstream)
        #expect(store.graph.children[upstream]?.contains(downstream) != true)
        #expect(store.graph.dependencies[downstream] == nil)
    }

    @Test("registerRecomputer runs during propagation")
    func registerRecomputerRunsDuringPropagation() {
        let store = SKAtomStore()
        let upstream = SKAtomKey(CounterAtom())
        let downstream = SKAtomKey(DoubledCounterAtom())
        var recomputed = false

        store.addGraphDependency(from: downstream, to: upstream)
        store.registerRecomputer(for: downstream) {
            recomputed = true
        }

        store.propagateChange(from: upstream)

        #expect(recomputed)
    }

    @Test("atomCount tracks initialized atoms")
    func atomCountTracksInitializedAtoms() {
        let store = SKAtomStore()
        #expect(store.atomCount == 0)

        _ = store.stateBox(for: CounterAtom())
        _ = store.valueBox(for: DoubledCounterAtom())

        #expect(store.atomCount == 2)
    }
}
