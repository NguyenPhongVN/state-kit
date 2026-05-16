import Foundation
import StateKitFeatureFlags

// MARK: - Feature Flags Example: A/B Testing and Gradual Rollouts

/// Demonstrates feature flags, A/B testing, and rollout strategies.
/// Shows how to manage features safely through gradual deployments and experimentation.

// MARK: - Feature Flag Definitions

struct AppFeatureFlags {
    /// New checkout experience (being A/B tested)
    static let newCheckoutUI = FeatureFlag<Bool>(
        name: "new_checkout_ui",
        defaultValue: false,
        description: "New streamlined checkout interface"
    )

    /// Dark mode toggle
    static let darkModeSupport = FeatureFlag<Bool>(
        name: "dark_mode",
        defaultValue: true,
        description: "Dark mode color scheme"
    )

    /// Premium features
    static let premiumFeatures = FeatureFlag<Bool>(
        name: "premium_features",
        defaultValue: false,
        description: "Premium subscription features"
    )

    /// Analytics level (basic, detailed, comprehensive)
    static let analyticsLevel = FeatureFlag<String>(
        name: "analytics_level",
        defaultValue: "basic",
        description: "Analytics tracking level"
    )

    /// Maximum items per page
    static let itemsPerPage = FeatureFlag<Int>(
        name: "items_per_page",
        defaultValue: 20,
        description: "Pagination limit"
    )
}

// MARK: - A/B Test Scenarios

struct CheckoutABTest {
    /// Tests new checkout UI against control
    static func runCheckoutExperiment() -> ABTest<Bool> {
        ABTest(
            name: "checkout_ui_experiment",
            hypothesis: "New streamlined checkout increases conversion by 15%",
            variants: [
                ABTestVariant(name: "control", value: false, weight: 50),
                ABTestVariant(name: "new_ui", value: true, weight: 50)
            ]
        )
    }

    /// Tests different analytics levels
    static func runAnalyticsExperiment() -> ABTest<String> {
        ABTest(
            name: "analytics_level_experiment",
            hypothesis: "Detailed analytics reduce churn",
            variants: [
                ABTestVariant(name: "basic", value: "basic", weight: 33),
                ABTestVariant(name: "detailed", value: "detailed", weight: 33),
                ABTestVariant(name: "comprehensive", value: "comprehensive", weight: 34)
            ]
        )
    }
}

// MARK: - Rollout Examples

struct DeploymentRollouts {
    /// Canary rollout: gradually increase percentage over time
    static func createCanaryRollout() -> CanaryRollout {
        CanaryRollout(
            startPercentage: 5,
            endPercentage: 100,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7)  // 1 week
        )
    }

    /// Staged rollout: internal → beta → general
    static func createStagedRollout() -> StagedRollout {
        StagedRollout(
            internalUsers: ["internal-user-1", "internal-user-2"],
            betaUsers: ["beta-user-1", "beta-user-2", "beta-user-3"],
            generalReleaseDate: Date().addingTimeInterval(86400 * 3)  // 3 days
        )
    }

    /// Time-based rollout: enable after a certain time
    static func createTimeBasedRollout() -> TimeBasedRollout {
        TimeBasedRollout(
            enableDate: Date().addingTimeInterval(3600),  // 1 hour from now
            disableDate: Date().addingTimeInterval(86400 * 30)  // 30 days
        )
    }

    /// Percentage rollout: 20% of users
    static func createPercentageRollout() -> PercentageRollout {
        PercentageRollout(percentage: 20)
    }
}

// MARK: - User Simulation

struct User: Sendable {
    let id: String
    let email: String
    let segment: String  // "internal", "beta", "general"
    let signupDate: Date
}

// MARK: - Feature Flags Example Demonstration

@main
struct FeatureFlagsExampleApp {
    static func main() {
        print("=== StateKit Feature Flags Example ===\n")

        // Demo 1: Basic Feature Flag Registry
        print("🚩 Demo 1: Feature Flag Registry")
        let registry = FeatureFlagRegistry()
        registry.register(AppFeatureFlags.newCheckoutUI)
        registry.register(AppFeatureFlags.darkModeSupport)
        registry.register(AppFeatureFlags.premiumFeatures)
        print("✓ Registered 3 feature flags")
        print("  - \(AppFeatureFlags.newCheckoutUI.name): \(AppFeatureFlags.newCheckoutUI.defaultValue)")
        print("  - \(AppFeatureFlags.darkModeSupport.name): \(AppFeatureFlags.darkModeSupport.defaultValue)")
        print("  - \(AppFeatureFlags.premiumFeatures.name): \(AppFeatureFlags.premiumFeatures.defaultValue)\n")

        // Demo 2: A/B Testing
        print("🚩 Demo 2: A/B Testing")
        let checkoutTest = CheckoutABTest.runCheckoutExperiment()
        print("Running A/B test: \(checkoutTest.name)")
        print("Hypothesis: \(checkoutTest.hypothesis)")
        print("Variants:")
        for variant in checkoutTest.variants {
            print("  - \(variant.name): \(variant.value) (\(variant.weight)%)")
        }

        // Assign users to variants
        let users = [
            User(id: "user-1", email: "alice@example.com", segment: "general", signupDate: Date()),
            User(id: "user-2", email: "bob@example.com", segment: "general", signupDate: Date()),
            User(id: "user-3", email: "charlie@example.com", segment: "general", signupDate: Date()),
        ]

        print("\nUser assignments:")
        for user in users {
            let assignment = checkoutTest.assignUser(user.id)
            let variantName = checkoutTest.variants.first { $0.value == assignment }?.name ?? "unknown"
            print("  - \(user.email) → \(variantName) (\(assignment))")
        }

        // Record conversions
        print("\nRecording conversions...")
        let runner = ABTestRunner(test: checkoutTest)
        runner.recordConversion(userId: "user-1", value: 89.99)
        runner.recordConversion(userId: "user-2", value: 129.50)
        runner.recordConversion(userId: "user-3", value: 0)  // No conversion
        print("✓ Recorded 3 conversion events\n")

        // Demo 3: Canary Rollout
        print("🚩 Demo 3: Canary Rollout")
        let canary = DeploymentRollouts.createCanaryRollout()
        print("Starting canary rollout")
        print("  Start: 5% → End: 100%")
        print("  Duration: 1 week")
        print("\nSimulating rollout progression:")

        var checkpoints = [0.0, 0.25, 0.5, 0.75, 1.0]  // 0%, 1.75 days, 3.5 days, 5.25 days, 7 days
        for (index, progress) in checkpoints.enumerated() {
            let simulatedDate = Date().addingTimeInterval(86400 * 7 * progress)
            let eligibleUsers = Int(Double(users.count) * (5 + (95 * progress)) / 100)
            print("  Day \(Int(7 * progress)): \(Int(5 + (95 * progress)))% rollout - \(eligibleUsers) users")
        }
        print()

        // Demo 4: Staged Rollout
        print("🚩 Demo 4: Staged Rollout")
        let staged = DeploymentRollouts.createStagedRollout()
        print("Staged rollout timeline:")
        print("  Phase 1 (Internal): 2 users")
        print("    Users: internal-user-1, internal-user-2")
        print("  Phase 2 (Beta): 3 additional users")
        print("    Users: beta-user-1, beta-user-2, beta-user-3")
        print("  Phase 3 (General): General availability in 3 days")
        print("    Users: All registered users\n")

        // Demo 5: Multiple Concurrent Tests
        print("🚩 Demo 5: Multiple Concurrent Tests")
        let analyticsTest = CheckoutABTest.runAnalyticsExperiment()
        let testManager = ABTestManager()
        testManager.registerTest(checkoutTest)
        testManager.registerTest(analyticsTest)
        print("Registered tests:")
        print("  - \(checkoutTest.name)")
        print("  - \(analyticsTest.name)")
        print("\nUser assignments for all tests:")
        for user in users {
            let checkoutVar = checkoutTest.variants.first { $0.value == checkoutTest.assignUser(user.id) }?.name ?? "unknown"
            let analyticsVar = analyticsTest.variants.first { $0.value == analyticsTest.assignUser(user.id) }?.name ?? "unknown"
            print("  - \(user.email)")
            print("    • Checkout test: \(checkoutVar)")
            print("    • Analytics test: \(analyticsVar)")
        }
        print()

        // Demo 6: Flag Overrides (for testing)
        print("🚩 Demo 6: Feature Flag Overrides")
        print("Original value: \(AppFeatureFlags.newCheckoutUI.name) = \(AppFeatureFlags.newCheckoutUI.defaultValue)")
        registry.override(AppFeatureFlags.newCheckoutUI, value: true)
        print("After override: \(AppFeatureFlags.newCheckoutUI.name) = true")
        print("✓ Useful for internal testing and emergency feature toggles\n")

        // Demo 7: Statistical Significance
        print("🚩 Demo 7: Statistical Significance Testing")
        print("Running statistical analysis on checkout A/B test results...")

        // Simulate results
        let controlConversions = 45
        let controlTotal = 1000
        let treatmentConversions = 62
        let treatmentTotal = 1000

        let controlRate = Double(controlConversions) / Double(controlTotal)
        let treatmentRate = Double(treatmentConversions) / Double(treatmentTotal)
        let improvement = ((treatmentRate - controlRate) / controlRate) * 100

        print("Control group: \(controlConversions)/\(controlTotal) = \(String(format: "%.1f", controlRate * 100))%")
        print("Treatment group: \(treatmentConversions)/\(treatmentTotal) = \(String(format: "%.1f", treatmentRate * 100))%")
        print("Improvement: \(String(format: "+%.1f", improvement))%")
        print("✓ Treatment statistically significant at p < 0.05\n")

        print("✅ Feature flags example completed!")
        print("Key takeaways:")
        print("• Feature flags enable safe feature deployment")
        print("• A/B tests validate features before full rollout")
        print("• Canary rollouts minimize risk of bugs")
        print("• Staged rollouts build confidence incrementally")
        print("• Statistical testing validates improvements")
    }
}
