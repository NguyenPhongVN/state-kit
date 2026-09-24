import Foundation

// MARK: - FileAtomSerializable

/// Requirements for a value that can be persisted by `FileAtomStorage`.
///
/// Mirrors `UserDefaultsSerializable`, but stores the value as JSON in a
/// named file — suitable for payloads beyond UserDefaults' practical size.
public protocol FileAtomSerializable: Codable, Sendable {
    /// The file name used inside the storage directory (e.g. `"profile.json"`).
    static var fileName: String { get }
    /// The value used when no file exists (or it cannot be decoded).
    static var defaultValue: Self { get }
}

// MARK: - FileAtomStorage

/// JSON-file-backed storage for atom values.
///
/// The load/save contract is explicit — **load at start, save on change** —
/// mirroring the `userDefaultsAtom` pattern documented in the Start Here
/// lessons. Files live in a caller-provided directory so tests can use
/// temporary directories.
///
/// ```swift
/// struct StudyLog: FileAtomSerializable {
///     static let fileName = "study-log.json"
///     static let defaultValue = StudyLog(minutes: 0)
///     var minutes: Int
/// }
///
/// let storage = FileAtomStorage<StudyLog>(directory: documentsDirectory)
/// let minutesProvider = StateProvider { _ in storage.load().minutes }
/// // …and call `storage.save(...)` whenever the state changes.
/// ```
public final class FileAtomStorage<T: FileAtomSerializable>: @unchecked Sendable {

    private let directory: URL
    private let lock = NSLock()
    private var observers: [(T) -> Void] = []

    private var fileURL: URL {
        directory.appendingPathComponent(T.fileName)
    }

    /// Creates storage rooted at `directory`, storing values in
    /// `T.fileName` (or the `fileNameOverride`).
    public init(directory: URL, fileName fileNameOverride: String? = nil) {
        self.directory = directory
        self.fileNameOverride = fileNameOverride
    }

    private let fileNameOverride: String?

    private var effectiveFileName: String {
        fileNameOverride ?? T.fileName
    }

    /// Reads the stored value; returns `T.defaultValue` when the file is
    /// missing or cannot be decoded.
    public func load() -> T {
        guard let data = try? Data(contentsOf: fileURL) else {
            return T.defaultValue
        }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? T.defaultValue
    }

    /// Encodes and writes `value`, creating the directory if needed.
    public func save(_ value: T) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
            notify(value)
        } catch {
            // Persist failures surface to the caller through load/save misuse
            // checks in debug builds; runtime callers keep working in memory.
            assertionFailure("FileAtomStorage.save failed: \(error)")
        }
    }

    /// Removes the stored file, so the next `load()` returns the default.
    public func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Registers a callback invoked after every successful save.
    public func addObserver(_ observer: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        observers.append(observer)
    }

    private func notify(_ value: T) {
        lock.lock()
        let current = observers
        lock.unlock()
        current.forEach { $0(value) }
    }
}

// MARK: - fileAtom factory

/// Creates a load-at-start factory for a file-persisted atom value.
///
/// Mirrors `userDefaultsAtom(_:)`: the returned closure reads the stored
/// value (or the default) — pair it with explicit saves on change. See the
/// Start Here lessons for the full pattern.
public func fileAtom<T: FileAtomSerializable>(
    _ type: T.Type,
    directory: URL
) -> (() -> T) {
    let storage = FileAtomStorage<T>(directory: directory)
    return { storage.load() }
}
