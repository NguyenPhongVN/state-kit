// ============================================================
// MARK: - Planned: Atom / Selector Graph
// ============================================================
//
// This file contains an in-progress implementation of a Recoil-style
// atom-selector dependency graph for StateKit's shared state layer.
//
// ## Concept
//
// The design mirrors Recoil (React) and Jotai's computed atoms:
//
//   Atom<Value>          — a leaf node holding mutable global state.
//                          Equivalent to Recoil's `atom()` or Jotai's
//                          writable `atom(initialValue)`.
//
//   Selector<Value>      — a derived node whose value is computed
//                          synchronously from one or more Atoms or other
//                          Selectors. Equivalent to Recoil's `selector()`
//                          or Jotai's read-only `atom(get => ...)`.
//
//   AsyncSelector<Value> — a derived node computed asynchronously (network,
//                          disk I/O, etc.). Equivalent to Recoil's async
//                          `selector` or Jotai's async `atom`.
//
// ## Dependency graph
//
// Each node tracks:
//   - `dependencies`  — the set of nodes this node reads from.
//   - `dependents`    — the set of nodes that read from this node.
//   - `revision`      — a monotonic clock value bumped on each write,
//                       used to detect stale cache entries.
//   - `dirty`         — true when the cached value may be out of date
//                       and needs recomputation.
//
// When an Atom is written, StateStore marks all transitive dependents dirty,
// enqueues them, and runs a scheduler that recomputes Selectors in order.
// This is equivalent to Recoil's atom effect propagation or MobX's
// derivation graph.
//
// ## Status: commented out — not yet integrated with the active StateStore.
// ============================================================

//import Foundation
//import Observation
//
//
//
//// ============================================================
//// MARK: - Node Protocol
//// ============================================================
//
//protocol Node: AnyObject, Sendable {
//
//    var id: NodeID { get }
//
//    var dependencies: Set<NodeID> { get set }
//
//    var dependents: Set<NodeID> { get set }
//
//    var revision: Revision { get set }
//
//    var dirty: Bool { get set }
//}
//
//// ============================================================
//// MARK: - Atom
//// ============================================================
//
//@Observable
//final class Atom<Value: Sendable>: Node, @unchecked Sendable {
//
//    let id = NodeID(Atom.self)
//
//    var value: Value
//
//    var dependencies: Set<NodeID> = []
//
//    var dependents: Set<NodeID> = []
//
//    var revision: Revision = .init(value: 0)
//
//    var dirty: Bool = false
//
//    init(_ value: Value) {
//        self.value = value
//    }
//}
//
//// ============================================================
//// MARK: - Selector
//// ============================================================
//@Observable
//final class Selector<Value: Sendable>: Node, @unchecked Sendable {
//
//    let id = NodeID(Selector.self)
//
//    var dependencies: Set<NodeID> = []
//
//    var dependents: Set<NodeID> = []
//
//    var revision: Revision = .init(value: 0)
//
//    var dirty: Bool = true
//
//    private let compute: @Sendable (StateStore) async -> Value
//
//    private var cache: Value?
//
//    private var depRevisions: [Revision] = []
//
//    init(
//        compute: @escaping @Sendable (StateStore) async -> Value
//    ) {
//        self.compute = compute
//    }
//
//    func recompute(store: StateStore) async throws -> Value {
//
//        let result = await compute(store)
//
//        cache = result
//
//        return result
//    }
//
//    func value() -> Value {
//
//        guard let cache else {
//            fatalError("Selector not computed")
//        }
//
//        return cache
//    }
//}
//
//// ============================================================
//// MARK: - AsyncSelector
//// ============================================================
//@Observable
//final class AsyncSelector<Value: Sendable>: Node, @unchecked Sendable {
//
//    let id = NodeID(AsyncSelector.self)
//
//    var dependencies: Set<NodeID> = []
//
//    var dependents: Set<NodeID> = []
//
//    var revision: Revision = .init(value: 0)
//
//    var dirty: Bool = true
//
//    private let compute: @Sendable (StateStore) async throws -> Value
//
//    private var cache: Value?
//
//    init(
//        compute: @escaping @Sendable (StateStore) async throws -> Value
//    ) {
//        self.compute = compute
//    }
//
//    func recompute(store: StateStore) async throws -> Value {
//
//        let value = try await compute(store)
//
//        cache = value
//
//        return value
//    }
//
//    func value() -> Value {
//
//        guard let cache else {
//            fatalError("Async selector not resolved")
//        }
//
//        return cache
//    }
//}
//
//// ============================================================
//// MARK: - Store
//// ============================================================
//
//@Observable
//@MainActor public class StateStore {
//
//    public static let shared = StateStore()
//
//    private var storage: [NodeID: any Node] = [:]
//
//    @ObservationIgnored
//    private var queue: [NodeID] = []
//
//    @ObservationIgnored
//    private let clock = RevisionClock()
//
//    // --------------------------------------------------------
//    // Register
//    // --------------------------------------------------------
//
//    func register(_ node: any Node) {
//
//        storage[node.id] = node
//    }
//
//    // --------------------------------------------------------
//    // Read Atom
//    // --------------------------------------------------------
//
//    func read<Value>(_ atom: Atom<Value>) -> Value {
//
//        atom.value
//    }
//
//    // --------------------------------------------------------
//    // Read Selector
//    // --------------------------------------------------------
//
//    func read<Value>(_ selector: Selector<Value>) async throws -> Value {
//
//        if selector.dirty {
//
//            let result = try await selector.recompute(store: self)
//
//            selector.revision = await clock.next()
//
//            selector.dirty = false
//
//            return result
//        }
//
//        return selector.value()
//    }
//
//    // --------------------------------------------------------
//    // Write Atom
//    // --------------------------------------------------------
//
//    func write<Value>(_ atom: Atom<Value>, _ value: Value) async {
//
//        atom.value = value
//
//        atom.revision = await clock.next()
//
//        markDirty(atom)
//
//        await runScheduler()
//    }
//
//    // --------------------------------------------------------
//    // Dirty Propagation
//    // --------------------------------------------------------
//
//    private func markDirty(_ node: any Node) {
//
//        for depID in node.dependents {
//
//            if let dep = storage[depID] {
//
//                if !dep.dirty {
//
//                    dep.dirty = true
//
//                    queue.append(depID)
//                }
//            }
//        }
//    }
//
//    // --------------------------------------------------------
//    // Scheduler
//    // --------------------------------------------------------
//
//    private func runScheduler() async {
//
//        while !queue.isEmpty {
//
//            let id = queue.removeFirst()
//
//            guard let node = storage[id] else { continue }
//
//            if let selector = node as? Selector<any Sendable> {
//
//                _ = try? await selector.recompute(store: self)
//
//                selector.dirty = false
//            }
//
//            markDirty(node)
//        }
//    }
//
//    // --------------------------------------------------------
//    // Debug Graph
//    // --------------------------------------------------------
//
//    func printGraph() {
//
//        for node in storage.values {
//
//            print(
//                "\(node.id) deps=\(node.dependencies.count) dependents=\(node.dependents.count)"
//            )
//        }
//    }
//}
