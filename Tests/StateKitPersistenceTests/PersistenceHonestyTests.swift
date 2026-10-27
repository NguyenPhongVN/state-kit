import Testing
import Foundation
@testable import StateKitPersistence

// Spec 009 US4: persistence honesty — throwing saves, error surfacing,
// corruption hook, versioned migration, keychain namespace.

@MainActor
@Suite("Persistence Honesty — 009 US4")
struct PersistenceHonestyTests {

    private struct IntBox: UserDefaultsSerializable, Equatable {
        static let userDefaultsKey = "009-intbox"
        static var defaultValue: IntBox { IntBox() }
        var value: Int = 0
    }

    private func uniqueKey(_ label: String) -> String {
        "statekit-009-\(label)-\(UUID().uuidString)"
    }

    @Test("changes() streams saved values (old observeChanges always returned [])")
    func changesStreams() async throws {
        let storage = PersistentAtomStorage<IntBox>(type: IntBox.self, userDefaultsKey: uniqueKey("stream"))
        let stream = storage.changes()
        var received: [IntBox] = []

        let task = Task {
            for await value in stream {
                received.append(value)
                if received.count == 2 { break }
            }
        }
        try await Task.sleep(for: .milliseconds(50))
        try storage.save(IntBox(value: 1))
        try storage.save(IntBox(value: 2))
        _ = await task.result

        #expect(received == [IntBox(value: 1), IntBox(value: 2)])
    }

    @Test("migration records its schema version only after success")
    func migrationRecordsVersion() throws {
        let key = uniqueKey("migrate")
        let storage = PersistentAtomStorage<IntBox>(type: IntBox.self, userDefaultsKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key + ".schemaVersion") }

        try storage.save(IntBox(value: 5))
        let migration = PersistenceMigration(storage: storage, version: 3)
        #expect(migration.needsMigration())

        try migration.migrate { $0.value += 1 }
        #expect(storage.load() == IntBox(value: 6))
        #expect(migration.persistedVersion == 3)
        #expect(!migration.needsMigration())

        // Second run is a no-op (no silent re-migration).
        try migration.migrate { $0.value += 100 }
        #expect(storage.load() == IntBox(value: 6))
    }

    @Test("keychain decode failures throw decodingFailed and notifier surfaces load errors")
    func keychainErrorSurfacing() throws {
        // Raw non-JSON data under a key -> decode failure must be surfaced.
        let key = uniqueKey("decode")
        var rawQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "state-kit",
            kSecAttrAccount as String: key,
        ]
        rawQuery[kSecValueData as String] = Data("not-json".utf8)
        SecItemDelete(rawQuery as CFDictionary)
        defer { SecItemDelete(rawQuery as CFDictionary) }
        let status = SecItemAdd(rawQuery as CFDictionary, nil)
        #expect(status == errSecSuccess)

        let provider = KeychainStateProvider<IntBox>(key: key)
        var threwDecoding = false
        do {
            _ = try provider.retrieve()
        } catch let error as KeychainError {
            threwDecoding = true
            if case .decodingFailed = error {} else { threwDecoding = false }
        } catch {}
        #expect(threwDecoding, "decode failure surfaced as a different error (or none)")

        // The notifier records the load error instead of silently substituting
        // the initial value.
        let notifier = KeychainNotifier(provider: provider, initial: IntBox(value: -1))
        _ = notifier.build()
        #expect(notifier.lastLoadError != nil,
                "keychain load failure was silently swallowed into the initial value")
    }

    @Test("keychain service namespaces isolate same-account items")
    func keychainServiceNamespaces() throws {
        let key = uniqueKey("ns")
        let a = KeychainStateProvider<IntBox>(key: key, service: "svc-a")
        let b = KeychainStateProvider<IntBox>(key: key, service: "svc-b")
        defer { try? a.delete(); try? b.delete() }

        try a.store(IntBox(value: 1))
        try b.store(IntBox(value: 2))

        #expect(try a.retrieve() == IntBox(value: 1), "same account key across services collided")
        #expect(try b.retrieve() == IntBox(value: 2))
    }

    @Test("fileAtom corruption hook fires and loads are cached")
    func fileAtomCorruptionAndCache() throws {
        struct Payload: FileAtomSerializable, Equatable {
            static let fileName = "009-corrupt-\(UUID().uuidString).json"
            var value: Int = 0
            static let defaultValue = Payload()
            init(value: Int = 0) { self.value = value }
            func encode(to encoder: any Encoder) throws {
                var c = encoder.singleValueContainer(); try c.encode(value)
            }
            init(from decoder: any Decoder) throws {
                let c = try decoder.singleValueContainer(); value = try c.decode(Int.self)
            }
        }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("009-fileatom")
        let storage = FileAtomStorage<Payload>(directory: dir, fileName: Payload.fileName)
        let corruptHits = LockedCounter()
        storage.onCorruption = { _ in corruptHits.hit() }

        // Write garbage directly to the file.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(Payload.fileName)
        try Data("{{{not json".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(storage.load() == Payload.defaultValue, "corrupt file must fall back to default")
        #expect(corruptHits.count == 1, "onCorruption never fired on decode failure")

        // Loads are cached: repeated reads do not re-trigger the hook.
        _ = storage.load()
        #expect(corruptHits.count == 1)
    }
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func hit() { lock.lock(); n += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
}
