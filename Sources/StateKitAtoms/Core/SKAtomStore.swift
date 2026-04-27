import Combine
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

    /// Active Combine subscriptions for publisher atoms.
    var cancellables: [SKAtomKey: AnyCancellable] = [:]

    /// Active lifecycle effects for atoms.
    var effects: [SKAtomKey: SKAtomEffectContainer] = [:]

    /// Number of external (View-level) subscribers for each atom.
    private var externalSubscriberCounts: [SKAtomKey: Int] = [:]

    /// Memory management strategy for each registered atom.
    private var evictionPolicies: [SKAtomKey: SKAtomEvictionPolicy] = [:]

    // MARK: - Batching

    /// If `true`, calls to `propagateChange` will be deferred until the batch ends.
    private var isBatching = false

    /// Keys that have changed during the current batch and need propagation.
    private var pendingChanges = Set<SKAtomKey>()

    /// Executes `body` and defers all change propagation until the end of the block.
    ///
    /// Use this to group multiple atom updates into a single re-computation pass.
    /// This prevents derived atoms from being recalculated multiple times when
    /// several of their dependencies change simultaneously.
    ///
    /// ```swift
    /// store.batch {
    ///     store.setStateValue(1, for: atomA)
    ///     store.setStateValue(2, for: atomB)
    /// } // propagateChange called once here for both A and B
    /// ```
    @MainActor
    public func batch(_ body: () -> Void) {
        let alreadyBatching = isBatching
        isBatching = true
        body()
        isBatching = alreadyBatching

        if !isBatching && !pendingChanges.isEmpty {
            let changes = pendingChanges
            pendingChanges.removeAll()
            propagateBatch(from: changes)
        }
    }

    /// Global interceptors for observing all atom changes.
    public typealias Interceptor = @MainActor (SKAtomKey, _ oldValue: Any, _ newValue: Any) -> Void
    private var interceptors: [Interceptor] = []

    /// Adds a global interceptor that is called whenever any atom's value changes.
    @MainActor
    public func addInterceptor(_ interceptor: @escaping Interceptor) {
        interceptors.append(interceptor)
    }

    @MainActor
    private func notifyInterceptors(key: SKAtomKey, oldValue: Any, newValue: Any) {
        for interceptor in interceptors {
            interceptor(key, oldValue, newValue)
        }
    }

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

    /// Updates an atom's value and notifies effects and interceptors.
    @MainActor
    private func updateBox<Value>(key: SKAtomKey, box: SKAtomBox<Value>, newValue: Value) {
        let oldValue = box.value
        box.value = newValue

        if let effect = effects[key] {
            effect.updated(oldValue, newValue, SKAtomViewContext(store: self))
        }

        notifyInterceptors(key: key, oldValue: oldValue, newValue: newValue)
    }

    // MARK: - Graph mutation helpers

    // MARK: - Eviction & Subscription

    /// Increments the external subscriber count for `key`.
    ///
    /// External subscribers are usually SwiftUI views using hooks or property
    /// wrappers. The store keeps the atom alive as long as it has at least
    /// one external or internal (dependent atom) subscriber.
    @MainActor
    public func addExternalSubscriber(for key: SKAtomKey) {
        externalSubscriberCounts[key, default: 0] += 1
    }

    /// Decrements the external subscriber count for `key` and triggers an
    /// eviction check if the count reaches zero.
    @MainActor
    public func removeExternalSubscriber(for key: SKAtomKey) {
        guard let count = externalSubscriberCounts[key] else { return }
        if count <= 1 {
            externalSubscriberCounts.removeValue(forKey: key)
            checkEviction(for: key)
        } else {
            externalSubscriberCounts[key] = count - 1
        }
    }

    /// Checks if `key` is still needed. If not, evicts it and recursively
    /// checks its dependencies.
    @MainActor
    private func checkEviction(for key: SKAtomKey) {
        // Only proceed if the atom is configured to be evicted when unused.
        guard evictionPolicies[key] == .evictWhenUnused else { return }

        // An atom is needed if it has external subscribers OR internal children.
        let hasExternal = externalSubscriberCounts[key] != nil
        let hasChildren = !graph.directChildren(of: key).isEmpty

        if !hasExternal && !hasChildren {
            // Capture dependencies before clearing them
            let deps = graph.dependencies[key] ?? []

            // Evict this atom
            clearCachedState(for: key)
            graph.clearDependencies(of: key)
            graph.clearChildren(of: key)

            // Recursively check if dependencies can now be evicted
            for dep in deps {
                checkEviction(for: dep)
            }
        }
    }

    @MainActor
    public func addGraphDependency(from dependent: SKAtomKey, to dependency: SKAtomKey) {
        graph.addDependency(from: dependent, to: dependency)
    }

    @MainActor
    public func clearGraphDependencies(of key: SKAtomKey) {
        let oldDeps = graph.dependencies[key] ?? []
        graph.clearDependencies(of: key)

        // Defer eviction checks to allow recomputers to immediately re-establish dependencies.
        if !oldDeps.isEmpty {
            Task { @MainActor [weak self] in
                for dep in oldDeps {
                    self?.checkEviction(for: dep)
                }
            }
        }
    }

    // MARK: - Recomputer registration

    @MainActor
    public func registerRecomputer(for key: SKAtomKey, _ body: @escaping @MainActor () -> Void) {
        recomputers[key] = body
    }

    @MainActor
    private func registerEffect<A: SKAtom>(for atom: A, key: SKAtomKey) {
        if let effectAtom = atom as? any SKAtomWithEffect {
            effectAtom._registerEffect(in: self, key: key)
        }
    }

    @MainActor
    private func registerEvictionPolicy<A: SKAtom>(for atom: A, key: SKAtomKey) {
        evictionPolicies[key] = atom.evictionPolicy
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

        registerEvictionPolicy(for: atom, key: key)
        registerEffect(for: atom, key: key)

        return box
    }

    /// Writes a new value for a `SKStateAtom` and propagates the change.
    @MainActor
    public func setStateValue<A: SKStateAtom>(_ value: A.Value, for atom: A) {
        let key = SKAtomKey(atom)
        let box = stateBox(for: atom)
        updateBox(key: key, box: box, newValue: value)
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

        registerEvictionPolicy(for: atom, key: key)
        registerEffect(for: atom, key: key)

        registerRecomputer(for: key) { [weak self, weak box] in
            guard let self, let box else { return }
            self.clearGraphDependencies(of: key)
            let ctx = SKAtomTransactionContext(store: self, currentKey: key)
            let newValue = atom.value(context: ctx)
            self.updateBox(key: key, box: box, newValue: newValue)
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

        registerEvictionPolicy(for: atom, key: key)
        registerEffect(for: atom, key: key)

        let task = makeTask(for: atom, box: box, key: key)
        setTask(task, for: key)

        registerRecomputer(for: key) { [weak self] in
            self?.restartTask(for: atom)
        }
        return box
    }

    @MainActor
    private func makeTask<A: SKTaskAtom>(
        for atom: A, box: SKAtomBox<A.Value>, key: SKAtomKey
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self, weak box] in
            guard let self, let box else { return }
            let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
            let result = await atom.task(context: ctx)
            guard !Task.isCancelled else { return }
            self.updateBox(key: key, box: box, newValue: .success(result))
            self.propagateChange(from: key)
        }
    }

    /// Cancels the current task and restarts it.
    @MainActor
    public func restartTask<A: SKTaskAtom>(for atom: A) {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        updateBox(key: key, box: box, newValue: .loading)
        let task = makeTask(for: atom, box: box, key: key)
        setTask(task, for: key)
    }

    /// Refreshes a `SKTaskAtom` and suspends until the new task completes.
    @MainActor
    public func refreshTask<A: SKTaskAtom>(for atom: A) async {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        updateBox(key: key, box: box, newValue: .loading)
        let task = makeTask(for: atom, box: box, key: key)
        setTask(task, for: key)
        await task.value
    }

    // MARK: - Throwing task atom operations

    /// Returns the box for a `SKThrowingTaskAtom`, launching the task immediately.
    @MainActor
    func throwingTaskBox<A: SKThrowingTaskAtom>(for atom: A) -> SKAtomBox<A.Value> {
        let key = SKAtomKey(atom)
        if let existing: SKAtomBox<A.Value> = existingBox(for: key) { return existing }

        let box = SKAtomBox<A.Value>(.loading)
        storeBox(box, for: key)

        registerEvictionPolicy(for: atom, key: key)
        registerEffect(for: atom, key: key)

        let task = makeThrowingTask(for: atom, box: box, key: key)
        setTask(task, for: key)

        registerRecomputer(for: key) { [weak self] in
            self?.restartThrowingTask(for: atom)
        }
        return box
    }

    @MainActor
    private func makeThrowingTask<A: SKThrowingTaskAtom>(
        for atom: A, box: SKAtomBox<A.Value>, key: SKAtomKey
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self, weak box] in
            guard let self, let box else { return }
            let ctx = SKAtomTransactionContext(store: self, currentKey: nil)
            do {
                let result = try await atom.task(context: ctx)
                guard !Task.isCancelled else { return }
                self.updateBox(key: key, box: box, newValue: .success(result))
            } catch {
                guard !Task.isCancelled else { return }
                self.updateBox(key: key, box: box, newValue: .failure(error))
            }
            self.propagateChange(from: key)
        }
    }

    @MainActor
    func restartThrowingTask<A: SKThrowingTaskAtom>(for atom: A) {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        updateBox(key: key, box: box, newValue: .loading)
        let task = makeThrowingTask(for: atom, box: box, key: key)
        setTask(task, for: key)
    }

    /// Refreshes a `SKThrowingTaskAtom` and suspends until the new task completes.
    @MainActor
    public func refreshThrowingTask<A: SKThrowingTaskAtom>(for atom: A) async {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        updateBox(key: key, box: box, newValue: .loading)
        let task = makeThrowingTask(for: atom, box: box, key: key)
        setTask(task, for: key)
        await task.value
    }

    // MARK: - Publisher atom operations

    /// Returns the box for a `SKPublisherAtom`, subscribing to the publisher immediately.
    @MainActor
    public func publisherBox<A: SKPublisherAtom>(for atom: A) -> SKAtomBox<A.Value> {
        let key = SKAtomKey(atom)
        if let existing: SKAtomBox<A.Value> = existingBox(for: key) { return existing }

        let box = SKAtomBox<A.Value>(.idle)
        storeBox(box, for: key)

        registerEvictionPolicy(for: atom, key: key)
        registerEffect(for: atom, key: key)

        subscribePublisher(for: atom, box: box, key: key)

        registerRecomputer(for: key) { [weak self] in
            self?.restartPublisher(for: atom)
        }
        return box
    }

    @MainActor
    private func subscribePublisher<A: SKPublisherAtom>(
        for atom: A, box: SKAtomBox<A.Value>, key: SKAtomKey
    ) {
        let deliver: (@escaping @MainActor () -> Void) -> Void = { operation in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    operation()
                }
            } else {
                Task { @MainActor in
                    operation()
                }
            }
        }

        cancellables[key]?.cancel()
        clearGraphDependencies(of: key)
        let ctx = SKAtomTransactionContext(store: self, currentKey: key)
        cancellables[key] = atom.publisher(context: ctx)
            .sink { [weak self, weak box] completion in
                deliver {
                    guard let self, let box else { return }
                    let newValue: A.Value
                    switch completion {
                    case .finished:
                        newValue = .finished
                    case .failure(let error):
                        newValue = .failure(error)
                    }
                    self.updateBox(key: key, box: box, newValue: newValue)
                    self.propagateChange(from: key)
                }
            } receiveValue: { [weak self, weak box] output in
                deliver {
                    guard let self, let box else { return }
                    self.updateBox(key: key, box: box, newValue: .value(output))
                    self.propagateChange(from: key)
                }
            }
    }

    /// Cancels the current subscription and re-subscribes.
    @MainActor
    public func restartPublisher<A: SKPublisherAtom>(for atom: A) {
        let key = SKAtomKey(atom)
        guard let box: SKAtomBox<A.Value> = existingBox(for: key) else { return }
        updateBox(key: key, box: box, newValue: .idle)
        subscribePublisher(for: atom, box: box, key: key)
    }

    // MARK: - Change propagation

    /// Walks the dependency graph from `key` and recomputes all descendants
    /// in topological order.
    @MainActor
    func propagateChange(from key: SKAtomKey) {
        pendingChanges.insert(key)

        if isBatching { return }

        isBatching = true
        defer { isBatching = false }

        while !pendingChanges.isEmpty {
            let changes = pendingChanges
            pendingChanges.removeAll()
            propagateBatch(from: changes)
        }
    }

    /// Walks the dependency graph from a set of changed keys and recomputes
    /// all descendants in topological order.
    @MainActor
    private func propagateBatch(from keys: Set<SKAtomKey>) {
        let sorted = graph.topologicallySortedDescendants(of: keys)
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

    @MainActor
    private func clearCachedState(for key: SKAtomKey) {
        boxes.removeValue(forKey: key)
        recomputers.removeValue(forKey: key)
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
        cancellables[key]?.cancel()
        cancellables.removeValue(forKey: key)

        if let effect = effects.removeValue(forKey: key) {
            effect.released()
        }
        evictionPolicies.removeValue(forKey: key)
    }

    /// Removes all cached state for `atom` and any cached descendants that
    /// depend on it.
    @MainActor
    public func evict<A: SKAtom>(_ atom: A) {
        let key = SKAtomKey(atom)
        let keysToEvict = [key] + graph.topologicallySortedDescendants(of: key)

        for evictedKey in keysToEvict {
            clearCachedState(for: evictedKey)
        }

        for evictedKey in keysToEvict {
            graph.clearDependencies(of: evictedKey)
            graph.clearChildren(of: evictedKey)
        }
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

// MARK: - SubscriberToken

/// Internal helper that manages an external subscription lifecycle via deinit.
///
/// Use this inside property wrappers or hook slots to ensure `removeExternalSubscriber`
/// is called when the view or hook is destroyed.
public final class SKSubscriberToken: @unchecked Sendable {

    /// A non-observable container for a token, suitable for use in `@State`.
    ///
    /// Initializing the contents of this box does not trigger SwiftUI re-renders,
    /// avoiding "Modifying state during view update" warnings.
    public final class Box {
        public var token: SKSubscriberToken?
        public init() {}
    }

    private let store: SKAtomStore
    private let key: SKAtomKey

    @MainActor
    public init(store: SKAtomStore, key: SKAtomKey) {
        self.store = store
        self.key = key
        store.addExternalSubscriber(for: key)
    }

    deinit {
        // Deinit can happen on any thread. We must jump to the main actor
        // to update the store's state.
        let store = self.store
        let key = self.key
        Task { @MainActor in
            store.removeExternalSubscriber(for: key)
        }
    }
}
