import XCTest
import Security
@testable import StateKitPersistence

final class KeychainBatchTests: XCTestCase {

    // MARK: - Key selection (pure — no Keychain access)

    func testNilPatternSelectsAllBatchKeys() {
        var batch = KeychainBatch()
        try? batch.add("v1", forKey: "cache_a")
        try? batch.add("v2", forKey: "auth_token")

        XCTAssertEqual(Set(batch.keysToDelete(matching: nil)), ["cache_a", "auth_token"])
    }

    func testEmptyPatternSelectsAllBatchKeys() {
        var batch = KeychainBatch()
        try? batch.add("v1", forKey: "cache_a")
        try? batch.add("v2", forKey: "auth_token")

        XCTAssertEqual(Set(batch.keysToDelete(matching: "")), ["cache_a", "auth_token"])
    }

    func testPrefixPatternSelectsOnlyMatchingBatchKeys() {
        var batch = KeychainBatch()
        try? batch.add("v1", forKey: "cache_a")
        try? batch.add("v2", forKey: "cache_b")
        try? batch.add("v3", forKey: "auth_token")

        XCTAssertEqual(Set(batch.keysToDelete(matching: "cache_")), ["cache_a", "cache_b"])
    }

    func testNonMatchingPatternSelectsNothing() {
        var batch = KeychainBatch()
        try? batch.add("v1", forKey: "cache_a")

        XCTAssertEqual(batch.keysToDelete(matching: "zzz"), [])
    }

    func testSelectionNeverIncludesForeignKeys() {
        var batch = KeychainBatch()
        try? batch.add("v1", forKey: "cache_a")

        // Even a pattern that would match arbitrary keychain keys can only
        // ever select keys this batch stored.
        XCTAssertTrue(batch.keysToDelete(matching: "").allSatisfy { $0 == "cache_a" })
    }

    // MARK: - Scoped deletion (real Keychain — macOS host)

    private func ensureKeychainAvailable() throws {
        let probeKey = "statekit_probe_\(UUID().uuidString)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: probeKey,
            kSecValueData as String: Data("probe".utf8),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw XCTSkip("Keychain unavailable in this environment (status \(status))")
        }
        SecItemDelete(query as CFDictionary)
    }

    private func retrieveRaw(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteRaw(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func testPatternScopedDeleteSparesForeignItems() throws {
        try ensureKeychainAvailable()
        let suffix = UUID().uuidString
        let cacheKeyA = "cache_a_\(suffix)"
        let cacheKeyB = "cache_b_\(suffix)"
        let foreignKey = "auth_token_\(suffix)"

        var batch = KeychainBatch()
        try batch.add("cache-a", forKey: cacheKeyA)
        try batch.add("cache-b", forKey: cacheKeyB)
        try batch.store()

        let foreign = KeychainStateProvider<String>(key: foreignKey)
        try foreign.store("secret")

        defer {
            deleteRaw(cacheKeyA)
            deleteRaw(cacheKeyB)
            deleteRaw(foreignKey)
        }

        // Sanity: both batch items actually reached the keychain.
        XCTAssertNotNil(retrieveRaw(cacheKeyA))
        XCTAssertNotNil(retrieveRaw(cacheKeyB))

        try batch.deleteAll(matching: "cache_")

        XCTAssertNil(retrieveRaw(cacheKeyA), "batch item matching pattern should be deleted")
        XCTAssertNil(retrieveRaw(cacheKeyB), "batch item matching pattern should be deleted")
        XCTAssertNotNil(retrieveRaw(foreignKey), "foreign item must survive a pattern-scoped delete")
        XCTAssertEqual(try foreign.retrieve(), "secret")
    }

    func testDeleteWithoutPatternRemovesOnlyBatchItems() throws {
        try ensureKeychainAvailable()
        let suffix = UUID().uuidString
        let cacheKey = "cache_a_\(suffix)"
        let foreignKey = "auth_token_\(suffix)"

        var batch = KeychainBatch()
        try batch.add("cache-a", forKey: cacheKey)
        try batch.store()

        let foreign = KeychainStateProvider<String>(key: foreignKey)
        try foreign.store("secret")

        defer { deleteRaw(cacheKey); deleteRaw(foreignKey) }

        try batch.deleteAll(matching: nil)

        XCTAssertNil(retrieveRaw(cacheKey))
        XCTAssertNotNil(retrieveRaw(foreignKey), "foreign item must survive a full batch delete")
    }

    func testNonMatchingPatternDeletesNothing() throws {
        try ensureKeychainAvailable()
        let suffix = UUID().uuidString
        let cacheKey = "cache_a_\(suffix)"

        var batch = KeychainBatch()
        try batch.add("cache-a", forKey: cacheKey)
        try batch.store()

        defer { deleteRaw(cacheKey) }

        // Sanity: the batch item actually reached the keychain.
        XCTAssertNotNil(retrieveRaw(cacheKey))

        try batch.deleteAll(matching: "zzz_")

        XCTAssertNotNil(retrieveRaw(cacheKey), "no batch item matches 'zzz_', nothing should be deleted")
    }
}
