import Foundation

// MARK: - StateKit Feature Flags Module

/// StateKitFeatureFlags provides type-safe feature flag management and A/B testing.
///
/// Features:
/// - Type-safe flag definitions (boolean, string, numeric)
/// - Feature flag registry with override support
/// - A/B experiment framework with deterministic assignment
/// - Rollout strategies (percentage-based, cohort-based)
/// - Conversion and result tracking

public enum StateKitFeatureFlags {
    public static let version = "2.6.0-beta"
}

// MARK: - Feature Flag Protocol

/// Protocol for feature flag definitions.
public protocol FeatureFlagDefinition: Sendable {
    associatedtype Value: Sendable

    /// Flag identifier.
    var id: String { get }

    /// Human-readable name.
    var name: String { get }

    /// Flag description.
    var description: String { get }

    /// Default value.
    var defaultValue: Value { get }
}

// MARK: - Feature Flag Value

/// Type-erased feature flag value.
public enum FeatureFlagValue: Sendable {
    case boolean(Bool)
    case string(String)
    case integer(Int)
    case double(Double)
    case percentage(Int)  // 0-100

    public var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case .integer(let value) = self { return value }
        if case .percentage(let value) = self { return value }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }
}

// MARK: - Feature Flag

/// Type-safe feature flag.
public struct FeatureFlag<T: Sendable>: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let defaultValue: T

    public init(
        id: String,
        name: String,
        description: String = "",
        defaultValue: T
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultValue = defaultValue
    }
}

// MARK: - Feature Flag Registry

/// Manages feature flags and overrides.
@MainActor
public final class FeatureFlagRegistry: Sendable {
    private var flags: [String: Any] = [:]
    private var overrides: [String: Any] = [:]

    public init() {}

    /// Registers a feature flag.
    public func register<T: Sendable>(_ flag: FeatureFlag<T>) {
        flags[flag.id] = flag
    }

    /// Gets flag value (respecting overrides).
    public func value<T: Sendable>(for flag: FeatureFlag<T>) -> T {
        if let override = overrides[flag.id] as? T {
            return override
        }
        return flag.defaultValue
    }

    /// Sets override for flag.
    public func setOverride<T: Sendable>(_ flag: FeatureFlag<T>, value: T) {
        overrides[flag.id] = value
    }

    /// Clears override for flag.
    public func clearOverride(_ flagId: String) {
        overrides.removeValue(forKey: flagId)
    }

    /// Clears all overrides.
    public func clearAllOverrides() {
        overrides.removeAll()
    }

    /// Gets all registered flags.
    public var allFlags: [String: String] {
        var result: [String: String] = [:]
        for (id, _) in flags {
            result[id] = id
        }
        return result
    }
}

// MARK: - Feature Flag Status

/// Status of a feature flag rollout.
public struct FeatureFlagStatus: Sendable {
    public let flagId: String
    public let isEnabled: Bool
    public let rolloutPercentage: Int
    public let enabledFor: Set<String>
    public let lastUpdated: Date

    public init(
        flagId: String,
        isEnabled: Bool,
        rolloutPercentage: Int = 100,
        enabledFor: Set<String> = [],
        lastUpdated: Date = Date()
    ) {
        self.flagId = flagId
        self.isEnabled = isEnabled
        self.rolloutPercentage = rolloutPercentage
        self.enabledFor = enabledFor
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Common Feature Flags

/// Example feature flag: new UI.
public let newUIFlag = FeatureFlag<Bool>(
    id: "feature_new_ui",
    name: "New UI",
    description: "Enable new user interface design",
    defaultValue: false
)

/// Example feature flag: dark mode.
public let darkModeFlag = FeatureFlag<Bool>(
    id: "feature_dark_mode",
    name: "Dark Mode",
    description: "Enable dark mode support",
    defaultValue: false
)

/// Example feature flag: beta features.
public let betaFeaturesFlag = FeatureFlag<Bool>(
    id: "feature_beta",
    name: "Beta Features",
    description: "Enable beta/experimental features",
    defaultValue: false
)

/// Example feature flag: analytics level.
public let analyticsLevelFlag = FeatureFlag<String>(
    id: "feature_analytics_level",
    name: "Analytics Level",
    description: "Set analytics detail level",
    defaultValue: "basic"
)
