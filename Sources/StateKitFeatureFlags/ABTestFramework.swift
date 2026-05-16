import Foundation

// MARK: - A/B Testing Framework

/// A/B test variant definition.
public struct ABTestVariant<T: Sendable>: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let value: T

    public init(id: String, name: String, description: String = "", value: T) {
        self.id = id
        self.name = name
        self.description = description
        self.value = value
    }
}

/// A/B test experiment.
public struct ABTest<T: Sendable>: Sendable {
    public let id: String
    public let name: String
    public let variants: [ABTestVariant<T>]
    public let trafficPercentage: Int
    public let userKey: (String) -> String
    public let isActive: Bool

    public init(
        id: String,
        name: String,
        variants: [ABTestVariant<T>],
        trafficPercentage: Int = 100,
        userKey: @escaping (String) -> String = { $0 },
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.variants = variants
        self.trafficPercentage = max(0, min(100, trafficPercentage))
        self.userKey = userKey
        self.isActive = isActive
    }

    /// Assigns user to variant (deterministic based on user ID).
    public func assignUser(_ userId: String) -> ABTestVariant<T>? {
        guard isActive else { return nil }

        let key = userKey(userId)
        let hash = hashString(key)
        let assigned = hash % 100

        guard assigned < trafficPercentage else { return nil }

        let variantIndex = (assigned / (trafficPercentage / variants.count))
        return variants[min(variantIndex, variants.count - 1)]
    }

    /// Gets assigned variant for user.
    public func variant(for userId: String) -> ABTestVariant<T>? {
        assignUser(userId)
    }

    /// Checks if user is in control group.
    public func isInControl(_ userId: String) -> Bool {
        variant(for: userId)?.id == "control"
    }

    /// Checks if user is in treatment group.
    public func isInTreatment(_ userId: String) -> Bool {
        variant(for: userId)?.id == "treatment"
    }

    private func hashString(_ str: String) -> Int {
        var hash = 5381
        for char in str {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        return abs(hash)
    }
}

// MARK: - A/B Test Runner

/// Runs A/B test and collects results.
@MainActor
public final class ABTestRunner<T: Sendable>: Sendable {
    public struct Result: Sendable {
        public let testId: String
        public let userId: String
        public let variant: ABTestVariant<T>
        public let timestamp: Date
        public let conversionValue: Double?

        public init(
            testId: String,
            userId: String,
            variant: ABTestVariant<T>,
            conversionValue: Double? = nil
        ) {
            self.testId = testId
            self.userId = userId
            self.variant = variant
            self.timestamp = Date()
            self.conversionValue = conversionValue
        }
    }

    private var results: [Result] = []
    private let test: ABTest<T>

    public init(test: ABTest<T>) {
        self.test = test
    }

    /// Records user assignment.
    public func recordAssignment(_ userId: String, variant: ABTestVariant<T>) {
        results.append(Result(testId: test.id, userId: userId, variant: variant))
    }

    /// Records conversion.
    public func recordConversion(_ userId: String, variant: ABTestVariant<T>, value: Double = 1.0) {
        results.append(Result(testId: test.id, userId: userId, variant: variant, conversionValue: value))
    }

    /// Gets results for variant.
    public func results(for variantId: String) -> [Result] {
        results.filter { $0.variant.id == variantId }
    }

    /// Gets all results.
    public var allResults: [Result] {
        results
    }

    /// Calculates conversion rate for variant.
    public func conversionRate(for variantId: String) -> Double {
        let variantResults = results(for: variantId)
        let conversions = variantResults.filter { $0.conversionValue != nil }.count
        return variantResults.isEmpty ? 0 : Double(conversions) / Double(variantResults.count)
    }

    /// Gets test report.
    public func report() -> String {
        var report = "A/B Test Report: \(test.name)\n"
        report += "===============\n\n"

        for variant in test.variants {
            let variantResults = results(for: variant.id)
            let conversionRate = conversionRate(for: variant.id)

            report += "Variant: \(variant.name)\n"
            report += "  Users: \(variantResults.count)\n"
            report += "  Conversion Rate: \(String(format: "%.1f", conversionRate * 100))%\n\n"
        }

        return report
    }

    /// Clears results.
    public func clearResults() {
        results.removeAll()
    }
}

// MARK: - A/B Test Manager

/// Manages multiple A/B tests.
@MainActor
public final class ABTestManager: Sendable {
    private var tests: [String: Any] = [:]
    private var runners: [String: Any] = [:]

    public init() {}

    /// Registers A/B test.
    public func register<T: Sendable>(_ test: ABTest<T>) {
        tests[test.id] = test
        runners[test.id] = ABTestRunner(test: test)
    }

    /// Gets test by ID.
    public func test<T: Sendable>(_ id: String, type: T.Type) -> ABTest<T>? {
        tests[id] as? ABTest<T>
    }

    /// Gets test runner.
    public func runner<T: Sendable>(_ testId: String, type: T.Type) -> ABTestRunner<T>? {
        runners[testId] as? ABTestRunner<T>
    }

    /// Gets all test IDs.
    public var testIds: [String] {
        Array(tests.keys)
    }
}

// MARK: - Statistical Testing

/// Helper for statistical significance testing.
public struct StatisticalTest {
    /// Chi-square test for variant conversion rates.
    public static func chiSquareTest(
        variantA: (successes: Int, total: Int),
        variantB: (successes: Int, total: Int)
    ) -> Double {
        let n = variantA.total + variantB.total
        let pA = Double(variantA.successes) / Double(variantA.total)
        let pB = Double(variantB.successes) / Double(variantB.total)
        let p = Double(variantA.successes + variantB.successes) / Double(n)

        let expected_A = Double(variantA.total) * p
        let expected_B = Double(variantB.total) * p

        let chi2 = pow(Double(variantA.successes) - expected_A, 2) / expected_A +
                   pow(Double(variantB.successes) - expected_B, 2) / expected_B

        return chi2
    }

    /// Checks if result is statistically significant (p < 0.05).
    public static func isSignificant(_ chiSquareValue: Double) -> Bool {
        chiSquareValue > 3.841  // Critical value for p=0.05
    }
}
