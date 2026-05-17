import SwiftUI
import Riverpods

struct Product: Hashable, Identifiable { let id: Int; let name: String; let price: Int }
private let products = [Product(id: 1, name: "Keyboard", price: 99), Product(id: 2, name: "Mouse", price: 59), Product(id: 3, name: "Monitor", price: 249)]
private let cartProvider = StateProvider { _ in [Product]() }
private let totalProvider = Provider { ref in ref.watch(cartProvider).reduce(0) { $0 + $1.price } }

struct ECommerceAppExampleView: View {
    @Watch(cartProvider) var cart
    @Watch(totalProvider) var total
    @Environment(\.providerContainer) var container

    var body: some View {
        Form {
            Section("Catalog") {
                ForEach(products) { product in
                    Button("Add \(product.name) - $\(product.price)") {
                        container.read(cartProvider.notifier).state.append(product)
                    }
                }
            }
            Section("Cart") {
                LabeledContent("Items", value: "\(cart.count)")
                LabeledContent("Total", value: "$\(total)")
                Button("Clear cart") { container.read(cartProvider.notifier).state = [] }
            }
        }
        .navigationTitle("E-Commerce")
    }
}
