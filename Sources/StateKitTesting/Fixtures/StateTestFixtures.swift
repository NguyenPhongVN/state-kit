import Foundation

// MARK: - Test Fixtures Protocol

/// Protocol for generating test data and fixtures.
///
/// Use fixtures to create consistent, repeatable test data without manual construction.
///
/// **Example:**
/// ```swift
/// let userFixture = UserFixture()
/// let user = userFixture.create(name: "John", email: "john@example.com")
/// ```
public protocol StateTestFixture {
    associatedtype FixtureType: Sendable

    /// Creates a fixture with default values.
    func create() -> FixtureType

    /// Creates a fixture with custom values.
    func create(with builder: (inout FixtureBuilder<FixtureType>) -> Void) -> FixtureType
}

// MARK: - Fixture Builder

/// Builder for constructing test fixtures with custom values.
///
/// Provides a fluent API for creating test data.
public struct FixtureBuilder<T: Sendable> {
    private var values: [String: Any] = [:]

    public mutating func set<V: Sendable>(_ key: String, to value: V) {
        values[key] = value
    }

    public func build() -> [String: Any] {
        values
    }
}

// MARK: - Common Test Data Generators

/// Generator for creating test state values.
public struct StateGenerator {
    /// Generates random integers.
    public static func randomInt(min: Int = 0, max: Int = 100) -> Int {
        Int.random(in: min...max)
    }

    /// Generates random doubles.
    public static func randomDouble(min: Double = 0, max: Double = 100) -> Double {
        Double.random(in: min...max)
    }

    /// Generates random strings.
    public static func randomString(length: Int = 10) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    /// Generates random boolean.
    public static func randomBool() -> Bool {
        Bool.random()
    }

    /// Generates random date within range.
    public static func randomDate(
        startDate: Date = Date(timeIntervalSince1970: 0),
        endDate: Date = Date()
    ) -> Date {
        let timeInterval = endDate.timeIntervalSince(startDate)
        let randomInterval = TimeInterval.random(in: 0...timeInterval)
        return startDate.addingTimeInterval(randomInterval)
    }

    /// Generates array of random values.
    public static func randomArray<T>(
        count: Int = 5,
        generator: () -> T
    ) -> [T] {
        (0..<count).map { _ in generator() }
    }
}

// MARK: - Test Data Builders

/// Builder for creating test data with a fluent API.
///
/// **Example:**
/// ```swift
/// let user = TestDataBuilder<User>()
///     .set(\.name, to: "John")
///     .set(\.email, to: "john@example.com")
///     .build()
/// ```
public struct TestDataBuilder<T: Sendable> {
    private var modifications: [(inout T) -> Void] = []
    private let base: T

    public init(base: T) {
        self.base = base
    }

    /// Sets a property using a key path.
    public mutating func set<V: Sendable>(_ keyPath: WritableKeyPath<T, V>, to value: V) -> Self {
        var copy = self
        copy.modifications.append { instance in
            instance[keyPath: keyPath] = value
        }
        return copy
    }

    /// Applies custom modifications.
    public mutating func modify(_ closure: @escaping (inout T) -> Void) -> Self {
        var copy = self
        copy.modifications.append(closure)
        return copy
    }

    /// Builds the final test data.
    public func build() -> T {
        var result = base
        modifications.forEach { $0(&result) }
        return result
    }
}

// MARK: - Fixture Collections

/// Collection of pre-built test fixtures for common scenarios.
public struct CommonFixtures {
    /// Creates a minimal/empty state.
    public static func minimal<T>() -> T? where T: Sendable {
        // Override in specific fixture implementations
        nil
    }

    /// Creates a typical/average state.
    public static func typical<T>() -> T? where T: Sendable {
        nil
    }

    /// Creates a maximal/complex state.
    public static func maximal<T>() -> T? where T: Sendable {
        nil
    }

    /// Creates a state with edge cases.
    public static func edgeCase<T>() -> T? where T: Sendable {
        nil
    }

    /// Creates a state representing an error condition.
    public static func errorState<T>() -> T? where T: Sendable {
        nil
    }
}

// MARK: - Snapshot Fixtures

/// Captures and validates state snapshots for snapshot testing.
///
/// Useful for detecting unintended state changes.
public struct StateSnapshot<T: Sendable & Codable> {
    /// The snapshot data.
    public let data: T

    /// When the snapshot was taken.
    public let timestamp: Date

    /// Description of the snapshot.
    public let description: String

    public init(
        data: T,
        description: String = ""
    ) {
        self.data = data
        self.timestamp = Date()
        self.description = description
    }

    /// Encodes snapshot to JSON for file comparison.
    public func encodeToJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(data)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    /// Decodes snapshot from JSON.
    public static func decodeFromJSON(_ json: String) throws -> StateSnapshot<T> {
        let decoder = JSONDecoder()
        let data = try decoder.decode(T.self, from: Data(json.utf8))
        return StateSnapshot(data: data, description: "Decoded from JSON")
    }
}

// MARK: - Fixture Registration

/// Registry for managing test fixtures across a test suite.
///
/// **Usage:**
/// ```swift
/// let registry = FixtureRegistry()
/// registry.register("default_user") { UserFixture().create() }
/// let user = registry.get("default_user")
/// ```
public class FixtureRegistry {
    private var fixtures: [String: Any] = [:]

    public init() {}

    /// Registers a fixture with a key.
    public func register<T: Sendable>(_ key: String, fixture: @escaping () -> T) {
        fixtures[key] = fixture
    }

    /// Retrieves a registered fixture.
    public func get<T: Sendable>(_ key: String) -> T? {
        (fixtures[key] as? () -> T)?()
    }

    /// Lists all registered fixture keys.
    public func allKeys() -> [String] {
        Array(fixtures.keys)
    }

    /// Clears all fixtures.
    public func clear() {
        fixtures.removeAll()
    }
}

// MARK: - Parameterized Fixtures

/// Generator for creating multiple fixture variations.
///
/// **Example:**
/// ```swift
/// let variations = ParameterizedFixture<User>(
///     parameters: [
///         ("admin", User(role: .admin)),
///         ("user", User(role: .user)),
///         ("guest", User(role: .guest))
///     ]
/// )
/// for (name, user) in variations.all() { ... }
/// ```
public struct ParameterizedFixture<T: Sendable> {
    private let parameters: [(String, T)]

    public init(parameters: [(String, T)]) {
        self.parameters = parameters
    }

    /// Gets a fixture by parameter name.
    public func get(_ name: String) -> T? {
        parameters.first { $0.0 == name }?.1
    }

    /// Returns all fixtures as key-value pairs.
    public func all() -> [(String, T)] {
        parameters
    }

    /// Maps over all fixtures.
    public func map<U>(_ transform: (String, T) -> U) -> [U] {
        parameters.map(transform)
    }

    /// Filters fixtures by predicate.
    public func filter(_ predicate: (String, T) -> Bool) -> [(String, T)] {
        parameters.filter(predicate)
    }
}

// MARK: - Factory Functions

/// Helper functions for common fixture patterns.
public struct FixtureFactory {
    /// Creates a sequence of test values.
    public static func sequence<T: Sendable>(
        start: T,
        count: Int,
        increment: (inout T) -> Void
    ) -> [T] {
        var results: [T] = []
        var current = start

        for _ in 0..<count {
            results.append(current)
            increment(&current)
        }

        return results
    }

    /// Creates test values with varying conditions.
    public static func conditions<T: Sendable>(
        base: T,
        conditions: [(String, (inout T) -> Void)]
    ) -> [(String, T)] {
        conditions.map { name, modifier in
            var copy = base
            modifier(&copy)
            return (name, copy)
        }
    }

    /// Creates a combination of multiple fixture dimensions.
    public static func cartesianProduct<A: Sendable, B: Sendable>(
        _ aValues: [A],
        _ bValues: [B]
    ) -> [(A, B)] {
        aValues.flatMap { a in
            bValues.map { b in (a, b) }
        }
    }

    /// Creates weighted random selections.
    public static func weightedRandom<T: Sendable>(
        choices: [(value: T, weight: Int)]
    ) -> T {
        let totalWeight = choices.reduce(0) { $0 + $1.weight }
        var random = Int.random(in: 0..<totalWeight)

        for choice in choices {
            random -= choice.weight
            if random < 0 {
                return choice.value
            }
        }

        return choices.last!.value
    }
}

// MARK: - Fixture Assertions

/// Helper assertions for fixture-based tests.
public struct FixtureAssertion {
    /// Asserts that two fixtures produce equivalent results.
    public static func assertEqual<T: Equatable & Sendable>(
        _ lhs: T,
        _ rhs: T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard lhs == rhs else {
            fatalError(
                "Fixture assertion failed: values are not equal\nExpected: \(rhs)\nActual: \(lhs)",
                file: file,
                line: line
            )
        }
    }

    /// Asserts that fixture satisfies a condition.
    public static func assert<T: Sendable>(
        _ fixture: T,
        _ condition: (T) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard condition(fixture) else {
            fatalError(
                "Fixture assertion failed: condition not satisfied",
                file: file,
                line: line
            )
        }
    }
}
