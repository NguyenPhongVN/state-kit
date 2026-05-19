import Foundation
import Riverpods
import Combine
import StateKitMacros

// MARK: - Providers

extension RProvider {

    // MARK: - 1. Basic Providers

    @StateProvider
    struct CounterState {
        let initial: Int = 0
    }

    @Provider
    static func doubleCounter(ref: ProviderRef) -> Int {
        let count = ref.watch(CounterStateProvider)
        return count * 2
    }

    // MARK: - 2. Notifier Providers

    @RiverpodNotifier
    class TodoNotifier: Notifier<[String]> {
        override func build() -> [String] {
            ["Learn Swift", "Build Riverpod"]
        }

        func add(_ todo: String) {
            state.append(todo)
        }

        func remove(at index: Int) {
            state.remove(at: index)
        }
    }

    @RiverpodNotifier
    class UserProfileNotifier: AsyncNotifier<String> {
        override func build() async throws -> String {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return "Mike Packard"
        }

        func updateName(_ newName: String) async {
            state = .loading()
            try? await Task.sleep(nanoseconds: 500_000_000)
            state = .data(newName)
        }
    }

    // MARK: - 3. Async Providers

    @FutureProvider
    static func weather() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "Sunny ☀️"
    }

    @StreamProvider
    static func clock() -> AnyPublisher<String, Error> {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { "\($0.formatted(date: .omitted, time: .standard))" }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    // MARK: - 4. Advanced Providers (Family & Select)

    @ProviderFamily
    static func userDetail(ref: ProviderRef, id: Int) -> String {
        "User Details for ID: \(id)"
    }

    struct SettingsState: Hashable {
        var theme: String = "Dark"
        var notificationsEnabled: Bool = true
    }

    @StateProvider
    struct Settings {
        let initial: SettingsState = SettingsState()
    }

    @RiverpodSelector
    static func themeOnly(ref: ProviderRef) -> String {
        ref.watch(SettingsProvider.select(\.theme))
    }
}

    // MARK: - Models

struct Product: Identifiable, Sendable, Codable {
    let id: Int
    let name: String
    let price: Double
}

    // MARK: - Providers

extension RProvider {

        /// Provider managing a product list from a simulated API.
    @RiverpodNotifier
    class ProductNotifier: AsyncNotifier<[Product]> {
        override func build() async throws -> [Product] {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return [
                Product(id: 1, name: "iPhone 15", price: 999.0),
                Product(id: 2, name: "iPad Pro", price: 799.0),
                Product(id: 3, name: "MacBook Air", price: 1199.0)
            ]
        }

        func refresh() async {
            state = .loading(previousData: state.value)
            state = await AsyncValue.guard { [weak self] in
                guard let self = self else { throw CancellationError() }
                return try await self.build()
            }
        }
    }

    @Provider
    static func cartSummary(ref: ProviderRef) -> String {
        let products = ref.watch(ProductNotifierProvider).value ?? []

        let balance = 1000.0

        let total = products.reduce(0) { $0 + $1.price }
        return "Total: $\(total) | Remaining: $\(balance - total)"
    }
}
