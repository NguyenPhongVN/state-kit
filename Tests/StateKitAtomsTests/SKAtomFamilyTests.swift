import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("atomFamily / selectorFamily")
struct SKAtomFamilyTests {

    @Test("atomFamily produces distinct atoms per identifier")
    func atomFamilyDistinctPerID() {
        let userAtom = atomFamily { (id: String) in "user:\(id)" }
        let store = SKAtomStore()

        let aliceBox = store.stateBox(for: userAtom("alice"))
        let bobBox = store.stateBox(for: userAtom("bob"))

        #expect(aliceBox.value == "user:alice")
        #expect(bobBox.value == "user:bob")
        #expect(aliceBox !== bobBox)
    }

    @Test("atomFamily same identifier produces same key")
    func atomFamilySameIDSameKey() {
        let userAtom = atomFamily { (id: Int) in id * 10 }

        #expect(SKAtomKey(userAtom(1)) == SKAtomKey(userAtom(1)))
        #expect(SKAtomKey(userAtom(1)) != SKAtomKey(userAtom(2)))
    }

    @Test("selectorFamily derives values using identifier")
    func selectorFamilyDerivesValue() {
        let store = SKAtomStore()
        let baseAtom = atom(3)
        let multiplied = selectorFamily { (factor: Int, context: SKAtomTransactionContext) in
            context.watch(baseAtom) * factor
        }

        _ = store.valueBox(for: multiplied(4))
        store.setStateValue(5, for: baseAtom)

        let box: SKAtomBox<Int>? = store.existingBox(for: SKAtomKey(multiplied(4)))
        #expect(box?.value == 20)
    }
}
