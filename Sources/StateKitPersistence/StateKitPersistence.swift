import Foundation
import Riverpods
import StateKit
import StateKitAtoms

// MARK: - StateKit Persistence Module

/// StateKitPersistence provides persistence integrations for StateKit state:
/// - SwiftData synchronization
/// - UserDefaults-backed atoms
/// - Secure Keychain storage
///
/// All integrations maintain type safety and reactive updates with StateKit's
/// provider and atom systems.

public enum StateKitPersistence {
    public static let version = "2.5.0-beta"
}

// Re-export main integration types
public typealias SecureStateProvider = KeychainStateProvider
