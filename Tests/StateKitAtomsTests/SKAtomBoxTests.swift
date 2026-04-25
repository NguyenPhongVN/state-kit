import Testing
import StateKit
@testable import StateKitAtoms

@Suite("SKAtomBox")
struct SKAtomBoxTests {

    @Test("initializer stores initial value")
    func initializerStoresInitialValue() {
        let box = SKAtomBox(42)
        #expect(box.value == 42)
    }

    @Test("value mutation updates stored value")
    func valueMutationUpdatesStoredValue() {
        let box = SKAtomBox("Alice")
        box.value = "Bob"
        #expect(box.value == "Bob")
    }
}
