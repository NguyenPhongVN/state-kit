@_exported import Foundation

// MARK: - Public Namespace

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
}
