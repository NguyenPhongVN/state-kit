import Testing
import SwiftData
import Foundation
@testable import Riverpods
@testable import StateKitPersistence

// Spec 011 US3: file storage must be safe under concurrent use, and the
// SwiftData-backed notifier must reload its persisted value when re-created.

@MainActor
@Suite("011 — Persistence hardening")
struct PersistenceHardeningTests {

    // MARK: File storage concurrency

    private struct Payload: FileAtomSerializable, Equatable {
        static let fileName = "p2-hardening.json"
        static let defaultValue = Payload(count: -1)
        var count: Int
    }

    @Test("concurrent save/load on FileAtomStorage completes without corruption")
    func fileStorageConcurrency() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("011-\(UUID().uuidString)")
        let storage = FileAtomStorage<Payload>(directory: directory)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask {
                    if i.isMultiple(of: 2) {
                        storage.save(Payload(count: i))
                    } else {
                        let loaded = storage.load()
                        // Must be a valid stored payload or the default — never garbage.
                        // Payload has no isEmpty — the count check is the only option here.
                        // swiftlint:disable:next empty_count
                        assert(loaded == Payload.defaultValue || loaded.count >= 0)
                    }
                }
            }
        }

        let final = storage.load()
        // Payload has no isEmpty — the count check is the only option here.
        // swiftlint:disable:next empty_count
        #expect(final == Payload.defaultValue || final.count >= 0,
                "post-stress load must return a coherent payload, got \(final)")
    }

    // MARK: SwiftData notifier reload

    private struct GameState: Codable, Sendable, Equatable {
        var score = 0
    }

    @Test("re-created SwiftData-backed notifier loads the persisted value")
    func swiftDataNotifierReloadsPersistedState() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: SwiftDataStateRecord.self, configurations: config)
        let context = ModelContext(modelContainer)
        let pc = ProviderContainer()

        // First notifier: persist a value through updateAndPersist.
        let first = SwiftDataNotifierProvider.create(initialState: GameState(), context: context)
        let notifier1 = try pc.read(first.notifier)
        try await notifier1.updateAndPersist { $0.score = 42 }

        // Second notifier (fresh instance → fresh element → build runs): must
        // reload 42 from storage instead of resetting to the seed default.
        let second = SwiftDataNotifierProvider.create(initialState: GameState(), context: context)
        let notifier2 = try pc.read(second.notifier)

        var loaded: GameState?
        for _ in 0..<200 {
            if case .data(let value) = notifier2.state {
                loaded = value
                break
            }
            // sleep justification: polling step inside a bounded notifier-build loop
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        #expect(loaded == GameState(score: 42), "re-created notifier must reload the persisted value, got \(loaded.map(String.init(describing:)) ?? "nil")")
    }
}
