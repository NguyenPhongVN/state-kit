import XCTest
import StateKitAtoms
@testable import Riverpods

/// Spec 014 US3: performance baselines for the atom graph and provider engine.
@MainActor
final class EngineBenchmarks: XCTestCase {

    final class CounterAtom: SKStateAtom, Hashable {
        typealias Value = Int
        func defaultValue(context: SKAtomTransactionContext) -> Int { 0 }
        static func == (lhs: CounterAtom, rhs: CounterAtom) -> Bool { true }
        func hash(into hasher: inout Hasher) { hasher.combine("counter") }
    }

    func testAtomReadWrite() {
        let store = SKAtomStore()
        let atom = CounterAtom()
        let box = store.stateBox(for: atom)
        measure {
            for i in 0..<1_000 {
                box.value = i
                _ = box.value
            }
        }
    }

    func testProviderRead() {
        let container = ProviderContainer()
        let p = Provider { _ in "bench" }
        _ = container.read(p)
        measure {
            for _ in 0..<1_000 {
                _ = container.read(p)
            }
        }
    }
}
