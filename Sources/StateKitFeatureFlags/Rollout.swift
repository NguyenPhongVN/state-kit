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
        var hash = 5381
        for char in userId {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        return abs(hash)
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
    public func isEnabled(for userId: String) -> Bool {
        // Would need user's region information
        // For now, always enabled in allowed regions
        true
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
        var hash = 5381
        for char in userId {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        return abs(hash)
    }
}

// MARK: - Rollout Manager

/// Manages feature rollouts.
@MainActor
public final class RolloutManager: Sendable {
    private var rollouts: [String: Any] = [:]

    public init() {}

    /// Registers rollout strategy.
    public func register<S: RolloutStrategy>(_ rollout: S, for featureId: String) {
        rollouts[featureId] = rollout
    }

    /// Checks if feature is enabled for user.
    public func isEnabled(_ featureId: String, for userId: String) -> Bool {
        if let rollout = rollouts[featureId] as? PercentageRollout {
            return rollout.isEnabled(for: userId)
        }
        if let rollout = rollouts[featureId] as? CohortRollout {
            return rollout.isEnabled(for: userId)
        }
        if let rollout = rollouts[featureId] as? TimeBasedRollout {
            return rollout.isEnabled(for: userId)
        }
        if let rollout = rollouts[featureId] as? CanaryRollout {
            return rollout.isEnabled(for: userId)
        }
        return false
    }

    /// Gets rollout percentage.
    public func percentage(for featureId: String) -> Int {
        if let rollout = rollouts[featureId] as? PercentageRollout {
            return rollout.percentage
        }
        if let rollout = rollouts[featureId] as? CanaryRollout {
            return rollout.percentage
        }
        if let rollout = rollouts[featureId] {
            if let strategy = rollout as? RolloutStrategy {
                return strategy.percentage
            }
        }
        return 0
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
