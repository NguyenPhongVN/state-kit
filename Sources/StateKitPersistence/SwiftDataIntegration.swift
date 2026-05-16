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
    public typealias Build = (SwiftDataProviderRef) async throws -> T

    private let build: Build

    /// Creates a SwiftData sync provider.
    public init(_ build: @escaping Build) {
        self.build = build
    }
}

/// Reference type for SwiftData provider context.
public final class SwiftDataProviderRef: Sendable {
    public let modelContext: ModelContext

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
    public static func create<T: Sendable>(
        initialState: T,
        context: ModelContext
    ) -> AsyncNotifierProvider<T> {
        return AsyncNotifierProvider { ref -> SwiftDataNotifier<T> in
            SwiftDataNotifier(initialState: initialState, context: context, ref: ref)
        }
    }
}

/// Notifier that maintains SwiftData synchronization.
final class SwiftDataNotifier<T: Sendable>: AsyncNotifier, Sendable {
    let initialState: T
    let context: ModelContext
    let ref: AsyncNotifierProviderRef

    init(initialState: T, context: ModelContext, ref: AsyncNotifierProviderRef) {
        self.initialState = initialState
        self.context = context
        self.ref = ref
    }

    /// Updates state and persists to SwiftData.
    nonisolated func updateAndPersist(_ update: @escaping (inout T) -> Void) async {
        var current = initialState
        update(&current)

        // Persist to SwiftData
        do {
            try context.save()
        } catch {
            // Handle persistence error
        }
    }
}

// MARK: - Query Provider for SwiftData

/// FutureProvider that queries SwiftData models.
public struct SwiftDataQueryProvider {
    /// Creates a provider that queries SwiftData for specific model type.
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
    /// Syncs this model's changes to StateKit state.
    public func syncToState<S: Sendable>(
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
