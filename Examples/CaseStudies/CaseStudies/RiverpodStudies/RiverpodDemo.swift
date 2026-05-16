import SwiftUI
import Riverpods

// MARK: - Models

struct Product: Identifiable, Sendable, Codable {
    let id: Int
    let name: String
    let price: Double
}

// MARK: - Providers

/// Provider quản lý danh sách sản phẩm từ API
class ProductNotifier: AsyncNotifier<[Product]> {
    override func build() async throws -> [Product] {
        // Giả lập gọi API
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

let productsProvider = AsyncNotifierProvider(cacheTime: 10.0, name: "ProductListProvider") { ProductNotifier() }

/// Provider tính toán tổng giá trị giỏ hàng
let cartSummaryProvider = Provider(name: "CartSummary") { ref in
    let products = ref.watch(productsProvider).value ?? []

    // Giá trị mặc định cho số dư tài khoản
    let balance = 1000.0

    let total = products.reduce(0) { $0 + $1.price }
    return "Total: $\(total) | Remaining: $\(balance - total)"
}

// MARK: - View

struct RiverpodDemoView: View {
    // Watch provider trong SwiftUI
    @Watch(productsProvider) var productsState
    @Watch(cartSummaryProvider) var summary
    
    @Environment(\.providerContainer) var container
    
    var body: some View {
        List {
            Section("Cart Summary") {
                Text(summary)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Section("Products") {
                productsState.when(
                    data: { products in
                        ForEach(products) { product in
                            HStack {
                                Text(product.name)
                                Spacer()
                                Text("$\(product.price, specifier: "%.2f")")
                            }
                        }
                    },
                    error: { err, prevData in
                        VStack(alignment: .leading) {
                            if let products = prevData {
                                ForEach(products) { Text($0.name).opacity(0.5) }
                            }
                            Text("Error: \(err.localizedDescription)")
                                .foregroundColor(.red)
                        }
                    },
                    loading: { prevData in
                        VStack {
                            if let products = prevData {
                                ForEach(products) { Text($0.name).opacity(0.5) }
                            }
                            ProgressView("Loading products...")
                        }
                    }
                )
            }
        }
        .navigationTitle("Riverpod Ecosystem")
        .toolbar {
            Button("Refresh") {
                Task {
                    let notifier = container.read(productsProvider.notifier)
                    await notifier.refresh()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RiverpodDemoView()
            .environment(\.providerContainer, ProviderContainer(observers: [ConsoleLogger()]))
    }
}

class ConsoleLogger: ProviderObserver {
    func didUpdateProvider<P: ProviderProtocol>(_ provider: P, oldValue: P.State, newValue: P.State, container: ProviderContainer) {
        print("🚀 [\(provider.name ?? "Provider")] Updated to: \(newValue)")
    }
}
