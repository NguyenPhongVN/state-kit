import StateKit

// MARK: - @AsyncHook Example

/// Generates an async hook function: `func useDataFetcher(url: URL) async`
/// with automatic dependency tracking and cleanup
@AsyncHook
struct DataFetcher {
    let url: URL
    let timeout: TimeInterval = 30

    async func run() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // Update atom with fetched data
        } catch {
            // Handle error
        }
    }

    func cleanup() {
        // Cancel any ongoing requests
    }
}

// MARK: - Usage in SwiftUI/View Code

struct ContentView: StateView {
    @State var data: Data?

    var stateBody: some View {
        // Hook called at top level
        useDataFetcher(url: URL(string: "https://api.example.com/data")!)

        VStack {
            if let data = data {
                Text("Loaded \(data.count) bytes")
            }
        }
    }
}

// MARK: - Comparison with @HookEffect

/// @HookEffect for synchronous side effects:
@HookEffect
struct SyncLogger {
    let message: String

    func run() {
        print(message)
    }
}

/// @AsyncHook for async side effects:
/// - Better for: API calls, async operations, awaiting results
/// - Has: direct async/await syntax, no Task wrapping needed
