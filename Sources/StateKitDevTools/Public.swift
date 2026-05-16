@_exported import Foundation

// MARK: - Module Namespace

public enum StateKitDevTools {
    public static let version = "2.2.0-beta"

    /// Creates a new DevTools observer for time-travel debugging.
    ///
    /// - Returns: A configured DevTools observer
    public static func createDevToolsObserver() -> DevToolsObserver {
        DevToolsObserver()
    }

    /// Creates a console logger observer for development.
    ///
    /// - Returns: A configured console logger
    public static func createConsoleLogger() -> ConsoleLoggerObserver {
        ConsoleLoggerObserver()
    }

    // MARK: - State History

    public enum History {
        public typealias StateHistory = Foundation.StateHistory
        public typealias InMemoryStateHistory = Foundation.InMemoryStateHistory
        public typealias HistoryEntry = Foundation.HistoryEntry
        public typealias JSONValue = Foundation.JSONValue
        public typealias AnyCodable = Foundation.AnyCodable
    }

    // MARK: - Performance Metrics

    public enum Performance {
        public typealias PerformanceMetrics = Foundation.PerformanceMetrics
        public typealias InMemoryPerformanceMetrics = Foundation.InMemoryPerformanceMetrics
        public typealias PerformanceData = Foundation.PerformanceData
    }

    // MARK: - Observers

    public enum Observers {
        public typealias DevToolsObserver = Foundation.DevToolsObserver
        public typealias ConsoleLoggerObserver = Foundation.ConsoleLoggerObserver
    }
}

// MARK: - Public Convenience Typealiases

public typealias StateHistory = StateKitDevTools.History.StateHistory
public typealias InMemoryStateHistory = StateKitDevTools.History.InMemoryStateHistory
public typealias HistoryEntry = StateKitDevTools.History.HistoryEntry
public typealias JSONValue = StateKitDevTools.History.JSONValue
public typealias AnyCodable = StateKitDevTools.History.AnyCodable
public typealias PerformanceMetrics = StateKitDevTools.Performance.PerformanceMetrics
public typealias InMemoryPerformanceMetrics = StateKitDevTools.Performance.InMemoryPerformanceMetrics
public typealias PerformanceData = StateKitDevTools.Performance.PerformanceData
public typealias DevToolsObserver = StateKitDevTools.Observers.DevToolsObserver
public typealias ConsoleLoggerObserver = StateKitDevTools.Observers.ConsoleLoggerObserver
