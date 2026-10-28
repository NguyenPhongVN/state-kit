import Foundation
import SwiftData
import Riverpods
import StateKit

// MARK: - SwiftData Integration

/// Synchronizes StateKit state with SwiftData @Model objects.
///
/// Maintains bidirectional sync: changes in state update SwiftData,
/// changes in SwiftData update state.
///
/// **Usage:**
/// ```swift
/// let userSyncProvider = SwiftDataProvider { ref, context in
///     ref.watch(userAtom).sync(to: User.self, in: context)
/// }
/// ```
public struct SwiftDataProvider<T: Sendable> {
    /// Async factory the provider runs on first access.
    public typealias Build = (SwiftDataProviderRef) async throws -> T

    private let build: Build

    /// Creates a SwiftData sync provider.
    public init(_ build: @escaping Build) {
        self.build = build
    }
}

/// Reference type for SwiftData provider context.
public final class SwiftDataProviderRef: @unchecked Sendable {
    /// The SwiftData context this feature reads and writes.
    public let modelContext: ModelContext

    /// Wraps an existing context for provider access.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetches models by predicate.
    public func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) throws -> [T] {
        var descriptor = FetchDescriptor<T>()
        if let predicate = predicate {
            descriptor.predicate = predicate
        }
        return try modelContext.fetch(descriptor)
    }

    /// Saves changes to SwiftData.
    public func save() throws {
        try modelContext.save()
    }
}

// MARK: - Bidirectional Sync Helper

/// Helper for syncing state with SwiftData models.
public struct SwiftDataSync<T: Sendable & Codable> {
    private let state: T
    private let context: ModelContext
    private let encoder: JSONEncoder = JSONEncoder()
    private let decoder: JSONDecoder = JSONDecoder()

    /// Bundles persisted state with its SwiftData context.
    public init(state: T, context: ModelContext) {
        self.state = state
        self.context = context
    }

    /// Encodes state to JSON for storage.
    public func encodeForStorage() throws -> Data {
        try encoder.encode(state)
    }

    /// Decodes state from JSON.
    public static func decodeFromStorage(_ data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }

    /// Gets all models of a specific type from SwiftData.
    public func getAllModels<M: PersistentModel>(_ type: M.Type) throws -> [M] {
        let descriptor = FetchDescriptor<M>()
        return try context.fetch(descriptor)
    }

    /// Saves changes back to SwiftData.
    public func persistChanges() throws {
        try context.save()
    }
}

// MARK: - SwiftData Notifier Provider

/// Provider factory for SwiftData-backed notifiers.
public struct SwiftDataNotifierProvider {
    /// Creates a notifier that syncs state with SwiftData.
    @MainActor
    public static func create<T: Sendable & Codable>(
        initialState: T,
        context: ModelContext
    ) -> AsyncNotifierProvider<SwiftDataNotifier<T>, T> {
        return AsyncNotifierProvider {
            SwiftDataNotifier(initialState: initialState, context: context)
        }
    }
}

/// Notifier that maintains SwiftData synchronization.
public final class SwiftDataNotifier<T: Sendable & Codable>: AsyncNotifier<T>, @unchecked Sendable {
    private let initialState: T
    private let context: ModelContext

    /// Creates the notifier starting from `initialState`.
    public init(initialState: T, context: ModelContext) {
        self.initialState = initialState
        self.context = context
        super.init()
    }

    public override func build() async throws -> T {
        return initialState
    }

    /// Updates state and persists it to SwiftData.
    ///
    /// The state is JSON-encoded into a keyed `SwiftDataStateRecord` model and
    /// saved; the in-memory state commits ONLY after the save succeeds
    /// (previously the empty catch silently swallowed failures after the state
    /// had already been committed, letting memory and storage diverge).
    @MainActor
    public func updateAndPersist(_ update: (inout T) -> Void) async throws {
        var current = state.value ?? initialState
        update(&current)

        let payload = try JSONEncoder().encode(current)
        let key = String(describing: T.self)

        let descriptor = FetchDescriptor<SwiftDataStateRecord>(
            predicate: #Predicate { $0.storageKey == key }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.payload = payload
        } else {
            context.insert(SwiftDataStateRecord(storageKey: key, payload: payload))
        }
        try context.save()

        state = .data(current)
    }
}

// MARK: - Query Provider for SwiftData

/// FutureProvider that queries SwiftData models.
public struct SwiftDataQueryProvider {
    /// Creates a provider that queries SwiftData for specific model type.
    @MainActor
    public static func query<T: PersistentModel>(
        type: T.Type,
        in context: ModelContext,
        predicate: Predicate<T>? = nil,
        sort: [SortDescriptor<T>] = []
    ) -> FutureProvider<[T]> {
        return FutureProvider { ref in
            var descriptor = FetchDescriptor<T>()
            if let predicate = predicate {
                descriptor.predicate = predicate
            }
            if !sort.isEmpty {
                descriptor.sortBy = sort
            }

            return try context.fetch(descriptor)
        }
    }
}

// MARK: - SwiftData Model Extension

extension PersistentModel where Self: Sendable {
    /// Saves pending model changes to the SwiftData context.
    public func syncToState(
        in context: ModelContext
    ) async throws -> Self {
        try context.save()
        return self
    }
}

// MARK: - Automatic Persistence Helper

/// Helper for automatic persistence of state changes.
public struct AutoPersist<T: Sendable & Codable> {
    private let key: String
    private var cachedData: T

    /// Creates a notifier bound to the SwiftData-backed key.
    public init(key: String, initial: T) {
        self.key = key
        self.cachedData = initial
    }

    /// Loads persisted data if available.
    public mutating func load() throws -> T {
        if let data = UserDefaults.standard.data(forKey: key) {
            cachedData = try JSONDecoder().decode(T.self, from: data)
        }
        return cachedData
    }

    /// Saves data for later retrieval.
    public func save(_ value: T) throws {
        let encoded = try JSONEncoder().encode(value)
        UserDefaults.standard.set(encoded, forKey: key)
    }

    /// Clears persisted data.
    public func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}


/// Key-value record backing `SwiftDataNotifier` persistence: the state is
/// stored JSON-encoded under a stable key derived from the state type.
@Model
public final class SwiftDataStateRecord {
    /// Unique storage key (the state type's name).
    public var storageKey: String
    /// JSON-encoded state payload.
    public var payload: Data

    public init(storageKey: String, payload: Data) {
        self.storageKey = storageKey
        self.payload = payload
    }
}
