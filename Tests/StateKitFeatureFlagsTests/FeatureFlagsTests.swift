import XCTest
import Testing
@testable import StateKitFeatureFlags

@MainActor
final class FeatureFlagsTests: XCTestCase {
    // MARK: - Feature Flag Registry Tests

    func testFlagRegistration() {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(id: "test_flag", name: "Test Flag", defaultValue: false)

        registry.register(flag)
        XCTAssertFalse(registry.value(for: flag))
    }

    func testFlagOverride() {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(id: "test_flag", name: "Test Flag", defaultValue: false)

        registry.register(flag)
        registry.setOverride(flag, value: true)

        XCTAssertTrue(registry.value(for: flag))
    }

    func testFlagOverrideClear() {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(id: "test_flag", name: "Test Flag", defaultValue: false)

        registry.register(flag)
        registry.setOverride(flag, value: true)
        registry.clearOverride(flag.id)

        XCTAssertFalse(registry.value(for: flag))
    }

    // MARK: - A/B Test Assignment Tests

    func testABTestDeterministicAssignment() {
        let variant1 = ABTestVariant(id: "control", name: "Control", value: 1)
        let variant2 = ABTestVariant(id: "treatment", name: "Treatment", value: 2)
        let test = ABTest(id: "test", name: "Test", variants: [variant1, variant2])

        let assignment1 = test.assignUser("user123")
        let assignment2 = test.assignUser("user123")

        XCTAssertEqual(assignment1?.id, assignment2?.id)  // Same user, same variant
    }

    func testABTestDifferentUsers() {
        let variant1 = ABTestVariant(id: "control", name: "Control", value: false)
        let variant2 = ABTestVariant(id: "treatment", name: "Treatment", value: true)
        let test = ABTest(id: "test", name: "Test", variants: [variant1, variant2])

        let assignment1 = test.assignUser("user1")
        let assignment2 = test.assignUser("user2")

        // Different users may get different variants
        _ = assignment1
        _ = assignment2
    }

    // MARK: - Rollout Strategy Tests

    func testPercentageRollout() {
        let rollout = PercentageRollout(percentage: 50)

        var enabledCount = 0
        for i in 0..<10_000 {
            if rollout.isEnabled(for: "user\(i)") {
                enabledCount += 1
            }
        }

        // Should be roughly 50% (allow ±5 percentage points — a 100-user
        // sample is too small for a deterministic hash to bound this tightly).
        XCTAssertGreaterThan(enabledCount, 4_500)
        XCTAssertLessThan(enabledCount, 5_500)
    }

    func testCohortRollout() {
        let rollout = CohortRollout(cohorts: ["user1", "user2", "user3"])

        XCTAssertTrue(rollout.isEnabled(for: "user1"))
        XCTAssertTrue(rollout.isEnabled(for: "user2"))
        XCTAssertFalse(rollout.isEnabled(for: "user99"))
    }

    func testTimeBasedRollout() {
        let start = Date()
        let end = Date().addingTimeInterval(3600)
        let rollout = TimeBasedRollout(percentage: 100, startDate: start, endDate: end)

        XCTAssertTrue(rollout.isEnabled(for: "user1"))
    }

    func testTimeBasedRolloutBefore() {
        let start = Date().addingTimeInterval(3600)  // 1 hour in future
        let rollout = TimeBasedRollout(percentage: 100, startDate: start)

        XCTAssertFalse(rollout.isEnabled(for: "user1"))
    }

    func testCanaryRollout() {
        let start = Date().addingTimeInterval(-100)  // 100 seconds ago
        let end = start.addingTimeInterval(1000)     // 1000 seconds duration
        let canary = CanaryRollout(
            startPercentage: 0,
            endPercentage: 100,
            startDate: start,
            endDate: end
        )

        // Should be partway through rollout
        let percentage = canary.percentage
        XCTAssertGreaterThan(percentage, 0)
        XCTAssertLessThan(percentage, 100)
    }

    // MARK: - Rollout Manager Tests

    func testRolloutManagerRegistration() {
        let manager = RolloutManager()
        let rollout = PercentageRollout(percentage: 100)

        manager.register(rollout, for: "feature1")
        XCTAssertTrue(manager.isEnabled("feature1", for: "user1"))
    }

    func testRolloutManagerMultipleRollouts() {
        let manager = RolloutManager()
        let percentageRollout = PercentageRollout(percentage: 100)
        let cohortRollout = CohortRollout(cohorts: ["user1"])

        manager.register(percentageRollout, for: "feature1")
        manager.register(cohortRollout, for: "feature2")

        XCTAssertTrue(manager.isEnabled("feature1", for: "any_user"))
        XCTAssertTrue(manager.isEnabled("feature2", for: "user1"))
        XCTAssertFalse(manager.isEnabled("feature2", for: "user99"))
    }

    // MARK: - Geolocation Rollout Tests

    func testGeolocationRolloutDisabled() {
        let rollout = GeolocationRollout(allowedRegions: ["US", "CA"])
        XCTAssertFalse(rollout.isEnabled(for: "user1"))  // Not implementable without location data
    }

    // MARK: - Statistical Test Tests

    func testStatisticalSignificance() {
        let controlGroup = (successes: 40, total: 1000)
        let treatmentGroup = (successes: 70, total: 1000)

        let chi2 = StatisticalTest.chiSquareTest(variantA: controlGroup, variantB: treatmentGroup)
        let isSignificant = StatisticalTest.isSignificant(chi2)

        XCTAssertTrue(isSignificant)
    }

    // MARK: - International User ID Bucketing (Hash Fix)

    /// 10,000 distinct IDs whose non-ASCII content must participate in bucketing.
    private let internationalIDs: [String] = {
        let scripts = ["Phạm", "Nguyễn", "Trần", "Lê", "姚明", "李小龍", "Иван", "Αλέξανδρος"]
        return (0..<1250).flatMap { i in scripts.map { "\($0)-user-\(i)" } }
    }()

    func testDistributionMatchesConfiguredPercentageForNonASCIIIDs() {
        let rollout = PercentageRollout(percentage: 10)

        let enabled = internationalIDs.filter { rollout.isEnabled(for: $0) }.count
        let share = Double(enabled) / Double(internationalIDs.count) * 100

        XCTAssertTrue((9.0...11.0).contains(share), "Expected ~10% enabled, got \(share)%")
    }

    func testBucketAssignmentIsStable() {
        let rollout = PercentageRollout(percentage: 10)

        let first = internationalIDs.map { rollout.isEnabled(for: $0) }
        let second = internationalIDs.map { rollout.isEnabled(for: $0) }

        XCTAssertEqual(first, second, "same ID must always get the same assignment")
    }

    func testEligibilityIsMonotonicInPercentage() {
        let five = PercentageRollout(percentage: 5)
        let fifty = PercentageRollout(percentage: 50)

        for id in internationalIDs {
            if five.isEnabled(for: id) {
                XCTAssertTrue(fifty.isEnabled(for: id), "\(id) enabled at 5% must stay enabled at 50%")
            }
        }
    }

    func testDistinctNonASCIIIDsDoNotCollapseToOneBucket() {
        // Same-length pure non-ASCII IDs: the old hash reduced every
        // character to 0, collapsing all of these onto one bucket.
        let pureNonASCII = ["姚一", "姚二", "姚三", "姚四", "姚五", "姚六", "姚七", "姚八"]
        let buckets = Set(pureNonASCII.map { djb2Hash($0) % 100 })

        XCTAssertGreaterThan(buckets.count, 1, "distinct non-ASCII IDs collapsed onto \(buckets.count) bucket(s)")
    }

    // MARK: - Geolocation Region Resolver (Polish Pass)

    func testGeolocationResolverAllows() {
        let resolver: @Sendable () -> String? = { "VN" }
        let rollout = GeolocationRollout(allowedRegions: ["VN", "US"], regionResolver: resolver)

        XCTAssertTrue(rollout.isEnabled(for: "any-user"))
    }

    func testGeolocationResolverRejects() {
        let resolver: @Sendable () -> String? = { "FR" }
        let rollout = GeolocationRollout(allowedRegions: ["VN", "US"], regionResolver: resolver)

        XCTAssertFalse(rollout.isEnabled(for: "any-user"))
    }

    func testGeolocationNilResolverStaysFalse() {
        let rollout = GeolocationRollout(allowedRegions: ["VN"], regionResolver: nil)

        XCTAssertFalse(rollout.isEnabled(for: "any-user"))
    }
}
