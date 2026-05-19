@_exported import Foundation
import Riverpods

// MARK: - Public Namespace

public enum StateKitDevTools {
    public static let version = "2.2.0-beta"

    /// Creates a new DevTools observer for time-travel debugging.
    ///
    /// - Returns: A configured DevTools observer
    @MainActor
    public static func createDevToolsObserver() -> DevToolsObserver {
        DevToolsObserver()
    }

    /// Creates a console logger observer for development.
    ///
    /// - Returns: A configured console logger
    @MainActor
    public static func createConsoleLogger() -> ConsoleLoggerObserver {
        ConsoleLoggerObserver()
    }

    /// Creates a debug provider observer with optional filtering.
    ///
    /// - Parameter filter: Optional filter to limit which providers are logged.
    /// - Returns: A configured debug observer
    @MainActor
    public static func createDebugObserver(
        filter: ((any ProviderProtocol) -> Bool)? = nil
    ) -> DebugProviderObserver {
        DebugProviderObserver(filter: filter)
    }
}
