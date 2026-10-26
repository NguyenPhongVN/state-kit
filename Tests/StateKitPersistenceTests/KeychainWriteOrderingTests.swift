import Testing
import Foundation
@testable import StateKitPersistence

// Spec 008 US9: Keychain writes must never destroy the previous secret on
// failure, and in-memory state must commit only after a successful store.
//
// Failure injection uses internal test seams (`_storeOverride` /
// `_writeOverride`) so the real SecItem path stays untouched in production.
// Reads go through the real Keychain so the test proves the previous value
// physically survives.

@MainActor
@Suite("Keychain Write Ordering — P1 fixes")
struct KeychainWriteOrderingTests {

    private func uniqueKey(_ label: String) -> String {
        "statekit-tests-p1-\(label)-\(UUID().uuidString)"
    }

    @Test("updateValue commits state only after a successful store")
    func updateValueCommitOrder() throws {
        var provider = KeychainStateProvider<[String: String]>(key: uniqueKey("notifier"))
        defer { try? provider.delete() }

        let override = KeychainStateProvider<[String: String]>._StoreOverrideBox()
        provider._storeOverride = override

        // A successful first update materializes the notifier's state
        // (Notifier.state traps before first attachment — separate finding).
        try provider.store(["stage": "A"])
        let notifier = KeychainNotifier(provider: provider, initial: [:])
        try notifier.updateValue(["stage": "A"])
        #expect(notifier.state == ["stage": "A"])

        override.handler = {
            throw KeychainError.storeFailed(errSecIO)
        }
        #expect(throws: KeychainError.self) {
            try notifier.updateValue(["stage": "B"])
        }
        #expect(notifier.state == ["stage": "A"],
                "state committed before the store failed — memory and Keychain diverge")
        #expect(try provider.retrieve() == ["stage": "A"])

        override.handler = nil
        try notifier.updateValue(["stage": "B"])
        #expect(notifier.state == ["stage": "B"])
        #expect(try provider.retrieve() == ["stage": "B"])
    }

    @Test("failed batch item leaves the previous secret readable")
    func batchFailurePreservesPreviousValue() throws {
        let key = uniqueKey("batch")
        let reader = KeychainStateProvider<String>(key: key)
        defer { try? reader.delete() }

        // Establish a previous value through the (safe) single-item path.
        try reader.store("previous-secret")

        var batch = KeychainBatch()
        try batch.add("new-secret", forKey: key)
        batch._writeOverride = { _, _, _ in errSecIO }

        #expect(throws: KeychainError.self) {
            try batch.store()
        }

        #expect(try reader.retrieve() == "previous-secret",
                "delete-then-add destroyed the previous secret when the re-add failed")
    }

    @Test("successful batch store replaces values")
    func batchSuccessReplaces() throws {
        let key = uniqueKey("batch-success")
        let reader = KeychainStateProvider<String>(key: key)
        defer { try? reader.delete() }

        try reader.store("old")
        var batch = KeychainBatch()
        try batch.add("new", forKey: key)
        try batch.store()

        #expect(try reader.retrieve() == "new")
    }
}
