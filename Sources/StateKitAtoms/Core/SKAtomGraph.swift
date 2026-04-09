/// Bidirectional dependency DAG used by `SKAtomStore`.
///
/// Edge semantics:
/// - `dependencies[B]` = atoms that B reads from (B's upstream).
/// - `children[A]`     = atoms that read from A (A's downstream).
///
/// When atom A is written, `topologicallySortedDescendants(of:)` walks the
/// `children` edges in post-order DFS and reverses the result, producing an
/// order where every dependency is recomputed before any of its dependents.
///
/// Example:  A → B → D,  A → C → D
/// Sorted descendants of A: [B, C, D]  (B and C before D).
struct SKAtomGraph {

    /// `dependencies[key]` — the set of atoms `key` reads from.
    private(set) var dependencies: [SKAtomKey: Set<SKAtomKey>] = [:]

    /// `children[key]` — the set of atoms that read from `key`.
    private(set) var children: [SKAtomKey: Set<SKAtomKey>] = [:]

    // MARK: Mutation

    /// Records that `dependent` reads from `dependency`.
    mutating func addDependency(from dependent: SKAtomKey, to dependency: SKAtomKey) {
        dependencies[dependent, default: []].insert(dependency)
        children[dependency, default: []].insert(dependent)
    }

    /// Removes all upstream edges for `key` and cleans up the reverse entries.
    ///
    /// Call this before recomputing a derived atom to replace its old dep-set
    /// with a fresh one captured during the new evaluation.
    mutating func clearDependencies(of key: SKAtomKey) {
        guard let deps = dependencies.removeValue(forKey: key) else { return }
        for dep in deps {
            children[dep]?.remove(key)
            if children[dep]?.isEmpty == true { children.removeValue(forKey: dep) }
        }
    }

    /// Removes all downstream edges for `key` and cleans up reverse entries.
    mutating func clearChildren(of key: SKAtomKey) {
        guard let ch = children.removeValue(forKey: key) else { return }
        for child in ch {
            dependencies[child]?.remove(key)
            if dependencies[child]?.isEmpty == true { dependencies.removeValue(forKey: child) }
        }
    }

    // MARK: Query

    /// Returns atoms that directly depend on `key`.
    func directChildren(of key: SKAtomKey) -> Set<SKAtomKey> {
        children[key] ?? []
    }

    /// Returns all descendants of `key` in topological order (ancestors first).
    ///
    /// The algorithm is a post-order DFS over the `children` map, reversed.
    /// This guarantees that when a node appears in the result, all of its own
    /// dependencies that are also descendants have already appeared — so
    /// recomputing in this order is always safe.
    func topologicallySortedDescendants(of key: SKAtomKey) -> [SKAtomKey] {
        var visited = Set<SKAtomKey>()
        var sorted: [SKAtomKey] = []

        func visit(_ k: SKAtomKey) {
            guard !visited.contains(k) else { return }
            visited.insert(k)
            for child in children[k] ?? [] { visit(child) }
            sorted.append(k)
        }

        for child in children[key] ?? [] { visit(child) }

        // Post-order reversed = topological order (ancestors before descendants)
        return sorted.reversed()
    }

    // MARK: Debug

    /// Returns a human-readable snapshot of the graph edges.
    func description() -> String {
        var lines: [String] = []
        for (key, deps) in dependencies {
            for dep in deps {
                lines.append("  \(key.typeID) → \(dep.typeID)")
            }
        }
        return lines.isEmpty ? "(empty)" : lines.joined(separator: "\n")
    }
}
