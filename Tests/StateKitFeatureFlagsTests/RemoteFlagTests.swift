import Testing
import StateKitFeatureFlags

@MainActor
@Suite("Remote Flags — Polish Pass", .serialized)
struct RemoteFlagTests {

    @Test("in-memory adapter returns its dictionary")
    func inMemoryAdapter() async {
        let source = InMemoryRemoteFlagSource(overrides: ["new_checkout": true, "dark_mode": false])

        let overrides = await source.fetchOverrides()

        #expect(overrides == ["new_checkout": true, "dark_mode": false])
    }

    @Test("remote override wins over local default")
    func remoteWins() async {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(id: "new_checkout", name: "New Checkout", defaultValue: false)
        registry.register(flag)
        let source = InMemoryRemoteFlagSource(overrides: ["new_checkout": true])

        await registry.applyRemoteOverrides(from: source)

        #expect(registry.value(for: flag) == true)
    }

    @Test("missing remote entry falls back to local default")
    func localFallback() async {
        let registry = FeatureFlagRegistry()
        let flag = FeatureFlag<Bool>(id: "legacy_flow", name: "Legacy Flow", defaultValue: true)
        registry.register(flag)
        let source = InMemoryRemoteFlagSource(overrides: ["other_flag": true])

        await registry.applyRemoteOverrides(from: source)

        #expect(registry.value(for: flag) == true)
    }
}
