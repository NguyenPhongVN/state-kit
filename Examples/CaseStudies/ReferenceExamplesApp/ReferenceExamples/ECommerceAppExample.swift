import SwiftUI
import StateKitAtoms
import StateKitUI
import StateKitMacros

struct Product: Hashable, Identifiable {
    let id: Int
    let name: String
    let price: Int
}

private let products = [
    Product(id: 1, name: "Keyboard", price: 99),
    Product(id: 2, name: "Mouse", price: 59),
    Product(id: 3, name: "Monitor", price: 249)
]

@StateAtom
private struct CartAtom {
    @MainActor
    func defaultValue(context: SKAtomTransactionContext) -> [Product] { [] }
}

@Computed
private struct TotalAtom {
    @MainActor
    func compute(context: SKAtomTransactionContext) -> Int {
        context.watch(CartAtom.shared).reduce(0) { $0 + $1.price }
    }
}

struct ECommerceAppExampleView: View {
    @SKState(CartAtom.shared) private var cart
    @SKValue(TotalAtom.shared) private var total

    var body: some View {
        Form {
            Section("Catalog") {
                ForEach(products) { product in
                    Button("Add \(product.name) - $\(product.price)") {
                        cart.append(product)
                    }
                }
            }
            Section("Cart") {
                LabeledContent("Items", value: "\(cart.count)")
                LabeledContent("Total", value: "$\(total)")
                Button("Clear cart") { cart = [] }
            }
        }
        .navigationTitle("E-Commerce")
    }
}

#Preview {
    NavigationStack {
        ECommerceAppExampleView()
    }
}
