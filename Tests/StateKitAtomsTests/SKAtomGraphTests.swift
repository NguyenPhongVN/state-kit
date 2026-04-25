import Testing
import StateKit
@testable import StateKitAtoms

@Suite("SKAtomGraph")
struct SKAtomGraphTests {

    @Test("addDependency records bidirectional edges")
    func addDependency() {
        var graph = SKAtomGraph()
        let dependency = SKAtomKey(CounterAtom())
        let dependent = SKAtomKey(DoubledCounterAtom())

        graph.addDependency(from: dependent, to: dependency)

        #expect(graph.dependencies[dependent]?.contains(dependency) == true)
        #expect(graph.children[dependency]?.contains(dependent) == true)
    }

    @Test("clearDependencies removes upstream edges")
    func clearDependencies() {
        var graph = SKAtomGraph()
        let dependency = SKAtomKey(CounterAtom())
        let dependent = SKAtomKey(DoubledCounterAtom())

        graph.addDependency(from: dependent, to: dependency)
        graph.clearDependencies(of: dependent)

        #expect(graph.dependencies[dependent] == nil)
        #expect(graph.children[dependency]?.contains(dependent) != true)
    }

    @Test("clearChildren removes downstream edges")
    func clearChildren() {
        var graph = SKAtomGraph()
        let dependency = SKAtomKey(CounterAtom())
        let dependent = SKAtomKey(DoubledCounterAtom())

        graph.addDependency(from: dependent, to: dependency)
        graph.clearChildren(of: dependency)

        #expect(graph.children[dependency] == nil)
        #expect(graph.dependencies[dependent]?.contains(dependency) != true)
    }

    @Test("directChildren returns immediate dependents")
    func directChildren() {
        var graph = SKAtomGraph()
        let dependency = SKAtomKey(CounterAtom())
        let childA = SKAtomKey(DoubledCounterAtom())
        let childB = SKAtomKey(FormattedAtom())

        graph.addDependency(from: childA, to: dependency)
        graph.addDependency(from: childB, to: dependency)

        let children = graph.directChildren(of: dependency)
        #expect(children == [childA, childB])
    }

    @Test("topological sort returns descendants after their own dependencies")
    func topologicalSort() {
        struct A: SKStateAtom, Hashable {
            typealias Value = Int
            func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
        }

        struct B: SKValueAtom, Hashable {
            typealias Value = Int
            func value(context: SKAtomTransactionContext) -> Int { 0 }
        }

        struct C: SKValueAtom, Hashable {
            typealias Value = Int
            func value(context: SKAtomTransactionContext) -> Int { 0 }
        }

        struct D: SKValueAtom, Hashable {
            typealias Value = Int
            func value(context: SKAtomTransactionContext) -> Int { 0 }
        }

        var graph = SKAtomGraph()
        let a = SKAtomKey(A())
        let b = SKAtomKey(B())
        let c = SKAtomKey(C())
        let d = SKAtomKey(D())

        graph.addDependency(from: b, to: a)
        graph.addDependency(from: c, to: a)
        graph.addDependency(from: d, to: b)
        graph.addDependency(from: d, to: c)

        let sorted = graph.topologicallySortedDescendants(of: a)
        let bIndex = sorted.firstIndex(of: b)
        let cIndex = sorted.firstIndex(of: c)
        let dIndex = sorted.firstIndex(of: d)

        #expect(bIndex != nil && cIndex != nil && dIndex != nil)
        #expect(dIndex! > bIndex!)
        #expect(dIndex! > cIndex!)
    }

    @Test("description is empty when graph has no edges")
    func descriptionEmpty() {
        let graph = SKAtomGraph()
        #expect(graph.description() == "(empty)")
    }

    @Test("description is non-empty when graph has edges")
    func descriptionNonEmpty() {
        var graph = SKAtomGraph()
        graph.addDependency(from: SKAtomKey(DoubledCounterAtom()), to: SKAtomKey(CounterAtom()))

        #expect(graph.description() != "(empty)")
    }
}
