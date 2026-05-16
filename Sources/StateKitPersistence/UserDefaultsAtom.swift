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
    private let key: String
    private var observers: [(T) -> Void] = []
    private let lock = NSLock()

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
    public func save(_ value: T) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(value) {
            defaults.set(encoded, forKey: key)
            notifyObservers(value)
        }
    }

    /// Deletes persisted value.
    public func delete() {
        defaults.removeObject(forKey: key)
    }

    /// Adds observer for value changes.
    public func addObserver(_ observer: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        observers.append(observer)
    }

    private func notifyObservers(_ value: T) {
        lock.lock()
        let currentObservers = observers
        lock.unlock()
        
        for observer in currentObservers {
            observer(value)
        }
    }
}

// MARK: - Common UserDefaults Serializables

/// User preferences with common app settings.
public struct AppPreferences: UserDefaultsSerializable {
    public let isDarkMode: Bool
    public let language: String
    public let lastOpenedDate: Date?

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
    public let lastUpdated: Date
    public let version: Int
    public let itemCount: Int

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
    public let userId: String?
    public let sessionToken: String?
    public let loginTime: Date?

    public init(userId: String? = nil, sessionToken: String? = nil, loginTime: Date? = nil) {
        self.userId = userId
        self.sessionToken = sessionToken
        self.loginTime = loginTime
    }

    public static let userDefaultsKey = "com.statekit.sessionInfo"
    public static let defaultValue = SessionInfo(userId: nil, sessionToken: nil, loginTime: nil)

    public var isAuthenticated: Bool {
        userId != nil && sessionToken != nil
    }
}

// MARK: - Atom Extensions

extension PersistentAtomStorage {
    /// Convenience method for observing UserDefaults changes.
    public func observeChanges() -> [T] {
        var values: [T] = []

        addObserver { value in
            values.append(value)
        }

        return values
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
            save(value)
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

    public init(storage: PersistentAtomStorage<T>, version: Int) {
        self.storage = storage
        self.currentVersion = version
    }

    /// Checks if migration is needed.
    public func needsMigration(_ previousVersion: Int) -> Bool {
        previousVersion < currentVersion
    }

    /// Performs migration with custom logic.
    public func migrate(from previousVersion: Int, using updater: (inout T) -> Void) {
        guard needsMigration(previousVersion) else { return }

        var current = storage.load()
        updater(&current)
        storage.save(current)
    }
}
