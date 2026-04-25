import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomStore — ValueAtom")
struct SKAtomStoreValueTests {

    @Test("valueBox computes initial derived value")
    func derivedAtomInitialValue() {
        let store = SKAtomStore()
        #expect(store.valueBox(for: DoubledCounterAtom()).value == 0)
    }

    @Test("valueBox returns cached box on repeated access")
    func valueBoxReturnsCachedBox() {
        let store = SKAtomStore()
        let first = store.valueBox(for: DoubledCounterAtom())
        let second = store.valueBox(for: DoubledCounterAtom())
        #expect(first === second)
    }

    @Test("derived atom recomputes when dependency changes")
    func derivedAtomRecomputes() {
        let store = SKAtomStore()
        _ = store.valueBox(for: DoubledCounterAtom())

        store.setStateValue(5, for: CounterAtom())

        let box: SKAtomBox<Int>? = store.existingBox(for: SKAtomKey(DoubledCounterAtom()))
        #expect(box?.value == 10)
    }

    @Test("multi-dependency atom recomputes when either dependency changes")
    func multiDependencyRecomputes() {
        let store = SKAtomStore()
        _ = store.valueBox(for: FormattedAtom())

        store.setStateValue(3, for: CounterAtom())
        let box: SKAtomBox<String>? = store.existingBox(for: SKAtomKey(FormattedAtom()))
        #expect(box?.value == "Alice: 3")

        store.setStateValue("Bob", for: NameAtom())
        #expect(box?.value == "Bob: 3")
    }

    @Test("derived atom clears stale dependencies when its branch changes")
    func derivedAtomClearsStaleDependencies() {
        let store = SKAtomStore()
        let box = store.valueBox(for: SwitchingValueAtom())

        #expect(box.value == 1)

        store.setStateValue(false, for: UsePrimaryPublisherAtom())
        #expect(box.value == 2)

        store.setStateValue(99, for: PrimaryPublisherValueAtom())
        #expect(box.value == 2)

        store.setStateValue(123, for: SecondaryPublisherValueAtom())
        #expect(box.value == 123)
    }
}
