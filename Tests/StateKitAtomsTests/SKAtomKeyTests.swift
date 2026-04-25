import Testing
import StateKit
@testable import StateKitAtoms

@Suite("SKAtomKey")
struct SKAtomKeyTests {

    @Test("equal atoms produce equal keys")
    func equalAtomsProduceEqualKeys() {
        #expect(SKAtomKey(CounterAtom()) == SKAtomKey(CounterAtom()))
    }

    @Test("different atom types produce different keys")
    func differentTypesProduceDifferentKeys() {
        struct A: SKStateAtom, Hashable {
            typealias Value = Int
            func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
        }

        struct B: SKStateAtom, Hashable {
            typealias Value = Int
            func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
        }

        #expect(SKAtomKey(A()) != SKAtomKey(B()))
    }
}
