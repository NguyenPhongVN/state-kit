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
    public let percentage: Int
    private let userHasher: (String) -> Int

    public init(percentage: Int, userHasher: @escaping (String) -> Int = defaultHasher) {
        self.percentage = max(0, min(100, percentage))
        self.userHasher = userHasher
    }

    /// Checks if enabled for user (based on user hash).
    public func isEnabled(for userId: String) -> Bool {
        let hash = userHasher(userId)
        let bucket = hash % 100
        return bucket < percentage
    }

    private static func defaultHasher(_ userId: String) -> Int {
        djb2Hash(userId)
    }
}

// MARK: - Cohort-Based Rollout

/// Enables feature for specific cohorts/user IDs.
public struct CohortRollout: RolloutStrategy {
    public let percentage: Int
    private let cohorts: Set<String>

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
    public let percentage: Int
    public let startDate: Date
    public let endDate: Date?

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
public struct GeolocationRollout: RolloutStrategy {
    public let percentage: Int
    public let allowedRegions: Set<String>

    public init(allowedRegions: Set<String>, percentage: Int = 100) {
        self.allowedRegions = allowedRegions
        self.percentage = max(0, min(100, percentage))
    }

    /// Checks if region is allowed.
    /// - Note: This implementation requires additional context to determine user region.
    /// You must resolve the user's region (via IP geolocation, user preferences, etc.)
    /// and check against `allowedRegions` manually, or override this method
    /// in a subclass that has access to location data.
    public func isEnabled(for userId: String) -> Bool {
        false
    }
}

// MARK: - Canary Rollout

/// Gradual rollout: start small, increase over time.
public struct CanaryRollout: RolloutStrategy {
    public let startPercentage: Int
    public let endPercentage: Int
    public let startDate: Date
    public let endDate: Date
    private let userHasher: (String) -> Int

    public init(
        startPercentage: Int = 1,
        endPercentage: Int = 100,
        startDate: Date,
        endDate: Date,
        userHasher: @escaping (String) -> Int = defaultHasher
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

    private static func defaultHasher(_ userId: String) -> Int {
        djb2Hash(userId)
    }
}

// MARK: - Rollout Manager

/// Manages feature rollouts.
@MainActor
public final class RolloutManager: Sendable {
    private var rollouts: [String: RolloutStrategy] = [:]

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
    public enum Stage: String, Sendable {
        case internal   // Internal team only
        case beta       // Beta users
        case general    // All users
    }

    public let percentage: Int
    public let stage: Stage
    public let internalUsers: Set<String>
    public let betaUsers: Set<String>

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
        case .internal:
            return internalUsers.contains(userId)
        case .beta:
            return internalUsers.contains(userId) || betaUsers.contains(userId)
        case .general:
            return true
        }
    }
}
