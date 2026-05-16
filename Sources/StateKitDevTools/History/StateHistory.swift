import Foundation

// MARK: - State History Protocol

/// Records and manages state history for time-travel debugging.
///
/// Allows developers to:
/// - Step backward/forward through state changes
/// - Replay state transitions
/// - Export/import action logs
/// - Inspect past state values
///
/// **Example Usage:**
/// ```swift
/// let history = container.stateHistory
/// history.record(action: "increment", before: oldState, after: newState, time: 2.5)
///
/// // Travel through time
/// history.goBack()      // Revert to previous state
/// history.goForward()   // Advance to next state
/// history.jumpTo(index: 5)
///
/// // Inspect history
/// for entry in history.entries {
///     print("\(entry.action): \(entry.computeTime)ms")
/// }
/// ```
///
/// **Thread Safety**: Not thread-safe. Use on main thread only.
public protocol StateHistory {
    /// All recorded history entries.
    var entries: [HistoryEntry] { get }

    /// Current position in history (0-based index).
    var currentIndex: Int { get }

    /// Whether there are entries before current position.
    var canGoBack: Bool { get }

    /// Whether there are entries after current position.
    var canGoForward: Bool { get }

    /// Records a state change event.
    ///
    /// - Parameters:
    ///   - action: The action that triggered the change (nil for external changes)
    ///   - before: The state before the change
    ///   - after: The state after the change
    ///   - computeTime: How long the computation took in milliseconds
    mutating func record(action: String?, before: AnyCodable, after: AnyCodable, computeTime: Double)

    /// Moves back one step in history.
    ///
    /// - Returns: The state at the previous position, or nil if at the beginning
    mutating func goBack() -> AnyCodable?

    /// Moves forward one step in history.
    ///
    /// - Returns: The state at the next position, or nil if at the end
    mutating func goForward() -> AnyCodable?

    /// Jumps to a specific index in history.
    ///
    /// - Parameter index: The target index (0-based)
    /// - Returns: The state at that index, or nil if index is out of bounds
    mutating func jumpTo(index: Int) -> AnyCodable?

    /// Clears all history entries.
    mutating func clear()

    /// Exports history as JSON for sharing/analysis.
    ///
    /// - Returns: JSON string representation of history
    func export() -> String

    /// Imports history from JSON.
    ///
    /// - Parameter json: JSON string to import
    /// - Returns: Success flag
    mutating func importJSON(_ json: String) -> Bool

    /// Returns the current state value.
    var currentState: AnyCodable? { get }

    /// Replays all actions from the beginning.
    func replay() async
}

// MARK: - History Entry

/// A single entry in state history.
public struct HistoryEntry: Codable, Sendable {
    /// Timestamp when the change occurred.
    public let timestamp: Date

    /// The action that triggered the change (nil for initialization or external changes).
    public let action: String?

    /// State before the change (as JSON-encodable value).
    public let stateBefore: JSONValue

    /// State after the change (as JSON-encodable value).
    public let stateAfter: JSONValue

    /// Time taken to compute the change in milliseconds.
    public let computeTime: Double

    /// Whether this entry is the currently active one.
    public var isActive: Bool = false

    public init(
        timestamp: Date,
        action: String?,
        stateBefore: JSONValue,
        stateAfter: JSONValue,
        computeTime: Double
    ) {
        self.timestamp = timestamp
        self.action = action
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
        self.computeTime = computeTime
    }
}

// MARK: - JSON Value (for encoding any state)

/// Type-erased JSON-encodable value for storing state in history.
public indirect enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode JSONValue"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .number(let number):
            try container.encode(number)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }

    /// Converts a Codable value to JSONValue.
    public static func from(_ value: Any) -> JSONValue? {
        do {
            let data = try JSONEncoder().encode(AnyCodable(value))
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - AnyCodable Type Eraser

/// Type-erased wrapper for any Codable value.
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if value is NSNull {
            try container.encodeNil()
        } else if let value = value as? Bool {
            try container.encode(value)
        } else if let value = value as? Int {
            try container.encode(value)
        } else if let value = value as? Double {
            try container.encode(value)
        } else if let value = value as? String {
            try container.encode(value)
        } else if let value = value as? [Any] {
            try container.encode(value.map { AnyCodable($0) })
        } else if let value = value as? [String: Any] {
            try container.encode(value.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Cannot encode \(type(of: value)) as AnyCodable"
                )
            )
        }
    }
}

// MARK: - Default Implementation

/// Default implementation of StateHistory with in-memory storage.
public struct InMemoryStateHistory: StateHistory {
    private(set) public var entries: [HistoryEntry] = []
    private(set) public var currentIndex: Int = -1

    /// Maximum number of entries to store (default: 100).
    public var maxEntries: Int = 100

    /// Whether to store state snapshots (can use significant memory).
    public var storeSnapshots: Bool = true

    public var canGoBack: Bool {
        currentIndex > 0
    }

    public var canGoForward: Bool {
        currentIndex < entries.count - 1
    }

    public var currentState: AnyCodable? {
        guard currentIndex >= 0, currentIndex < entries.count else { return nil }
        return AnyCodable(entries[currentIndex].stateAfter)
    }

    public mutating func record(
        action: String?,
        before: AnyCodable,
        after: AnyCodable,
        computeTime: Double
    ) {
        // Remove any entries after current position (they're now invalid due to new branch)
        if currentIndex < entries.count - 1 {
            entries = Array(entries.prefix(currentIndex + 1))
        }

        // Create new entry
        let entry = HistoryEntry(
            timestamp: Date(),
            action: action,
            stateBefore: JSONValue.from(before.value) ?? .null,
            stateAfter: JSONValue.from(after.value) ?? .null,
            computeTime: computeTime
        )

        entries.append(entry)
        currentIndex = entries.count - 1

        // Limit history size
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
            currentIndex = entries.count - 1
        }
    }

    public mutating func goBack() -> AnyCodable? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        return currentState
    }

    public mutating func goForward() -> AnyCodable? {
        guard canGoForward else { return nil }
        currentIndex += 1
        return currentState
    }

    public mutating func jumpTo(index: Int) -> AnyCodable? {
        guard index >= 0, index < entries.count else { return nil }
        currentIndex = index
        return currentState
    }

    public mutating func clear() {
        entries = []
        currentIndex = -1
    }

    public func export() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(entries)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }

    public mutating func importJSON(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }

        do {
            let decoder = JSONDecoder()
            entries = try decoder.decode([HistoryEntry].self, from: data)
            currentIndex = entries.count - 1
            return true
        } catch {
            return false
        }
    }

    public func replay() async {
        // Implementation for replaying actions
        // This would typically re-execute stored actions
        for entry in entries {
            // Simulate replay delay
            try? await Task.sleep(nanoseconds: UInt64(entry.computeTime * 1_000_000))
        }
    }
}
