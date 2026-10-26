import Testing
import Foundation
@testable import StateKitFeatureFlags

// Spec 008 US6: assignUser must be total — an active ABTest with no variants
// assigns no user instead of trapping on variants[min(0, -1)].

@Suite("ABTest Empty Variants — P1 fixes")
struct ABTestEmptyVariantsTests {

    @Test("empty variants return nil instead of crashing (100% traffic)")
    func emptyVariantsFullTraffic() {
        let test = ABTest<String>(
            id: "empty-full",
            name: "Empty variants, full traffic",
            variants: [],
            trafficPercentage: 100
        )
        let assigned = test.assignUser("user-1")
        #expect(assigned == nil)
    }

    @Test("empty variants return nil with zero traffic")
    func emptyVariantsZeroTraffic() {
        let test = ABTest<String>(
            id: "empty-zero",
            name: "Empty variants, zero traffic",
            variants: [],
            trafficPercentage: 0
        )
        let assigned = test.assignUser("user-1")
        #expect(assigned == nil)
    }

    @Test("non-empty variants still assign")
    func nonEmptyStillAssigns() {
        let test = ABTest<String>(
            id: "normal",
            name: "Normal test",
            variants: [
                ABTestVariant(id: "a", name: "A", value: "A"),
                ABTestVariant(id: "b", name: "B", value: "B"),
            ],
            trafficPercentage: 100
        )
        #expect(test.assignUser("user-1") != nil)
        #expect(test.assignUser("user-2") != nil)
    }
}
