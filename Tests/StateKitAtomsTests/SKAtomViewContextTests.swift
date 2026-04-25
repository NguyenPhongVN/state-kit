import Testing
import SwiftUI
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("SKAtomViewContext")
struct SKAtomViewContextTests {

    @Test("read returns current value")
    func readReturnsCurrentValue() {
        let store = SKAtomStore()
        store.setStateValue(7, for: CounterAtom())

        #expect(SKAtomViewContext(store: store).read(CounterAtom()) == 7)
    }

    @Test("set updates atom value")
    func setUpdatesValue() {
        let store = SKAtomStore()
        let context = SKAtomViewContext(store: store)

        context.set(99, for: CounterAtom())

        #expect(context.read(CounterAtom()) == 99)
    }

    @Test("reset restores default value")
    func resetRestoresDefault() {
        let store = SKAtomStore()
        let context = SKAtomViewContext(store: store)
        context.set(50, for: CounterAtom())

        context.reset(CounterAtom())

        #expect(context.read(CounterAtom()) == 0)
    }

    @Test("binding reads and writes through context")
    func bindingReadsAndWrites() {
        let store = SKAtomStore()
        let context = SKAtomViewContext(store: store)
        let binding = context.binding(for: CounterAtom())

        binding.wrappedValue = 12

        #expect(context.read(CounterAtom()) == 12)
        #expect(binding.wrappedValue == 12)
    }

    @Test("refresh for task atom updates latest value")
    func refreshTaskUpdatesLatestValue() async {
        let store = SKAtomStore()
        let context = SKAtomViewContext(store: store)
        let source = ControlledTaskSource()
        let atom = ControlledRefreshAtom(source: source)

        _ = store.taskBox(for: atom)
        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        let refresh = Task { @MainActor in
            await context.refresh(atom)
        }
        await waitUntil(source.pendingRequestIDs.count == 1)

        let requestID = source.pendingRequestIDs[0]
        source.resolve(requestID, with: "fresh")
        await refresh.value

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(atom))
        #expect(box?.value.value == "fresh")
    }

    @Test("refresh for throwing task atom updates latest value")
    func refreshThrowingTaskUpdatesLatestValue() async {
        let store = SKAtomStore()
        let context = SKAtomViewContext(store: store)
        let source = ControlledThrowingTaskSource()
        let atom = ControlledThrowingRefreshAtom(source: source)

        _ = store.throwingTaskBox(for: atom)
        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        let refresh = Task { @MainActor in
            await context.refresh(atom)
        }
        await waitUntil(source.pendingRequestIDs.count == 1)

        let requestID = source.pendingRequestIDs[0]
        source.resolve(requestID, with: "fresh")
        await refresh.value

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(atom))
        #expect(box?.value.value == "fresh")
    }

    @Test("evict removes cached descendants as well")
    func evictRemovesCachedDescendants() {
        let store = SKAtomStore()
        let context = SKAtomViewContext(store: store)

        _ = store.valueBox(for: DoubledCounterAtom())
        store.setStateValue(4, for: CounterAtom())

        context.evict(CounterAtom())

        let derivedBox: SKAtomBox<Int>? = store.existingBox(for: SKAtomKey(DoubledCounterAtom()))
        #expect(derivedBox == nil)
    }
}
