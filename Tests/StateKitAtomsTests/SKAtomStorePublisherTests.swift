import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomStore — PublisherAtom")
struct SKAtomStorePublisherTests {

    @Test("publisherBox emits the current upstream value")
    func publisherBoxEmitsCurrentValue() {
        let store = SKAtomStore()
        let tracker = PublisherBuildTracker()
        let atom = SwitchingPublisherAtom(tracker: tracker)

        let box = store.publisherBox(for: atom)

        #expect(tracker.builds == 1)
        #expect(box.value.output == 1)
    }

    @Test("publisherBox returns cached box on repeated access")
    func publisherBoxReturnsCachedBox() {
        let store = SKAtomStore()
        let atom = SwitchingPublisherAtom(tracker: PublisherBuildTracker())
        let first = store.publisherBox(for: atom)
        let second = store.publisherBox(for: atom)

        #expect(first === second)
    }

    @Test("restartPublisher resubscribes immediately")
    func restartPublisherResubscribesImmediately() {
        let store = SKAtomStore()
        let tracker = PublisherBuildTracker()
        let atom = SwitchingPublisherAtom(tracker: tracker)
        let box = store.publisherBox(for: atom)

        store.restartPublisher(for: atom)

        #expect(tracker.builds == 2)
        #expect(box.value.output == 1)
    }

    @Test("publisher restart clears stale dependency edges")
    func publisherRestartClearsStaleDependencyEdges() {
        let store = SKAtomStore()
        let tracker = PublisherBuildTracker()
        let atom = SwitchingPublisherAtom(tracker: tracker)

        let box = store.publisherBox(for: atom)
        #expect(tracker.builds == 1)
        #expect(box.value.output == 1)

        store.setStateValue(false, for: UsePrimaryPublisherAtom())
        #expect(tracker.builds == 2)
        #expect(box.value.output == 2)

        store.setStateValue(99, for: PrimaryPublisherValueAtom())
        #expect(tracker.builds == 2)
        #expect(box.value.output == 2)

        store.setStateValue(123, for: SecondaryPublisherValueAtom())
        #expect(tracker.builds == 3)
        #expect(box.value.output == 123)
    }
}
