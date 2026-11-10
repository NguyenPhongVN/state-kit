import Testing
import StateKitFeatureFlags
import Foundation

// Spec 012 US2: GeolocationRollout evaluates through the host-supplied region
// resolver. (Contract previously documented as "always false"; the resolver was
// added in an earlier remediation — this suite pins the full path so it cannot
// silently regress.)

@Suite("GeolocationRollout — resolver contract")
struct GeolocationRolloutTests {

    @Test("allowed region resolves to true")
    func allowedRegionIsEnabled() {
        let rollout = GeolocationRollout(
            allowedRegions: ["VN", "SG"],
            regionResolver: { "VN" }
        )
        #expect(rollout.isEnabled(for: "user-1") == true)
    }

    @Test("disallowed region resolves to false")
    func disallowedRegionIsDisabled() {
        let rollout = GeolocationRollout(
            allowedRegions: ["VN", "SG"],
            regionResolver: { "US" }
        )
        #expect(rollout.isEnabled(for: "user-1") == false)
    }

    @Test("missing resolver defaults to false (documented default)")
    func missingResolverDefaultsToFalse() {
        let rollout = GeolocationRollout(allowedRegions: ["VN"])
        #expect(rollout.isEnabled(for: "user-1") == false)
    }
}
