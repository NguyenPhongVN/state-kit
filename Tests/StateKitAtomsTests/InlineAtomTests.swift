import Testing
import StateKit
@testable import StateKitAtoms

@MainActor
@Suite("Inline atoms")
struct InlineAtomTests {

    @Test("two atom calls are distinct atoms")
    func twoAtomCallsAreDistinct() {
        let atomA = atom(0)
        let atomB = atom(0)
        #expect(atomA != atomB)
    }

    @Test("atom stores default value")
    func atomStoresDefaultValue() {
        let store = SKAtomStore()
        let inlineAtom = atom(42)
        #expect(store.stateBox(for: inlineAtom).value == 42)
    }

    @Test("two selector calls are distinct atoms")
    func twoSelectorCallsAreDistinct() {
        let selectorA = selector { _ in 1 }
        let selectorB = selector { _ in 1 }
        #expect(selectorA != selectorB)
    }

    @Test("selector recomputes when inline state atom changes")
    func selectorRecomputes() {
        let store = SKAtomStore()
        let countAtom = atom(5)
        let doubleAtom = selector { ctx in
            ctx.watch(countAtom) * 2
        }

        _ = store.valueBox(for: doubleAtom)
        store.setStateValue(7, for: countAtom)

        let box: SKAtomBox<Int>? = store.existingBox(for: SKAtomKey(doubleAtom))
        #expect(box?.value == 14)
    }

    @Test("asyncAtom succeeds")
    func asyncAtomSucceeds() async throws {
        let store = SKAtomStore()
        let inlineAtom = asyncAtom { _ in "loaded" }

        _ = store.taskBox(for: inlineAtom)
        var box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(inlineAtom))
        for _ in 0..<100 where box?.value.value != "loaded" {
            try await Task.sleep(nanoseconds: 5_000_000)
            box = store.existingBox(for: SKAtomKey(inlineAtom))
        }
        #expect(box?.value.value == "loaded")
    }

    @Test("throwingAsyncAtom stores failure")
    func throwingAsyncAtomFails() async throws {
        let store = SKAtomStore()
        let inlineAtom: SKThrowingAsyncAtomRef<String> = throwingAsyncAtom { _ in
            throw ControlledRefreshError()
        }

        _ = store.throwingTaskBox(for: inlineAtom)
        var box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(inlineAtom))
        for _ in 0..<100 where box?.value.isFailure != true {
            try await Task.sleep(nanoseconds: 5_000_000)
            box = store.existingBox(for: SKAtomKey(inlineAtom))
        }
        #expect(box?.value.isFailure == true)
    }
}
