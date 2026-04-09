import Testing
import SwiftUI
import StateKit
@testable import StateKitAtoms

// MARK: - Named atom fixtures

struct CounterAtom: SKStateAtom, Hashable {
    typealias Value = Int
    func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
}

struct NameAtom: SKStateAtom, Hashable {
    typealias Value = String
    func defaultValue(context: SKAtomTransactionContext) -> String { "Alice" }
}

struct DoubledCounterAtom: SKValueAtom, Hashable {
    typealias Value = Int
    func value(context: SKAtomTransactionContext) -> Int {
        context.watch(CounterAtom()) * 2
    }
}

struct FormattedAtom: SKValueAtom, Hashable {
    typealias Value = String
    func value(context: SKAtomTransactionContext) -> String {
        "\(context.watch(NameAtom())): \(context.watch(CounterAtom()))"
    }
}

struct FetchAtom: SKTaskAtom, Hashable {
    typealias TaskSuccess = String
    func task(context: SKAtomTransactionContext) async -> String { "fetched" }
}

struct FailingAtom: SKThrowingTaskAtom, Hashable {
    typealias TaskSuccess = String
    struct FetchError: Error {}
    func task(context: SKAtomTransactionContext) async throws -> String {
        throw FetchError()
    }
}

// MARK: - SKAtomKey

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

// MARK: - SKAtomGraph

@Suite("SKAtomGraph")
struct SKAtomGraphTests {

    @Test("addDependency records bidirectional edges")
    func addDependency() {
        var g = SKAtomGraph()
        let a = SKAtomKey(CounterAtom()), b = SKAtomKey(DoubledCounterAtom())
        g.addDependency(from: b, to: a)
        #expect(g.dependencies[b]?.contains(a) == true)
        #expect(g.children[a]?.contains(b) == true)
    }

    @Test("clearDependencies removes edges")
    func clearDependencies() {
        var g = SKAtomGraph()
        let a = SKAtomKey(CounterAtom()), b = SKAtomKey(DoubledCounterAtom())
        g.addDependency(from: b, to: a)
        g.clearDependencies(of: b)
        #expect(g.dependencies[b] == nil)
        #expect(g.children[a]?.contains(b) != true)
    }

    @Test("topological sort: D after B and C when A→B→D and A→C→D")
    func topologicalSort() {
        struct A: SKStateAtom, Hashable { typealias Value = Int; func defaultValue(context: SKAtomTransactionContext) -> Int { 0 } }
        struct B: SKValueAtom, Hashable { typealias Value = Int; func value(context: SKAtomTransactionContext) -> Int { 0 } }
        struct C: SKValueAtom, Hashable { typealias Value = Int; func value(context: SKAtomTransactionContext) -> Int { 0 } }
        struct D: SKValueAtom, Hashable { typealias Value = Int; func value(context: SKAtomTransactionContext) -> Int { 0 } }

        var g = SKAtomGraph()
        let a = SKAtomKey(A()), b = SKAtomKey(B()), c = SKAtomKey(C()), d = SKAtomKey(D())
        g.addDependency(from: b, to: a)
        g.addDependency(from: c, to: a)
        g.addDependency(from: d, to: b)
        g.addDependency(from: d, to: c)

        let sorted = g.topologicallySortedDescendants(of: a)
        let iB = sorted.firstIndex(of: b), iC = sorted.firstIndex(of: c), iD = sorted.firstIndex(of: d)
        #expect(iB != nil && iC != nil && iD != nil)
        #expect(iD! > iB!)
        #expect(iD! > iC!)
    }
}

// MARK: - SKAtomStore: StateAtom

@MainActor
@Suite("SKAtomStore — StateAtom")
struct SKAtomStoreStateTests {

    @Test("default value on first access")
    func defaultValue() {
        let store = SKAtomStore()
        #expect(store.stateBox(for: CounterAtom()).value == 0)
    }

    @Test("setStateValue updates box")
    func setStateValue() {
        let store = SKAtomStore()
        store.setStateValue(42, for: CounterAtom())
        #expect(store.stateBox(for: CounterAtom()).value == 42)
    }

    @Test("resetStateValue restores default")
    func resetStateValue() {
        let store = SKAtomStore()
        store.setStateValue(99, for: CounterAtom())
        store.resetStateValue(for: CounterAtom())
        #expect(store.stateBox(for: CounterAtom()).value == 0)
    }
}

// MARK: - SKAtomStore: ValueAtom dependency tracking

@MainActor
@Suite("SKAtomStore — ValueAtom dependency tracking")
struct SKAtomStoreDependencyTests {

    @Test("derived atom starts at 0 when counter is 0")
    func derivedAtomInitialValue() {
        let store = SKAtomStore()
        #expect(store.valueBox(for: DoubledCounterAtom()).value == 0)
    }

    @Test("derived atom recomputes when dependency changes")
    func derivedAtomRecomputes() {
        let store = SKAtomStore()
        _ = store.valueBox(for: DoubledCounterAtom())
        store.setStateValue(5, for: CounterAtom())
        let box: SKAtomBox<Int>? = store.existingBox(for: SKAtomKey(DoubledCounterAtom()))
        #expect(box?.value == 10)
    }

    @Test("multi-dependency atom recomputes when either dep changes")
    func multiDependencyRecomputes() {
        let store = SKAtomStore()
        _ = store.valueBox(for: FormattedAtom())
        store.setStateValue(3, for: CounterAtom())
        let box: SKAtomBox<String>? = store.existingBox(for: SKAtomKey(FormattedAtom()))
        #expect(box?.value == "Alice: 3")
        store.setStateValue("Bob", for: NameAtom())
        #expect(box?.value == "Bob: 3")
    }
}

// MARK: - SKAtomStore: TaskAtom

@MainActor
@Suite("SKAtomStore — TaskAtom")
struct SKAtomStoreTaskTests {

    @Test("task atom starts with .loading")
    func taskAtomStartsLoading() {
        let store = SKAtomStore()
        #expect(store.taskBox(for: FetchAtom()).value.isLoading)
    }

    @Test("task atom transitions to .success")
    func taskAtomSuccess() async {
        let store = SKAtomStore()
        _ = store.taskBox(for: FetchAtom())
        try? await Task.sleep(nanoseconds: 100_000_000)
        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(FetchAtom()))
        #expect(box?.value.value == "fetched")
    }

    @Test("throwing task atom transitions to .failure")
    func throwingTaskAtomFailure() async {
        let store = SKAtomStore()
        _ = store.throwingTaskBox(for: FailingAtom())
        try? await Task.sleep(nanoseconds: 100_000_000)
        let box: SKAtomBox<AsyncPhase<String>>? = store.existingBox(for: SKAtomKey(FailingAtom()))
        #expect(box?.value.isFailure == true)
    }
}

// MARK: - Inline atoms

@MainActor
@Suite("Inline atoms — atom() / selector()")
struct InlineAtomTests {

    @Test("two atom() calls are distinct atoms")
    func twoAtomCallsAreDistinct() {
        let a = atom(0), b = atom(0)
        #expect(a != b)
    }

    @Test("inline state atom stores default value")
    func inlineStateAtomDefaultValue() {
        let store = SKAtomStore()
        let myAtom = atom(42)
        #expect(store.stateBox(for: myAtom).value == 42)
    }

    @Test("selector recomputes when inline state atom changes")
    func selectorRecomputes() {
        let store = SKAtomStore()
        let countAtom  = atom(5)
        let doubleAtom = selector { ctx in ctx.watch(countAtom) * 2 }

        _ = store.valueBox(for: doubleAtom)
        store.setStateValue(7, for: countAtom)

        let box: SKAtomBox<Int>? = store.existingBox(for: SKAtomKey(doubleAtom))
        #expect(box?.value == 14)
    }
}

// MARK: - Atom family

@MainActor
@Suite("atomFamily / selectorFamily")
struct AtomFamilyTests {

    @Test("atomFamily produces distinct atoms per ID")
    func atomFamilyDistinctPerID() {
        let userAtom = atomFamily { (id: String) in "user:\(id)" }
        let store = SKAtomStore()
        let aliceBox = store.stateBox(for: userAtom("alice"))
        let bobBox   = store.stateBox(for: userAtom("bob"))
        #expect(aliceBox.value == "user:alice")
        #expect(bobBox.value == "user:bob")
        #expect(aliceBox !== bobBox)
    }

    @Test("atomFamily same ID produces same key")
    func atomFamilySameIDSameKey() {
        let userAtom = atomFamily { (id: Int) in id * 10 }
        #expect(SKAtomKey(userAtom(1)) == SKAtomKey(userAtom(1)))
        #expect(SKAtomKey(userAtom(1)) != SKAtomKey(userAtom(2)))
    }

    @Test("selectorFamily derives value using ID")
    func selectorFamilyDerivesValue() {
        let store = SKAtomStore()
        let baseAtom = atom(3)
        let multiplied = selectorFamily { (factor: Int, ctx: SKAtomTransactionContext) in
            ctx.watch(baseAtom) * factor
        }

        _ = store.valueBox(for: multiplied(4))
        store.setStateValue(5, for: baseAtom)

        let box: SKAtomBox<Int>? = store.existingBox(for: SKAtomKey(multiplied(4)))
        #expect(box?.value == 20)
    }
}

// MARK: - SKAtomViewContext

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
        let ctx = SKAtomViewContext(store: store)
        ctx.set(99, for: CounterAtom())
        #expect(ctx.read(CounterAtom()) == 99)
    }

    @Test("reset restores default")
    func resetRestoresDefault() {
        let store = SKAtomStore()
        let ctx = SKAtomViewContext(store: store)
        ctx.set(50, for: CounterAtom())
        ctx.reset(CounterAtom())
        #expect(ctx.read(CounterAtom()) == 0)
    }

    @Test("binding reads and writes through context")
    func bindingReadsAndWrites() {
        let store = SKAtomStore()
        let ctx = SKAtomViewContext(store: store)
        let binding = ctx.binding(for: CounterAtom())
        binding.wrappedValue = 12
        #expect(ctx.read(CounterAtom()) == 12)
        #expect(binding.wrappedValue == 12)
    }
}

// MARK: - Eviction

@MainActor
@Suite("SKAtomStore — contains / evict")
struct SKAtomStoreEvictionTests {

    @Test("contains is false before first access")
    func containsBeforeAccess() {
        #expect(!SKAtomStore().contains(CounterAtom()))
    }

    @Test("contains is true after first access")
    func containsAfterAccess() {
        let store = SKAtomStore()
        _ = store.stateBox(for: CounterAtom())
        #expect(store.contains(CounterAtom()))
    }

    @Test("evict removes atom")
    func evictRemovesAtom() {
        let store = SKAtomStore()
        _ = store.stateBox(for: CounterAtom())
        store.evict(CounterAtom())
        #expect(!store.contains(CounterAtom()))
    }

    @Test("after eviction atom re-initialises to default")
    func afterEvictionResetsToDefault() {
        let store = SKAtomStore()
        store.setStateValue(99, for: CounterAtom())
        store.evict(CounterAtom())
        #expect(store.stateBox(for: CounterAtom()).value == 0)
    }
}

// MARK: - Atom hooks (useAtomState / useAtomValue / useAtomBinding / useAtomReset)
//
// These hooks bypass StateRuntime (they only need SKAtomStore), so they can be
// tested directly on the MainActor without a StateScope wrapper.

@MainActor
@Suite("Atom hooks")
struct AtomHookTests {

    // Shared store pre-seeded with a known value so tests are isolated from
    // the process-wide SKAtomStore.shared.
    private func makeStore(counter: Int = 0) -> SKAtomStore {
        let s = SKAtomStore()
        if counter != 0 { s.setStateValue(counter, for: CounterAtom()) }
        return s
    }

    // MARK: useAtomValue

    @Test("useAtomValue reads current state atom value")
    func useAtomValueState() {
        let store = makeStore(counter: 7)
        // Simulate hook execution: inject store into StateRuntime environment
        let env = environmentWith(store: store)
        let ctx = StateContext()
        let value = StateRuntime.stateRun(context: ctx, environment: env) {
            useAtomValue(CounterAtom())
        }
        #expect(value == 7)
    }

    @Test("useAtomValue reads derived (value atom) value")
    func useAtomValueDerived() {
        let store = makeStore(counter: 5)
        let env = environmentWith(store: store)
        let ctx = StateContext()
        let doubled = StateRuntime.stateRun(context: ctx, environment: env) {
            useAtomValue(DoubledCounterAtom())
        }
        #expect(doubled == 10)
    }

    // MARK: useAtomState

    @Test("useAtomState returns current value and setter")
    func useAtomStateReadWrite() {
        let store = makeStore()
        let env = environmentWith(store: store)
        let ctx = StateContext()

        let (v1, set) = StateRuntime.stateRun(context: ctx, environment: env) {
            useAtomState(CounterAtom())
        }
        #expect(v1 == 0)

        set(42)

        let v2 = StateRuntime.stateRun(context: ctx, environment: env) {
            useAtomValue(CounterAtom())
        }
        #expect(v2 == 42)
    }

    @Test("useAtomState setter propagates to derived atom")
    func useAtomStatePropagatesToDerived() {
        let store = makeStore()
        let env = environmentWith(store: store)
        let ctx = StateContext()

        let (_, set) = StateRuntime.stateRun(context: ctx, environment: env) {
            useAtomState(CounterAtom())
        }
        set(6)

        let doubled = StateRuntime.stateRun(context: ctx, environment: env) {
            useAtomValue(DoubledCounterAtom())
        }
        #expect(doubled == 12)
    }

    // MARK: useAtomBinding

    @Test("useAtomBinding wrappedValue reads and writes through store")
    func useAtomBindingReadWrite() {
        let store = makeStore()
        let env = environmentWith(store: store)
        let ctx = StateContext()

        var binding: Binding<Int>!
        StateRuntime.stateRun(context: ctx, environment: env) {
            binding = useAtomBinding(CounterAtom())
        }

        #expect(binding.wrappedValue == 0)
        binding.wrappedValue = 99
        #expect(store.stateBox(for: CounterAtom()).value == 99)
    }

    // MARK: useAtomReset

    @Test("useAtomReset restores atom to default")
    func useAtomResetRestoresDefault() {
        let store = makeStore(counter: 55)
        let env = environmentWith(store: store)
        let ctx = StateContext()

        let reset = StateRuntime.stateRun(context: ctx, environment: env) {
            useAtomReset(CounterAtom())
        }
        reset()
        #expect(store.stateBox(for: CounterAtom()).value == 0)
    }
}

// MARK: - Helper

/// Builds an `EnvironmentValues` that carries `store` under `\.skAtomStore`.
@MainActor
private func environmentWith(store: SKAtomStore) -> EnvironmentValues {
    var env = EnvironmentValues()
    env.skAtomStore = store
    return env
}
