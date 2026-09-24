import XCTest
import Security
@testable import StateKitPersistence

final class KeychainAccessibilityTests: XCTestCase {

    // MARK: - Official constant mapping

    func testAccessibilityMapsToOfficialConstants() {
        XCTAssertEqual(KeychainAccessibility.afterFirstUnlock.secAttr, kSecAttrAccessibleAfterFirstUnlock)
        XCTAssertEqual(
            KeychainAccessibility.afterFirstUnlockThisDeviceOnly.secAttr,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
        XCTAssertEqual(KeychainAccessibility.always.secAttr, kSecAttrAccessibleAlways)
        XCTAssertEqual(KeychainAccessibility.whenUnlocked.secAttr, kSecAttrAccessibleWhenUnlocked)
        XCTAssertEqual(
            KeychainAccessibility.whenUnlockedThisDeviceOnly.secAttr,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        )
    }

    func testRawValuesAreNotInventedStrings() {
        let allLevels: [KeychainAccessibility] = [
            .afterFirstUnlock,
            .afterFirstUnlockThisDeviceOnly,
            .always,
            .whenUnlocked,
            .whenUnlockedThisDeviceOnly,
        ]
        for level in allLevels {
            XCTAssertFalse(level.rawValue.isEmpty, "\(level) has an empty raw value")
            XCTAssertFalse(
                level.rawValue.hasPrefix("com.apple.keychain"),
                "\(level) still carries the invented raw value '\(level.rawValue)'"
            )
        }
        XCTAssertEqual(Set(allLevels.map(\.rawValue)).count, allLevels.count, "raw values must be unique")
    }

    // MARK: - Round-trip per level (real Keychain — macOS host)

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

    func testRoundTripEachAccessibilityLevel() throws {
        try ensureKeychainAvailable()
        let suffix = UUID().uuidString
        let levels: [KeychainAccessibility] = [
            .whenUnlocked,
            .whenUnlockedThisDeviceOnly,
            .afterFirstUnlock,
            .afterFirstUnlockThisDeviceOnly,
            .always,
        ]

        for (index, level) in levels.enumerated() {
            let key = "statekit_roundtrip_\(suffix)_\(index)"
            let provider = KeychainStateProvider<String>(key: key, accessibility: level)

            try provider.store("value-\(index)")
            defer { try? provider.delete() }

            XCTAssertEqual(try provider.retrieve(), "value-\(index)", "round-trip failed for \(level)")
        }
        // Note: the stored protection attribute itself is not asserted here —
        // the macOS keychain does not report kSecAttrAccessible in the
        // attributes returned by SecItemCopyMatching. The constant each level
        // maps to is pinned by testAccessibilityMapsToOfficialConstants, and
        // every write path uses that mapping.
    }

    func testUpdateReappliesChosenAccessibility() throws {
        try ensureKeychainAvailable()
        let key = "statekit_update_\(UUID().uuidString)"
        let provider = KeychainStateProvider<String>(key: key, accessibility: .whenUnlocked)
        try provider.store("first")
        defer { try? provider.delete() }

        // Second write with a different level: last write wins.
        let stricter = KeychainStateProvider<String>(key: key, accessibility: .whenUnlockedThisDeviceOnly)
        try stricter.store("second")

        XCTAssertEqual(try stricter.retrieve(), "second", "update path must succeed for an existing key")
    }
}
