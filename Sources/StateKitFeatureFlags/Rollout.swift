import Foundation

// MARK: - Rollout Strategies

/// Strategy for rolling out features to users.
public protocol RolloutStrategy: Sendable {
    /// Checks if feature should be enabled for user.
    func isEnabled(for userId: String) -> Bool

    /// Gets rollout percentage (0-100).
    var percentage: Int { get }
}

// MARK: - Percentage Rollout

/// Enables feature for a percentage of users.
public struct PercentageRollout: RolloutStrategy {
    /// Configured share of users (0–100).
    public let percentage: Int
    private let userHasher: @Sendable (String) -> Int

    /// - Parameters: target percentage and an optional custom hasher.
    public init(percentage: Int, userHasher: @escaping @Sendable (String) -> Int = { djb2Hash($0) }) {
        self.percentage = max(0, min(100, percentage))
        self.userHasher = userHasher
    }

    /// Checks if enabled for user (based on user hash).
    public func isEnabled(for userId: String) -> Bool {
        let hash = userHasher(userId)
        let bucket = hash % 100
        return bucket < percentage
    }
}

// MARK: - Cohort-Based Rollout

/// Enables feature for specific cohorts/user IDs.
public struct CohortRollout: RolloutStrategy {
    /// Documentation-only field; cohort membership decides eligibility.
    public let percentage: Int
    private let cohorts: Set<String>

    /// Creates a cohort rollout (percentage is informational).
    public init(cohorts: Set<String>, percentage: Int = 100) {
        self.cohorts = cohorts
        self.percentage = max(0, min(100, percentage))
    }

    /// Checks if user is in cohort.
    public func isEnabled(for userId: String) -> Bool {
        cohorts.contains(userId)
    }
}

// MARK: - Time-Based Rollout

/// Enables feature at specific times.
public struct TimeBasedRollout: RolloutStrategy {
    /// Documentation-only field; the time window decides eligibility.
    public let percentage: Int
    /// Eligibility opens at this moment.
    public let startDate: Date
    /// Eligibility closes at this moment, if bounded.
    public let endDate: Date?

    /// Creates a time-window rollout.
    public init(
        percentage: Int,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.percentage = max(0, min(100, percentage))
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Checks if feature is enabled now.
    public func isEnabled(for userId: String) -> Bool {
        let now = Date()
        guard now >= startDate else { return false }
        if let endDate = endDate {
            return now <= endDate
        }
        return true
    }
}

// MARK: - Geolocation Rollout

/// Enables feature for specific regions.
///
/// The host supplies the user's region through `regionResolver` — the rollout
/// itself never performs geolocation. Region matching is exact string
/// equality (case-sensitive). Without a resolver (or with one returning nil),
/// the rollout evaluates to false.
public struct GeolocationRollout: RolloutStrategy {
    /// Configured share (informational; eligibility is region-based).
    public let percentage: Int
    /// Region codes that would qualify — region resolution is external.
    public let allowedRegions: Set<String>
    /// Host-supplied resolver returning the user's current region (or nil).
    private let regionResolver: (@Sendable () -> String?)?

    /// Creates a region rollout (requires external region resolution).
    public init(
        allowedRegions: Set<String>,
        percentage: Int = 100,
        regionResolver: (@Sendable () -> String?)? = nil
    ) {
        self.allowedRegions = allowedRegions
        self.percentage = max(0, min(100, percentage))
        self.regionResolver = regionResolver
    }

    /// Checks if the resolved region is allowed. Requires a region resolver;
    /// without one this evaluates to false.
    public func isEnabled(for userId: String) -> Bool {
        guard let region = regionResolver?() else { return false }
        return allowedRegions.contains(region)
    }
}

// MARK: - Canary Rollout

/// Gradual rollout: start small, increase over time.
public struct CanaryRollout: RolloutStrategy {
    /// Rollout share at the start date.
    public let startPercentage: Int
    /// Rollout share at the end date.
    public let endPercentage: Int
    /// When the ramp begins.
    public let startDate: Date
    /// When the ramp completes.
    public let endDate: Date
    private let userHasher: @Sendable (String) -> Int

    /// Creates a time-based ramp between start and end percentages.
    public init(
        startPercentage: Int = 1,
        endPercentage: Int = 100,
        startDate: Date,
        endDate: Date,
        userHasher: @escaping @Sendable (String) -> Int = { djb2Hash($0) }
    ) {
        self.startPercentage = max(0, min(100, startPercentage))
        self.endPercentage = max(0, min(100, endPercentage))
        self.startDate = startDate
        self.endDate = endDate
        self.userHasher = userHasher
    }

    /// Current percentage based on time.
    public var percentage: Int {
        let now = Date()
        guard now >= startDate else { return 0 }
        guard now <= endDate else { return endPercentage }

        let elapsed = now.timeIntervalSince(startDate)
        let total = endDate.timeIntervalSince(startDate)
        let progress = min(1.0, elapsed / total)

        let range = Double(endPercentage - startPercentage)
        return startPercentage + Int(range * progress)
    }

    /// Checks if enabled for user given current percentage.
    public func isEnabled(for userId: String) -> Bool {
        let hash = userHasher(userId)
        let bucket = hash % 100
        return bucket < percentage
    }
}

// MARK: - Rollout Manager

/// Manages feature rollouts.
@MainActor
public final class RolloutManager: Sendable {
    private var rollouts: [String: RolloutStrategy] = [:]

    /// Creates an empty manager.
    public init() {}

    /// Registers rollout strategy.
    public func register<S: RolloutStrategy>(_ rollout: S, for featureId: String) {
        rollouts[featureId] = rollout
    }

    /// Checks if feature is enabled for user.
    public func isEnabled(_ featureId: String, for userId: String) -> Bool {
        rollouts[featureId]?.isEnabled(for: userId) ?? false
    }

    /// Gets rollout percentage.
    public func percentage(for featureId: String) -> Int {
        rollouts[featureId]?.percentage ?? 0
    }

    /// Gets all registered rollouts.
    public var allRollouts: [String] {
        Array(rollouts.keys)
    }
}

// MARK: - Staged Rollout

/// Rollout stages: internal → beta → general.
public struct StagedRollout: RolloutStrategy {
    /// Progressive access levels for a staged rollout.
    public enum Stage: String, Sendable {
        case team   // Internal team only
        case beta   // Beta users
        case general    // All users
    }

    /// Configured share (informational; stage membership decides access).
    public let percentage: Int
    /// The access stage in effect.
    public let stage: Stage
    /// Users with team-stage access.
    public let internalUsers: Set<String>
    /// Users with beta-stage access.
    public let betaUsers: Set<String>

    /// Creates a staged rollout.
    public init(
        stage: Stage,
        percentage: Int = 100,
        internalUsers: Set<String> = [],
        betaUsers: Set<String> = []
    ) {
        self.stage = stage
        self.percentage = max(0, min(100, percentage))
        self.internalUsers = internalUsers
        self.betaUsers = betaUsers
    }

    /// Checks if user can access based on stage.
    public func isEnabled(for userId: String) -> Bool {
        switch stage {
        case .team:
            return internalUsers.contains(userId)
        case .beta:
            return internalUsers.contains(userId) || betaUsers.contains(userId)
        case .general:
            return true
        }
    }
}
