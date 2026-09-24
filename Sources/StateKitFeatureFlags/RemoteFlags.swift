import Foundation

// MARK: - RemoteFlagSource

/// A source of remote flag overrides (e.g. a backend or Firebase Remote
/// Config). Hosts implement this to pull flag values from anywhere; the
/// registry merges the returned dictionary over local evaluation — remote
/// entries win, missing entries fall back to local.
public protocol RemoteFlagSource: Sendable {
    /// Fetches a snapshot of remote overrides: flag id → enabled.
    func fetchOverrides() async -> [String: Bool]
}

// MARK: - InMemoryRemoteFlagSource

/// An in-memory `RemoteFlagSource` — handy for tests and SwiftUI previews.
public struct InMemoryRemoteFlagSource: RemoteFlagSource {
    private let overrides: [String: Bool]

    /// Creates the adapter with a fixed dictionary of overrides.
    public init(overrides: [String: Bool]) {
        self.overrides = overrides
    }

    public func fetchOverrides() async -> [String: Bool] {
        overrides
    }
}

// MARK: - Registry merge

@MainActor
extension FeatureFlagRegistry {

    /// Fetches overrides from `source` and applies them as Bool overrides.
    ///
    /// Remote entries win over local defaults and local overrides; flags the
    /// source does not mention keep their local evaluation.
    ///
    /// - Parameter source: The remote flag source to pull from.
    public func applyRemoteOverrides(from source: some RemoteFlagSource) async {
        let remote = await source.fetchOverrides()
        applyRawBoolOverrides(remote)
    }
}
