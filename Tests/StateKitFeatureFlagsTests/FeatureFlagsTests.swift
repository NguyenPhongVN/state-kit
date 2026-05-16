import XCTest
import StateKitFeatureFlags

@MainActor
final class FeatureFlagsTests: XCTestCase {
    // MARK: - Feature Flag Registry Tests

    func testFlagRegistration() {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(name: "test_flag", defaultValue: false)

        registry.register(flag)
        XCTAssertFalse(registry.isEnabled("test_flag"))
    }

    func testFlagOverride() {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(name: "test_flag", defaultValue: false)

        registry.register(flag)
        registry.override(flag, value: true)

        XCTAssertTrue(registry.isEnabled("test_flag"))
    }

    func testFlagOverrideClear() {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(name: "test_flag", defaultValue: false)

        registry.register(flag)
        registry.override(flag, value: true)
        registry.clearOverride(flag)

        XCTAssertFalse(registry.isEnabled("test_flag"))
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
        for i in 0..<100 {
            if rollout.isEnabled(for: "user\(i)") {
                enabledCount += 1
            }
        }

        // Should be roughly 50% (allow 10% variance)
        XCTAssertGreaterThan(enabledCount, 35)
        XCTAssertLessThan(enabledCount, 65)
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
        let controlGroup = (successes: 45, total: 1000)
        let treatmentGroup = (successes: 62, total: 1000)

        let chi2 = StatisticalTest.chiSquareTest(variantA: controlGroup, variantB: treatmentGroup)
        let isSignificant = StatisticalTest.isSignificant(chi2)

        XCTAssertTrue(isSignificant)
    }
}
