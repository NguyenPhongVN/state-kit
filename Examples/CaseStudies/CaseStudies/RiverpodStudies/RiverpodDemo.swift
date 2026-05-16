import SwiftUI
import Riverpods
import StateKitAtoms

// MARK: - Models

struct Product: Identifiable, Sendable, Codable {
    let id: Int
    let name: String
    let price: Double
}

// MARK: - Atoms (Ecosystem Bridge Demo)

struct UserBalanceAtom: SKStateAtom, Hashable {
    typealias Value = Double
    func defaultValue(context: SKAtomTransactionContext) -> Double { 1000.0 }
}

// MARK: - Providers

/// Provider quản lý danh sách sản phẩm từ API
class ProductNotifier: AsyncNotifier<[Product]> {
    override var name: String? { "ProductListProvider" }
    
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
        state = await AsyncValue.guard {
            try await build()
        }
    }
}

let productsProvider = AsyncNotifierProvider(cacheTime: 10.0) { ProductNotifier() }

/// Provider tính toán tổng giá trị giỏ hàng, lắng nghe cả Atom và Provider khác
let cartSummaryProvider = Provider(name: "CartSummary") { ref in
    let products = ref.watch(productsProvider).value ?? []
    let balance = ref.watch(UserBalanceAtom()) // Lắng nghe từ Atom hệ thống
    
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
                    error: { error, prevData in
                        VStack(alignment: .leading) {
                            if let products = prevData {
                                ForEach(products) { Text($0.name).opacity(0.5) }
                            }
                            Text("Error: \(error.localizedDescription)")
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
                    await container.refresh(productsProvider).notifier?.refresh()
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
