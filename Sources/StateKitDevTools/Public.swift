@_exported import Foundation

// MARK: - State History

public typealias StateHistory = History.StateHistory
public typealias InMemoryStateHistory = History.InMemoryStateHistory
public typealias HistoryEntry = History.HistoryEntry
public typealias JSONValue = History.JSONValue
public typealias AnyCodable = History.AnyCodable

// MARK: - Performance Metrics

public typealias PerformanceMetrics = Performance.PerformanceMetrics
public typealias InMemoryPerformanceMetrics = Performance.InMemoryPerformanceMetrics
public typealias PerformanceData = Performance.PerformanceData

// MARK: - Observers

public typealias DevToolsObserver = Observers.DevToolsObserver
public typealias ConsoleLoggerObserver = Observers.ConsoleLoggerObserver

// MARK: - Module Namespace

enum StateKitDevTools {
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
}

// Namespace reorganization for cleaner imports
extension StateKitDevTools {
    enum History {
        public typealias StateHistory = Foundation.StateHistory
        public typealias InMemoryStateHistory = Foundation.InMemoryStateHistory
        public typealias HistoryEntry = Foundation.HistoryEntry
        public typealias JSONValue = Foundation.JSONValue
        public typealias AnyCodable = Foundation.AnyCodable
    }

    enum Performance {
        public typealias PerformanceMetrics = Foundation.PerformanceMetrics
        public typealias InMemoryPerformanceMetrics = Foundation.InMemoryPerformanceMetrics
        public typealias PerformanceData = Foundation.PerformanceData
    }

    enum Observers {
        public typealias DevToolsObserver = Foundation.DevToolsObserver
        public typealias ConsoleLoggerObserver = Foundation.ConsoleLoggerObserver
    }
}
