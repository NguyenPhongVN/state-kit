import StateKit
import Observation

// MARK: - @ObservableState Example

/// Generates Observable conformance helpers:
/// - `_observationRegistrar` for tracking mutations
/// - `withObserver(_:)` for observing state changes
/// - `_observe(_:)` for internal mutation tracking
@Observable
@ObservableState
final class AppState {
    var userName: String = ""
    var isLoggedIn: Bool = false
    var theme: String = "light"

    func login(name: String) {
        userName = name
        isLoggedIn = true
    }

    func logout() {
        userName = ""
        isLoggedIn = false
    }
}

// MARK: - SwiftUI Integration

struct AppView: View {
    @State private var appState = AppState()

    var body: some View {
        if appState.isLoggedIn {
            Text("Welcome, \(appState.userName)")
        } else {
            Text("Please log in")
        }
    }
}

// MARK: - Observing State Changes

struct StateMonitor {
    let appState: AppState

    func observeChanges() {
        appState.withObserver {
            print("State changed!")
        }
    }
}

// MARK: - Why Use @ObservableState?

/// Swift's Observation framework provides:
/// - Better performance than @Published (no extra Reference types)
/// - Compile-time generation of tracking code
/// - Fine-grained reactivity
///
/// @ObservableState macro helps by:
/// - Auto-generating required conformance helpers
/// - Providing consistent mutation tracking setup
/// - Reducing boilerplate for Observable types
