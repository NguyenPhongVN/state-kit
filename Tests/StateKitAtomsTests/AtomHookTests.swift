import Testing
import SwiftUI
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("Atom hooks")
struct AtomHookTests {

    @Test("useAtomValue reads current state atom value")
    func useAtomValueState() {
        let store = makeStore(counter: 7)
        let env = environmentWith(store: store)
        let context = StateContext()

        let value = StateRuntime.stateRun(context: context, environment: env) {
            useAtomValue(CounterAtom())
        }

        #expect(value == 7)
    }

    @Test("useAtomValue reads derived value atom")
    func useAtomValueDerived() {
        let store = makeStore(counter: 5)
        let env = environmentWith(store: store)
        let context = StateContext()

        let doubled = StateRuntime.stateRun(context: context, environment: env) {
            useAtomValue(DoubledCounterAtom())
        }

        #expect(doubled == 10)
    }

    @Test("useAtomState returns current value and setter")
    func useAtomStateReadWrite() {
        let store = makeStore()
        let env = environmentWith(store: store)
        let context = StateContext()

        let (value, setValue) = StateRuntime.stateRun(context: context, environment: env) {
            useAtomState(CounterAtom())
        }

        #expect(value == 0)

        setValue(42)

        let updatedValue = StateRuntime.stateRun(context: context, environment: env) {
            useAtomValue(CounterAtom())
        }
        #expect(updatedValue == 42)
    }

    @Test("useAtomState setter propagates to derived atom")
    func useAtomStatePropagatesToDerived() {
        let store = makeStore()
        let env = environmentWith(store: store)
        let context = StateContext()

        let (_, setValue) = StateRuntime.stateRun(context: context, environment: env) {
            useAtomState(CounterAtom())
        }
        setValue(6)

        let doubled = StateRuntime.stateRun(context: context, environment: env) {
            useAtomValue(DoubledCounterAtom())
        }

        #expect(doubled == 12)
    }

    @Test("useAtomBinding wrappedValue reads and writes through store")
    func useAtomBindingReadWrite() {
        let store = makeStore()
        let env = environmentWith(store: store)
        let context = StateContext()

        var binding: Binding<Int>!
        StateRuntime.stateRun(context: context, environment: env) {
            binding = useAtomBinding(CounterAtom())
        }

        #expect(binding.wrappedValue == 0)

        binding.wrappedValue = 99
        #expect(store.stateBox(for: CounterAtom()).value == 99)
    }

    @Test("useAtomReset restores atom to default")
    func useAtomResetRestoresDefault() {
        let store = makeStore(counter: 55)
        let env = environmentWith(store: store)
        let context = StateContext()

        let reset = StateRuntime.stateRun(context: context, environment: env) {
            useAtomReset(CounterAtom())
        }

        reset()

        #expect(store.stateBox(for: CounterAtom()).value == 0)
    }

    @Test("useAtomRefresher refreshes non-throwing async atom")
    func useAtomRefresherRefreshesTaskAtom() async {
        let store = makeStore()
        let env = environmentWith(store: store)
        let context = StateContext()
        let source = ControlledTaskSource()
        let atom = ControlledRefreshAtom(source: source)

        _ = store.taskBox(for: atom)
        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        let refresher = StateRuntime.stateRun(context: context, environment: env) {
            useAtomRefresher(atom)
        }

        let refresh = Task { @MainActor in
            await refresher()
        }
        await waitUntil(source.pendingRequestIDs.count == 1)

        let requestID = source.pendingRequestIDs[0]
        source.resolve(requestID, with: "fresh")
        await refresh.value

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(atom))
        #expect(box?.value.value == "fresh")
    }

    @Test("useAtomRefresher refreshes throwing async atom")
    func useAtomRefresherRefreshesThrowingTaskAtom() async {
        let store = makeStore()
        let env = environmentWith(store: store)
        let context = StateContext()
        let source = ControlledThrowingTaskSource()
        let atom = ControlledThrowingRefreshAtom(source: source)

        _ = store.throwingTaskBox(for: atom)
        await Task.yield()
        source.resolve(source.pendingRequestIDs[0], with: "initial")
        await Task.yield()

        let refresher = StateRuntime.stateRun(context: context, environment: env) {
            useAtomRefresher(atom)
        }

        let refresh = Task { @MainActor in
            await refresher()
        }
        await waitUntil(source.pendingRequestIDs.count == 1)

        let requestID = source.pendingRequestIDs[0]
        source.resolve(requestID, with: "fresh")
        await refresh.value

        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(atom))
        #expect(box?.value.value == "fresh")
    }
}
