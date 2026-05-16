import Foundation
import SwiftUI
import Riverpods
import StateKit
import StateKitAtoms
import StateKitDevTools

// MARK: - Models

struct Product: Sendable, Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let imageURL: String
    let description: String
    let inStock: Bool

    static let samples = [
        Product(id: "p1", name: "Laptop", price: 999.99, imageURL: "laptop.jpg", description: "High-performance laptop", inStock: true),
        Product(id: "p2", name: "Wireless Mouse", price: 29.99, imageURL: "mouse.jpg", description: "Ergonomic wireless mouse", inStock: true),
        Product(id: "p3", name: "USB-C Cable", price: 19.99, imageURL: "cable.jpg", description: "Fast USB-C cable", inStock: false),
    ]
}

struct CartItem: Sendable, Codable, Identifiable {
    let id: String
    let product: Product
    var quantity: Int

    var subtotal: Double { product.price * Double(quantity) }
}

struct Order: Sendable, Codable, Identifiable {
    let id: String
    let items: [CartItem]
    let total: Double
    let createdAt: Date
    let status: OrderStatus

    enum OrderStatus: String, Sendable, Codable {
        case pending, processing, shipped, delivered
    }
}

struct User: Sendable, Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let isAuthenticated: Bool
}

// MARK: - Atoms (Shared State)

// User authentication state
@SKStateAtom
var userAtom: User = User(id: "", email: "", name: "", isAuthenticated: false)

// Shopping cart
@SKStateAtom
var cartAtom: [CartItem] = []

// Orders history
@SKStateAtom
var ordersAtom: [Order] = []

// UI state
@SKStateAtom
var isLoadingAtom: Bool = false

// MARK: - Riverpods (Provider Pattern)

/// Fetches products from API (simulated)
let productsProvider = FutureProvider { ref -> [Product] in
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
    return Product.samples
}

/// Product search with family
let searchProductsProvider = FutureProvider.family { (ref, query: String) -> [Product] in
    let products = try await ref.watch(productsProvider)
    guard !query.isEmpty else { return products }
    return products.filter { $0.name.lowercased().contains(query.lowercased()) }
}

/// Cart total computation
let cartTotalProvider = Provider { ref -> Double in
    let items = ref.watch(cartAtom)
    return items.reduce(0) { $0 + $1.subtotal }
}

/// Checkout notifier - handles order processing
let checkoutNotifier = NotifierProvider { ref -> CheckoutNotifier in
    CheckoutNotifier(ref: ref)
}

final class CheckoutNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    func checkout() async -> Order {
        ref.read(isLoadingAtom.notifier).state = true

        do {
            // Simulate payment processing
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1s

            let cart = ref.read(cartAtom)
            let total = ref.read(cartTotalProvider)

            let order = Order(
                id: UUID().uuidString,
                items: cart,
                total: total,
                createdAt: Date(),
                status: .pending
            )

            // Save order and clear cart
            ref.read(ordersAtom.notifier).state.append(order)
            ref.read(cartAtom.notifier).state = []

            ref.read(isLoadingAtom.notifier).state = false
            return order
        } catch {
            ref.read(isLoadingAtom.notifier).state = false
            throw error
        }
    }
}

/// Authentication notifier
let authNotifier = NotifierProvider { ref -> AuthNotifier in
    AuthNotifier(ref: ref)
}

final class AuthNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    func login(email: String, password: String) async {
        ref.read(isLoadingAtom.notifier).state = true

        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

        let user = User(
            id: UUID().uuidString,
            email: email,
            name: email.split(separator: "@").first.map(String.init) ?? "User",
            isAuthenticated: true
        )

        ref.read(userAtom.notifier).state = user
        ref.read(isLoadingAtom.notifier).state = false
    }

    func logout() {
        ref.read(userAtom.notifier).state = User(id: "", email: "", name: "", isAuthenticated: false)
        ref.read(cartAtom.notifier).state = []
    }
}

// MARK: - View Example

/// Complete e-commerce app view combining all patterns
struct ECommerceAppView: View {
    @Watch(productAtom: productsProvider) var products
    @Watch(var cart: cartAtom)
    @Watch(var total: cartTotalProvider)
    @Watch(var user: userAtom)
    @Watch(var isLoading: isLoadingAtom)

    @State private var searchQuery = ""
    @State private var showCart = false
    @State private var showCheckout = false
    @State private var showOrders = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("StateKit Shop")
                        .font(.title).bold()

                    Spacer()

                    HStack(spacing: 12) {
                        // Cart button
                        Button(action: { showCart = true }) {
                            HStack {
                                Image(systemName: "cart.fill")
                                Text("\(cart.count)")
                                    .font(.caption).bold()
                            }
                        }

                        // Orders button
                        if user.isAuthenticated {
                            Button(action: { showOrders = true }) {
                                Image(systemName: "list.clipboard")
                            }
                        }

                        // User menu
                        if user.isAuthenticated {
                            Button(user.name) {
                                // Logout action
                            }
                        } else {
                            Button("Login") {
                                Task {
                                    let authRef = ProviderContainer().read(authNotifier)
                                    await authRef.login(email: "user@example.com", password: "password")
                                }
                            }
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))

                // Search
                SearchBar(text: $searchQuery, placeholder: "Search products...")
                    .padding()

                // Products list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(products) { product in
                            ProductCell(product: product, onAdd: {
                                addToCart(product)
                            })
                        }
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showCart) {
                CartView(isPresented: $showCart, onCheckout: {
                    showCheckout = true
                })
            }
            .sheet(isPresented: $showCheckout) {
                CheckoutView(isPresented: $showCheckout)
            }
            .sheet(isPresented: $showOrders) {
                OrdersListView(isPresented: $showOrders)
            }
            .navigationTitle("E-Commerce")
            .overlay(alignment: .bottom) {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                }
            }
        }
    }

    private func addToCart(_ product: Product) {
        // Use atom notifier to update cart
        let container = ProviderContainer()
        let cartNotifier = container.read(cartAtom.notifier)

        if let index = cart.firstIndex(where: { $0.id == product.id }) {
            cart[index].quantity += 1
        } else {
            cart.append(CartItem(id: product.id, product: product, quantity: 1))
        }

        cartNotifier.state = cart
    }
}

// MARK: - UI Components

struct ProductCell: View {
    let product: Product
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(product.name)
                        .font(.headline)

                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("$\(product.price, specifier: "%.2f")")
                        .font(.title3).bold()
                }

                Spacer()

                VStack {
                    if product.inStock {
                        Button(action: onAdd) {
                            Label("Add", systemImage: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text("Out of Stock")
                            .font(.caption).bold()
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .border(Color(.systemGray3))
        .cornerRadius(8)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct CartView: View {
    @Binding var isPresented: Bool
    let onCheckout: () -> Void

    @Watch(var cart: cartAtom)
    @Watch(var total: cartTotalProvider)

    var body: some View {
        NavigationStack {
            VStack {
                if cart.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cart.badge.minus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Your cart is empty")
                            .font(.headline)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        ForEach(cart) { item in
                            CartItemRow(item: item)
                        }
                        .onDelete { indexSet in
                            let container = ProviderContainer()
                            var updated = cart
                            updated.remove(atOffsets: indexSet)
                            container.read(cartAtom.notifier).state = updated
                        }
                    }

                    VStack(spacing: 12) {
                        Divider()

                        HStack {
                            Text("Total:")
                                .font(.headline)
                            Spacer()
                            Text("$\(total, specifier: "%.2f")")
                                .font(.headline).bold()
                        }
                        .padding()

                        Button(action: onCheckout) {
                            Text("Proceed to Checkout")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
            }
            .navigationTitle("Shopping Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.product.name)
                    .font(.headline)
                Text("$\(item.product.price, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("×\(item.quantity)")
                    .font(.headline)
                Text("$\(item.subtotal, specifier: "%.2f")")
                    .font(.caption).bold()
            }
        }
    }
}

struct CheckoutView: View {
    @Binding var isPresented: Bool
    @Watch(var isLoading: isLoadingAtom)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Processing your order...")
                    .font(.headline)

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("Order Placed Successfully!")
                            .font(.headline)

                        Text("Your order has been received and is being processed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Continue Shopping") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct OrdersListView: View {
    @Binding var isPresented: Bool
    @Watch(var orders: ordersAtom)

    var body: some View {
        NavigationStack {
            VStack {
                if orders.isEmpty {
                    Text("No orders yet")
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        ForEach(orders) { order in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Order \(order.id.prefix(8))")
                                        .font(.headline)
                                    Spacer()
                                    Text(order.status.rawValue.capitalized)
                                        .font(.caption).bold()
                                        .padding(4)
                                        .background(statusColor(order.status))
                                        .cornerRadius(4)
                                }

                                Text("\(order.items.count) items • $\(order.total, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(order.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }

    private func statusColor(_ status: Order.OrderStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .shipped: return .purple
        case .delivered: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    ECommerceAppView()
}
