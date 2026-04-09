import SwiftUI
import StateKit

/// The central atom store for `StateKitAtoms`.
///
/// `SKAtomStore` owns every `SKAtomBox`, the dependency graph that connects
/// them, and the type-erased recomputers needed to propagate changes through
/// derived atoms. It is the single source of truth.
///
/// ## Usage
///
/// Provide a store to a view tree with `SKAtomRoot`. A default shared store is
/// used automatically when no root is present.
///
/// ```swift
/// SKAtomRoot {
///     ContentView()
/// }
/// ```
///
/// ## Thread safety
///
/// All mutation methods are `@MainActor`. Do not call them from a background
/// thread or actor.
public final class SKAtomStore: @unchecked Sendable {

    // MARK: - Singleton

    /// The process-wide default store.
    ///
    /// Used when no `SKAtomRoot` injects a custom store via the environment.
    public static let shared = SKAtomStore()

    // MARK: - Storage (MainActor-only in practice)

    /// Per-atom observable boxes, keyed by atom identity (type-erased).
    var boxes: [SKAtomKey: AnyObject] = [:]

    /// Dependency graph (bidirectional).
    var graph = SKAtomGraph()

    /// Type-erased closures that recompute derived atom values.
    var recomputers: [SKAtomKey: @MainActor () -> Void] = [:]

    /// Running tasks for async atoms.
    var tasks: [SKAtomKey: Task<Void, Never>] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Box access

    @MainActor
    public func existingBox<Value>(for key: SKAtomKey) -> SKAtomBox<Value>? {
        boxes[key] as? SKAtomBox<Value>
    }

    @MainActor
    public func storeBox<Value>(_ box: SKAtomBox<Value>, for key: SKAtomKey) {
        boxes[key] = box
    }

    // MARK: - Graph mutation helpers

    @MainActor
    public func addGraphDependency(from dependent: SKAtomKey, to dependency: SKAtomKey) {
        graph.addDependency(from: dependent, to: dependency)
    }

    @MainActor
    public func clearGraphDependencies(of key: SKAtomKey) {
        graph.clearDependencies(of: key)
    }

    // MARK: - Recomputer registration

    @MainActor
    public func registerRecomputer(for key: SKAtomKey, _ body: @escaping @MainActor () -> Void) {
        recomputers[key] = body
    }

    // MARK: - State atom operations

    /// Returns the box for a `SKStateAtom`, creating and initialising it on
    /// first access.
    @MainActor
    public func stateBox<A: SKStateAtom>(for atom: A) -> SKAtomBox<A.Value> {
        let key = SKAtomKey(atom)
        if let existing: SKAtomBox<A.Value> = existingBox(for: key) { return existing }

        let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
        let box = SKAtomBox(atom.defaultValue(context: ctx))
        storeBox(box, for: key)
        return box
    }

    /// Writes a new value for a `SKStateAtom` and propagates the change.
    @MainActor
    public func setStateValue<A: SKStateAtom>(_ value: A.Value, for atom: A) {
        let key = SKAtomKey(atom)
        let box = stateBox(for: atom)
        box.value = value
        propagateChange(from: key)
    }

    /// Resets a `SKStateAtom` to its default value.
    @MainActor
    public func resetStateValue<A: SKStateAtom>(for atom: A) {
        let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
        setStateValue(atom.defaultValue(context: ctx), for: atom)
    }

    // MARK: - Value atom operations

    /// Returns the box for a `SKValueAtom`, computing the initial value with
    /// dependency tracking and registering a recomputer for future updates.
    @MainActor
    public func valueBox<A: SKValueAtom>(for atom: A) -> SKAtomBox<A.Value> {
        let key = SKAtomKey(atom)
        if let existing: SKAtomBox<A.Value> = existingBox(for: key) { return existing }

        clearGraphDependencies(of: key)
        let ctx = SKAtomTransactionContext(store: self, currentKey: key)
        let box = SKAtomBox(atom.value(context: ctx))
        storeBox(box, for: key)

        registerRecomputer(for: key) { [weak self, weak box] in
            guard let self, let box else { return }
            self.clearGraphDependencies(of: key)
            let ctx = SKAtomTransactionContext(store: self, currentKey: key)
            box.value = atom.value(context: ctx)
            self.propagateChange(from: key)
        }
        return box
    }

    // MARK: - Task atom operations

    /// Returns the box for a `SKTaskAtom`, launching the task immediately.
    @MainActor
    public func taskBox<A: SKTaskAtom>(for atom: A) -> SKAtomBox<A.Value> {
        let key = SKAtomKey(atom)
        if let existing: SKAtomBox<A.Value> = existingBox(for: key) { return existing }

        let box = SKAtomBox<A.Value>(.loading)
        storeBox(box, for: key)
        launchTask(for: atom, box: box, key: key)

        registerRecomputer(for: key) { [weak self] in
            self?.restartTask(for: atom)
        }
        return box
    }

    @MainActor
    private func launchTask<A: SKTaskAtom>(
        for atom: A, box: SKAtomBox<A.Value>, key: SKAtomKey
    ) {
        let task = Task { @MainActor [weak self, weak box] in
            guard let self, let box else { return }
            let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
            let result = await atom.task(context: ctx)
            guard !Task.isCancelled else { return }
            box.value = .success(result)
            self.propagateChange(from: key)
        }
        setTask(task, for: key)
    }

    /// Cancels the current task and restarts it.
    @MainActor
    public func restartTask<A: SKTaskAtom>(for atom: A) {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        box.value = .loading
        launchTask(for: atom, box: box, key: key)
    }

    /// Refreshes a `SKTaskAtom` and suspends until the new task completes.
    @MainActor
    public func refreshTask<A: SKTaskAtom>(for atom: A) async {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        tasks[key]?.cancel()
        box.value = .loading
        let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
        let result = await atom.task(context: ctx)
        guard !Task.isCancelled else { return }
        box.value = .success(result)
        propagateChange(from: key)
    }

    // MARK: - Throwing task atom operations

    /// Returns the box for a `SKThrowingTaskAtom`, launching the task immediately.
    @MainActor
    func throwingTaskBox<A: SKThrowingTaskAtom>(for atom: A) -> SKAtomBox<A.Value> {
        let key = SKAtomKey(atom)
        if let existing: SKAtomBox<A.Value> = existingBox(for: key) { return existing }

        let box = SKAtomBox<A.Value>(.loading)
        storeBox(box, for: key)
        launchThrowingTask(for: atom, box: box, key: key)

        registerRecomputer(for: key) { [weak self] in
            self?.restartThrowingTask(for: atom)
        }
        return box
    }

    @MainActor
    private func launchThrowingTask<A: SKThrowingTaskAtom>(
        for atom: A, box: SKAtomBox<A.Value>, key: SKAtomKey
    ) {
        let task = Task { @MainActor [weak self, weak box] in
            guard let self, let box else { return }
            let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
            do {
                let result = try await atom.task(context: ctx)
                guard !Task.isCancelled else { return }
                box.value = .success(result)
            } catch {
                guard !Task.isCancelled else { return }
                box.value = .failure(error)
            }
            self.propagateChange(from: key)
        }
        setTask(task, for: key)
    }

    @MainActor
    func restartThrowingTask<A: SKThrowingTaskAtom>(for atom: A) {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        box.value = .loading
        launchThrowingTask(for: atom, box: box, key: key)
    }

    /// Refreshes a `SKThrowingTaskAtom` and suspends until the new task completes.
    @MainActor
    public func refreshThrowingTask<A: SKThrowingTaskAtom>(for atom: A) async {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        tasks[key]?.cancel()
        box.value = .loading
        let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
        do {
            let result = try await atom.task(context: ctx)
            guard !Task.isCancelled else { return }
            box.value = .success(result)
        } catch {
            guard !Task.isCancelled else { return }
            box.value = .failure(error)
        }
        propagateChange(from: key)
    }

    // MARK: - Change propagation

    /// Walks the dependency graph from `key` and recomputes all descendants
    /// in topological order.
    @MainActor
    func propagateChange(from key: SKAtomKey) {
        let sorted = graph.topologicallySortedDescendants(of: key)
        for descendantKey in sorted {
            recomputers[descendantKey]?()
        }
    }

    // MARK: - Task lifecycle

    @MainActor
    private func setTask(_ task: Task<Void, Never>, for key: SKAtomKey) {
        tasks[key]?.cancel()
        tasks[key] = task
    }

    // MARK: - Eviction

    /// Removes all cached state for `atom`: box, graph edges, recomputer, task.
    @MainActor
    public func evict<A: SKAtom>(_ atom: A) {
        let key = SKAtomKey(atom)
        boxes.removeValue(forKey: key)
        graph.clearDependencies(of: key)
        graph.clearChildren(of: key)
        recomputers.removeValue(forKey: key)
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
    }

    // MARK: - Debug

    /// The number of atoms currently cached in this store.
    @MainActor
    public var atomCount: Int { boxes.count }

    /// Returns `true` if `atom` has been initialised in this store.
    @MainActor
    public func contains<A: SKAtom>(_ atom: A) -> Bool {
        boxes[SKAtomKey(atom)] != nil
    }
}
