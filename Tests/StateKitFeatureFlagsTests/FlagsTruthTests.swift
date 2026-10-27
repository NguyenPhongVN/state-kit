import Testing
import Foundation
@testable import StateKitFeatureFlags

// Spec 009 US6: flags — remote precedence, snapshot replacement, salted
// bucketing with independent assignments.

@MainActor
@Suite("Flags Truth — 009 US6")
struct FlagsTruthTests {

    private let boolFlag = FeatureFlag(id: "009-bool", name: "Bool flag", defaultValue: false)

    @Test("remote override wins over local override")
    func remoteWinsOverLocal() {
        let registry = FeatureFlagRegistry()
        registry.register(boolFlag)
        registry.setOverride(boolFlag, value: true)   // local override
        registry.applyRawBoolOverrides(["009-bool": false])  // remote
        #expect(registry.value(for: boolFlag) == false,
                "local override beat the remote override — contract says remote wins")
    }

    @Test("remote snapshot replaces stale entries")
    func snapshotReplaces() {
        let registry = FeatureFlagRegistry()
        registry.register(boolFlag)
        registry.applyRawBoolOverrides(["009-bool": true, "009-other": false])
        #expect(registry.value(for: boolFlag) == true)

        // New snapshot no longer mentions the flag: the stale remote value must go.
        registry.applyRawBoolOverrides([:])
        #expect(registry.value(for: boolFlag) == false,
                "stale remote value survived a snapshot that dropped it")

        // clearAllOverrides clears both stores.
        registry.setOverride(boolFlag, value: true)
        registry.applyRawBoolOverrides(["009-bool": true])
        registry.clearAllOverrides()
        #expect(registry.value(for: boolFlag) == false)
    }

    @Test("bucketing is salted per experiment id")
    func bucketingSalted() {
        let a = ABTest<String>(
            id: "exp-alpha", name: "Alpha",
            variants: [
                ABTestVariant(id: "v0", name: "V0", value: "a0"),
                ABTestVariant(id: "v1", name: "V1", value: "a1"),
            ],
            trafficPercentage: 100
        )
        let b = ABTest<String>(
            id: "exp-beta", name: "Beta",
            variants: [
                ABTestVariant(id: "v0", name: "V0", value: "b0"),
                ABTestVariant(id: "v1", name: "V1", value: "b1"),
            ],
            trafficPercentage: 100
        )

        var differing = 0
        for user in 0..<50 {
            let ua = a.assignUser("user-\(user)")
            let ub = b.assignUser("user-\(user)")
            if (ua?.value) != (ub?.value) { differing += 1 }
        }
        #expect(differing > 0,
                "every user got the identical variant across two different experiments — bucketing is unsalted")

        // Stability: the same user gets the same variant on repeated calls.
        #expect(a.assignUser("user-7")?.value == a.assignUser("user-7")?.value)
    }

    @Test("percentage rollout supports a per-feature salt")
    func rolloutSalt() {
        let rolloutA = PercentageRollout(percentage: 50, salt: "feature-a")
        let rolloutB = PercentageRollout(percentage: 50, salt: "feature-b")

        var differing = 0
        for user in 0..<50 {
            if rolloutA.isEnabled(for: "user-\(user)") != rolloutB.isEnabled(for: "user-\(user)") {
                differing += 1
            }
        }
        #expect(differing > 0, "unsalted rollouts correlate across features")

        // Stability per feature.
        #expect(rolloutA.isEnabled(for: "user-3") == rolloutA.isEnabled(for: "user-3"))
    }
}
