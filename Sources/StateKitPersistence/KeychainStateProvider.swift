import Foundation
import Security
import Riverpods

// MARK: - Keychain Integration

/// Provider for Keychain-backed secure state storage.
///
/// Stores sensitive data (passwords, tokens, secrets) securely in Keychain.
/// Integrates with StateKit's provider system for reactive updates.
///
/// **Usage:**
/// ```swift
/// let authTokenProvider = KeychainStateProvider<String>(
///     key: "authToken",
///     accessibility: .afterFirstUnlock
/// )
///
/// let token = authTokenProvider.retrieve()
/// authTokenProvider.store(newToken)
/// ```
public struct KeychainStateProvider<T: Sendable & Codable> {
    private let key: String
    private let accessibility: KeychainAccessibility
    private let encoder: JSONEncoder = JSONEncoder()
    private let decoder: JSONDecoder = JSONDecoder()

    public init(key: String, accessibility: KeychainAccessibility = .afterFirstUnlock) {
        self.key = key
        self.accessibility = accessibility
    }

    /// Retrieves value from Keychain.
    public func retrieve() throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.retrievalFailed(status)
        }

        return try decoder.decode(T.self, from: data)
    }

    /// Stores value in Keychain.
    public func store(_ value: T) throws {
        let data = try encoder.encode(value)

        // Try to update existing
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.rawValue,
        ]

        var status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        // If not found, insert new
        if status == errSecItemNotFound {
            var insertQuery = updateQuery
            insertQuery[kSecValueData as String] = data
            insertQuery[kSecAttrAccessible as String] = accessibility.rawValue

            status = SecItemAdd(insertQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    /// Deletes value from Keychain.
    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Checks if value exists in Keychain.
    public func exists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanFalse as Any,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Clears all values for this provider's key pattern.
    public func clearAll() throws {
        try delete()
    }
}

// MARK: - Keychain Accessibility Levels

/// Security level for Keychain items.
public enum KeychainAccessibility: String, Sendable {
    /// Item is inaccessible after device restart until user unlocks device.
    case afterFirstUnlock = "com.apple.keychain.when-unlocked"

    /// Item is inaccessible after device restart, and while device is locked.
    case afterFirstUnlockThisDeviceOnly = "com.apple.keychain.when-unlocked-this-device-only"

    /// Item is always accessible (least secure).
    case always = "com.apple.keychain.always"

    /// Item is accessible when device is unlocked (most common).
    case whenUnlocked = "com.apple.keychain.when-unlocked"

    /// Item is accessible when device is unlocked, this device only.
    case whenUnlockedThisDeviceOnly = "com.apple.keychain.when-unlocked-this-device-only"
}

// MARK: - Keychain Errors

/// Errors from Keychain operations.
public enum KeychainError: Error, Sendable {
    case retrievalFailed(OSStatus)
    case storeFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodingFailed

    public var localizedDescription: String {
        switch self {
        case .retrievalFailed(let status):
            return "Failed to retrieve from Keychain (status: \(status))"
        case .storeFailed(let status):
            return "Failed to store in Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        case .decodingFailed:
            return "Failed to decode Keychain value"
        }
    }
}

// MARK: - Keychain Notifier Provider

/// NotifierProvider factory for Keychain-backed state.
public struct KeychainNotifierProvider {
    /// Creates a notifier for managing Keychain state.
    public static func create<T: Sendable & Codable>(
        key: String,
        initial: T,
        accessibility: KeychainAccessibility = .whenUnlocked
    ) -> NotifierProvider<KeychainNotifier<T>> {
        return NotifierProvider { ref in
            let provider = KeychainStateProvider<T>(key: key, accessibility: accessibility)
            return KeychainNotifier(provider: provider, initial: initial, ref: ref)
        }
    }
}

/// Notifier that maintains Keychain synchronization.
public final class KeychainNotifier<T: Sendable & Codable>: Notifier, Sendable {
    private let provider: KeychainStateProvider<T>
    private var cachedValue: T

    public init(
        provider: KeychainStateProvider<T>,
        initial: T,
        ref: NotifierProviderRef
    ) {
        self.provider = provider

        // Try to load from Keychain, fall back to initial
        if let retrieved = try? provider.retrieve() {
            self.cachedValue = retrieved
        } else {
            self.cachedValue = initial
        }
    }

    /// Gets current value (from cache, not Keychain).
    public var value: T {
        cachedValue
    }

    /// Updates value and persists to Keychain.
    public func update(_ value: T) throws {
        cachedValue = value
        try provider.store(value)
    }

    /// Clears from Keychain.
    public func clear() throws {
        try provider.delete()
    }
}

// MARK: - Common Keychain Values

/// AuthToken for API authentication.
public struct AuthToken: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String? = nil, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        Date() > expiresAt
    }
}

/// SecureCredentials for user authentication.
public struct SecureCredentials: Codable, Sendable {
    public let username: String
    public let password: String
    public let lastUpdated: Date

    public init(username: String, password: String, lastUpdated: Date = Date()) {
        self.username = username
        self.password = password
        self.lastUpdated = lastUpdated
    }
}

/// BiometricState for Touch/Face ID.
public struct BiometricState: Codable, Sendable {
    public let isEnabled: Bool
    public let lastVerified: Date?

    public init(isEnabled: Bool = false, lastVerified: Date? = nil) {
        self.isEnabled = isEnabled
        self.lastVerified = lastVerified
    }
}

// MARK: - Batch Keychain Operations

/// Helper for managing multiple Keychain values.
public struct KeychainBatch: Sendable {
    private var items: [String: Data] = [:]

    public init() {}

    /// Adds item to batch.
    public mutating func add<T: Codable>(_ value: T, forKey key: String) throws {
        let encoded = try JSONEncoder().encode(value)
        items[key] = encoded
    }

    /// Stores all items in batch.
    public func store(accessibility: KeychainAccessibility = .whenUnlocked) throws {
        for (key, data) in items {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibility.rawValue,
            ]

            SecItemDelete(query as CFDictionary)  // Remove old value first

            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.storeFailed(status)
            }
        }
    }

    /// Deletes all items in batch.
    public func deleteAll(matching pattern: String? = nil) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain Migration

/// Helper for migrating Keychain values.
public struct KeychainMigration {
    /// Migrates value from one key to another.
    public static func migrateKey<T: Codable>(
        from oldKey: String,
        to newKey: String,
        type: T.Type
    ) throws {
        let provider = KeychainStateProvider<T>(key: oldKey)
        let newProvider = KeychainStateProvider<T>(key: newKey)

        if let value = try provider.retrieve() {
            try newProvider.store(value)
            try provider.delete()
        }
    }

    /// Rotates Keychain values (useful for token rotation).
    public static func rotate<T: Codable>(
        key: String,
        with newValue: T,
        type: T.Type
    ) throws {
        let provider = KeychainStateProvider<T>(key: key)
        try provider.store(newValue)
    }
}
