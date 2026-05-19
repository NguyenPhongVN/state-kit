import SwiftUI
import Riverpods
import StateKitMacros

// MARK: - View

struct RiverpodDemoView: View {
    @Watch(RProvider.ProductNotifierProvider) var productsState
    @Watch(RProvider.cartSummaryProvider) var summary

    @Environment(\.providerContainer) var container

    @ViewBuilder
    private var productsStateView: some View {
        if case .data(let products) = productsState {
            ForEach(products) { product in
                HStack {
                    Text(product.name)
                    Spacer()
                    Text("$\(product.price, specifier: "%.2f")")
                }
            }
        } else if case .error(let err, let prevData) = productsState {
            VStack(alignment: .leading, spacing: 8) {
                if let products = prevData {
                    ForEach(products) { Text($0.name).opacity(0.5) }
                }
                Text("Error: \(err.localizedDescription)")
                    .foregroundColor(.red)
            }
        } else if case .loading(let prevData) = productsState {
            VStack(spacing: 12) {
                if let products = prevData {
                    ForEach(products) { Text($0.name).opacity(0.5) }
                }
                ProgressView("Loading products...")
            }
        } else if case .refreshing(let products) = productsState {
            VStack(spacing: 8) {
                ForEach(products) { Text($0.name).opacity(0.7) }
                ProgressView().scaleEffect(0.8)
            }
        }
    }

    var body: some View {
        List {
            Section("Cart Summary") {
                Text(summary)
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            Section("Products") {
                productsStateView
            }
        }
        .navigationTitle("Riverpod Ecosystem")
        .toolbar {
            Button("Refresh") {
                Task {
                    let notifier = container.read(RProvider.ProductNotifierProvider.notifier)
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
