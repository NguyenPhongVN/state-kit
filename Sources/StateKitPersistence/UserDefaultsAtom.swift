import Foundation
import StateKitAtoms

// MARK: - UserDefaults-Backed Atoms

/// Protocol for values that can be persisted to UserDefaults.
public protocol UserDefaultsSerializable: Sendable, Codable {
    /// Key for UserDefaults storage.
    static var userDefaultsKey: String { get }

    /// Default value if nothing stored.
    static var defaultValue: Self { get }
}

/// Creates a UserDefaults-backed atom that automatically persists changes.
///
/// Changes to the atom state are automatically saved to UserDefaults.
/// Loads previous value on initialization.
///
/// **Usage:**
/// ```swift
/// struct UserPreferences: UserDefaultsSerializable {
///     let theme: String
///     let fontSize: Int
///
///     static let userDefaultsKey = "userPreferences"
///     static let defaultValue = UserPreferences(theme: "light", fontSize: 16)
/// }
///
/// let preferencesAtom = userDefaultsAtom(UserPreferences.self)
/// ```
public func userDefaultsAtom<T: UserDefaultsSerializable>(
    _ type: T.Type,
    suiteName: String? = nil
) -> (() -> T) {
    let defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? UserDefaults.standard

    return {
        // Try to load from UserDefaults
        if let data = defaults.data(forKey: T.userDefaultsKey) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(T.self, from: data) {
                return decoded
            }
        }

        // Fall back to default
        return T.defaultValue
    }
}

// MARK: - Persistent Atom Storage

/// Storage system for persistent atoms with observation.
public final class PersistentAtomStorage<T: UserDefaultsSerializable>: @unchecked Sendable {
    private let defaults: UserDefaults
    let key: String
    private struct ObserverEntry {
        let id: UUID
        let handler: (T) -> Void
    }

    private var observers: [ObserverEntry] = []
    private let lock = NSLock()

    /// Creates storage bound to standard defaults or a named suite.
    public init(
        type: T.Type,
        userDefaultsKey: String? = nil,
        suiteName: String? = nil
    ) {
        self.key = userDefaultsKey ?? T.userDefaultsKey
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? UserDefaults.standard
    }

    /// Loads current value.
    public func load() -> T {
        if let data = defaults.data(forKey: key) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(T.self, from: data) {
                return decoded
            }
        }
        return T.defaultValue
    }

    /// Saves value and notifies observers.
    ///
    /// - Throws: `PersistenceError.encodingFailed` when the value cannot be
    ///   encoded — nothing is written and observers are NOT notified of a
    ///   write that did not happen.
    public func save(_ value: T) throws {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(value)
            defaults.set(encoded, forKey: key)
            notifyObservers(value)
        } catch {
            throw PersistenceError.encodingFailed(underlying: error)
        }
    }

    /// Deletes persisted value.
    public func delete() {
        defaults.removeObject(forKey: key)
    }

    /// Adds observer for value changes.
    ///
    /// - Returns: A thread-safe removal token.
    @discardableResult
    public func addObserver(_ observer: @escaping (T) -> Void) -> @Sendable () -> Void {
        let entry = ObserverEntry(id: UUID(), handler: observer)
        lock.lock()
        defer { lock.unlock() }
        observers.append(entry)
        let id = entry.id
        return { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.observers.removeAll { $0.id == id }
            self.lock.unlock()
        }
    }

    private func notifyObservers(_ value: T) {
        lock.lock()
        let currentObservers = observers
        lock.unlock()

        for observer in currentObservers {
            observer.handler(value)
        }
    }
}

// MARK: - Common UserDefaults Serializables

/// User preferences with common app settings.
public struct AppPreferences: UserDefaultsSerializable {
    /// Whether dark appearance is enabled.
    public let isDarkMode: Bool
    /// Preferred language code.
    public let language: String
    /// When the app was last opened, if recorded.
    public let lastOpenedDate: Date?

    /// Creates storage bound to standard defaults or a named suite.
    public init(isDarkMode: Bool = false, language: String = "en", lastOpenedDate: Date? = nil) {
        self.isDarkMode = isDarkMode
        self.language = language
        self.lastOpenedDate = lastOpenedDate
    }

    public static let userDefaultsKey = "com.statekit.appPreferences"
    public static let defaultValue = AppPreferences(isDarkMode: false, language: "en", lastOpenedDate: nil)

    private enum CodingKeys: String, CodingKey {
        case isDarkMode
        case language
        case lastOpenedDate
    }
}

/// Cache metadata for managing stored data.
public struct CacheMetadata: UserDefaultsSerializable {
    /// When the cache metadata was written.
    public let lastUpdated: Date
    /// Cache schema version.
    public let version: Int
    /// Entries currently cached.
    public let itemCount: Int

    /// Creates cache metadata (defaults capture the current time).
    public init(lastUpdated: Date = Date(), version: Int = 1, itemCount: Int = 0) {
        self.lastUpdated = lastUpdated
        self.version = version
        self.itemCount = itemCount
    }

    public static let userDefaultsKey = "com.statekit.cacheMetadata"
    public static let defaultValue = CacheMetadata()
}

/// User session information.
public struct SessionInfo: UserDefaultsSerializable {
    /// Signed-in user's identifier, if any.
    public let userId: String?
    /// Session token, if signed in.
    public let sessionToken: String?
    /// When the current session started, if any.
    public let loginTime: Date?

    /// Creates a versioned atom backed by the given storage.
    public init(userId: String? = nil, sessionToken: String? = nil, loginTime: Date? = nil) {
        self.userId = userId
        self.sessionToken = sessionToken
        self.loginTime = loginTime
    }

    public static let userDefaultsKey = "com.statekit.sessionInfo"
    public static let defaultValue = SessionInfo(userId: nil, sessionToken: nil, loginTime: nil)

    /// True when a session token is present.
    public var isAuthenticated: Bool {
        userId != nil && sessionToken != nil
    }
}

// MARK: - Atom Extensions

extension PersistentAtomStorage {
    /// Observes value changes as a stream.
    ///
    /// Replaces the broken `observeChanges() -> [T]`, which always returned an
    /// empty array (the captured buffer mutated after the value copy returned).
    /// The stream yields every successfully saved value and terminates when the
    /// consumer cancels.
    public func changes() -> AsyncStream<T> {
        AsyncStream { continuation in
            let remove = addObserver { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                remove()
            }
        }
    }

    /// Exports all stored data as JSON.
    public func exportAsJSON() -> Data? {
        let value = load()
        return try? JSONEncoder().encode(value)
    }

    /// Imports data from JSON.
    public func importFromJSON(_ data: Data) -> Bool {
        do {
            let value = try JSONDecoder().decode(T.self, from: data)
            try save(value)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Migration Helpers

/// Helper for migrating persisted data between versions.
public struct PersistenceMigration<T: UserDefaultsSerializable> {
    private let storage: PersistentAtomStorage<T>
    private let currentVersion: Int

    /// Creates a versioned atom backed by the given storage.
    public init(storage: PersistentAtomStorage<T>, version: Int) {
        self.storage = storage
        self.currentVersion = version
    }

    /// The schema version persisted alongside the payload (0 if never marked).
    public var persistedVersion: Int {
        UserDefaults.standard.integer(forKey: storage.key + ".schemaVersion")
    }

    /// Persists the schema version after a successful migration.
    public func markMigrated(to version: Int) {
        UserDefaults.standard.set(version, forKey: storage.key + ".schemaVersion")
    }

    /// Checks if migration is needed (caller-supplied version — the on-disk
    /// version is `persistedVersion`).
    public func needsMigration(_ previousVersion: Int) -> Bool {
        previousVersion < currentVersion
    }

    /// Checks if the persisted schema version is behind `currentVersion`.
    public func needsMigration() -> Bool {
        persistedVersion < currentVersion
    }

    /// Performs migration with custom logic and records the new schema version
    /// only after the write succeeds, so migrations do not re-run silently.
    public func migrate(using updater: (inout T) -> Void) throws {
        guard needsMigration() else { return }
        var current = storage.load()
        updater(&current)
        try storage.save(current)
        markMigrated(to: currentVersion)
    }

    /// Legacy entry point: migrates from an explicitly supplied previous
    /// version (the version is still recorded on success).
    public func migrate(from previousVersion: Int, using updater: (inout T) -> Void) throws {
        guard needsMigration(previousVersion) else { return }
        var current = storage.load()
        updater(&current)
        try storage.save(current)
        markMigrated(to: currentVersion)
    }
}

/// Errors surfaced by persistence primitives.
public enum PersistenceError: Error, Sendable {
    /// The value could not be encoded; nothing was written.
    case encodingFailed(underlying: any Error)
}
