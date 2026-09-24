import XCTest
import StateKitPersistence

final class FileAtomTests: XCTestCase {

    private var tempDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("statekit-fileatom-\(UUID().uuidString)")
    }

    private struct Theme: FileAtomSerializable {
        static let fileName = "theme.json"
        static let defaultValue = Theme(mode: "light", accent: "blue")
        var mode: String
        var accent: String
    }

    func testLoadFallsBackToDefaultWhenFileMissing() {
        let storage = FileAtomStorage<Theme>(directory: tempDirectory)

        let loaded = storage.load()

        XCTAssertEqual(loaded.mode, "light")
        XCTAssertEqual(loaded.accent, "blue")
    }

    func testSaveThenLoadRoundTrips() {
        let directory = tempDirectory
        let storage = FileAtomStorage<Theme>(directory: directory)

        storage.save(Theme(mode: "dark", accent: "purple"))
        let reloaded = FileAtomStorage<Theme>(directory: directory).load()

        XCTAssertEqual(reloaded.mode, "dark")
        XCTAssertEqual(reloaded.accent, "purple")
    }

    func testLoadFallsBackToDefaultOnCorruptFile() {
        let directory = tempDirectory
        let storage = FileAtomStorage<Theme>(directory: directory)

        storage.save(Theme(mode: "dark", accent: "purple"))
        // Corrupt the file directly.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? "{ not json".write(to: directory.appendingPathComponent(Theme.fileName), atomically: true, encoding: .utf8)

        let loaded = storage.load()

        XCTAssertEqual(loaded.mode, "light", "corrupt file must fall back to the default")
        // And the next save repairs it.
        storage.save(Theme(mode: "dark", accent: "purple"))
        XCTAssertEqual(storage.load().mode, "dark")
    }

    func testDeleteRemovesFile() {
        let directory = tempDirectory
        let storage = FileAtomStorage<Theme>(directory: directory)

        storage.save(Theme(mode: "dark", accent: "purple"))
        storage.delete()

        XCTAssertEqual(storage.load().mode, "light")
    }

    func testFileAtomFactoryLoadsStoredValue() {
        let directory = tempDirectory
        let storage = FileAtomStorage<Theme>(directory: directory)
        storage.save(Theme(mode: "oled", accent: "teal"))
        defer { storage.delete() }

        let loader = fileAtom(Theme.self, directory: directory)

        XCTAssertEqual(loader().mode, "oled")
    }
}
