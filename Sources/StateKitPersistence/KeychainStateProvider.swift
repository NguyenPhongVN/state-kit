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
    private let service: String
    private let accessibility: KeychainAccessibility
    private let encoder: JSONEncoder = JSONEncoder()
    private let decoder: JSONDecoder = JSONDecoder()

    /// Test seam (internal): reference box holding a store failure handler.
    /// A struct copy shared with a notifier still sees handler mutations.
    /// When `handler` is non-nil, `store` invokes it instead of the real
    /// Keychain write; `nil` handler (or nil box) uses the real path.
    final class _StoreOverrideBox: @unchecked Sendable {
        var handler: (@Sendable () throws -> Void)?
    }

    var _storeOverride: _StoreOverrideBox?

    /// - Parameters:
    ///   - key: unique storage key
    ///   - service: keychain service namespace — providers with different
    ///     services never collide even when they share an account key
    ///   - accessibility: the item's protection level
    public init(
        key: String,
        service: String = "state-kit",
        accessibility: KeychainAccessibility = .afterFirstUnlock
    ) {
        self.key = key
        self.service = service
        self.accessibility = accessibility
    }

    /// The keychain query attributes shared by every operation.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    /// Retrieves value from Keychain.
    public func retrieve() throws -> T? {
        var query = baseQuery
        query[kSecReturnData as String] = kCFBooleanTrue as Any

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.retrievalFailed(status)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw KeychainError.decodingFailed
        }
    }

    /// Stores value in Keychain.
    public func store(_ value: T) throws {
        if let override = _storeOverride, let handler = override.handler {
            try handler()
            return
        }

        let data = try encoder.encode(value)

        // Try to update existing
        let updateQuery = baseQuery

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.secAttr,
        ]

        var status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        // If not found, insert new
        if status == errSecItemNotFound {
            var insertQuery = updateQuery
            insertQuery[kSecValueData as String] = data
            insertQuery[kSecAttrAccessible as String] = accessibility.secAttr

            status = SecItemAdd(insertQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    /// Deletes value from Keychain.
    public func delete() throws {
        let query = baseQuery

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

    /// Deletes this provider's single keychain value.
    ///
    /// Deletes exactly the item stored under this provider's key — nothing
    /// else in the keychain is touched. (Despite the name, this is not a
    /// pattern-based wipe; for batched deletion use `KeychainBatch`.)
    public func clearAll() throws {
        try delete()
    }
}

// MARK: - Keychain Accessibility Levels

/// Security level for Keychain items.
///
/// Raw values follow the platform's canonical accessibility codes. The value
/// applied to Keychain items is `secAttr`, which references the official
/// `kSecAttrAccessible*` constants — never use the raw value as an attribute.
public enum KeychainAccessibility: String, Sendable {
    /// Item is inaccessible after device restart until user unlocks device.
    case afterFirstUnlock = "ck"

    /// Item is inaccessible after device restart, and while device is locked.
    case afterFirstUnlockThisDeviceOnly = "cku"


    /// Item is accessible when device is unlocked (most common).
    case whenUnlocked = "ak"

    /// Item is accessible when device is unlocked, this device only.
    case whenUnlockedThisDeviceOnly = "aku"

    /// The official `kSecAttrAccessible` constant for this protection level.
    var secAttr: CFString {
        switch self {
        case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlocked: kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
    }
}

// MARK: - Keychain Errors

/// Errors from Keychain operations.
public enum KeychainError: Error, Sendable {
    case retrievalFailed(OSStatus)
    case storeFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodingFailed

    /// Human-readable failure message including the OSStatus code.
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
    ) -> NotifierProvider<KeychainNotifier<T>, T> {
        return NotifierProvider {
            let provider = KeychainStateProvider<T>(key: key, accessibility: accessibility)
            return KeychainNotifier(provider: provider, initial: initial)
        }
    }
}

/// Notifier that maintains Keychain synchronization.
public final class KeychainNotifier<T: Sendable & Codable>: Notifier<T>, @unchecked Sendable {
    private let provider: KeychainStateProvider<T>
    private let initial: T

    /// Creates a notifier backed by keychain persistence under `key`.
    public init(
        provider: KeychainStateProvider<T>,
        initial: T
    ) {
        self.provider = provider
        self.initial = initial
        super.init()
    }

    /// The error from the most recent failed load, if any. A retrieval
    /// failure previously fell back to `initial` silently — an auth provider
    /// reported "no token" on a locked keychain with no signal.
    public internal(set) var lastLoadError: (any Error)?

    public override func build() -> T {
        do {
            let value = try provider.retrieve() ?? initial
            lastLoadError = nil
            return value
        } catch {
            lastLoadError = error
            return initial
        }
    }

    /// Updates value and persists to Keychain.
    ///
    /// Persists first, then commits the in-memory state: a failed store must
    /// leave the state reflecting what the Keychain actually holds, never a
    /// value that silently reverts on the next read.
    public func updateValue(_ value: T) throws {
        try provider.store(value)
        state = value
    }

    /// Clears from Keychain.
    public func clear() throws {
        try provider.delete()
        state = initial
    }
}

// MARK: - Common Keychain Values

/// AuthToken for API authentication.
public struct AuthToken: Codable, Sendable {
    /// The bearer token for API calls.
    public let accessToken: String
    /// Token used to obtain a new access token, if the server issues one.
    public let refreshToken: String?
    /// Moment after which the access token must be renewed.
    public let expiresAt: Date

    /// Creates an auth token payload.
    public init(accessToken: String, refreshToken: String? = nil, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// True once `expiresAt` has passed.
    public var isExpired: Bool {
        Date() > expiresAt
    }
}

/// SecureCredentials for user authentication.
public struct SecureCredentials: Codable, Sendable {
    /// The account's user name.
    public let username: String
    /// The account's secret.
    public let password: String
    /// When these credentials were last written.
    public let lastUpdated: Date

    /// Whether biometric unlock is turned on.
    public init(username: String, password: String, lastUpdated: Date = Date()) {
        self.username = username
        self.password = password
        self.lastUpdated = lastUpdated
    }
}

/// BiometricState for Touch/Face ID.
public struct BiometricState: Codable, Sendable {
    /// Whether biometric unlock is turned on.
    public let isEnabled: Bool
    /// When the user last passed biometric verification.
    public let lastVerified: Date?

    /// Creates an empty batch; add items with `add(_:forKey:)`.
    public init(isEnabled: Bool = false, lastVerified: Date? = nil) {
        self.isEnabled = isEnabled
        self.lastVerified = lastVerified
    }
}

// MARK: - Batch Keychain Operations

/// Helper for managing multiple Keychain values.
public struct KeychainBatch: Sendable {
    private var items: [String: Data] = [:]
    private let service: String

    /// Test seam (internal): when non-nil, each item write reports this status
    /// instead of touching the real Keychain. Arguments: (key, data, accessibility).
    var _writeOverride: (@Sendable (String, Data, KeychainAccessibility) -> OSStatus)?

    /// Creates an empty batch; add items with `add(_:forKey:)`.
    ///
    /// - Parameter service: keychain service namespace written on every item so
    ///   batch-owned keys never collide with other providers'.
    public init(service: String = "state-kit") {
        self.service = service
    }

    /// Adds item to batch.
    public mutating func add<T: Codable>(_ value: T, forKey key: String) throws {
        let encoded = try JSONEncoder().encode(value)
        items[key] = encoded
    }

    /// Stores all items in batch.
    public func store(accessibility: KeychainAccessibility = .whenUnlocked) throws {
        for (key, data) in items {
            // Update the existing item first and only insert when it does not
            // exist yet: deleting up front would destroy the previous secret
            // whenever the write then failed (device locked, entitlement
            // missing, disk pressure), aborting the batch irreversibly.
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibility.secAttr,
            ]

            var status: OSStatus
            if let override = _writeOverride {
                status = override(key, data, accessibility)
            } else {
                status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

                if status == errSecItemNotFound {
                    var insertQuery = updateQuery
                    insertQuery[kSecValueData as String] = data
                    insertQuery[kSecAttrAccessible as String] = accessibility.secAttr

                    status = SecItemAdd(insertQuery as CFDictionary, nil)
                }
            }
            guard status == errSecSuccess else {
                throw KeychainError.storeFailed(status)
            }
        }
    }

    /// Returns the batch keys selected for deletion.
    ///
    /// Only keys this batch stored can ever be selected — keychain items the
    /// batch did not create are out of scope by construction.
    ///
    /// - Parameter pattern: `nil` or empty selects every batch key; otherwise
    ///   only keys starting with `pattern` (prefix match) are selected.
    func keysToDelete(matching pattern: String?) -> [String] {
        let allKeys = Array(items.keys)
        guard let pattern, !pattern.isEmpty else { return allKeys }
        return allKeys.filter { $0.hasPrefix(pattern) }
    }

    /// Deletes matching items previously added to this batch.
    ///
    /// Deletion is scoped to this batch's `items`: a key that was never added
    /// to the batch is never touched, so unrelated keychain content (auth
    /// tokens, credentials) cannot be affected.
    ///
    /// - Parameter pattern: `nil` or empty deletes every batch item;
    ///   otherwise only batch items whose key starts with `pattern`
    ///   (prefix match). Aborts on the first failed delete; already-deleted
    ///   items stay deleted.
    public func deleteAll(matching pattern: String? = nil) throws {
        for key in keysToDelete(matching: pattern) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
            ]

            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deleteFailed(status)
            }
        }
    }
}

// MARK: - Keychain Migration

/// Helper for migrating Keychain values.
public struct KeychainMigration {
    /// Migrates value from one key to another.
    public static func migrateKey<T: Sendable & Codable>(
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
    public static func rotate<T: Sendable & Codable>(
        key: String,
        with newValue: T,
        type: T.Type
    ) throws {
        let provider = KeychainStateProvider<T>(key: key)
        try provider.store(newValue)
    }
}
